import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:bavi/models/answer_chunk.dart';
import 'package:bavi/objectbox_store.dart';
import 'package:bavi/objectbox.g.dart';

/// Service for managing answer-memory with semantic search and recency scoring.
/// Handles chunk processing, embedding generation, and cache management.
/// Uses OpenAI text-embedding-3-small for embedding generation.
class AnswerMemoryService {
  static AnswerMemoryService? _instance;

  AnswerMemoryService._internal();

  static AnswerMemoryService get instance {
    _instance ??= AnswerMemoryService._internal();
    return _instance!;
  }

  /// Reuse threshold - if match score exceeds this, update existing instead of storing new
  /// Set very high (0.95) to only merge nearly identical chunks
  static const double reuseThreshold = 0.95;

  /// Confidence decay factor applied on each reuse
  static const double confidenceDecayFactor = 0.98;

  /// Top-K results to fetch in vector search
  static const int topK = 10;

  /// Cached status of whether memory system is available (models installed)
  bool? _isAvailable;

  /// Check if the answer memory system is available (ObjectBox + API key).
  /// This is a quick check that won't interrupt the normal query flow.
  /// Initializes ObjectBox lazily on first call.
  Future<bool> isAvailable() async {
    if (_isAvailable != null) return _isAvailable!;

    try {
      // Check if OpenAI API key is configured
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('ℹ️ Answer memory disabled: OPENAI_API_KEY not configured');
        _isAvailable = false;
        return false;
      }

      // Try to initialize ObjectBox lazily (will fail gracefully on hot restart)
      final objectBox = await ObjectBoxStore.initialize();
      if (objectBox == null || objectBox.store == null) {
        debugPrint('ℹ️ Answer memory disabled: ObjectBox not available');
        _isAvailable = false;
        return false;
      }

      _isAvailable = true;
      debugPrint('✅ Answer memory system available');
      return true;
    } catch (e) {
      debugPrint('⚠️ Answer memory check failed: $e');
      _isAvailable = false;
      return false;
    }
  }

  // ============================================
  // CHUNK SPLITTING
  // ============================================

  /// Maximum characters per chunk - Gecko embedder has ~256 token limit
  /// Using 400 chars to be safely under the limit (some text tokenizes poorly)
  static const int maxChunkChars = 400;

  /// Split answer text into atomic chunks that fit embedder limits.
  List<String> splitIntoChunks(String text) {
    if (text.trim().isEmpty) return [];

    // Split by sentence-ending punctuation, keeping the punctuation
    final sentencePattern = RegExp(r'(?<=[.!?])\s+');
    final sentences =
        text.split(sentencePattern).where((s) => s.trim().isNotEmpty).toList();

    if (sentences.isEmpty) return [];

    // Build chunks that stay under the character limit
    final chunks = <String>[];
    String currentChunk = '';

    for (final sentence in sentences) {
      final trimmedSentence = sentence.trim();

      // If single sentence exceeds limit, truncate it
      if (trimmedSentence.length > maxChunkChars) {
        // Save current chunk if exists
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
          currentChunk = '';
        }
        // Truncate and add the long sentence
        chunks.add(trimmedSentence.substring(0, maxChunkChars));
        continue;
      }

      // Check if adding this sentence would exceed limit
      if ((currentChunk.length + trimmedSentence.length + 1) > maxChunkChars) {
        // Save current chunk and start new one
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
        }
        currentChunk = trimmedSentence;
      } else {
        // Add to current chunk
        currentChunk = currentChunk.isEmpty
            ? trimmedSentence
            : '$currentChunk $trimmedSentence';
      }
    }

    // Don't forget the last chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    debugPrint('📝 Split answer into ${chunks.length} chunks');
    return chunks;
  }

  // ============================================
  // CHUNK CLASSIFICATION (Heuristic-based)
  // ============================================

  /// Classify a chunk as info (factual/reusable) or not-info using heuristics.
  /// Returns true if the chunk contains useful factual information.
  bool classifyChunkAsInfo(String chunk) {
    return _heuristicClassify(chunk);
  }

  /// Simple heuristic fallback for classification
  bool _heuristicClassify(String chunk) {
    final lower = chunk.toLowerCase();
    // Exclude greetings, questions, and very short chunks
    if (chunk.length < 20) return false;
    if (lower.startsWith('hi') ||
        lower.startsWith('hello') ||
        lower.startsWith('hey')) return false;
    if (chunk.endsWith('?')) return false;
    if (lower.contains('sorry') ||
        lower.contains("i can't") ||
        lower.contains("i don't")) return false;
    return true;
  }

  // ============================================
  // EMBEDDING GENERATION (OpenAI API)
  // ============================================

  /// Generate embedding for the given text using OpenAI text-embedding-3-small.
  /// Returns a 1536-dimensional embedding vector.
  Future<List<double>?> generateEmbedding(String text) async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('⚠️ OPENAI_API_KEY not configured');
        return null;
      }

      // Truncate text to avoid token limits (8191 tokens max for text-embedding-3-small)
      // Approximate: 1 token ≈ 4 chars, so ~32000 chars max
      final truncatedText =
          text.length > 30000 ? text.substring(0, 30000) : text;

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/embeddings'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'text-embedding-3-small',
          'input': truncatedText,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
            '❌ OpenAI embedding API error: ${response.statusCode} ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body);
      final embeddingData = json['data']?[0]?['embedding'];

      if (embeddingData == null) {
        debugPrint('⚠️ No embedding in response');
        return null;
      }

      final embedding =
          (embeddingData as List).map((e) => (e as num).toDouble()).toList();

      debugPrint('🔢 Generated ${embedding.length}-dim embedding via OpenAI');
      return embedding;
    } catch (e) {
      debugPrint('❌ Embedding generation error: $e');
      return null;
    }
  }

  // ============================================
  // VECTOR SEARCH WITH RECENCY SCORING
  // ============================================

  /// Compute the recency weight based on lastUsedAt timestamp.
  /// - 1.0 if used within 24 hours
  /// - Linear decay to 0.3 between 1-7 days
  /// - 0.1 if older than 7 days
  double computeRecencyWeight(DateTime lastUsedAt) {
    final now = DateTime.now();
    final daysSinceUse = now.difference(lastUsedAt).inHours / 24.0;

    if (daysSinceUse <= 1) {
      return 1.0;
    } else if (daysSinceUse <= 7) {
      // Linear decay from 1.0 to 0.3 over 6 days
      return 1.0 - (daysSinceUse - 1) * (0.7 / 6);
    } else {
      return 0.1;
    }
  }

  /// Compute final match score: similarity × recencyWeight × confidence
  double computeFinalScore(
      double similarity, DateTime lastUsedAt, double confidence) {
    final recencyWeight = computeRecencyWeight(lastUsedAt);
    return similarity * recencyWeight * confidence;
  }

  /// Search for similar chunks using ObjectBox vector search.
  /// Returns list of (chunk, score) pairs sorted by final score descending.
  Future<List<({AnswerChunk chunk, double score})>> searchSimilarChunks(
      List<double> queryEmbedding) async {
    try {
      final objectBox = ObjectBoxStore.instanceOrNull;
      if (objectBox == null || objectBox.store == null) {
        debugPrint('⚠️ ObjectBox not available for vector search');
        return [];
      }

      final box = objectBox.store!.box<AnswerChunk>();

      // Perform HNSW nearest neighbor search
      final query = box
          .query(AnswerChunk_.embedding.nearestNeighborsF32(
              queryEmbedding.map((e) => e.toDouble()).toList(), topK))
          .build();

      final results = query.findWithScores();
      query.close();

      // Calculate final scores with recency weighting
      final scoredResults = results.map((result) {
        final chunk = result.object;
        // ObjectBox returns L2 (Euclidean) distance - lower is more similar
        // Convert to similarity using: similarity = 1 / (1 + distance)
        // This maps distance 0 -> similarity 1, distance ∞ -> similarity 0
        final rawDistance = result.score;
        final similarity = 1.0 / (1.0 + rawDistance);
        final recencyWeight = computeRecencyWeight(chunk.lastUsedAt);
        final finalScore = similarity * recencyWeight * chunk.confidence;

        debugPrint(
            '  🔢 Raw distance: ${rawDistance.toStringAsFixed(3)}, similarity: ${similarity.toStringAsFixed(3)}, recency: ${recencyWeight.toStringAsFixed(2)}, final: ${finalScore.toStringAsFixed(3)}');

        return (chunk: chunk, score: finalScore);
      }).toList();

      // Sort by final score descending
      scoredResults.sort((a, b) => b.score.compareTo(a.score));

      debugPrint('🔍 Found ${scoredResults.length} similar chunks');
      return scoredResults;
    } catch (e) {
      debugPrint('❌ Vector search error: $e');
      return [];
    }
  }

  // ============================================
  // STORAGE & DEDUPLICATION
  // ============================================

  /// Store a new chunk or update an existing match if score exceeds threshold.
  Future<void> storeOrUpdateChunk({
    required String text,
    required List<double> embedding,
    required String sourceQuery,
    List<({AnswerChunk chunk, double score})>? existingMatches,
  }) async {
    final objectBox = ObjectBoxStore.instanceOrNull;
    if (objectBox == null || objectBox.store == null) {
      debugPrint('⚠️ ObjectBox not available for storing chunk');
      return;
    }

    final box = objectBox.store!.box<AnswerChunk>();
    final now = DateTime.now();

    // Check if we have a high-scoring existing match
    if (existingMatches != null && existingMatches.isNotEmpty) {
      final bestMatch = existingMatches.first;
      if (bestMatch.score >= reuseThreshold) {
        // Update existing chunk instead of storing new
        final existingChunk = bestMatch.chunk;
        existingChunk.lastUsedAt = now;
        existingChunk.confidence *= confidenceDecayFactor;
        box.put(existingChunk);
        debugPrint(
            '♻️ Updated existing chunk (score: ${bestMatch.score.toStringAsFixed(3)})');
        return;
      }
    }

    // Store new chunk
    final newChunk = AnswerChunk(
      text: text,
      embedding: embedding,
      createdAt: now,
      lastUsedAt: now,
      confidence: 1.0,
      sourceQuery: sourceQuery,
    );
    box.put(newChunk);
    debugPrint(
        '💾 Stored new chunk: "${text.substring(0, min(40, text.length))}..."');
  }

  // ============================================
  // MAIN PROCESSING PIPELINE
  // ============================================

  /// Process a generated answer and cache valid info chunks.
  /// Call this after Gemma/Vercel generates a final answer.
  /// Silently skips if models aren't installed - won't interrupt normal flow.
  ///
  /// NOTE: Classification step disabled to avoid Gemma/Gecko conflict.
  /// All chunks are stored directly without INFO/NOT_INFO filtering.
  Future<void> processAndCacheAnswer(String answer, String sourceQuery) async {
    try {
      // Skip if embedder not available
      if (!await isAvailable()) return;

      if (answer.trim().isEmpty) return;

      debugPrint('🧠 Processing answer for memory caching...');

      // Step 1: Split into chunks
      final chunks = splitIntoChunks(answer);

      for (final chunkText in chunks) {
        try {
          // SKIP classification step - causes Gemma/Gecko native conflict
          // Just use basic length/content filter instead
          if (chunkText.length < 50) {
            debugPrint('⏭️ Skipping short chunk');
            continue;
          }

          // Basic filter: skip obvious filler phrases
          final lower = chunkText.toLowerCase();
          if (lower.contains('let me know') ||
              lower.contains('hope this helps') ||
              lower.contains('feel free to ask')) {
            debugPrint('⏭️ Skipping filler chunk');
            continue;
          }

          // Step 2: Generate embedding (Gecko only - no Gemma)
          final embedding = await generateEmbedding(chunkText);
          if (embedding == null) {
            debugPrint('⚠️ Skipping chunk - embedding generation failed');
            continue;
          }

          // Step 3: Search for existing matches
          final existingMatches = await searchSimilarChunks(embedding);

          // Step 4: Store or update
          await storeOrUpdateChunk(
            text: chunkText,
            embedding: embedding,
            sourceQuery: sourceQuery,
            existingMatches: existingMatches,
          );
        } catch (chunkError) {
          debugPrint('⚠️ Error processing chunk, skipping: $chunkError');
          continue;
        }
      }

      debugPrint('✅ Answer memory processing complete');
    } catch (e) {
      debugPrint('❌ Answer memory processing failed (non-fatal): $e');
    }
  }

  /// Find a cached answer for the given query.
  /// Returns the best matching chunk text if a high-confidence match exists.
  /// Returns null silently if models aren't installed - won't interrupt normal flow.
  Future<String?> findCachedAnswer(String query) async {
    // Skip if models not available - don't interrupt normal query flow
    if (!await isAvailable()) return null;

    try {
      debugPrint(
          '🔎 Checking answer memory for: "${query.substring(0, min(50, query.length))}..."');

      // Generate embedding for query
      final queryEmbedding = await generateEmbedding(query);
      if (queryEmbedding == null) return null;

      // Search for similar chunks
      final matches = await searchSimilarChunks(queryEmbedding);
      if (matches.isEmpty) {
        debugPrint('❌ No cached matches found');
        return null;
      }

      final bestMatch = matches.first;
      debugPrint('📊 Best match score: ${bestMatch.score.toStringAsFixed(3)}');

      if (bestMatch.score >= reuseThreshold) {
        // Update lastUsedAt for the matched chunk
        final objectBox = ObjectBoxStore.instanceOrNull;
        if (objectBox != null && objectBox.store != null) {
          final box = objectBox.store!.box<AnswerChunk>();
          final chunk = bestMatch.chunk;
          chunk.lastUsedAt = DateTime.now();
          chunk.confidence *= confidenceDecayFactor;
          box.put(chunk);
        }

        debugPrint('✨ Cache hit! Returning cached answer chunk');
        return bestMatch.chunk.text;
      }

      debugPrint('📉 Best match below threshold, no cache hit');
      return null;
    } catch (e) {
      debugPrint('❌ Cache lookup error: $e');
      return null;
    }
  }

  /// Search memory for relevant content to use in answer generation.
  /// Returns list of relevant memory chunks sorted by score (similarity × recency × confidence).
  /// Use this to enhance AI answers with previously learned information.
  Future<List<({String text, String sourceQuery, double score})>>
      searchRelevantMemory(
    String query, {
    int maxResults = 20,
    double minScore = 0.05,
  }) async {
    if (!await isAvailable()) return [];

    try {
      debugPrint(
          '🧠 Searching memory for: "${query.substring(0, min(50, query.length))}..."');

      // Generate embedding for query
      final queryEmbedding = await generateEmbedding(query);
      if (queryEmbedding == null) {
        debugPrint('⚠️ Failed to generate query embedding');
        return [];
      }

      // Search for similar chunks
      final matches = await searchSimilarChunks(queryEmbedding);

      // Debug: show all scores before filtering
      for (final m in matches) {
        debugPrint(
            '  📊 Chunk score: ${m.score.toStringAsFixed(3)} - "${m.chunk.text.substring(0, min(40, m.chunk.text.length))}..."');
      }

      // Filter by minimum score and limit results
      final relevantChunks = matches
          .where((m) => m.score >= minScore)
          .take(maxResults)
          .map((m) => (
                text: m.chunk.text,
                sourceQuery: m.chunk.sourceQuery,
                score: m.score,
              ))
          .toList();

      debugPrint(
          '📚 Found ${relevantChunks.length} relevant memory chunks (minScore: $minScore)');
      return relevantChunks;
    } catch (e) {
      debugPrint('❌ Memory search error: $e');
      return [];
    }
  }

  /// Get statistics about the answer memory store.
  Future<Map<String, dynamic>> getStats() async {
    try {
      final objectBox = ObjectBoxStore.instanceOrNull;
      if (objectBox == null || objectBox.store == null) {
        return {'error': 'ObjectBox not available'};
      }
      final box = objectBox.store!.box<AnswerChunk>();
      final count = box.count();
      return {
        'totalChunks': count,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

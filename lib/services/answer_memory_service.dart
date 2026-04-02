import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:bavi/models/answer_chunk.dart';
import 'package:bavi/objectbox_store.dart';

/// Service for managing answer-memory with semantic search and recency scoring.
/// Handles chunk processing, text similarity, and cache management.
/// All processing is fully on-device using TF-IDF cosine similarity — no external APIs.
class AnswerMemoryService {
  static AnswerMemoryService? _instance;

  AnswerMemoryService._internal();

  static AnswerMemoryService get instance {
    _instance ??= AnswerMemoryService._internal();
    return _instance!;
  }

  /// Reuse threshold — if match score exceeds this, update existing instead of storing new
  static const double reuseThreshold = 0.95;

  /// Confidence decay factor applied on each reuse
  static const double confidenceDecayFactor = 0.98;

  /// Top-K results to return from similarity search
  static const int topK = 10;

  /// Cached availability status
  bool? _isAvailable;

  /// Check if the answer memory system is available (ObjectBox ready).
  Future<bool> isAvailable() async {
    if (_isAvailable != null) return _isAvailable!;

    try {
      final objectBox = await ObjectBoxStore.initialize();
      if (objectBox == null || objectBox.store == null) {
        debugPrint('ℹ️ Answer memory disabled: ObjectBox not available');
        _isAvailable = false;
        return false;
      }

      _isAvailable = true;
      debugPrint('✅ Answer memory system available (on-device)');
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

  /// Maximum characters per chunk
  static const int maxChunkChars = 400;

  /// Split answer text into atomic chunks.
  List<String> splitIntoChunks(String text) {
    if (text.trim().isEmpty) return [];

    final sentencePattern = RegExp(r'(?<=[.!?])\s+');
    final sentences =
        text.split(sentencePattern).where((s) => s.trim().isNotEmpty).toList();

    if (sentences.isEmpty) return [];

    final chunks = <String>[];
    String currentChunk = '';

    for (final sentence in sentences) {
      final trimmedSentence = sentence.trim();

      if (trimmedSentence.length > maxChunkChars) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
          currentChunk = '';
        }
        chunks.add(trimmedSentence.substring(0, maxChunkChars));
        continue;
      }

      if ((currentChunk.length + trimmedSentence.length + 1) > maxChunkChars) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
        }
        currentChunk = trimmedSentence;
      } else {
        currentChunk = currentChunk.isEmpty
            ? trimmedSentence
            : '$currentChunk $trimmedSentence';
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    debugPrint('📝 Split answer into ${chunks.length} chunks');
    return chunks;
  }

  // ============================================
  // CHUNK CLASSIFICATION
  // ============================================

  /// Returns true if the chunk contains useful factual information.
  bool classifyChunkAsInfo(String chunk) {
    return _heuristicClassify(chunk);
  }

  bool _heuristicClassify(String chunk) {
    final lower = chunk.toLowerCase();
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
  // ON-DEVICE TEXT SIMILARITY (TF-IDF cosine)
  // ============================================

  static const List<String> _stopWords = [
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were', 'be', 'been',
    'it', 'its', 'this', 'that', 'as', 'if', 'so', 'do', 'not', 'no',
  ];

  /// Tokenize text into lowercase words, filtering stop words.
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
  }

  /// Compute a normalized TF vector (unit vector in term space).
  Map<String, double> _tfVector(List<String> tokens) {
    final tf = <String, double>{};
    for (final token in tokens) {
      tf[token] = (tf[token] ?? 0) + 1;
    }
    final norm =
        sqrt(tf.values.map((v) => v * v).fold(0.0, (a, b) => a + b));
    if (norm > 0) {
      tf.updateAll((_, v) => v / norm);
    }
    return tf;
  }

  /// Cosine similarity between two unit TF vectors. Result in [0, 1].
  double _cosineSimilarity(Map<String, double> a, Map<String, double> b) {
    double dot = 0;
    for (final entry in a.entries) {
      final bVal = b[entry.key];
      if (bVal != null) dot += entry.value * bVal;
    }
    return dot.clamp(0.0, 1.0);
  }

  // ============================================
  // SIMILARITY SEARCH
  // ============================================

  /// Score all stored chunks against the query tokens and return top-K by final score.
  List<({AnswerChunk chunk, double score})> _searchChunks(
      Map<String, double> queryVector) {
    final objectBox = ObjectBoxStore.instanceOrNull;
    if (objectBox == null || objectBox.store == null) return [];

    final box = objectBox.store!.box<AnswerChunk>();
    final allChunks = box.getAll();

    final results = <({AnswerChunk chunk, double score})>[];

    for (final chunk in allChunks) {
      final chunkTokens = _tokenize(chunk.text);
      final chunkVector = _tfVector(chunkTokens);
      final similarity = _cosineSimilarity(queryVector, chunkVector);
      final recencyWeight = computeRecencyWeight(chunk.lastUsedAt);
      final finalScore = similarity * recencyWeight * chunk.confidence;

      results.add((chunk: chunk, score: finalScore));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }

  // ============================================
  // RECENCY SCORING
  // ============================================

  double computeRecencyWeight(DateTime lastUsedAt) {
    final daysSinceUse = DateTime.now().difference(lastUsedAt).inHours / 24.0;

    if (daysSinceUse <= 1) {
      return 1.0;
    } else if (daysSinceUse <= 7) {
      return 1.0 - (daysSinceUse - 1) * (0.7 / 6);
    } else {
      return 0.1;
    }
  }

  // ============================================
  // STORAGE & DEDUPLICATION
  // ============================================

  void _storeOrUpdateChunk({
    required String text,
    required Map<String, double> textVector,
    required String sourceQuery,
    required List<({AnswerChunk chunk, double score})> existingMatches,
  }) {
    final objectBox = ObjectBoxStore.instanceOrNull;
    if (objectBox == null || objectBox.store == null) return;

    final box = objectBox.store!.box<AnswerChunk>();
    final now = DateTime.now();

    if (existingMatches.isNotEmpty) {
      final bestMatch = existingMatches.first;
      if (bestMatch.score >= reuseThreshold) {
        final existingChunk = bestMatch.chunk;
        existingChunk.lastUsedAt = now;
        existingChunk.confidence *= confidenceDecayFactor;
        box.put(existingChunk);
        debugPrint(
            '♻️ Updated existing chunk (score: ${bestMatch.score.toStringAsFixed(3)})');
        return;
      }
    }

    box.put(AnswerChunk(
      text: text,
      createdAt: now,
      lastUsedAt: now,
      confidence: 1.0,
      sourceQuery: sourceQuery,
    ));
    debugPrint(
        '💾 Stored new chunk: "${text.substring(0, min(40, text.length))}..."');
  }

  // ============================================
  // MAIN PROCESSING PIPELINE
  // ============================================

  /// Process a generated answer and cache valid info chunks.
  Future<void> processAndCacheAnswer(String answer, String sourceQuery) async {
    try {
      if (!await isAvailable()) return;
      if (answer.trim().isEmpty) return;

      debugPrint('🧠 Processing answer for memory caching...');

      final chunks = splitIntoChunks(answer);

      for (final chunkText in chunks) {
        try {
          if (chunkText.length < 50) continue;

          final lower = chunkText.toLowerCase();
          if (lower.contains('let me know') ||
              lower.contains('hope this helps') ||
              lower.contains('feel free to ask')) {
            continue;
          }

          final tokens = _tokenize(chunkText);
          if (tokens.isEmpty) continue;

          final vector = _tfVector(tokens);
          final existingMatches = _searchChunks(vector);

          _storeOrUpdateChunk(
            text: chunkText,
            textVector: vector,
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
  Future<String?> findCachedAnswer(String query) async {
    if (!await isAvailable()) return null;

    try {
      final tokens = _tokenize(query);
      if (tokens.isEmpty) return null;

      final vector = _tfVector(tokens);
      final matches = _searchChunks(vector);
      if (matches.isEmpty) return null;

      final bestMatch = matches.first;
      debugPrint('📊 Best match score: ${bestMatch.score.toStringAsFixed(3)}');

      if (bestMatch.score >= reuseThreshold) {
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

      return null;
    } catch (e) {
      debugPrint('❌ Cache lookup error: $e');
      return null;
    }
  }

  /// Search memory for relevant content to use in answer generation.
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

      final tokens = _tokenize(query);
      if (tokens.isEmpty) return [];

      final vector = _tfVector(tokens);
      final matches = _searchChunks(vector);

      return matches
          .where((m) => m.score >= minScore)
          .take(maxResults)
          .map((m) => (
                text: m.chunk.text,
                sourceQuery: m.chunk.sourceQuery,
                score: m.score,
              ))
          .toList();
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
      return {'totalChunks': objectBox.store!.box<AnswerChunk>().count()};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

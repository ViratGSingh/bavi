import 'package:objectbox/objectbox.dart';

/// Represents an atomic cached answer chunk with semantic embedding.
/// Used for local offline answer-memory with recency-aware retrieval.
@Entity()
class AnswerChunk {
  @Id()
  int id = 0;

  /// The atomic text chunk (1-2 sentences of factual/info content)
  String text;

  /// 1536-dimensional OpenAI text-embedding-3-small for semantic similarity search
  @HnswIndex(dimensions: 1536)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  /// When this chunk was first created
  @Property(type: PropertyType.date)
  DateTime createdAt;

  /// When this chunk was last used/matched (for recency scoring)
  @Property(type: PropertyType.date)
  DateTime lastUsedAt;

  /// Confidence score (starts at 1.0, decays slightly on each reuse)
  double confidence;

  /// The original query that generated this chunk
  String sourceQuery;

  AnswerChunk({
    required this.text,
    this.embedding,
    required this.createdAt,
    required this.lastUsedAt,
    this.confidence = 1.0,
    required this.sourceQuery,
  });
}

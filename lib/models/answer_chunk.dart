import 'package:objectbox/objectbox.dart';

/// Represents an atomic cached answer chunk with on-device text similarity.
/// Used for local offline answer-memory with recency-aware retrieval.
@Entity()
class AnswerChunk {
  @Id()
  int id = 0;

  /// The atomic text chunk (1-2 sentences of factual/info content)
  String text;

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
    required this.createdAt,
    required this.lastUsedAt,
    this.confidence = 1.0,
    required this.sourceQuery,
  });
}

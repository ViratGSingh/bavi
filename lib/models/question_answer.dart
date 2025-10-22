import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AnswerData extends Equatable {
  const AnswerData({
    required this.reply,
    required this.process,
    required this.sourceLinks,
    required this.createdAt,
    required this.updatedAt,
  });

  final String reply;
  final String process;
  final List<String> sourceLinks;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  @override
  List<Object?> get props => [reply, process, sourceLinks, createdAt, updatedAt];

  factory AnswerData.fromJson(Map<String, dynamic> json) {
    return AnswerData(
      reply: json['reply'] as String,
      process: json['process'] as String,
      sourceLinks: (json['source_links'] as List<dynamic>).map((e) => e.toString()).toList(),
      createdAt: json['created_at'] != null ? json['created_at'] as Timestamp : null,
      updatedAt: json['updated_at'] != null ? json['updated_at'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reply': reply,
      'process': process,
      'source_links': sourceLinks,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class SearchData extends Equatable {
  const SearchData({
    required this.id,
    required this.query,
    required this.answer,
    required this.process,
    required this.createdAt,
    required this.updatedAt,
    required this.sourceLinks
  });

  final String id;
  final String query;
  final String answer;
  final String process;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final List<String> sourceLinks;

  @override
  List<Object?> get props => [id, query, answer, process, sourceLinks, createdAt, updatedAt];

  factory SearchData.fromJson(Map<String, dynamic> json) {
    return SearchData(
      id: json['id'] as String,
      query: json['query'] as String,
      answer: json['answer'] as String,
      process: json['process'] as String,
      sourceLinks: (json['source_links'] as List<dynamic>).map((e) => e.toString()).toList(),
      createdAt: json['created_at'] != null ? json['created_at'] as Timestamp : null,
      updatedAt: json['updated_at'] != null ? json['updated_at'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query':query,
      'answer': answer,
      'process':process,
      'source_links': sourceLinks,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

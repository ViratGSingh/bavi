import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class QuestionAnswerData extends Equatable {
  const QuestionAnswerData({
    required this.reply,
    required this.query,
    required this.createdAt,
    required this.updatedAt,
  });

  final String reply;
  final String query;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  @override
  List<Object?> get props => [reply, query];

  factory QuestionAnswerData.fromJson(Map<String, dynamic> json) {
    return QuestionAnswerData(
      query: json['query'] as String,
      reply: json['reply'] as String,
      createdAt: json['created_at'] != null ? json['created_at'] as Timestamp : null,
      updatedAt: json['updated_at'] != null ? json['updated_at'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'reply': reply,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class ConversationData extends Equatable {
  const ConversationData({
    required this.id,
    required this.conversation,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final List<QuestionAnswerData> conversation;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  @override
  List<Object?> get props => [id, conversation, createdAt, updatedAt];

  factory ConversationData.fromJson(Map<String, dynamic> json) {
    return ConversationData(
      id: json['id'] as String,
      conversation: (json['conversation'] as List)
          .map((e) => QuestionAnswerData.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null ? json['created_at'] as Timestamp : null,
      updatedAt: json['updated_at'] != null ? json['updated_at'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation': conversation.map((e) => e.toJson()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

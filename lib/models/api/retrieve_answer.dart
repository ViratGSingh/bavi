import 'package:equatable/equatable.dart';

class RetrieveAnswerResponse extends Equatable {
  const RetrieveAnswerResponse({
    required this.query,
    required this.process,
    required this.answer,
    required this.sourceUrls,
  });

  final String query;
  final String process;
  final String answer;
  final List<String> sourceUrls;

  @override
  List<Object> get props => [query, process, answer, sourceUrls];

  factory RetrieveAnswerResponse.fromJson(Map<String, dynamic> json) {
    return RetrieveAnswerResponse(
      query: json['query'] as String,
      process: json['process'] as String,
      answer: json['answer'] as String,
      sourceUrls: (json['sourceUrls'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'process': process,
      'answer': answer,
      'videos': sourceUrls.map((sourceUrl) => sourceUrl.toString()).toList(),
    };
  }
}

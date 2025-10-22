class SessionData {
  final List<String> sourceUrls;
  final List<String> videos;
  final List<String> questions;
  final List<String> searchTerms;
  final List<String> answers;
  final String email;
  final int understandDuration;
  final int searchDuration;
  final int fetchDuration;
  final int extractDuration;
  final int contentDuration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSearchMode;
  final String? id;

  SessionData(
      {
        required this.sourceUrls,
      required this.videos,
      required this.questions,
      required this.searchTerms,
      required this.answers,
      required this.email,
      required this.understandDuration,
      required this.searchDuration,
      required this.fetchDuration,
      required this.extractDuration,
      required this.contentDuration,
      required this.createdAt,
      required this.updatedAt,
      required this.isSearchMode,
      this.id
      });

  Map<String, dynamic> toJson() {
    return {
      'id':id??"",
      'isSearchMode':isSearchMode,
      'sourceUrls': sourceUrls,
      'videos': videos,
      'questions': questions,
      'searchTerms': searchTerms,
      'answers': answers,
      'email': email,
      'understandDuration': understandDuration,
      'searchDuration': searchDuration,
      'fetchDuration': fetchDuration,
      'extractDuration': extractDuration,
      'contentDuration': contentDuration,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

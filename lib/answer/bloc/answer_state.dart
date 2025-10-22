part of 'answer_bloc.dart';

enum AnswerPageStatus { idle, thinking, loading, summarize,  loadingPics, loadedPics}
enum AnswerThumbnailStatus { idle, loading}

final class AnswerState extends Equatable {
  const AnswerState({
    this.searchAnswer = "",
    this.searchQuery = "",
    this.searchId = "",
    this.searchProcess = "",
    this.sourceUrls = const [],
    this.videoThumbnails=const [],
    this.videoUrls=const [],
    this.status = AnswerPageStatus.idle,
    this.assetStatus = AnswerThumbnailStatus.idle,
  });
  final String searchAnswer;
  final String searchQuery;
  final String searchId;
  final String searchProcess;
  final List<String> sourceUrls;
  final List<String> videoThumbnails;
  final List<String> videoUrls;
  final AnswerThumbnailStatus assetStatus;
  final AnswerPageStatus status;
  AnswerState copyWith({
    List<String>? sourceUrls,
    String? searchAnswer,
    String? searchQuery,
    String? searchId,
    String? searchProcess,
    List<String>? videoThumbnails,
    List<String>? videoUrls,
    AnswerThumbnailStatus? assetStatus,
    AnswerPageStatus? status
  }) {
    return AnswerState(
      searchAnswer: searchAnswer ?? this.searchAnswer,
      searchQuery: searchQuery ?? this.searchQuery,
      searchId: searchId ?? this.searchId,
      searchProcess: searchProcess ?? this.searchProcess,
      sourceUrls: sourceUrls ?? this.sourceUrls,
      videoThumbnails: videoThumbnails ?? this.videoThumbnails,
      videoUrls: videoUrls ?? this.videoUrls,
      assetStatus: assetStatus ?? this.assetStatus,
      status: status ?? this.status,
      );
  }

  @override
  List<Object?> get props => [searchAnswer, searchQuery, searchId, searchProcess, sourceUrls, videoThumbnails, videoUrls, status, assetStatus];
}

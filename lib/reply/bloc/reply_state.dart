part of 'reply_bloc.dart';

enum NavBarOption { home, search, player, profile }

enum ReplyPageStatus { idle, thinking, loading, summarize,  loadingPics, loadedPics}
enum ReplyThumbnailStatus { idle, loading}

final class ReplyState extends Equatable {
  ReplyState({
    this.page = NavBarOption.home,
    this.status = ReplyPageStatus.idle,
    this.assetStatus = ReplyThumbnailStatus.idle,
    this.searchAnswer = "",
    this.searchQuery = "",
    this.searchId = "",
    this.answerNumber = 1,
    this.thinking = "",
    this.videoThumbnails=const [],
    this.videoUrls=const []
  });
  final String thinking;
  final String searchQuery;
  final String searchId;
  final List<String> videoThumbnails;
  final List<String> videoUrls;
  final int answerNumber;
  final NavBarOption page;
  final ReplyPageStatus status;
  final ReplyThumbnailStatus assetStatus;
  final String searchAnswer;
  ReplyState copyWith({
    int? answerNumber,
    List<String>? videoThumbnails,
    List<String>? videoUrls,
    String? thinking,
    String? searchQuery,
    String? searchId,
    NavBarOption? page,
    ExtractedAccountInfo? account,
    ReplyPageStatus? status,
    ReplyThumbnailStatus? assetStatus,
    String? searchAnswer,
  }) {
    return ReplyState(
      videoThumbnails: videoThumbnails ?? this.videoThumbnails,
      videoUrls: videoUrls ?? this.videoUrls,
      answerNumber: answerNumber?? this.answerNumber,
      searchAnswer: searchAnswer ?? this.searchAnswer,
      thinking: thinking ?? this.thinking,
      searchQuery: searchQuery ?? this.searchQuery,
      searchId: searchId ?? this.searchId,
      page: page ?? this.page,
      status: status ?? this.status,
      assetStatus: assetStatus ?? this.assetStatus,
      );
  }

  @override
  List<Object?> get props => [page, answerNumber, videoThumbnails,videoUrls, searchId, thinking, status, assetStatus, searchAnswer, searchQuery];
}

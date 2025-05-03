part of 'reply_bloc.dart';

enum NavBarOption { home, search, player, profile }

enum ReplyPageStatus { idle, loading, generateQuery, getSearchResults,summarize,  success, failure}

final class ReplyState extends Equatable {
  ReplyState({
    this.page = NavBarOption.home,
    this.status = ReplyPageStatus.idle,
    this.searchResults = const [],
    this.conversationData = const [],
    this.searchInstaResults = const [],
    this.searchYouTubeResults = const [],
    this.searchAnswer = "",
    this.videos = const [],
    this.collectionsVideos = const [],
    this.collections = const [],
    this.allVideoPlatformData = const {},
    this.account = const ExtractedAccountInfo.empty(),
    this.searchQuery = ""
  });
  final String searchQuery;
  final NavBarOption page;
  final ReplyPageStatus status;
  final List<QuestionAnswerData> conversationData;
  final List<ExtractedVideoInfo> searchResults;
  final List<ExtractedVideoInfo> searchInstaResults;
  final List<ExtractedVideoInfo> searchYouTubeResults;
  final Map<String, dynamic> allVideoPlatformData;
  final List<ExtractedVideoInfo> videos;
  final List<List<ExtractedVideoInfo>> collectionsVideos;
  final List<VideoCollectionInfo> collections;
  final String searchAnswer;
  ExtractedAccountInfo account;
  ReplyState copyWith({
    String? searchQuery,
    NavBarOption? page,
    ExtractedAccountInfo? account,
    ReplyPageStatus? status,
    String? searchAnswer,
    List<ExtractedVideoInfo>? searchResults,
    List<QuestionAnswerData>? conversationData,
    List<ExtractedVideoInfo>? searchInstaResults,
    List<ExtractedVideoInfo>? searchYouTubeResults,
    List<ExtractedVideoInfo>? videos,
    List<List<ExtractedVideoInfo>>? collectionsVideos,
    List<VideoCollectionInfo>? collections,
    Map<String, dynamic>? allVideoPlatformData,
  }) {
    return ReplyState(
      searchAnswer: searchAnswer ?? this.searchAnswer,
      searchQuery: searchQuery ?? this.searchQuery,
      account: account ?? this.account,
      page: page ?? this.page,
      status: status ?? this.status,
      searchResults: searchResults ?? this.searchResults,
      conversationData: conversationData ?? this.conversationData,
      searchInstaResults: searchInstaResults ?? this.searchInstaResults,
      searchYouTubeResults: searchYouTubeResults ?? this.searchYouTubeResults,
      videos: videos ?? this.videos,
      collectionsVideos: collectionsVideos ?? this.collectionsVideos,
      collections: collections ?? this.collections,
      allVideoPlatformData: allVideoPlatformData ?? this.allVideoPlatformData,
    );
  }

  @override
  List<Object?> get props => [page,account, status, conversationData, searchResults, searchAnswer, searchInstaResults, searchYouTubeResults, videos, collectionsVideos, collections, allVideoPlatformData];
}

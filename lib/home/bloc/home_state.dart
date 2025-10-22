part of 'home_bloc.dart';

enum NavBarOption { home, search, player, profile }

enum HomePageStatus {
  changingMode,
  idle,
  loading,
  generateQuery,
  getSearchResults,
  getResultVideos,
  watchResultVideos,
  filterSearchResults,
  summarize,
  success,
  failure,
  recallVideos,
  genScreenshot
}

enum HomeReplyStatus { loading, success, failure, idle }
enum HomeSavedStatus { fetched, idle }
enum HomeHistoryStatus { loading, idle }

enum HomeProfileStatus { loading, success, failure, idle }

final class HomeState extends Equatable {
  HomeState(
      {UserProfileInfo? userData,
      this.page = NavBarOption.home,
      this.status = HomePageStatus.idle,
      this.replyStatus = HomeReplyStatus.idle,
      this.savedStatus = HomeSavedStatus.idle,
      this.historyStatus = HomeHistoryStatus.idle,
      this.profileStatus = HomeProfileStatus.idle,
      this.searchResults = const [],
      this.generalSearchResults = const [],
      this.shortVideoResults = const [],
      this.replyContext = const [],
      this.videoResults = const [],
      this.followupQuestions = const [],
      this.followupAnswers = const [],
      this.searchAnswer = "",
      this.sessionId = "",
      this.searchAnswerChunk = "",
      this.videosCount = 0,
      this.isSearchMode = false,
      this.isIncognito = false,
      this.totalContentDuration = 0,
      SessionData? sessionData,
      this.account = const ExtractedAccountInfo(
          accountId: "bengaluru_food_scene",
          username: "Let us put one full scene together",
          fullname: "Bengaluru Food Scene",
          profilePicUrl:
              "https://bavi.s3.ap-south-1.amazonaws.com/profiles/bengaluru_food_scene.png",
          isVerified: false,
          isPrivate: false),
      this.searchQuery = "",
      this.userQuery = "",
      this.sessionHistory = const []})
      : userData = userData ??
            UserProfileInfo(
              email: "NA",
              fullname: "NA",
              username: "NA",
              profilePicUrl: "NA",
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
              searchHistory: [],
            ),
        sessionData = sessionData ??
            SessionData(
              isSearchMode: true,
              id:"",
              sourceUrls: [],
              videos: [],
              questions: [],
              searchTerms: [],
              answers: [],
              email: "",
              understandDuration: 0,
              searchDuration: 0,
              fetchDuration: 0,
              extractDuration: 0,
              contentDuration: 0,
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            );
  final String searchQuery;
  final String searchAnswerChunk;
  final String userQuery;
  final String sessionId;
  final UserProfileInfo userData;
  final SessionData sessionData;
  final NavBarOption page;
  final HomePageStatus status;
  final HomeReplyStatus replyStatus;
  final HomeSavedStatus savedStatus;
  final HomeHistoryStatus historyStatus;
  final HomeProfileStatus profileStatus;
  final List<SessionData> sessionHistory;
  final List<String> followupQuestions;
  final List<String> followupAnswers;
  final List<ExtractedVideoInfo> searchResults;
  final List<ExtractedResultInfo> generalSearchResults;
  final List<ExtractedVideoInfo> shortVideoResults;
  final List<ExtractedVideoInfo> videoResults;
  final List<ResultVideoItem> replyContext;
  final String searchAnswer;
  final int videosCount;
  final int totalContentDuration;
  final bool isSearchMode;
  final bool isIncognito;
  ExtractedAccountInfo account;
  HomeState copyWith({
    String? searchQuery,
    String? userQuery,
    String? searchAnswerChunk,
    String? sessionId,
    bool? isSearchMode,
    bool? isIncognito,
    UserProfileInfo? userData,
    SessionData? sessionData,
    List<ResultVideoItem>? replyContext,
    NavBarOption? page,
    ExtractedAccountInfo? account,
    HomePageStatus? status,
    HomeReplyStatus? replyStatus,
    HomeSavedStatus? savedStatus,
    HomeHistoryStatus? historyStatus,
    HomeProfileStatus? profileStatus,
    String? searchAnswer,
    int? videosCount,
    int? totalContentDuration,
    List<SessionData>? sessionHistory,
    List<String>? followupQuestions,
    List<String>? followupAnswers,
    List<ExtractedVideoInfo>? searchResults,
    List<ExtractedResultInfo>? generalSearchResults,
    List<ExtractedVideoInfo>? shortVideoResults,
    List<ExtractedVideoInfo>? videoResults,
  }) {
    return HomeState(
      isSearchMode: isSearchMode ?? this.isSearchMode,
      isIncognito: isIncognito ?? this.isIncognito,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      searchAnswer: searchAnswer ?? this.searchAnswer,
      searchAnswerChunk: searchAnswerChunk??this.searchAnswerChunk,
      searchQuery: searchQuery ?? this.searchQuery,
      userQuery: userQuery ?? this.userQuery,
      account: account ?? this.account,
      userData: userData ?? this.userData,
      sessionData: sessionData ?? this.sessionData,
      page: page ?? this.page,
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      replyStatus: replyStatus ?? this.replyStatus,
      savedStatus: savedStatus ?? this.savedStatus,
      historyStatus: historyStatus ?? this.historyStatus,
      profileStatus: profileStatus ?? this.profileStatus,
      videosCount: videosCount ?? this.videosCount,
      totalContentDuration: totalContentDuration ?? this.totalContentDuration,
      searchResults: searchResults ?? this.searchResults,
      generalSearchResults: generalSearchResults ?? this.generalSearchResults,
      shortVideoResults: shortVideoResults ?? this.shortVideoResults,
      replyContext: replyContext ?? this.replyContext,
      videoResults: videoResults ?? this.videoResults,
      followupQuestions: followupQuestions ?? this.followupQuestions,
      followupAnswers: followupAnswers ?? this.followupAnswers,
    );
  }

  @override
  List<Object?> get props => [
        page,
        searchAnswerChunk,
        account,
        sessionData,
        sessionHistory,
        replyContext,
        profileStatus,
        replyStatus,
        savedStatus,
        historyStatus,
        followupAnswers,
        followupQuestions,
        sessionId,
        totalContentDuration,
        userQuery,
        videosCount,
        status,
        userData,
        sessionHistory,
        searchResults,
        generalSearchResults,
        shortVideoResults,
        videoResults,
        searchAnswer,
        isSearchMode,
        isIncognito
      ];
}

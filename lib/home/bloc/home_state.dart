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

  webSearch,
  shortVideosSearch,
  videosSearch,
  imagesSearch,
  newsSearch
}

enum HomeReplyStatus { loading, success, failure, idle }

enum HomeSavedStatus { fetched, idle }

enum HomeHistoryStatus { loading, idle }

enum HomeProfileStatus { loading, success, failure, idle }

final class HomeState extends Equatable {
  HomeState({
    UserProfileInfo? userData,
    this.page = NavBarOption.home,
    this.status = HomePageStatus.idle,
    this.replyStatus = HomeReplyStatus.idle,
    this.historyStatus = HomeHistoryStatus.idle,
    this.profileStatus = HomeProfileStatus.idle,
    this.sessionId = "",
    this.loadingIndex = 0,
    this.backgroundLoading = true,
    this.isSearchMode = true,
    this.isIncognito = false,
    this.threadHistory = const [],
    ThreadSessionData? threadData,
  })  : userData = userData ??
            UserProfileInfo(
              email: "NA",
              fullname: "NA",
              username: "NA",
              profilePicUrl: "NA",
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
              searchHistory: [],
            ),
        threadData = threadData ??
            ThreadSessionData(
              id: "",
              email: "",
              results: [],
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            );

  final String sessionId;
  final UserProfileInfo userData;
  final NavBarOption page;
  final HomePageStatus status;
  final HomeReplyStatus replyStatus;
  final HomeHistoryStatus historyStatus;
  final HomeProfileStatus profileStatus;
  final List<ThreadSessionData> threadHistory;
  final ThreadSessionData threadData;
  final bool isSearchMode;
  final bool isIncognito;
  final bool backgroundLoading;
  final int loadingIndex;

  HomeState copyWith({
    String? sessionId,
    bool? isSearchMode,
    bool? isIncognito,
    bool? backgroundLoading,
    int? loadingIndex,
    UserProfileInfo? userData,
    NavBarOption? page,
    HomePageStatus? status,
    HomeReplyStatus? replyStatus,
    HomeHistoryStatus? historyStatus,
    HomeProfileStatus? profileStatus,
    List<ThreadSessionData>? threadHistory,
    ThreadSessionData? threadData,
  }) {
    return HomeState(
      sessionId: sessionId ?? this.sessionId,
      loadingIndex: loadingIndex ?? this.loadingIndex,
      backgroundLoading: backgroundLoading ?? this.backgroundLoading,
      isSearchMode: isSearchMode ?? this.isSearchMode,
      isIncognito: isIncognito ?? this.isIncognito,
      threadHistory: threadHistory ?? this.threadHistory,
      threadData: threadData ?? this.threadData,
      userData: userData ?? this.userData,
      page: page ?? this.page,
      status: status ?? this.status,
      replyStatus: replyStatus ?? this.replyStatus,
      historyStatus: historyStatus ?? this.historyStatus,
      profileStatus: profileStatus ?? this.profileStatus,
    );
  }

  @override
  List<Object?> get props => [
        loadingIndex,
        backgroundLoading,
        page,
        threadHistory,
        threadData,
        replyStatus,
        historyStatus,
        profileStatus,
        sessionId,
        status,
        userData,
        isSearchMode,
        isIncognito,
      ];
}

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

enum HomeEditStatus { loading, idle, selected }

enum HomeProfileStatus { loading, success, failure, idle }

final class HomeState extends Equatable {
  HomeState({
    UserProfileInfo? userData,
    this.page = NavBarOption.home,
    this.status = HomePageStatus.idle,
    this.replyStatus = HomeReplyStatus.idle,
    this.historyStatus = HomeHistoryStatus.idle,
    this.profileStatus = HomeProfileStatus.idle,
    this.editStatus = HomeEditStatus.idle,
    this.sessionId = "",
    this.loadingIndex = 0,
    this.editIndex = -1,
    this.backgroundLoading = true,
    this.isSearchMode = true,
    this.isIncognito = false,
    this.threadHistory = const [],
    this.editQuery = "",
    ThreadSessionData? threadData,
    ThreadSessionData? cacheThreadData,
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
              isIncognito: false,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            ),
          cacheThreadData = cacheThreadData ??
            ThreadSessionData(
              id: "",
              email: "",
              results: [],
              isIncognito: false,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            );   
            

  final String sessionId;
  final String editQuery;
  final UserProfileInfo userData;
  final NavBarOption page;
  final HomePageStatus status;
  final HomeReplyStatus replyStatus;
  final HomeHistoryStatus historyStatus;
  final HomeProfileStatus profileStatus;
  final HomeEditStatus editStatus;
  final List<ThreadSessionData> threadHistory;
  final ThreadSessionData threadData;
  final ThreadSessionData cacheThreadData;
  final bool isSearchMode;
  final bool isIncognito;
  final bool backgroundLoading;
  final int loadingIndex;
  final int editIndex;

  HomeState copyWith({
    String? sessionId,
    String? editQuery,
    bool? isSearchMode,
    bool? isIncognito,
    bool? backgroundLoading,
    int? loadingIndex,
    int? editIndex,
    UserProfileInfo? userData,
    NavBarOption? page,
    HomePageStatus? status,
    HomeReplyStatus? replyStatus,
    HomeEditStatus? editStatus,
    HomeHistoryStatus? historyStatus,
    HomeProfileStatus? profileStatus,
    List<ThreadSessionData>? threadHistory,
    ThreadSessionData? threadData,
    ThreadSessionData? cacheThreadData,
  }) {
    return HomeState(
      editQuery: editQuery ?? this.editQuery,
      sessionId: sessionId ?? this.sessionId,
      loadingIndex: loadingIndex ?? this.loadingIndex,
      editIndex: editIndex ?? this.editIndex,
      backgroundLoading: backgroundLoading ?? this.backgroundLoading,
      isSearchMode: isSearchMode ?? this.isSearchMode,
      isIncognito: isIncognito ?? this.isIncognito,
      threadHistory: threadHistory ?? this.threadHistory,
      threadData: threadData ?? this.threadData,
      cacheThreadData: cacheThreadData ?? this.cacheThreadData,
      userData: userData ?? this.userData,
      page: page ?? this.page,
      status: status ?? this.status,
      replyStatus: replyStatus ?? this.replyStatus,
      editStatus: editStatus ?? this.editStatus,
      historyStatus: historyStatus ?? this.historyStatus,
      profileStatus: profileStatus ?? this.profileStatus,
    );
  }

  @override
  List<Object?> get props => [
        editQuery,
        loadingIndex,
        editIndex,
        backgroundLoading,
        page,
        threadHistory,
        threadData,
        replyStatus,
        editStatus,
        historyStatus,
        profileStatus,
        sessionId,
        status,
        userData,
        isSearchMode,
        isIncognito,
      ];
}

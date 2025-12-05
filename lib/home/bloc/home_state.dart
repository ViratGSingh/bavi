part of 'home_bloc.dart';

// // ignore: depend_on_referenced_packages
// import 'package:image_picker/image_picker.dart';

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

enum HomeSearchType { nsfw, general, shopping, map, extractUrl, portal }

enum HomeActionType { general, agent, extractUrl }

enum HomeSavedStatus { fetched, idle }

enum HomeImageStatus { selected, unselected }

enum HomeHistoryStatus { loading, idle }

enum HomeEditStatus { loading, idle, selected }

enum HomeProfileStatus { loading, success, failure, idle }

enum HomeExtractUrlStatus { loading, success, failure, idle }

enum HomeModel { deepseek, gemini, claude, openAI }

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
    this.isSearchMode = false,
    this.isIncognito = false,
    this.threadHistory = const [],
    this.editQuery = "",
    ThreadSessionData? threadData,
    ThreadSessionData? cacheThreadData,
    this.selectedImage,
    this.imageStatus = HomeImageStatus.unselected,
    this.uploadedImageUrl,
    this.isAnalyzingImage = false,
    this.selectedModel = HomeModel.deepseek,
    this.searchType = HomeSearchType.general,
    this.actionType = HomeActionType.general,
    this.extractUrlStatus = HomeExtractUrlStatus.idle,
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
  final XFile? selectedImage;
  final HomeImageStatus imageStatus;
  final String? uploadedImageUrl;
  final bool isAnalyzingImage;
  final HomeModel selectedModel;
  final HomeSearchType searchType;
  final HomeActionType actionType;
  final HomeExtractUrlStatus extractUrlStatus;

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
    XFile? selectedImage,
    HomeImageStatus? imageStatus,
    String? uploadedImageUrl,
    bool? isAnalyzingImage,
    HomeModel? selectedModel,
    HomeSearchType? searchType,
    HomeActionType? actionType,
    HomeExtractUrlStatus? extractUrlStatus,
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
      selectedImage: selectedImage ?? this.selectedImage,
      imageStatus: imageStatus ?? this.imageStatus,
      uploadedImageUrl: uploadedImageUrl ?? this.uploadedImageUrl,
      isAnalyzingImage: isAnalyzingImage ?? this.isAnalyzingImage,
      selectedModel: selectedModel ?? this.selectedModel,
      searchType: searchType ?? this.searchType,
      actionType: actionType ?? this.actionType,
      extractUrlStatus: extractUrlStatus ?? this.extractUrlStatus,
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
        selectedImage,
        imageStatus,
        uploadedImageUrl,
        isAnalyzingImage,
        selectedModel,
        searchType,
        actionType,
        extractUrlStatus,
      ];
}

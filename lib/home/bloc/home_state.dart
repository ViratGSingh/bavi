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

enum HomeSearchType {
  nsfw,
  general,
  shopping,
  map,
  extractUrl,
  portal,
  youtube,
  instagram,
}

enum HomeActionType { general, agent, extractUrl }

enum HomeSavedStatus { fetched, idle }

enum HomeMapStatus { enabled, disabled }

enum HomeYoutubeStatus { enabled, disabled }

enum HomeGeneralStatus { enabled, disabled }

enum HomeInstagramStatus { enabled, disabled }

enum HomeSpicyStatus { enabled, disabled }

enum HomeImageStatus { selected, unselected }

enum HomeHistoryStatus { loading, idle }

enum HomeEditStatus { loading, idle, selected }

enum HomeProfileStatus { loading, success, failure, idle }

enum HomeExtractUrlStatus { loading, success, failure, idle }

enum OCRExtractionStatus { idle, loading, success, failed, cancelled }

enum HomeModel { deepseek, gemini, claude, openAI, flashThink }

const _sentinel = Object();

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
    this.ocrExtractionStatus = OCRExtractionStatus.idle,
    this.selectedModel = HomeModel.deepseek,
    this.searchType = HomeSearchType.general,
    this.actionType = HomeActionType.general,
    this.extractUrlStatus = HomeExtractUrlStatus.idle,
    this.mapStatus = HomeMapStatus.disabled,
    this.youtubeStatus = HomeYoutubeStatus.enabled,
    this.spicyStatus = HomeSpicyStatus.disabled,
    this.instagramStatus = HomeInstagramStatus.enabled,
    this.generalStatus = HomeGeneralStatus.enabled,
    this.showLocationRationale = false,
    this.isChatModeActive = true,
    this.userCity = "",
    this.userRegion = "",
    this.userCountry = "",
    this.userCountryCode = "",
    this.webSearchQuery,
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
              results: [],
              isIncognito: false,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            ),
        cacheThreadData = cacheThreadData ??
            ThreadSessionData(
              id: "",
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
  final OCRExtractionStatus ocrExtractionStatus;
  final HomeModel selectedModel;
  final HomeSearchType searchType;
  final HomeActionType actionType;
  final HomeExtractUrlStatus extractUrlStatus;
  final HomeMapStatus mapStatus;
  final HomeYoutubeStatus youtubeStatus;
  final HomeSpicyStatus spicyStatus;
  final HomeInstagramStatus instagramStatus;
  final HomeGeneralStatus generalStatus;
  final bool showLocationRationale;
  final bool isChatModeActive;
  final String userCity;
  final String userRegion;
  final String userCountry;
  final String userCountryCode;
  final String? webSearchQuery;

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
    Object? selectedImage = _sentinel,
    HomeImageStatus? imageStatus,
    Object? uploadedImageUrl = _sentinel,
    bool? isAnalyzingImage,
    OCRExtractionStatus? ocrExtractionStatus,
    HomeModel? selectedModel,
    HomeSearchType? searchType,
    HomeActionType? actionType,
    HomeExtractUrlStatus? extractUrlStatus,
    HomeMapStatus? mapStatus,
    HomeYoutubeStatus? youtubeStatus,
    HomeSpicyStatus? spicyStatus,
    HomeInstagramStatus? instagramStatus,
    HomeGeneralStatus? generalStatus,
    bool? showLocationRationale,
    bool? isChatModeActive,
    String? userCity,
    String? userRegion,
    String? userCountry,
    String? userCountryCode,
    Object? webSearchQuery = _sentinel,
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
      selectedImage: selectedImage == _sentinel
          ? this.selectedImage
          : selectedImage as XFile?,
      imageStatus: imageStatus ?? this.imageStatus,
      uploadedImageUrl: uploadedImageUrl == _sentinel
          ? this.uploadedImageUrl
          : uploadedImageUrl as String?,
      isAnalyzingImage: isAnalyzingImage ?? this.isAnalyzingImage,
      ocrExtractionStatus: ocrExtractionStatus ?? this.ocrExtractionStatus,
      selectedModel: selectedModel ?? this.selectedModel,
      searchType: searchType ?? this.searchType,
      actionType: actionType ?? this.actionType,
      extractUrlStatus: extractUrlStatus ?? this.extractUrlStatus,
      mapStatus: mapStatus ?? this.mapStatus,
      youtubeStatus: youtubeStatus ?? this.youtubeStatus,
      spicyStatus: spicyStatus ?? this.spicyStatus,
      instagramStatus: instagramStatus ?? this.instagramStatus,
      generalStatus: generalStatus ?? this.generalStatus,
      showLocationRationale:
          showLocationRationale ?? this.showLocationRationale,
      isChatModeActive: isChatModeActive ?? this.isChatModeActive,
      userCity: userCity ?? this.userCity,
      userRegion: userRegion ?? this.userRegion,
      userCountry: userCountry ?? this.userCountry,
      userCountryCode: userCountryCode ?? this.userCountryCode,
      webSearchQuery: webSearchQuery == _sentinel
          ? this.webSearchQuery
          : webSearchQuery as String?,
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
        ocrExtractionStatus,
        selectedModel,
        searchType,
        actionType,
        extractUrlStatus,
        mapStatus,
        youtubeStatus,
        spicyStatus,
        instagramStatus,
        generalStatus,
        showLocationRationale,
        isChatModeActive,
        userCity,
        userRegion,
        userCountry,
        userCountryCode,
        webSearchQuery,
      ];
}

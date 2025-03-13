part of 'home_bloc.dart';

enum NavBarOption { home, search, player, profile }

enum HomePageStatus { idle, loading }

final class HomeState extends Equatable {
  HomeState({
    UserProfileInfo? userData,
    this.page = NavBarOption.home,
    this.status = HomePageStatus.idle,
    this.videos = const [],
    this.collectionsVideos = const [],
    this.collections = const [],
    this.allVideoPlatformData = const {},
    this.searchResults = const [],
  }) : userData = userData ?? UserProfileInfo(
          email: "NA",
          fullname: "NA",
          username: "NA",
          profilePicUrl: "NA",
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          videoCollections: [],
        );

  final UserProfileInfo userData;
  final NavBarOption page;
  final HomePageStatus status;
  final Map<String, dynamic> allVideoPlatformData;
  final List<ExtractedVideoInfo> videos;
  final List<List<ExtractedVideoInfo>> collectionsVideos;
  final List<VideoCollectionInfo> collections;
  final List<ExtractedVideoInfo> searchResults;
  HomeState copyWith({
    UserProfileInfo? userData,
    NavBarOption? page,
    HomePageStatus? status,
    List<ExtractedVideoInfo>? videos,
    List<List<ExtractedVideoInfo>>? collectionsVideos,
    List<VideoCollectionInfo>? collections,
    Map<String, dynamic>? allVideoPlatformData,
    List<ExtractedVideoInfo>? searchResults,
  }) {
    return HomeState(
      userData: userData ?? this.userData,
      page: page ?? this.page,
      status: status ?? this.status,
      videos: videos ?? this.videos,
      collectionsVideos: collectionsVideos ?? this.collectionsVideos,
      collections: collections ?? this.collections,
      allVideoPlatformData: allVideoPlatformData ?? this.allVideoPlatformData,
      searchResults: searchResults ?? this.searchResults,
    );
  }

  @override
  List<Object> get props => [page, status, videos, collectionsVideos, collections, userData, allVideoPlatformData, searchResults];
}

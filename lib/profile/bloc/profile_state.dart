part of 'profile_bloc.dart';


enum ProfilePageStatus { idle, loading, collectionsLoading}

final class ProfileState extends Equatable {
  ProfileState({
    UserProfileInfo? userData,
    this.status = ProfilePageStatus.idle,
    this.videos = const [],
    this.collectionsVideos = const [],
    this.collections = const [],
    this.allVideoPlatformData = const {},
  }) : userData = userData ?? UserProfileInfo(
          email: "NA",
          fullname: "NA",
          username: "NA",
          profilePicUrl: "NA",
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          searchHistory: [],
        );

  final UserProfileInfo userData;
  final ProfilePageStatus status;
  final Map<String, dynamic> allVideoPlatformData;
  final List<ExtractedVideoInfo> videos;
  final List<List<ExtractedVideoInfo>> collectionsVideos;
  final List<VideoCollectionInfo> collections;
  ProfileState copyWith({
    UserProfileInfo? userData,
    ProfilePageStatus? status,
    List<ExtractedVideoInfo>? videos,
    List<List<ExtractedVideoInfo>>? collectionsVideos,
    List<VideoCollectionInfo>? collections,
    Map<String, dynamic>? allVideoPlatformData,
  }) {
    return ProfileState(
      userData: userData ?? this.userData,
      status: status ?? this.status,
      videos: videos ?? this.videos,
      collectionsVideos: collectionsVideos ?? this.collectionsVideos,
      collections: collections ?? this.collections,
      allVideoPlatformData: allVideoPlatformData ?? this.allVideoPlatformData,
    );
  }

  @override
  List<Object?> get props => [status, userData, videos, collectionsVideos, collections, allVideoPlatformData];
}

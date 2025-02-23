part of 'add_video_bloc.dart';

enum AddVideoStatus {idle, initialLoading, loading, success, error}

final class AddVideoState extends Equatable {
  const AddVideoState({
    this.status = AddVideoStatus.idle,
    this.extractedVideoInfo,
    this.collectionsInfo,
    this.videoId
  });

  final AddVideoStatus status;
  final ExtractedVideoInfo? extractedVideoInfo;
  final List<VideoCollectionInfo>? collectionsInfo;
  final String? videoId;

  AddVideoState copyWith({
    AddVideoStatus? status,
    ExtractedVideoInfo? extractedVideoInfo,
    List<VideoCollectionInfo>? collectionsInfo,
    String? videoId
  }) {
    return AddVideoState(
      status: status ?? this.status,
      extractedVideoInfo: extractedVideoInfo ?? this.extractedVideoInfo,
      collectionsInfo:  collectionsInfo ?? this.collectionsInfo,
      videoId: videoId ?? this.videoId
    );
  }

  

  @override
  List<Object> get props => [status];
}
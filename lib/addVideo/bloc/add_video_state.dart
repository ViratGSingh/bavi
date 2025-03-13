import 'package:bavi/models/collection.dart';
import 'package:bavi/models/short_video.dart';
import 'package:equatable/equatable.dart';

enum AddVideoStatus { idle, initialLoading, loading, success, error }

final class AddVideoState extends Equatable {
  const AddVideoState({
    this.status = AddVideoStatus.idle,
    this.isValidLink = false,
    this.extractedVideoInfo,
    this.collectionsInfo,
    this.videoId,
    this.platform,
  });

  final AddVideoStatus status;
  final ExtractedVideoInfo? extractedVideoInfo;
  final List<VideoCollectionInfo>? collectionsInfo;
  final String? videoId;
  final String? platform;
  final bool isValidLink;

  AddVideoState copyWith({
    AddVideoStatus? status,
    ExtractedVideoInfo? extractedVideoInfo,
    List<VideoCollectionInfo>? collectionsInfo,
    String? videoId,
    String? platform,
    bool? isValidLink,
  }) {
    return AddVideoState(
      status: status ?? this.status,
      extractedVideoInfo: extractedVideoInfo ?? this.extractedVideoInfo,
      collectionsInfo: collectionsInfo ?? this.collectionsInfo,
      videoId: videoId ?? this.videoId,
      platform: platform ?? this.platform,
      isValidLink: isValidLink ?? this.isValidLink,
    );
  }

  @override
  List<Object?> get props => [
        status,
        extractedVideoInfo,
        collectionsInfo,
        videoId,
        platform,
        isValidLink,
      ];
}
part of 'add_video_bloc.dart';

@immutable
sealed class AddVideoEvent {}

final class AddVideoExtract extends AddVideoEvent {
  final String link;
  AddVideoExtract(this.link);
}
//Reset to idle state
final class AddVideoReset extends AddVideoEvent {
}

//Direct without extracting
final class AddVideoRedirect extends AddVideoEvent {
}

//Fetch videos collections
final class AddVideoFetchCollections extends AddVideoEvent {
}

// Add video collection
final class AddVideoUpdateCollections extends AddVideoEvent {
  final List<VideoCollectionInfo> collections; // Accept a list of collections
  final ExtractedVideoInfo videoInfo;
  final String videoId;
  final String platform;
  AddVideoUpdateCollections(this.collections, this.videoInfo, this.videoId, this.platform);
}

// Add video collection
final class AddVideoCheckLink extends AddVideoEvent {
  final String link;
  AddVideoCheckLink(this.link);
}


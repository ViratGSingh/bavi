import 'package:equatable/equatable.dart';

class ExtractedVideoInfo extends Equatable {
  const ExtractedVideoInfo({
    required this.searchContent,
    required this.caption,
    required this.userData,
    required this.videoData,
    required this.videoId,
    required this.platform,
    required this.videoDescription,
    required this.audioDescription,
  });

  final String searchContent;
  final String caption;
  final String videoDescription;
  final String audioDescription;
  final UserData userData;
  final VideoData videoData;
  final String videoId;
  final String platform;

  @override
  List<Object> get props => [searchContent, videoDescription,audioDescription, caption, userData, videoData, videoId, platform];

  factory ExtractedVideoInfo.fromJson(Map<String, dynamic> json) {
    return ExtractedVideoInfo(
      platform: json["platform"] as String,
      videoId: json["video_id"] as String,
      searchContent: json['search_content'] as String,
      caption: json['caption'] as String,
      videoDescription: json['video_description'] as String,
      audioDescription: json['audio_description'] as String,
      userData: UserData.fromJson(json['user_data'] as Map<String, dynamic>),
      videoData: VideoData.fromJson(json['video_data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id':videoId,
      'platform': platform,
      'search_content': searchContent,
      'caption': caption,
      'video_description': videoDescription,
      'audio_description': audioDescription,
      'user_data': userData.toJson(),
      'video_data': videoData.toJson(),
    };
  }
}

class UserData extends Equatable {
  const UserData({
    required this.username,
    required this.fullname,
    required this.profilePicUrl,
  });

  final String username;
  final String fullname;
  final String profilePicUrl;

  @override
  List<Object> get props => [username, fullname, profilePicUrl];

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      username: json['username'] as String,
      fullname: json['fullname'] as String,
      profilePicUrl: json['profile_pic_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'fullname': fullname,
      'profile_pic_url': profilePicUrl,
    };
  }
}

class VideoData extends Equatable {
  const VideoData({
    required this.thumbnailUrl,
    required this.videoUrl,
  });

  final String thumbnailUrl;
  final String videoUrl;

  @override
  List<Object> get props => [thumbnailUrl, videoUrl];

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(
      thumbnailUrl: json['thumbnail_url'] as String,
      videoUrl: json['video_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
    };
  }
}
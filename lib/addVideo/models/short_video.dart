import 'package:equatable/equatable.dart';

class ExtractedVideoInfo extends Equatable {
  const ExtractedVideoInfo({
    required this.searchContent,
    required this.caption,
    required this.userData,
    required this.videoData,
  });

  final String searchContent;
  final String caption;
  final UserData userData;
  final VideoData videoData;

  @override
  List<Object> get props => [searchContent, caption, userData, videoData];

  factory ExtractedVideoInfo.fromJson(Map<String, dynamic> json) {
    return ExtractedVideoInfo(
      searchContent: json['search_content'] as String,
      caption: json['caption'] as String,
      userData: UserData.fromJson(json['user_data'] as Map<String, dynamic>),
      videoData: VideoData.fromJson(json['video_data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'search_content': searchContent,
      'caption': caption,
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
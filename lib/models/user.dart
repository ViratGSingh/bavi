import 'package:bavi/models/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Timestamp

enum CollectionStatus { private, connects, public }

class UserProfileInfo extends Equatable {
  const UserProfileInfo({
    required this.email,
    required this.fullname,
    required this.username,
    required this.profilePicUrl,
    required this.createdAt,
    required this.updatedAt,
    this.videoCollections,
  });

  final String email;
  final String fullname;
  final String username;
  final String profilePicUrl;
  final List<VideoCollectionInfo>? videoCollections;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  @override
  List<Object?> get props => [email, fullname, username, videoCollections, createdAt, updatedAt];

  factory UserProfileInfo.fromJson(Map<String, dynamic> json) {
    return UserProfileInfo(
      email: json['email'] as String,
      username: json['username'] as String,
      fullname:json['fullname'] as String,
      profilePicUrl:json['profile_pic_url'] as String,
      videoCollections: (json['video_collections']
              as List<dynamic>)
          .map((videoJson) =>
              VideoCollectionInfo.fromJson(videoJson as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as Timestamp,
      updatedAt: json['updated_at'] as Timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullname': fullname,
      'username': username,
      'profile_pic_url': profilePicUrl,
      'video_collections': videoCollections?.map((collection) => collection.toJson()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

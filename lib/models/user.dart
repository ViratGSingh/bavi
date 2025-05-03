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
    this.createdAt,
    this.updatedAt,
    this.searchHistory,
  });

  final String email;
  final String fullname;
  final String username;
  final String profilePicUrl;
  final List<String>? searchHistory;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  @override
  List<Object?> get props => [email, fullname, username, searchHistory, createdAt, updatedAt];

  factory UserProfileInfo.fromJson(Map<String, dynamic> json) {
    return UserProfileInfo(
      email: json['email'] as String,
      username: json['username'] as String,
      fullname: json['fullname'] as String,
      profilePicUrl: json['profile_pic_url'] as String,
      searchHistory: (json['search_history'] as List<dynamic>)
          .map((conversationId) => conversationId as String)
          .toList(),
      createdAt: json['created_at'] != null ? json['created_at'] as Timestamp : null,
      updatedAt: json['updated_at'] != null ? json['updated_at'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullname': fullname,
      'username': username,
      'profile_pic_url': profilePicUrl,
      'search_history': searchHistory,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class ExtractedAccountInfo extends Equatable {
  const ExtractedAccountInfo({
    required this.accountId,
    required this.username,
    required this.fullname,
    required this.profilePicUrl,
    required this.isVerified,
    required this.isPrivate,
    this.createdAt,
    this.updatedAt,
  });

  final String username;
  final String fullname;
  final bool isVerified;
  final bool isPrivate;
  final String profilePicUrl;
  final String accountId;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const ExtractedAccountInfo.empty()
      : accountId = '',
        isPrivate = false,
        isVerified = false,
        username = '',
        fullname = '',
        profilePicUrl = '',
        createdAt = null,
        updatedAt = null;

  @override
  List<Object?> get props => [
        isVerified,
        isPrivate,
        username,
        fullname,
        profilePicUrl,
        accountId,
        createdAt,
        updatedAt,
      ];

  factory ExtractedAccountInfo.fromJson(Map<String, dynamic> json) {
    return ExtractedAccountInfo(
      accountId: json['account_id'] as String,
      isPrivate: json["is_private"] as bool,
      isVerified: json["is_verified"] as bool,
      username: json['username'] as String,
      fullname: json['fullname'] as String,
      profilePicUrl: json['profile_pic_url'] as String,
      createdAt: json['created_at'] != null ? json['created_at'] as Timestamp : null,
      updatedAt: json['updated_at'] != null ? json['updated_at'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'fullname': fullname,
      'is_private': isPrivate,
      'is_verified': isVerified,
      'profile_pic_url': profilePicUrl,
      'account_id': accountId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

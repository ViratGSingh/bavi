import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Timestamp

enum CollectionStatus { private, connects, public }

class VideoCollectionInfo extends Equatable {
  VideoCollectionInfo({
    required this.collectionId,
    required this.name,
    required this.type,
    required this.videos,
    required this.createdAt,
    required this.updatedAt,
  });

  final int collectionId;
  final String name;
  final CollectionStatus type;
  final List<CollectionVideoData> videos;
  final Timestamp createdAt;
  Timestamp updatedAt;

  @override
  List<Object> get props => [collectionId, name, type, videos, createdAt, updatedAt];

  factory VideoCollectionInfo.fromJson(Map<String, dynamic> json) {
    return VideoCollectionInfo(
      collectionId: json['collection_id'] as int,
      name: json['name'] as String,
      type: json['type'] == "private"
          ? CollectionStatus.private
          : json['type'] == "connects"
              ? CollectionStatus.connects
              : CollectionStatus.public,
      videos: (json['videos'] as List<dynamic>)
          .map((e) => CollectionVideoData.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as Timestamp,
      updatedAt: json['updated_at'] as Timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collection_id': collectionId,
      'name': name,
      'type': type == CollectionStatus.private
          ? "private"
          : type == CollectionStatus.connects
              ? "connects"
              : "public",
      'videos': videos.map((video) => video.toJson()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class CollectionVideoData extends Equatable {
  CollectionVideoData({
    required this.videoId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String videoId;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  @override
  List<Object> get props => [videoId, createdAt, updatedAt];

  factory CollectionVideoData.fromJson(Map<String, dynamic> json) {
    return CollectionVideoData(
      videoId: json['video_id'] as String,
      createdAt: json['created_at'] as Timestamp,
      updatedAt: json['updated_at'] as Timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
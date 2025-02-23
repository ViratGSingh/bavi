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
  final List<String> videos;
  final Timestamp createdAt; // Added createdAt field
  Timestamp updatedAt; // Added updatedAt field

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
      videos: (json['videos'] as List<dynamic>).map((e) => e as String).toList(),
      createdAt: json['created_at'] as Timestamp, // Parse createdAt
      updatedAt: json['updated_at'] as Timestamp, // Parse updatedAt
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
      'videos': videos,
      'created_at': createdAt, // Include createdAt in JSON
      'updated_at': updatedAt, // Include updatedAt in JSON
    };
  }
}
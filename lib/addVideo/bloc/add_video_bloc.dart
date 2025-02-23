import 'dart:convert';

import 'package:bavi/addVideo/models/collection.dart';
import 'package:bavi/addVideo/models/short_video.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

part 'add_video_event.dart';
part 'add_video_state.dart';

class AddVideoBloc extends Bloc<AddVideoEvent, AddVideoState> {
  final http.Client httpClient;
  AddVideoBloc({required this.httpClient}) : super(AddVideoState()) {
    on<AddVideoExtract>(_extractVideo);
    on<AddVideoReset>(_resetPage);
    on<AddVideoRedirect>(_redirectToVideo);
    on<AddVideoFetchCollections>(_fetchCollections);
    on<AddVideoUpdateCollections>(_addVideoCollectionToUser);
  }
  ExtractedVideoInfo? extractedVideoInfo;

  //Fetch Collections
  Future<void> _fetchCollections(
      AddVideoFetchCollections event, Emitter<AddVideoState> emit) async {
    emit(state.copyWith(status: AddVideoStatus.initialLoading));
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String? userEmaildId = prefs.getString("email");

    // Reference to the Firestore collection "users"
    final CollectionReference usersCollection =
        FirebaseFirestore.instance.collection('users');

    // Query the users collection for a document with the matching email
    final QuerySnapshot querySnapshot = await usersCollection
        .where('email', isEqualTo: userEmaildId)
        .limit(1)
        .get();

    // Check if any documents were found
    if (querySnapshot.docs.isEmpty) {
      throw Exception('User not found');
    }

    // Get the first document (since we limited the query to 1)
    final DocumentSnapshot userDoc = querySnapshot.docs.first;

    // Check if the "video_collections" field exists in the document
    if (userDoc.exists && userDoc.data() != null) {
      final Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;

      if (userData.containsKey('video_collections')) {
        // Extract the "video_collections" field from the user document
        final List<dynamic> videoCollectionsData =
            userData['video_collections'] as List<dynamic>;

        // Parse the data into a list of VideoCollectionInfo objects
        final List<VideoCollectionInfo> videoCollections = videoCollectionsData
            .map((collectionData) => VideoCollectionInfo.fromJson(
                  collectionData as Map<String, dynamic>,
                ))
            .toList();
        emit(state.copyWith(
            collectionsInfo: videoCollections, status: AddVideoStatus.idle));
      } else {
        // If "video_collections" does not exist, emit an empty list
        emit(state.copyWith(collectionsInfo: []));
      }
    } else {
      // If the document data is null, emit an empty list
      emit(state.copyWith(collectionsInfo: []));
    }
  }

  // Add Collection
  Future<void> _addVideoCollectionToUser(
      AddVideoUpdateCollections event, Emitter<AddVideoState> emit) async {
    emit(state.copyWith(status: AddVideoStatus.loading));
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String? userEmaildId = prefs.getString("email");

    try {
      // Reference to the Firestore collection "users"
      final CollectionReference usersCollection =
          FirebaseFirestore.instance.collection('users');

      // Query the users collection for a document with the matching email
      final QuerySnapshot querySnapshot = await usersCollection
          .where('email', isEqualTo: userEmaildId)
          .limit(1)
          .get();

      // Check if any documents were found
      if (querySnapshot.docs.isEmpty) {
        throw Exception('User not found');
      }

      // Get the first document (since we limited the query to 1)
      final DocumentSnapshot userDoc = querySnapshot.docs.first;

      // Convert the new list of collections to a list of maps
      final List<Map<String, dynamic>> newCollectionsMap =
          event.collections.map((collection) => collection.toJson()).toList();

      // Update the user document with the new list of video collections
      await usersCollection.doc(userDoc.id).update({
        'video_collections': newCollectionsMap,
      });

      print('New collections added successfully');
    } catch (e) {
      print('Error adding video collections: $e');
      // Optionally, you can rethrow the error or handle it differently
      // rethrow;
    }

    emit(state.copyWith(
        status: AddVideoStatus.idle,
        extractedVideoInfo: null,
        videoId: null,
        collectionsInfo: null));
    
          navService.goTo('/home');
  }

  Future<void> _resetPage(
      AddVideoReset event, Emitter<AddVideoState> emit) async {
    emit(state.copyWith(status: AddVideoStatus.idle, extractedVideoInfo: null));
  }

  Future<void> _redirectToVideo(
      AddVideoRedirect event, Emitter<AddVideoState> emit) async {
    emit(state.copyWith(status: AddVideoStatus.success));
  }

  String? extractInstagramId(String url) {
    Uri uri = Uri.parse(url);
    List<String> segments = uri.pathSegments;
    return segments.length > 1 ? segments[1] : null;
  }

  String? extractYouTubeShortsId(String url) {
    Uri uri = Uri.parse(url);
    List<String> segments = uri.pathSegments;

    // Check if the URL contains the 'shorts' segment
    if (segments.contains('shorts') && segments.length > 1) {
      // The video ID is the segment immediately after 'shorts'
      return segments[segments.indexOf('shorts') + 1];
    }

    return null; // Return null if the URL is not a valid YouTube Shorts URL
  }

  Future<void> _extractVideo(
      AddVideoExtract event, Emitter<AddVideoState> emit) async {
    emit(state.copyWith(status: AddVideoStatus.loading));
    String videoLink = event.link;
    String videoId = "";
    //Check link
    if (videoLink.contains("instagram")) {
      String? igVideoId = extractInstagramId(videoLink);
      if (igVideoId != null) {
        videoId = igVideoId;
        await checkBackupVidInfo(igVideoId, "instagram");
        if (extractedVideoInfo == null) {
          await fetchInstagramVideoInfo(igVideoId);
        }
      }
    } else if (videoLink.contains("youtube")) {
      String? ytVideoId = extractInstagramId(videoLink);
      if (ytVideoId != null) {
        videoId = ytVideoId;
        await checkBackupVidInfo(ytVideoId, "youtube");
        if (extractedVideoInfo == null) {
          await fetchYoutubeShortInfo(ytVideoId);
        }
      }
    }
    //fetch info
    //fetchInstagramVideoInfo();
    emit(state.copyWith(
        status: AddVideoStatus.success,
        extractedVideoInfo: extractedVideoInfo,
        videoId: videoId));
  }

  Future<void> checkBackupVidInfo(String videoId, String platform) async {
    extractedVideoInfo = null;
    //Save Extracted Reel Info
    FirebaseFirestore db = FirebaseFirestore.instance;
    //Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("videos")
        .where('videoId', isEqualTo: videoId)
        .where('platform', isEqualTo: platform)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
      extractedVideoInfo = ExtractedVideoInfo.fromJson(data["data"]);
      await db.collection("videos").doc(querySnapshot.docs.first.id).set({
        'total_extracts': data["total_extracts"] + 1,
        'updated_at': Timestamp.now()
      }, SetOptions(merge: true)); // Merge to update only specified fields
    }
  }

  Future<void> fetchInstagramVideoInfo(String id) async {
    final url = Uri.https(
      dotenv.get("IG_RAPID_API_HOST"),
      '/v1/post_info',
      {'code_or_id_or_url': id, 'include_insights': 'true'},
    );

    final headers = {
      'x-rapidapi-key': dotenv.get("RAPID_API_KEY"),
      'x-rapidapi-host': dotenv.get("IG_RAPID_API_HOST"),
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      // Successfully fetched data
      final data = response.body;
      Map<String, dynamic> respData = jsonDecode(data);

      print('Data: ${respData["user"]}');
      //User Data
      UserData userData = UserData(
          username: respData["data"]["user"]["username"],
          fullname: respData["data"]["user"]["full_name"],
          profilePicUrl: respData["data"]["user"]["profile_pic_url"]);

      //Video Data
      VideoData videoData = VideoData(
        thumbnailUrl: respData["data"]["thumbnail_url"],
        videoUrl: respData["data"]["video_url"],
      );

      extractedVideoInfo = ExtractedVideoInfo(
          searchContent:
              "${userData.username}, ${userData.fullname}, ${respData["data"]["caption"]["text"]}",
          caption: respData["data"]["caption"]["text"],
          userData: userData,
          videoData: videoData);
      Map<String, dynamic> extractedData = {
        "videoId": id,
        "platform": "instagram",
        "data": extractedVideoInfo?.toJson() ?? {},
        "total_extracts": 1,
        "created_at": Timestamp.now(),
        "updated_at": Timestamp.now()
      };
      backupExtractedData(extractedData, id, "instagram");
      print('Data: $extractedVideoInfo');
    } else {
      // Handle error
      print('Failed to load data: ${response.statusCode}');
    }
  }

  Future<void> backupExtractedData(Map<String, dynamic> extractedData,
      String videoId, String platform) async {
    //Save Extracted Reel Info
    FirebaseFirestore db = FirebaseFirestore.instance;
    //Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("videos")
        .where('videoId', isEqualTo: videoId)
        .where('platform', isEqualTo: platform)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      // Document with the same id exists, update it
      String documentId = querySnapshot.docs.first.id;
      int totalExtracts = querySnapshot.docs.first.get("total_extracts") ?? 0;
      await db.collection("videos").doc(documentId).set(
          {'total_extracts': totalExtracts + 1, 'updated_at': Timestamp.now()},
          SetOptions(merge: true)); // Merge to update only specified fields
    } else {
      // Add a new document with a generated ID
      await db.collection("videos").add(extractedData);
    }
  }

  Future<void> fetchYoutubeShortInfo(String id) async {
    final url = Uri.https(
      dotenv.get("YT_RAPID_API_HOST"),
      '/v2/video/details',
      {'videoId': id},
    );

    final headers = {
      'x-rapidapi-key': dotenv.get("RAPID_API_KEY"),
      'x-rapidapi-host': dotenv.get("YT_RAPID_API_HOST"),
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      // Successfully fetched data
      final data = response.body;
      Map<String, dynamic> respData = jsonDecode(data);

      //User Data
      UserData userData = UserData(
          username: respData["channel"]["handle"],
          fullname: respData["channel"]["name"],
          profilePicUrl: respData["channel"]["avatar"][0]["url"]);

      //Video Data
      VideoData videoData = VideoData(
        thumbnailUrl: respData["thumbnails"][4]["url"],
        videoUrl: respData["videos"]["items"][0]["url"],
      );

      extractedVideoInfo = ExtractedVideoInfo(
          searchContent:
              "${userData.username}, ${userData.fullname}, ${respData["title"]}, ${respData["description"]}",
          caption: respData["description"],
          userData: userData,
          videoData: videoData);

      Map<String, dynamic> extractedData = {
        "videoId": id,
        "platform": "youtube",
        "data": extractedVideoInfo?.toJson() ?? {},
        "total_extracts": 1,
        "created_at": Timestamp.now(),
        "updated_at": Timestamp.now()
      };
      backupExtractedData(extractedData, id, "youtube");

      print('Data: $extractedVideoInfo');
    } else {
      // Handle error
      print('Failed to load data: ${response.statusCode}');
    }
  }
}

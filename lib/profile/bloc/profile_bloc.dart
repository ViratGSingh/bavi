import 'package:bavi/models/collection.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final http.Client httpClient;
  ProfileBloc({required this.httpClient}) : super(ProfileState()) {
    on<ProfileFetchAllVideos>(_getAllUserVideos);
    on<ProfileAttemptGoogleSignOut>(_handleGoogleSignOut);

  }

  GoogleSignIn _googleSignIn = GoogleSignIn();


  Future<void> _handleGoogleSignOut(
      ProfileAttemptGoogleSignOut event, Emitter<ProfileState> emit) async {
    print("asd");
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      await _googleSignIn.disconnect();
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      await prefs.setString('displayName', "");
      await prefs.setString('email', "");
      await prefs.setString('profile_pic_url', "");
      await prefs.setBool('isLoggedIn', false);
      print("done");
      navService.goToAndPopUntil('/login');
    } catch (error) {
      print("Google Sign-Out Error: $error");
      //return null;
    }
  }


  Future<void> _getAllUserVideos(
      ProfileFetchAllVideos event, Emitter<ProfileState> emit) async {
    emit(state.copyWith(
        status: ProfilePageStatus.loading));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userEmaildId = prefs.getString("email");
    try {
      // Reference to the Firestore collection "users"

      FirebaseFirestore db = FirebaseFirestore.instance;
      final CollectionReference usersCollection = db.collection('users');

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
      final data = userDoc.data() as Map<String, dynamic>;

      //Check if video collections is empty or not
      if(data.containsKey('video_collections') == false){
        emit(state.copyWith(status: ProfilePageStatus.idle, videos: []));
        throw Exception('Collections is unavailable');
      }

      // //Get user data
      // print("trye");
      // print(data);
      // UserProfileInfo userData = UserProfileInfo.fromJson(data);

      // emit(state.copyWith(status: ProfilePageStatus.collectionsLoading, userData: userData));
      // //Get All Video Ids
      // List<VideoCollectionInfo>? videoIdInfoList = userData.videoCollections;
      // // (data['video_collections']
      // //         as List<dynamic>)
      // //     .map((videoJson) =>
      // //         VideoCollectionInfo.fromJson(videoJson as Map<String, dynamic>))
      // //     .toList();
      // List<String> allVideoIds = videoIdInfoList!.first.videos
      //     .map((collectionVideoInfo) => collectionVideoInfo.videoId)
      //     .toList();

      // //Get All Video Datas
      // List<ExtractedVideoInfo> allSavedVideoList = [];
      // Map<String, dynamic> allVideoPlatformData = {};
      // // Reference to the "videos" collection
      // final CollectionReference videosCollection =
      //     FirebaseFirestore.instance.collection('videos');
      // // Fetch documents where "videoId" is in the list of videoIds
      // final QuerySnapshot videosQuerySnapshot =
      //     await videosCollection.where('videoId', whereIn: allVideoIds).get();
      // if (videosQuerySnapshot.docs.isNotEmpty) {
      //   print(allVideoIds);
      //   print("");
      //   for (QueryDocumentSnapshot videoSnapshot in videosQuerySnapshot.docs) {
      //     if (videoSnapshot.exists) {
      //       final videoData = videoSnapshot.data() as Map<String, dynamic>;
      //       ExtractedVideoInfo savedVideoInfo =
      //           ExtractedVideoInfo.fromJson(videoData["data"]);

      //       allVideoPlatformData[videoData["videoId"]] = videoData["platform"];
      //       allSavedVideoList.add(savedVideoInfo);
      //     }
      //   }
      // }

    //   //Sort according to user collection list
    //   List<ExtractedVideoInfo> sortedSavedVideoList = [];
    //   for (String videoId in allVideoIds) {
    //     //check if videoId is in allSavedVideoList
    //     String platform = allVideoPlatformData[videoId] ?? "";
    //     if (allSavedVideoList.any((element) =>
    //         element.videoData.videoUrl.contains(videoId) &&
    //         element.videoData.videoUrl.contains(platform) == true)) {
    //       //if it is, add it to the allSavedVideoList
    //       sortedSavedVideoList.add(allSavedVideoList.firstWhere(
    //           (element) => element.videoData.videoUrl.contains(videoId)));
    //     }
    //   }
    //   List<List<ExtractedVideoInfo>> allCollectionsVideos =
    //       await _getAllCollectionsVideos(
    //           videoIdInfoList, sortedSavedVideoList, allVideoIds);

    //   emit(state.copyWith(
    //       status: ProfilePageStatus.idle,
    //       userData: userData,
    //       videos: sortedSavedVideoList.reversed.toList(),
    //       allVideoPlatformData: allVideoPlatformData,
    //       collectionsVideos: allCollectionsVideos,
    //       collections: videoIdInfoList));

    //   print('Videos fetched successfully');
    //   print(state.userData.toJson());
    } catch (e) {
      print('Error adding video collections: $e');
      // Optionally, you can rethrow the error or handle it differently
      // rethrow;
    }
  }

  

  Future<List<List<ExtractedVideoInfo>>> _getAllCollectionsVideos(
      List<VideoCollectionInfo> videoCollections,
      List<ExtractedVideoInfo> allSavedVideoList,
      List<String> allVideoIds) async {
    List<List<ExtractedVideoInfo>> allCollectionsVideos = [];
    for (VideoCollectionInfo collection in videoCollections) {
      print(collection.name);
      print("");
      List<ExtractedVideoInfo> collectionVideos = [];
      for (CollectionVideoData collectionVideoData in collection.videos) {
        int index = allVideoIds.indexOf(collectionVideoData.videoId);
        ExtractedVideoInfo videoInfo = allSavedVideoList[index];
        print(videoInfo.userData.fullname);
        print("");
        collectionVideos.add(videoInfo);
      }
      allCollectionsVideos.add(collectionVideos);
    }
    return allCollectionsVideos;
  }
}

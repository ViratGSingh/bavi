import 'dart:io';
import 'dart:math';

import 'package:bavi/models/collection.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final http.Client httpClient;
  LoginBloc({required this.httpClient}) : super(LoginState()) {
    on<LoginInfoScrolled>(_changeInfoPosition);
    on<LoginAttemptGoogle>(_handleGoogleSignIn);
    on<LoginAttemptGuest>(_handleGuestSignIn);
    on<LoginInitialize>(_handleInitialize);
    on<LoginInitiateMixpanel>(_initMixpanel);
  }

  late Mixpanel mixpanel;
  Future<void> _initMixpanel(
      LoginInitiateMixpanel event, Emitter<LoginState> emit) async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("sign_in_view");
  }

  String initialVideoId = "C6auaneCk05";
  String initialVideoUrl =
      "https://bavi.s3.ap-south-1.amazonaws.com/videos/instagram_C6auaneCk05.mp4";
  String initialThumbnailUrl =
      "https://bavi.s3.ap-south-1.amazonaws.com/thumbnails/instagram_C6auaneCk05.jpg";
  String initialPlatform = "instagram";

  //Tutorial Video Links
  String instagramTutorialVideoUrl =
      "https://bavi.s3.ap-south-1.amazonaws.com/videos/save_instagram_video.mp4";
  String youtubeTutorialVideoUrl =
      "https://bavi.s3.ap-south-1.amazonaws.com/videos/save_youtube_video.mp4";
  Future<void> _handleInitialize(
      LoginInitialize event, Emitter<LoginState> emit) async {
    await DefaultCacheManager()
        .getSingleFile(initialVideoUrl, key: initialVideoUrl);
    await DefaultCacheManager().getSingleFile(
      initialThumbnailUrl,
      key: initialThumbnailUrl, // Unique cache key
    );
    await DefaultCacheManager().getSingleFile(instagramTutorialVideoUrl,
        key: instagramTutorialVideoUrl);
    await DefaultCacheManager()
        .getSingleFile(youtubeTutorialVideoUrl, key: youtubeTutorialVideoUrl);
  }

  Future<void> _changeInfoPosition(
      LoginInfoScrolled event, Emitter<LoginState> emit) async {
    int updatedPosition = event.position;
    print(updatedPosition);
    emit(state.copyWith(position: updatedPosition));
  }

  /// The scopes required by this application.
// #docregion Initialize

  GoogleSignIn _googleSignIn = GoogleSignIn();
  Future<void> _handleGoogleSignIn(
      LoginAttemptGoogle event, Emitter<LoginState> emit) async {
    try {
      // Sign out first to force account picker
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      emit(state.copyWith(status: LoginStatus.loading));
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign out of Firebase first
        await FirebaseAuth.instance.signOut();

        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);

        print("User Signed In: ${userCredential.user?.email}");

        await saveUserData(googleUser);
      }
      emit(state.copyWith(status: LoginStatus.success));
    } catch (error) {
      print("Google Sign-In Error: $error");
      emit(state.copyWith(status: LoginStatus.failure));
    }
  }

  Future<void> saveUserData(GoogleSignInAccount googleUser) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString('displayName', googleUser.displayName ?? "");
    await prefs.setString('email', googleUser.email);
    await prefs.setString('profile_pic_url', googleUser.photoUrl ?? "");
    await prefs.setBool('isLoggedIn', true);

    FirebaseFirestore db = FirebaseFirestore.instance;
    // Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("users")
        .where('email', isEqualTo: googleUser.email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      print("asdasd");
      // Document with the same email exists, update it
      String documentId = querySnapshot.docs.first.id;
      await db.collection("users").doc(documentId).set({
        'updated_at': Timestamp.now(),
      }, SetOptions(merge: true)).then((onValue) {
        print("aaa");
        String username = googleUser.email.split("@").first;
        mixpanel.identify(username);
        mixpanel.track("sign_in");
      navService.goToAndPopUntil('/home');
      }); // Merge to update only specified fields
    } else {
      // Create a new user with a first and last name
      String username = googleUser.email.split("@").first;
      final user = <String, dynamic>{
        "username": username,
        "email": googleUser.email,
        "fullname": googleUser.displayName ?? "",
        "profile_pic_url": googleUser.photoUrl ?? "",
        "created_at": Timestamp.now(),
        "updated_at": Timestamp.now(),
        "search_history": [],
      };
      // Add a new document with a generated ID
      await db.collection("users").add(user).then((onValue) {
        mixpanel.identify(username);
        mixpanel.track("sign_up");
      navService.goToAndPopUntil('/home');
      });
    }
  }

  Future<void> _handleGuestSignIn(
      LoginAttemptGuest event, Emitter<LoginState> emit) async {
    try {
      emit(state.copyWith(status: LoginStatus.guestLoading));
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
      await saveGuestData();
      emit(state.copyWith(status: LoginStatus.success));
    } catch (error) {
      print("Google Sign-In Error: $error");
      emit(state.copyWith(status: LoginStatus.failure));
    }
  }

  Future<void> saveGuestData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    String username = List.generate(10, (index) => chars[rand.nextInt(chars.length)]).join();
    String email = "$username@gmail.com";
    await prefs.setString('displayName', "Guest");
    await prefs.setString('email', email);
    await prefs.setString('profile_pic_url', "");
    await prefs.setBool('isLoggedIn', true);

    FirebaseFirestore db = FirebaseFirestore.instance;
    // Check if a document with the same email exists
    final user = <String, dynamic>{
      "username": username,
      "email": email,
      "fullname": "Guest",
      "profile_pic_url": "",
      "created_at": Timestamp.now(),
      "updated_at": Timestamp.now(),
      "search_history": [],
    };
    // Add a new document with a generated ID
    await db.collection("users").add(user).then((onValue) {
      mixpanel.identify(username);
      mixpanel.track("sign_up");
      navService.goToAndPopUntil('/home');
    });
  }

  Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
  }
}

import 'dart:io';
import 'dart:math';

import 'package:bavi/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:bavi/app_database.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final http.Client httpClient;
  LoginBloc({required this.httpClient}) : super(LoginState()) {
    on<LoginInfoScrolled>(_changeInfoPosition);
    on<LoginAttemptGoogle>(_handleGoogleSignIn);
    on<LoginAttemptApple>(_handleAppleSignIn);
    on<LoginAttemptGuest>(_handleGuestSignIn);
    on<LoginInitialize>(_handleInitialize);
    on<LoginInitiateMixpanel>(_initMixpanel);
    on<LoginSignOut>(_handleSignOut);
  }

  late Mixpanel mixpanel;
  Future<void> _initMixpanel(
      LoginInitiateMixpanel event, Emitter<LoginState> emit) async {
    // initialize Mixpanel
    try{
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("sign_in_view");}
    catch(e){
      print("Mixpanel Error: $e");
    }
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

  Future<void> _handleGoogleSignIn(
      LoginAttemptGoogle event, Emitter<LoginState> emit) async {
    try {
      emit(state.copyWith(status: LoginStatus.loading));
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithCredential(credential);
      await saveUserData(googleUser);
      emit(state.copyWith(status: LoginStatus.success));
    } catch (error) {
      emit(state.copyWith(status: LoginStatus.failure));
    }
  }

  Future<void> _handleAppleSignIn(
      LoginAttemptApple event, Emitter<LoginState> emit) async {
    try {
      emit(state.copyWith(status: LoginStatus.appleLoading));
      await FirebaseAuth.instance.signOut();

      if (Platform.isIOS) {
        // Native Apple Sign In on iOS
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );
        final userCredential =
            await FirebaseAuth.instance.signInWithCredential(oauthCredential);
        await saveAppleUserData(userCredential, appleCredential);
      } else {
        // On Android, use Firebase's built-in Apple provider (web-based flow)
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        final userCredential =
            await FirebaseAuth.instance.signInWithProvider(provider);
        await saveAppleUserDataFromFirebase(userCredential);
      }

      emit(state.copyWith(status: LoginStatus.success));
    } catch (error) {
      print("Apple Sign-In Error: $error");
      emit(state.copyWith(status: LoginStatus.failure));
    }
  }

  Future<void> saveAppleUserData(UserCredential userCredential,
      AuthorizationCredentialAppleID appleCredential) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final user = userCredential.user;
    final displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((s) => s != null && s.isNotEmpty).join(' ');
    final email = user?.email ?? appleCredential.email ?? '';
    final name = displayName.isNotEmpty ? displayName : (user?.displayName ?? 'Apple User');

    await prefs.setString('displayName', name);
    await prefs.setString('email', email);
    await prefs.setString('profile_pic_url', user?.photoURL ?? '');
    await prefs.setBool('isLoggedIn', true);

    FirebaseFirestore db = FirebaseFirestore.instance;
    final username = email.isNotEmpty ? email.split('@').first : user?.uid ?? '';
    QuerySnapshot querySnapshot = await db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      String documentId = querySnapshot.docs.first.id;
      await db.collection('users').doc(documentId).set({
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    } else {
      final userData = <String, dynamic>{
        'username': username,
        'email': email,
        'name': name,
        'image': user?.photoURL ?? '',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'id': '',
        'userId': user?.uid ?? '',
        'sessionToken': '',
        'userAgent': '',
      };
      await db.collection('users').add(userData);
    }
    try {
      mixpanel.identify(username);
      mixpanel.track('apple_sign_in');
    } catch (_) {}
    navService.goToAndPopUntil('/home');
  }

  Future<void> saveAppleUserDataFromFirebase(UserCredential userCredential) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final user = userCredential.user;
    final email = user?.email ?? '';
    final name = user?.displayName ?? 'Apple User';

    await prefs.setString('displayName', name);
    await prefs.setString('email', email);
    await prefs.setString('profile_pic_url', user?.photoURL ?? '');
    await prefs.setBool('isLoggedIn', true);

    FirebaseFirestore db = FirebaseFirestore.instance;
    final username = email.isNotEmpty ? email.split('@').first : user?.uid ?? '';
    QuerySnapshot querySnapshot = await db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      String documentId = querySnapshot.docs.first.id;
      await db.collection('users').doc(documentId).set({
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    } else {
      final userData = <String, dynamic>{
        'username': username,
        'email': email,
        'name': name,
        'image': user?.photoURL ?? '',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'id': '',
        'userId': user?.uid ?? '',
        'sessionToken': '',
        'userAgent': '',
      };
      await db.collection('users').add(userData);
    }
    try {
      mixpanel.identify(username);
      mixpanel.track('apple_sign_in');
    } catch (_) {}
    navService.goToAndPopUntil('/home');
  }

  Future<void> _handleSignOut(
      LoginSignOut event, Emitter<LoginState> emit) async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('displayName');
      await prefs.remove('email');
      await prefs.remove('profile_pic_url');

      // Clear local threads
      final localThreads = await AppDatabase().getAllThreads();
      for (final thread in localThreads) {
        await AppDatabase().deleteThread(thread.id);
      }

      emit(state.copyWith(status: LoginStatus.initial));
      navService.goToAndPopUntil('/home');
    } catch (error) {
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

    String userDocId;
    String username = googleUser.email.split("@").first;

    if (querySnapshot.docs.isNotEmpty) {
      // Document with the same email exists, update it
      userDocId = querySnapshot.docs.first.id;
      await db.collection("users").doc(userDocId).set({
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
      mixpanel.identify(username);
      mixpanel.track("sign_in");
    } else {
      // Create a new user
      final user = <String, dynamic>{
        "username": username,
        "email": googleUser.email,
        "name": googleUser.displayName ?? "",
        "image": googleUser.photoUrl ?? "",
        "createdAt": DateTime.now().toUtc().toIso8601String(),
        "updatedAt": DateTime.now().toUtc().toIso8601String(),
        "id":"",
        "userId":googleUser.id,
        "sessionToken":"",
        "userAgent": ""
      };
      final docRef = await db.collection("users").add(user);
      userDocId = docRef.id;
      mixpanel.identify(username);
      mixpanel.track("sign_up");
    }

    // Claim local threads: add userId to matching Firestore thread docs
    try {
      final localThreads = await AppDatabase().getAllThreads();
      for (final thread in localThreads) {
        final threadDoc = await db.collection("threads").doc(thread.id).get();
        if (threadDoc.exists) {
          await db.collection("threads").doc(thread.id).set(
            {'userId': userDocId},
            SetOptions(merge: true),
          );
        }
      }
    } catch (e) {
      print("Error claiming threads: $e");
    }

    navService.goToAndPopUntil('/home');
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
      mixpanel.track("guest_sign_up");
      navService.goToAndPopUntil('/home');
    });
  }

  // Future<void> signOutGoogle() async {
  //   await _googleSignIn.signOut();
  // }
}

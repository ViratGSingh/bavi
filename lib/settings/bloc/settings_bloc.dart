import 'dart:io';

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

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final http.Client httpClient;
  SettingsBloc({required this.httpClient}) : super(SettingsState()) {
    on<SettingsDelete>(_handleDelete);
    on<SettingsLogout>(_handleLogout);
    on<SettingsInitiateMixpanel>(_initMixpanel);
  }

  late Mixpanel mixpanel;
  Future<void> _initMixpanel(
      SettingsInitiateMixpanel event, Emitter<SettingsState> emit) async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("settings_view");
  }

  /// The scopes required by this application.
  // #docregion Initialize

  GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _handleLogout(
      SettingsLogout event, Emitter<SettingsState> emit) async {
    print("asd");
    emit(state.copyWith(status: SettingsStatus.logout));
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

      //emit(state.copyWith(status: SettingsStatus.initial));
      navService.goToAndPopUntil('/login');
    } catch (error) {
      print("Google Sign-Out Error: $error");
      //return null;
    }
  }

  Future<void> _handleDelete(
      SettingsDelete event, Emitter<SettingsState> emit) async {
    print("asd");
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');
    emit(state.copyWith(status: SettingsStatus.delete));
    //Delete account data

    FirebaseFirestore db = FirebaseFirestore.instance;
    // Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("users")
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      print("asdasd");
      // Document with the same email exists, update it
      String documentId = querySnapshot.docs.first.id;
      await db.collection("users").doc(documentId).delete();
    }

    try {
      await _googleSignIn.disconnect();
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      await prefs.setString('displayName', "");
      await prefs.setString('email', "");
      await prefs.setString('profile_pic_url', "");
      await prefs.setBool('isLoggedIn', false);
      print("done");

      //emit(state.copyWith(status: SettingsStatus.initial));

      navService.goToAndPopUntil('/login');
    } catch (error) {
      print("Google Sign-Out Error: $error");
      //return null;
    }
  }
}

//import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'package:bavi/navigation_service.dart';
import 'package:bavi/routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bavi/app.dart';
import 'package:bavi/bavi_bloc_observer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';

void main() async {
  // Preserve splash screen until initialization is complete
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  Bloc.observer = BaviBlocObserver();
  await Future.wait([
    dotenv.load(fileName: ".env"),
    Firebase.initializeApp(),
  ]);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  final bool isLoggedIn = true; //await _checkUserLogin();
  final router = AppRouter(isLoggedIn).router;
  navService.setRouter(router);

  // Remove splash screen right before running the app
  FlutterNativeSplash.remove();

  runApp(BaviApp(router: router));

  // Start listening for links
  //_initAppLinks();
}

// Load user data from SharedPreferences
Future<bool> _checkUserLogin() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isLoggedIn') ?? false;
}

// Future<bool> _checkUserOnboard() async {
//   final prefs = await SharedPreferences.getInstance();
//   return prefs.getBool('isOnboarded') ?? false;
// }
// Future<String> _getDisplayName() async {
//   final prefs = await SharedPreferences.getInstance();
//   return prefs.getString('displayName') ?? "";
// }

StreamSubscription<Uri>? _linkSub;

Future<void> _initAppLinks() async {
  final appLinks = AppLinks();

  // Handle link that launched the app
  try {
    _linkSub = AppLinks().uriLinkStream.listen((uri) {
      debugPrint('onAppLink: $uri');
      _openWebView(uri);
    });
  } catch (e) {
    print('Error fetching initial link: $e');
  }

  // Handle links received while the app is running
  _linkSub = appLinks.uriLinkStream.listen((Uri uri) {
    _openWebView(uri);
  }, onError: (err) {
    print('Error receiving app link: $err');
  });
}

void _openWebView(Uri uri) {
  // Navigate to your WebView route, passing the URL
  navService.goTo('/webview', extra: {"url": uri.toString()});
}

// Future<bool> _checkUserLogin() async {
//   final prefs = await SharedPreferences.getInstance();
//   return prefs.getBool('isLoggedIn') ?? false;
// }

//import 'package:firebase_core/firebase_core.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bavi/routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bavi/app.dart';
import 'package:bavi/bavi_bloc_observer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async{
  Bloc.observer = BaviBlocObserver();
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  final bool isLoggedIn = await _checkUserLogin(); 
  final bool isOnboarded = await _checkUserOnboard(); 
  final String displayName = await _getDisplayName();
  final router = AppRouter(isLoggedIn, isOnboarded, displayName).router;  
  navService.setRouter(router); 
  runApp(BaviApp(router: router));
}

// Load user data from SharedPreferences
  Future<bool> _checkUserLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<bool> _checkUserOnboard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isOnboarded') ?? false;
  }
  Future<String> _getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('displayName') ?? "";
  }

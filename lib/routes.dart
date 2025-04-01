import 'package:bavi/addVideo/view/add_video_page.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/home/widgets/video_scroll.dart';
import 'package:bavi/login/view/login_page.dart';
import 'package:bavi/login/widgets/onboarding.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/settings/view/settings_page.dart'; 
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRouter {
  final bool initalIsLoggedIn;
  final bool isOnboarded;
  final String name;
  AppRouter(this.initalIsLoggedIn, this.isOnboarded, this.name);
  late final GoRouter router = GoRouter(
    initialLocation: 
    initalIsLoggedIn==true && isOnboarded==true? 
    '/home'
    : 
    initalIsLoggedIn==true && isOnboarded==false?
    '/onboarding?name=$name'
    :
    '/login',
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      await Future.delayed(const Duration(milliseconds: 300)).then((value) {
        if (!isLoggedIn && state.fullPath != '/login') {
          return '/login'; // Force logout
        }
      });
    return null;
  },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          // Extract the name from queryParams
          final String name = state.uri.queryParameters['name'] ?? '';
          return WelcomePage(
            name:name
          );},
      ),
      GoRoute(
        path: '/addVideo',
        builder: (context, state) {
          
          final String isOnboarding = state.uri.queryParameters['isOnboarding'] ?? "false";
         print(state.uri.queryParameters);
         return AddVideoPage(
            isOnboarding: isOnboarding=="true"?true:false,
          );
          },
      ),
      GoRoute(
        path: '/videoPlayer',
        builder: (context, state) {
          // Extract the videoList from state.extra
          final videoList = state.extra as List<ExtractedVideoInfo>;

          // Extract the initialPosition from queryParams
          final initialPosition = int.parse(state.uri.queryParameters['initialPosition'] ?? '0');
          
          // Pass the extracted data to VideoPlayerPage
          return VideoPlayerPage(
            videoList: videoList,
            initialPosition: initialPosition,
          );
        },
      ),
    ],
  );
}
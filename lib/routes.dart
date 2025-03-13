import 'package:bavi/addVideo/view/add_video_page.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/home/widgets/video_scroll.dart';
import 'package:bavi/login/view/login_page.dart';
import 'package:bavi/models/short_video.dart'; 
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRouter {
  final bool initalIsLoggedIn;
  AppRouter(this.initalIsLoggedIn);
  late final GoRouter router = GoRouter(
    initialLocation: initalIsLoggedIn ? '/home' : '/login',
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
        path: '/addVideo',
        builder: (context, state) => const AddVideoPage(),
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
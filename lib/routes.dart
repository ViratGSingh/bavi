import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/home/widgets/video_scroll.dart';
import 'package:bavi/home/widgets/web_view.dart';
import 'package:bavi/login/view/login_page.dart';
import 'package:bavi/onboarding/view/onboarding_page.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bavi/widgets/loading.screen.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  final bool isLoggedIn;
  final bool hasCompletedOnboarding;
  AppRouter(this.isLoggedIn, {this.hasCompletedOnboarding = true});
  late final GoRouter router = GoRouter(
    initialLocation: hasCompletedOnboarding ? '/home' : '/onboarding',
    redirect: (context, state) {
      final uriString = state.uri.toString();
      if (uriString.startsWith('http') || uriString.startsWith('https')) {
        navService.goTo('/webview', extra: {'url': uriString});
      }
      return null;
    },
    errorBuilder: (context, state) {
      // Fallback — show WebView for any unmatched URL
      return WebViewPage(url: state.uri.toString(), isInitial: true);
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          if (state.extra != null) {
            final extra = state.extra as Map<String, dynamic>;
            final query = extra['query'] as String;
            return HomePage(query: query);
          } else {
            return HomePage();
          }
        },
      ),
      GoRoute(
        path: '/webview',
        builder: (context, state) {
          if (state.extra != null) {
            final extra = state.extra as Map<String, dynamic>;
            final webUrl = extra['url'] as String;
            return WebViewPage(url: webUrl, isInitial: true);
          } else {
            return HomePage();
          }
        },
      ),
      // GoRoute(
      //   path: '/search',
      //   builder: (context, state) {
      //     final extra = state.extra as Map<String, dynamic>;
      //     final videos = extra["videos"] as List<ExtractedVideoInfo>;

      //     return WillPopScope(
      //       onWillPop: () async {
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute<void>(
      //             builder: (BuildContext context) => const HomePage(),
      //           ),
      //         );
      //         return false;
      //       },
      //       child: AnswersView(
      //         videos: videos,
      //       ),
      //     );
      //   },
      // ),
      GoRoute(
        path: '/taskResult',
        builder: (context, state) {
          // Extract the videoList from state.extra
          final videoInfoList = state.extra as List<ExtractedVideoInfo>;

          // Pass the extracted data to VideoPlayerPage
          return VideoPlayerPage(videoList: videoInfoList, initialPosition: 0);
          // HomeVideoPlayerWidget(
          //   videoUrl: videoInfo.videoData.videoUrl,
          // );
        },
      ),
      // GoRoute(
      //   path: '/searchResult',
      //   builder: (context, state) {
      //     // Extract the videoList from state.extra
      //     final videoInfoList = state.extra as List<ExtractedVideoInfo>;

      //     // Pass the extracted data to VideoPlayerPage
      //     return SearchResultsGridScreen(savedVideos: videoInfoList);
      //     // HomeVideoPlayerWidget(
      //     //   videoUrl: videoInfo.videoData.videoUrl,
      //     // );
      //   },
      // ),
      
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final skipToSetup = extra?['skipToSetup'] as bool? ?? false;
          return OnboardingPage(skipToSetup: skipToSetup);
        },
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: '/videoPlayer',
        builder: (context, state) {
          // Extract the videoList from state.extra
          final videoList = state.extra as List<ExtractedVideoInfo>;

          // Extract the initialPosition from queryParams
          final initialPosition =
              int.parse(state.uri.queryParameters['initialPosition'] ?? '0');

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

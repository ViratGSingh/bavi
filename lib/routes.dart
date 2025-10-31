import 'package:bavi/answer/view/answer_page.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/home/widgets/answers_view.dart';
import 'package:bavi/home/widgets/video_grid.dart';
import 'package:bavi/home/widgets/video_scroll.dart';
import 'package:bavi/login/view/login_page.dart';
import 'package:bavi/login/widgets/onboarding.dart';
import 'package:bavi/models/question_answer.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/profile/view/profile_page.dart';
import 'package:bavi/reply/view/reply_page.dart';
import 'package:bavi/settings/view/settings_page.dart';
import 'package:bavi/widgets/loading.screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRouter {
  final bool isLoggedIn;
  AppRouter(this.isLoggedIn);
  late final GoRouter router = GoRouter(
    initialLocation: isLoggedIn == true ? '/home' : '/login',
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
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/reply',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final query = extra['query'] as String;
          final searchTime = extra['searchTime'] as int;
          final isGlanceMode = extra['isGlanceMode'] as bool;
          String? searchId;
          if (extra.containsKey("searchId") == true) {
            searchId = extra['searchId'] as String;
          }
          final videos = extra["videos"] as List<ExtractedVideoInfo>;

          return WillPopScope(
            onWillPop: () async {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const HomePage(),
                ),
              );
              return false;
            },
            child: ReplyView(
              isGlanceMode:isGlanceMode,
              similarVideos: videos,
              query: query,
              searchId: searchId,
              searchTime: searchTime,
            ),
          );
        },
      ),
      GoRoute(
        path: '/answer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final query = extra['query'] as String;
          final process = extra['process'] as String;
          final answer = extra['answer'] as String;
          final videos = extra["videos"] as List<String>;
          final searchTime = extra['searchTime'] as int;
          final searchId = extra['searchId'] as String;

          return WillPopScope(
            onWillPop: () async {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const HomePage(),
                ),
              );
              return false;
            },
            child: AnswerView(
              sourceUrls: videos,
              query: query,
              process: process,
              answer: answer,
              searchTime: searchTime,
              searchId:searchId
            ),
          );
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
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          // Extract the name from queryParams
          final String name = state.uri.queryParameters['name'] ?? '';
          return WelcomePage(name: name);
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

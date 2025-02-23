import 'package:bavi/addVideo/view/add_video_page.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/login/view/login_page.dart';
import 'package:go_router/go_router.dart';


class AppRouter {
  final bool isLoggedIn;
  AppRouter(this.isLoggedIn);

  late final GoRouter router = GoRouter(
    initialLocation: isLoggedIn ? '/home' : '/login',
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
    ],
  );
}

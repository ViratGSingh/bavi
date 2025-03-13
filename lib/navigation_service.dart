import 'package:go_router/go_router.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();

  factory NavigationService() => _instance;

  NavigationService._internal();

  late GoRouter router;

  void setRouter(GoRouter goRouter) {
    router = goRouter;
  }

  // Navigate to a path with optional extra data and query parameters
  void goTo(String path, {Object? extra, Map<String, String>? queryParams}) {
    final uri = Uri(path: path, queryParameters: queryParams);
    router.go(uri.toString(), extra: extra);
  }

  void goToAndPopUntil(String path, {Object? extra, Map<String, String>? queryParams}) {
    final uri = Uri(path: path, queryParameters: queryParams);
    router.pushReplacement(uri.toString(), extra: extra);
  }
}

final navService = NavigationService();
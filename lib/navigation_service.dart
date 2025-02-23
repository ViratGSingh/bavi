import 'package:go_router/go_router.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();

  factory NavigationService() => _instance;

  NavigationService._internal();

  late GoRouter router;

  void setRouter(GoRouter goRouter) {
    router = goRouter;
  }

  void goTo(String path) {
    router.go(path);
  }
}

final navService = NavigationService();
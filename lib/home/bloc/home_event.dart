part of 'home_bloc.dart';

@immutable
sealed class HomeEvent {}

final class HomeNavOptionSelect extends HomeEvent {
  final NavBarOption page;
  HomeNavOptionSelect(this.page);
}

final class HomeSearchVideos extends HomeEvent {
  final String query;
  HomeSearchVideos(this.query);
}

final class HomeAttemptGoogle extends HomeEvent {
}

final class HomeFetchAllVideos extends HomeEvent {
}

final class HomeAttemptGoogleSignOut extends HomeEvent {
}

final class HomeDetectExtractVideoLink extends HomeEvent {
}


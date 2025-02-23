part of 'home_bloc.dart';

@immutable
sealed class HomeEvent {}

final class HomeNavOptionSelect extends HomeEvent {
  final NavBarOption page;
  HomeNavOptionSelect(this.page);
}
final class HomeAttemptGoogle extends HomeEvent {
}


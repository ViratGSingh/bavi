part of 'home_bloc.dart';

enum NavBarOption { home, search, saved, profile }

final class HomeState extends Equatable {
  const HomeState({
    this.page = NavBarOption.home,
  });

  final NavBarOption page;

  HomeState copyWith({
    NavBarOption? page,
  }) {
    return HomeState(
      page: page ?? this.page,
    );
  }

  

  @override
  List<Object> get props => [page];
}
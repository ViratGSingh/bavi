part of 'onboarding_bloc.dart';

final class OnboardingState extends Equatable {
  const OnboardingState({
    this.currentPage = 0,
    this.totalPages = 2,
  });

  final int currentPage;
  final int totalPages;

  OnboardingState copyWith({int? currentPage}) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages,
    );
  }

  @override
  List<Object> get props => [currentPage, totalPages];
}

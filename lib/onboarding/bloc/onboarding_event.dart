part of 'onboarding_bloc.dart';

@immutable
sealed class OnboardingEvent {}

final class OnboardingPageChanged extends OnboardingEvent {
  final int page;
  OnboardingPageChanged(this.page);
}

final class OnboardingNextPage extends OnboardingEvent {}

final class OnboardingSkipToSignIn extends OnboardingEvent {}

final class OnboardingCompleted extends OnboardingEvent {}

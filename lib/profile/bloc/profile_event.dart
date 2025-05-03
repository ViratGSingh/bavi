part of 'profile_bloc.dart';

@immutable
sealed class ProfileEvent {}

final class ProfileAttemptGoogle extends ProfileEvent {
}

final class ProfileFetchAllVideos extends ProfileEvent {
}

final class ProfileAttemptGoogleSignOut extends ProfileEvent {
}



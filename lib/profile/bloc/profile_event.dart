part of 'profile_bloc.dart';

sealed class ProfileEvent {}

final class ProfileLoadRequested extends ProfileEvent {}

final class ProfileMetricChanged extends ProfileEvent {
  final ProfileMetric metric;
  ProfileMetricChanged(this.metric);
}

final class ProfilePeriodChanged extends ProfileEvent {
  final StatPeriod period;
  ProfilePeriodChanged(this.period);
}

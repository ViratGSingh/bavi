part of 'profile_bloc.dart';

enum ProfileLoadStatus { initial, loading, success, failure }

final class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileLoadStatus.initial,
    this.displayName = '',
    this.email = '',
    this.profilePicUrl = '',
    this.stats,
    this.selectedMetric = ProfileMetric.curiosity,
    this.selectedPeriod = StatPeriod.weekly,
  });

  final ProfileLoadStatus status;
  final String displayName;
  final String email;
  final String profilePicUrl;
  final ProfileStats? stats;
  final ProfileMetric selectedMetric;
  final StatPeriod selectedPeriod;

  ProfileState copyWith({
    ProfileLoadStatus? status,
    String? displayName,
    String? email,
    String? profilePicUrl,
    ProfileStats? stats,
    ProfileMetric? selectedMetric,
    StatPeriod? selectedPeriod,
  }) =>
      ProfileState(
        status: status ?? this.status,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        profilePicUrl: profilePicUrl ?? this.profilePicUrl,
        stats: stats ?? this.stats,
        selectedMetric: selectedMetric ?? this.selectedMetric,
        selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      );

  @override
  List<Object?> get props => [
        status, displayName, email, profilePicUrl, stats,
        selectedMetric, selectedPeriod,
      ];
}

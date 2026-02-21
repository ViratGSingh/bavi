import 'package:bloc/bloc.dart';
import 'package:bavi/services/profile_stats_service.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(const ProfileState()) {
    on<ProfileLoadRequested>(_onLoad);
    on<ProfileMetricChanged>(_onMetricChanged);
    on<ProfilePeriodChanged>(_onPeriodChanged);
  }

  Future<void> _onLoad(
      ProfileLoadRequested event, Emitter<ProfileState> emit) async {
    emit(state.copyWith(status: ProfileLoadStatus.loading));
    try {
      final prefs = await SharedPreferences.getInstance();
      final displayName = prefs.getString('displayName') ?? '';
      final email = prefs.getString('email') ?? '';
      final profilePicUrl = prefs.getString('profile_pic_url') ?? '';

      final stats = await ProfileStatsService.fetchAndComputeStats();

      emit(state.copyWith(
        status: ProfileLoadStatus.success,
        displayName: displayName,
        email: email,
        profilePicUrl: profilePicUrl,
        stats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(status: ProfileLoadStatus.failure));
    }
  }

  void _onMetricChanged(
      ProfileMetricChanged event, Emitter<ProfileState> emit) {
    emit(state.copyWith(selectedMetric: event.metric));
  }

  void _onPeriodChanged(
      ProfilePeriodChanged event, Emitter<ProfileState> emit) {
    emit(state.copyWith(selectedPeriod: event.period));
  }
}

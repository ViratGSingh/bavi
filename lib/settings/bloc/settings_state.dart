part of 'settings_bloc.dart';

enum SettingsStatus { initial, success, failure, loading, logout, delete}

final class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    
  });

  final SettingsStatus status;

  SettingsState copyWith({
    SettingsStatus? status,
  }) {
    return SettingsState(
      status: status ?? this.status,
    );
  }

  

  @override
  List<Object> get props => [status];
}
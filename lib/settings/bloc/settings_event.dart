part of 'settings_bloc.dart';

@immutable
sealed class SettingsEvent {}

final class SettingsDelete extends SettingsEvent {
}
final class SettingsLogout extends SettingsEvent {
}

//Initiate Mixpanel
final class SettingsInitiateMixpanel extends SettingsEvent {
}


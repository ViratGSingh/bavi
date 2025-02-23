part of 'login_bloc.dart';

@immutable
sealed class LoginEvent {}

final class LoginInfoScrolled extends LoginEvent {
  final int position;
  LoginInfoScrolled(this.position);
}
final class LoginAttemptGoogle extends LoginEvent {
}


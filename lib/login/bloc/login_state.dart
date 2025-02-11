part of 'login_bloc.dart';

enum LoginStatus { initial, success, failure }

final class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.initial,
    this.position = 0,
  });

  final LoginStatus status;
  final int position;

  LoginState copyWith({
    LoginStatus? status,
    int? position,
  }) {
    return LoginState(
      status: status ?? this.status,
      position: position ?? this.position,
    );
  }

  

  @override
  List<Object> get props => [status, position];
}
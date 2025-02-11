import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final http.Client httpClient;
  LoginBloc({required this.httpClient}) : super(LoginState()) {
     on<LoginInfoScrolled>(_changeInfoPosition);
    
  }

  Future<void> _changeInfoPosition(
      LoginInfoScrolled event, Emitter<LoginState> emit) async {
    int updatedPosition = event.position;
    print(updatedPosition)
;    emit(state.copyWith(position: updatedPosition));
  }
  
}

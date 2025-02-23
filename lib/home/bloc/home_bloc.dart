import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final http.Client httpClient;
  HomeBloc({required this.httpClient}) : super(HomeState()) {
    on<HomeNavOptionSelect>(_changeNavOption);
    // on<HomeAttemptGoogle>(_handleGoogleSignIn);
  }

    Future<void> _changeNavOption(
      HomeNavOptionSelect event, Emitter<HomeState> emit) async {
    NavBarOption updatedPosition = event.page;
    emit(state.copyWith(page: updatedPosition));
  }


  
}

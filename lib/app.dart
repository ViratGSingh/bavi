import 'package:bavi/answer/bloc/answer_bloc.dart';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:bavi/login/view/login_page.dart';
import 'package:bavi/profile/bloc/profile_bloc.dart';
import 'package:bavi/reply/bloc/reply_bloc.dart';
import 'package:bavi/routes.dart';
import 'package:bavi/settings/bloc/settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BaviApp extends StatefulWidget {
  final GoRouter router;
  const BaviApp({super.key, required this.router});

  @override
  State<BaviApp> createState() => _BaviAppState();
}


class _BaviAppState extends State<BaviApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LoginBloc(httpClient: http.Client()),
        ),
        BlocProvider(
          create: (_) => HomeBloc(httpClient: http.Client()),
        ),
        // BlocProvider(
        //   create: (_) => ProfileBloc(httpClient: http.Client()),
        // ),
        // BlocProvider(
        //   create: (_) => SettingsBloc(httpClient: http.Client()),
        // ),
        BlocProvider(
          create: (_) => ReplyBloc(httpClient: http.Client()),
        ),
        BlocProvider(
          create: (_) => AnswerBloc(httpClient: http.Client()),
        )
      ],
      child: MaterialApp.router(
        routerConfig: widget.router,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        ),
      ),
    );
  }
}

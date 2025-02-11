import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:bavi/login/view/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;


class BaviApp extends StatelessWidget {
  const BaviApp({super.key});


  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(httpClient: http.Client()),  
      child: const BaviAppView(),
    );
  }
}

class BaviAppView extends StatelessWidget {
  const BaviAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
      ),
      home: const LoginPage(),
    );
  }
}

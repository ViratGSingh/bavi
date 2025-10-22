import 'dart:io' show Platform;
import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          LoginBloc(httpClient: http.Client())..add(LoginInitiateMixpanel()),
      child: BlocBuilder<LoginBloc, LoginState>(builder: (context, state) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height / 2,
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white),
                          child: // Load a Lottie file from your assets
                              Lottie.asset(
                                  'assets/animations/onboarding_2.json',
                                  fit: BoxFit.contain),
                        ),
                        SizedBox(height: 15),
                        Container(
                          width: MediaQuery.of(context).size.width - 40,
                          child: Text(
                            'The Reel Way to Search',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 28,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        Container(
                          width: MediaQuery.of(context).size.width - 40,
                          child: Text(
                            'Skip the scroll and get answers from reels that actually help',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Visibility(
                          visible: Platform.isAndroid,
                          child: ElevatedButton(
                              onPressed: state.status == LoginStatus.loading || state.status == LoginStatus.guestLoading 
                                  ? null
                                  : () {
                                      context.read<LoginBloc>().add(
                                            LoginAttemptGoogle(),
                                          );
                                    },
                              style: ButtonStyle(
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      side: BorderSide(
                                          width: 1, color: Color(0xFFE6E7E8)),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  backgroundColor:
                                      WidgetStatePropertyAll(Color(0xFF8A2BE2)),
                                  fixedSize: WidgetStatePropertyAll(
                                    Size(MediaQuery.of(context).size.width - 40,
                                        56),
                                  )),
                              child: state.status == LoginStatus.loading
                                  ? CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          padding: EdgeInsets.all(4),
                                          child: SvgPicture.asset(
                                              "assets/images/login/google.svg",
                                              fit: BoxFit.cover),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )),
                        ),
 
                        // SizedBox(height: 15),
                        Visibility(
                          visible: Platform.isIOS,
                          child: ElevatedButton(
                              onPressed: state.status == LoginStatus.loading || state.status == LoginStatus.guestLoading 
                                  ? null
                                  : () {
                                      context.read<LoginBloc>().add(
                                            LoginAttemptGuest(),
                                          );
                                    },
                              style: ButtonStyle(
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      // side: BorderSide(
                                      //     width: 1, color: Color(0xFFE6E7E8)),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  backgroundColor:
                                      WidgetStatePropertyAll(Color(0xFF8A2BE2)),
                                  fixedSize: WidgetStatePropertyAll(
                                    Size(MediaQuery.of(context).size.width - 40,
                                        56),
                                  )),
                              child: state.status == LoginStatus.guestLoading
                                  ? CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // Container(
                                        //   width: 24,
                                        //   height: 24,
                                        //   decoration: BoxDecoration(
                                        //   color: Colors.white,
                                        //   borderRadius: BorderRadius.circular(12)
                          
                                        //   ),
                                        //   padding: EdgeInsets.all(4),
                                        //   child: SvgPicture.asset(
                                        //       "assets/images/login/google.svg",
                                        //       fit: BoxFit.cover),
                                        // ),
                                        // SizedBox(width: 12),
                                        Text(
                                          'Continue',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    context.read<LoginBloc>().add(LoginInitialize());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(builder: (context, state) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: Color(0xFF8A2BE2),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(0, 40, 0, 40),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Bavi",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      height: 0.8,
                      fontFamily: 'Gugi',
                    ),
                  ),
                  Container(
                    child: Column(
                      children: [
                        Container(
                          child: CarouselSlider(
                            options: CarouselOptions(
                              autoPlay: true,
                              //enlargeCenterPage: true,
                              padEnds: false,
                              aspectRatio: (MediaQuery.of(context).size.width -
                                      40) /
                                  (MediaQuery.of(context).size.width - 40 + 90),
                              viewportFraction: 1,
                              autoPlayAnimationDuration: Duration(seconds: 2),
                              onPageChanged: (index, reason) {
                                context
                                    .read<LoginBloc>()
                                    .add(LoginInfoScrolled(index));
                              },
                            ),
                            items: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width - 40,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Color(0xFFDFFF00)),
                                    child: // Load a Lottie file from your assets
                                        Lottie.asset(
                                            'assets/animations/onboarding_1.json',
                                            fit: BoxFit.contain),
                                  ),
                                  SizedBox(height: 15),
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width - 40,
                                    child: Text(
                                      'Make collections of your favourite videos',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width - 40,
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Color(0xFFDFFF00)),
                                    child: // Load a Lottie file from your assets
                                        Lottie.asset(
                                            'assets/animations/onboarding_2.json',
                                            fit: BoxFit.contain),
                                  ),
                                  SizedBox(height: 15),
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width - 40,
                                    child: Text(
                                      'Search from your collections with ease',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width - 40,
                                    padding: EdgeInsets.all(25),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Color(0xFFDFFF00)),
                                    child: // Load a Lottie file from your assets
                                        Lottie.asset(
                                            'assets/animations/onboarding_3.json',
                                            fit: BoxFit.contain),
                                  ),
                                  SizedBox(height: 15),
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width - 40,
                                    child: Text(
                                      'Back up your collections for free',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 0; i < 3; i++)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: ShapeDecoration(
                                    color: state.position == i
                                        ? Color(0xFFDFFF00)
                                        : Color(0xFFFCFFE6),
                                    shape: OvalBorder(),
                                  ),
                                ),
                              )
                          ],
                        ),
                        SizedBox(height: 20)
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      ElevatedButton(
                          onPressed: () {
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
                                  WidgetStatePropertyAll(Colors.white),
                              fixedSize: WidgetStatePropertyAll(
                                Size(
                                    MediaQuery.of(context).size.width - 40, 56),
                              )),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                child: SvgPicture.asset(
                                    "assets/images/login/google.svg",
                                    fit: BoxFit.cover),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  color: Color(0xFF090E1D),
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

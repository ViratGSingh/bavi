import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:bavi/onboarding/bloc/onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

class SigninScreen extends StatelessWidget {
  const SigninScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state.status == LoginStatus.success) {
          // LoginBloc already navigates to /home
        }
      },
      child: Column(
        children: [
          // Top lavender section with Lottie
          Expanded(
            flex: 50,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFE8D0F0),
              ),
              child: Center(
                child: Lottie.asset(
                  'assets/animations/onboarding_2.json',
                  width: MediaQuery.of(context).size.width * 0.85,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Bottom white card
          Expanded(
            flex: 50,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              transform: Matrix4.translationValues(0, -28, 0),
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              child: Column(
                children: [
                  const Text(
                    'Start Learning Now 🚀',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Take your first step towards mastering a new language\ntoday! 🎧',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  // Auth buttons
                  BlocBuilder<LoginBloc, LoginState>(
                    builder: (context, state) {
                      final isBusy = state.status == LoginStatus.loading ||
                          state.status == LoginStatus.appleLoading ||
                          state.status == LoginStatus.guestLoading;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Log In + Register row
                          Row(
                            children: [
                              // Log In (Google)
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isBusy
                                        ? null
                                        : () {
                                            context
                                                .read<OnboardingBloc>()
                                                .add(OnboardingCompleted());
                                            context
                                                .read<LoginBloc>()
                                                .add(LoginAttemptGoogle());
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      disabledBackgroundColor:
                                          Colors.black.withValues(alpha: 0.5),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(28),
                                      ),
                                    ),
                                    child: state.status == LoginStatus.loading
                                        ? const _Spinner()
                                        : const Text(
                                            'Log In',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Register (Apple)
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isBusy
                                        ? null
                                        : () {
                                            context
                                                .read<OnboardingBloc>()
                                                .add(OnboardingCompleted());
                                            context
                                                .read<LoginBloc>()
                                                .add(LoginAttemptApple());
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      disabledBackgroundColor:
                                          Colors.black.withValues(alpha: 0.5),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(28),
                                      ),
                                    ),
                                    child:
                                        state.status == LoginStatus.appleLoading
                                            ? const _Spinner()
                                            : const Text(
                                                'Register',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Continue with Guest
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: isBusy
                                  ? null
                                  : () {
                                      context
                                          .read<OnboardingBloc>()
                                          .add(OnboardingCompleted());
                                      context
                                          .read<LoginBloc>()
                                          .add(LoginAttemptGuest());
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(
                                  color: Colors.black26,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: state.status == LoginStatus.guestLoading
                                  ? const _Spinner(color: Colors.black)
                                  : const Text(
                                      'Continue with Guest',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                          // Error message
                          if (state.status == LoginStatus.failure) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Sign in failed. Please try again.',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({this.color = Colors.white});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(color: color, strokeWidth: 2.5),
    );
  }
}

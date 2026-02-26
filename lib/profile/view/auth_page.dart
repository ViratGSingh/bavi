import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;

/// Shows the auth bottom sheet and returns `true` if the user signed in.
Future<bool> showAuthBottomSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AuthBottomSheet(),
  );
  return result == true;
}

class AuthBottomSheet extends StatelessWidget {
  const AuthBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LoginBloc(httpClient: http.Client())..add(LoginInitiateMixpanel()),
      child: const _AuthSheetContent(),
    );
  }
}

class _AuthSheetContent extends StatelessWidget {
  const _AuthSheetContent();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state.status == LoginStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Close button row
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 22),
                onPressed: () => Navigator.of(context).pop(false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            // Logo
            // Container(
            //   width: 92,
            //   height: 92,
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(18),
            //     boxShadow: [
            //       BoxShadow(
            //         color: const Color(0xFF8A2BE2).withValues(alpha: 0.10),
            //         blurRadius: 16,
            //         spreadRadius: 4,
            //         offset: Offset.zero,
            //       ),
            //     ],
            //   ),
            //   child: ClipRRect(
            //     borderRadius: BorderRadius.circular(18),
            //     child: Image.asset(
            //       'assets/images/logo/icon.png',
            //       fit: BoxFit.cover,
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 20),
            const Text(
              'Welcome to Drissy',
              style: TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'To sync your history across devices and get \na cool profile card, please sign in with your Google account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
                        height: MediaQuery.of(context).size.height * 0.25,
                        child: Lottie.asset(
                          'assets/animations/onboarding_2.json',
                          fit: BoxFit.contain,
                        ),
                      ),
            const SizedBox(height: 16),
            BlocBuilder<LoginBloc, LoginState>(
              builder: (context, state) {
                final isBusy = state.status == LoginStatus.loading;
                return Column(
                  children: [
                    // Google — gradient
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A2BE2), Color(0xFFAB5CFA)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8A2BE2).withValues(alpha: 0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isBusy
                              ? null
                              : () => context
                                  .read<LoginBloc>()
                                  .add(LoginAttemptGoogle()),
                          borderRadius: BorderRadius.circular(16),
                          splashColor: Colors.white.withValues(alpha: 0.15),
                          child: Center(
                            child: isBusy
                                ? const _Spinner()
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: SvgPicture.asset(
                                          'assets/images/login/google.svg',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
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
                    const SizedBox(height: 20),
                    // Skip
                    // GestureDetector(
                    //   onTap: isBusy
                    //       ? null
                    //       : () => context
                    //           .read<LoginBloc>()
                    //           .add(LoginAttemptGuest()),
                    //   child: Padding(
                    //     padding: const EdgeInsets.symmetric(vertical: 6),
                    //     child: state.status == LoginStatus.guestLoading
                    //         ? const _Spinner(color: Color(0xFF8A2BE2))
                    //         : Row(
                    //             mainAxisAlignment: MainAxisAlignment.center,
                    //             children: const [
                    //               Text(
                    //                 'Skip for now',
                    //                 style: TextStyle(
                    //                   color: Color(0xFF6B7280),
                    //                   fontSize: 14,
                    //                   fontFamily: 'Poppins',
                    //                   fontWeight: FontWeight.w400,
                    //                 ),
                    //               ),
                    //               SizedBox(width: 4),
                    //               Icon(
                    //                 Icons.arrow_forward_ios_rounded,
                    //                 size: 12,
                    //                 color: Color(0xFF6B7280),
                    //               ),
                    //             ],
                    //           ),
                    //   ),
                    // ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FooterLink(label: 'Privacy policy', onTap: () {}),
                        const SizedBox(width: 4),
                        const Text(
                          '·',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _FooterLink(label: 'Terms of service', onTap: () {}),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.child,
    this.borderColor,
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color? borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.6),
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: borderColor != null
                ? BorderSide(color: borderColor!, width: 1)
                : BorderSide.none,
          ),
        ),
        child: child,
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12,
          fontFamily: 'Poppins',
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

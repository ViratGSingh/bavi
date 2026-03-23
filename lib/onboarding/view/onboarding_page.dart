import 'package:bavi/onboarding/bloc/onboarding_bloc.dart';
import 'package:bavi/onboarding/widgets/ai_setup_screen.dart';
import 'package:bavi/onboarding/widgets/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingBloc(),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    context.read<OnboardingBloc>().add(OnboardingPageChanged(page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          context.read<OnboardingBloc>().add(OnboardingPageChanged(page));
        },
        children: [
          // Screen 1: Welcome
          WelcomeScreen(
            onNext: () => _goToPage(1),
          ),
          // Screen 2: AI model download & setup
          AiSetupScreen(
            onNext: () async {
              final nav = GoRouter.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('hasCompletedOnboarding', true);
              if (mounted) nav.go('/home');
            },
          ),
        ],
      ),
    );
  }
}

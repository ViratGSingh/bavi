import 'dart:async';
import 'package:flutter/material.dart';

class _SetupSlide {
  final String title;
  final String subtitle;
  final String image;
  const _SetupSlide({
    required this.title,
    required this.subtitle,
    required this.image,
  });
}

const _slides = [
  _SetupSlide(
    title: 'Set Drissy as Your\nDefault Browser',
    subtitle:
        'Go to Settings > Apps > Default Apps and\nselect Drissy as your browser.',
    image: 'assets/images/onboarding/setup.png',
  ),
  _SetupSlide(
    title: 'Search Smarter,\nNot Harder',
    subtitle:
        'Just type naturally. Drissy understands\nwhat you mean, not just what you type.',
    image: 'assets/images/onboarding/feature_1.png',
  ),
  _SetupSlide(
    title: 'Deep Drissy Dives\nDeep for You',
    subtitle:
        'Tap the Deep Drissy mode for research that\ngoes beyond the first page of results.',
    image: 'assets/images/onboarding/feature_2.jpeg',
  ),
  _SetupSlide(
    title: 'Your Research,\nAll in One Place',
    subtitle:
        'Every search builds on the last. Drissy\nremembers context so you don\'t have to.',
    image: 'assets/images/onboarding/feature_3.png',
  ),
];

class FeaturesCarouselScreen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const FeaturesCarouselScreen({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  State<FeaturesCarouselScreen> createState() =>
      _FeaturesCarouselScreenState();
}

class _FeaturesCarouselScreenState extends State<FeaturesCarouselScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;
  Timer? _autoAdvanceTimer;
  int _currentSlide = 0;

  static const _slideDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: _slideDuration,
    );
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _progressController.forward(from: 0);
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(_slideDuration, () {
      if (!mounted) return;
      final next = (_currentSlide + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onSlideChanged(int index) {
    setState(() => _currentSlide = index);
    _startAutoAdvance();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top section with image
        Expanded(
          flex: 55,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFf3eafc),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Progress indicator bar at top
                  Positioned(
                    top: 8,
                    left: 56,
                    right: 56,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) => _SegmentedProgressBar(
                        totalSegments: _slides.length,
                        currentSegment: _currentSlide,
                        segmentProgress: _progressController.value,
                      ),
                    ),
                  ),
                  // Slide image
                  Positioned.fill(
                    top: 40,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Image.asset(
                          _slides[_currentSlide].image,
                          key: ValueKey(_currentSlide),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Bottom white card with sliding text
        Expanded(
          flex: 24,
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
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onSlideChanged,
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 36),
                        child: Column(
                          children: [
                            // Step indicator pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8A2BE2).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Step ${index + 1} of ${_slides.length}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8A2BE2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      "I'm Ready",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentedProgressBar extends StatelessWidget {
  final int totalSegments;
  final int currentSegment;
  final double segmentProgress;

  const _SegmentedProgressBar({
    required this.totalSegments,
    required this.currentSegment,
    required this.segmentProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSegments, (index) {
        final isCompleted = index < currentSegment;
        final isActive = index == currentSegment;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index < totalSegments - 1 ? 4 : 0,
            ),
            height: 3.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withValues(alpha: 0.4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: isCompleted
                  ? 1.0
                  : isActive
                      ? segmentProgress
                      : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

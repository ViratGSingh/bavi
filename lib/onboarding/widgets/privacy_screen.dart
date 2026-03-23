import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class PrivacyScreen extends StatelessWidget {
  final VoidCallback onNext;
  const PrivacyScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Shield icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB388FF), Color(0xFF8A2BE2)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8A2BE2).withValues(alpha: 0.30),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Iconsax.shield_tick_bold,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 28),
          // Heading
          const Text(
            'Your AI,\nOn Your Device',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'BagelFatOne',
              fontSize: 30,
              color: Color(0xFF8A2BE2),
            ),
          ),
          const SizedBox(height: 28),
          // Privacy points
          _PrivacyPoint(text: 'Runs completely on your phone'),
          const SizedBox(height: 14),
          _PrivacyPoint(text: 'No data sent to the cloud'),
          const SizedBox(height: 14),
          _PrivacyPoint(text: 'Creative, accurate answers with less hallucination'),
          const SizedBox(height: 28),
          // Subtext
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Powered by Drissy Qwen \u2014 a fine-tuned 2B parameter model built for creative writing, better context handling, and reduced hallucinations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ),
          const Spacer(flex: 3),
          // Next button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A2BE2),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  final String text;
  const _PrivacyPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF8A2BE2),
            size: 18,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

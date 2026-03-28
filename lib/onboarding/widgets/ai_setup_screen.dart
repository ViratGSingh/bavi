import 'dart:async';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

const _loadingTips = [
  'Drissy scores 92.9% accuracy — nearly double the vanilla model.',
  'Trained on 2,168 real-world examples distilled from DeepSeek V3.',
  '135,000 entities pre-loaded for instant recognition.',
  'Built on Qwen3.5-2B\'s hybrid Gated DeltaNet + Attention architecture.',
  'Zero refusals — if the answer is in context, Drissy finds it.',
  'Two-level memory: static engrams + dynamic per-query attention bias.',
  'Your searches never leave your device. True privacy.',
  'Fine-tuned with LoRA across all projection layers in 15 minutes.',
];

class AiSetupScreen extends StatefulWidget {
  final VoidCallback onNext;
  const AiSetupScreen({super.key, required this.onNext});

  @override
  State<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends State<AiSetupScreen> {
  int _currentTip = 0;
  Timer? _tipTimer;

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startTipRotation() {
    if (_tipTimer != null) return;
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _currentTip = (_currentTip + 1) % _loadingTips.length);
    });
  }

  void _stopTipRotation() {
    _tipTimer?.cancel();
    _tipTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      buildWhen: (prev, curr) =>
          prev.localAIStatus != curr.localAIStatus ||
          prev.localAIDownloadProgress != curr.localAIDownloadProgress ||
          prev.localAITotalBytes != curr.localAITotalBytes ||
          prev.localAIVisionTotalBytes != curr.localAIVisionTotalBytes ||
          prev.localAIDownloadPhase != curr.localAIDownloadPhase,
      listenWhen: (prev, curr) => prev.localAIStatus != curr.localAIStatus,
      listener: (context, homeState) {
        if (homeState.localAIStatus == LocalAIStatus.downloading ||
            homeState.localAIStatus == LocalAIStatus.loading) {
          _startTipRotation();
        } else {
          _stopTipRotation();
        }
        // Auto-navigate to home once model is ready
        if (homeState.localAIStatus == LocalAIStatus.ready) {
          widget.onNext();
        }
      },
      builder: (context, homeState) {
        final status = homeState.localAIStatus;
        final progress = homeState.localAIDownloadProgress;

        return Column(
          children: [
            // Top section — model showcase on lavender
            Expanded(
              flex: 55,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFf3eafc),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        // Tag pills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8A2BE2)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ON-DEVICE',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8A2BE2),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8A2BE2)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '2B PARAMS',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8A2BE2),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // D with chat icon inside
                                  Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      Text(
                                        'D',
                                        style: TextStyle(
                                          color: Color(0xFF8A2BE2),
                                          fontSize: 56,
                                          fontFamily: 'BagelFatOne',
                                          height: 1,
                                        ),
                                      ),
                                      Container(
                                        color: Color(0xFF8A2BE2),
                                        width: 20,
                                        height: 30,
                                        child: SizedBox.shrink(),
                                      ),
                                      // Yellow chat bubble icon positioned inside D's counter
                                      Positioned(
                                        top: 24,
                                        left: 14,
                                        child: CustomPaint(
                                          size: Size(10, 18),
                                          painter: ChatBubblePainter(
                                            color: Color(0xFFDFFF00),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // rissy text
                                  Text(
                                    'rissy',
                                    style: TextStyle(
                                      color: Color(0xFF8A2BE2),
                                      fontSize: 56,
                                      fontFamily: 'BagelFatOne',
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                ' Qwen',
                                style: TextStyle(
                                  fontFamily: 'BagelFatOne',
                                  fontSize: 56,
                                  color: Color(0xFF8A2BE2),
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Text(
                        //   'RAG-Engram Answer Engine',
                        //   style: TextStyle(
                        //     fontFamily: 'Poppins',
                        //     fontSize: 14,
                        //     fontWeight: FontWeight.w400,
                        //     color: const Color(0xFF8A2BE2)
                        //         .withValues(alpha: 0.6),
                        //   ),
                        // ),
                        const SizedBox(height: 20),
                        // Benchmark comparison
                        const _BenchmarkCard(),
                        const SizedBox(height: 14),
                        // Feature pills row
                        const Row(
                          children: [
                            Expanded(
                              child: _StatPill(
                                icon: Icons.shield_outlined,
                                label: 'Private',
                                sublabel: 'on your device',
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _StatPill(
                                icon: Icons.bolt_rounded,
                                label: 'Fast',
                                sublabel: 'answers',
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _StatPill(
                                icon: Icons.image_outlined,
                                label: 'Multimodal',
                                sublabel: 'text + images',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Architecture highlight
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF8A2BE2)
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8A2BE2)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.memory_rounded,
                                  color: Color(0xFF8A2BE2),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Two-level memory system',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '135K entities pre-loaded + per-query attention guidance',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom section — download action
            Expanded(
              flex: 25,
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    if (status == LocalAIStatus.idle ||
                        status == LocalAIStatus.error ||
                        status == LocalAIStatus.noStorage) ...[
                      const Text(
                        'Setting up your personal \nassistant',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        status == LocalAIStatus.noStorage
                            ? 'Not enough storage on your device. Free up at least 2 GB to download the model.'
                            : 'This requires a 1.86 GB download.\nWe recommend using Wi-Fi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: status == LocalAIStatus.noStorage
                              ? Colors.redAccent
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (status == LocalAIStatus.error) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Download failed. Check your connection.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ],
                    if (status == LocalAIStatus.downloading) ...[
                      Text(
                        homeState.localAIDownloadPhase.isNotEmpty
                            ? homeState.localAIDownloadPhase
                            : 'Downloading model...',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFFf3eafc),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF8A2BE2)),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(progress * 1855).toInt()} MB of 1855 MB',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Cycling tips like a game loading screen
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Padding(
                          key: ValueKey(_currentTip),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Color(0xFF8A2BE2),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _loadingTips[_currentTip],
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (status == LocalAIStatus.loading) ...[
                      const Text(
                        'Loading into memory...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Color(0xFF8A2BE2),
                          strokeWidth: 3,
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Padding(
                          key: ValueKey(_currentTip),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Color(0xFF8A2BE2),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _loadingTips[_currentTip],
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (status == LocalAIStatus.idle ||
                        status == LocalAIStatus.error ||
                        status == LocalAIStatus.noStorage)
                      const Spacer(),
                    if (status == LocalAIStatus.idle ||
                        status == LocalAIStatus.error ||
                        status == LocalAIStatus.noStorage)
                      _buildPrimaryButton(context, status),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrimaryButton(BuildContext context, LocalAIStatus status) {
    switch (status) {
      case LocalAIStatus.idle:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<HomeBloc>().add(HomeLocalAIDownloadAndLoad());
                },
                icon: const Icon(Iconsax.document_download_outline, size: 20),
                label: const Text(
                  'Download Model',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2BE2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            //const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () {
                  widget.onNext();
                },
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        );
      case LocalAIStatus.downloading:
      case LocalAIStatus.loading:
      case LocalAIStatus.ready:
        return const SizedBox.shrink();
      case LocalAIStatus.noStorage:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              // Re-check storage and retry
              context.read<HomeBloc>().add(HomeLocalAIDownloadAndLoad());
            },
            icon: const Icon(Icons.storage_rounded, size: 20),
            label: const Text(
              'Check Again',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2BE2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        );
      case LocalAIStatus.error:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              context.read<HomeBloc>().add(HomeLocalAIDownloadAndLoad());
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text(
              'Retry Download',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2BE2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        );
    }
  }
}

// Benchmark comparison card
class _BenchmarkCard extends StatelessWidget {
  const _BenchmarkCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8A2BE2).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Accuracy on real-world RAG',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '+42.9%',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _BarRow(
            label: 'Drissy Qwen',
            value: 92.9,
            color: Color(0xFF8A2BE2),
            isHighlighted: true,
          ),
          const SizedBox(height: 10),
          _BarRow(
            label: 'Vanilla Qwen 2B',
            value: 50.0,
            color: const Color(0xFF8A2BE2).withValues(alpha: 0.2),
            isHighlighted: false,
          ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isHighlighted;

  const _BarRow({
    required this.label,
    required this.value,
    required this.color,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                color: isHighlighted ? Colors.black87 : Colors.grey.shade500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isHighlighted
                    ? const Color(0xFF8A2BE2)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: const Color(0xFF8A2BE2).withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8A2BE2).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF8A2BE2), size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            sublabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

// ── Per-model config ──────────────────────────────────────────────────────────

class _ModelConfig {
  final String name;
  final String subtitle;
  final String paramTag;
  final Color bgColor;
  final Color accentColor;
  final IconData icon;
  final String downloadSizeLabel;
  final List<String> tips;
  final List<_FeaturePill> features;

  const _ModelConfig({
    required this.name,
    required this.subtitle,
    required this.paramTag,
    required this.bgColor,
    required this.accentColor,
    required this.icon,
    required this.downloadSizeLabel,
    required this.tips,
    required this.features,
  });
}

class _FeaturePill {
  final IconData icon;
  final String label;
  final String sublabel;
  const _FeaturePill(this.icon, this.label, this.sublabel);
}

const _gemma4Config = _ModelConfig(
  name: 'Gemma 4',
  subtitle: "Google's latest open model",
  paramTag: '2B PARAMS',
  bgColor: Color(0xFFE8F5E9),
  accentColor: Color(0xFF059669),
  icon: Icons.auto_awesome_rounded,
  downloadSizeLabel: '~4.1 GB',
  tips: [
    "Gemma 4 is Google's latest open model, optimized for on-device inference.",
    'Supports multi-turn conversations and advanced reasoning tasks.',
    'Your data stays private — all processing happens on your device.',
    "Built with Google's latest efficiency research for mobile hardware.",
    'Runs fully offline after download — no internet needed.',
  ],
  features: [
    _FeaturePill(Icons.shield_outlined, 'Private', 'on your device'),
    _FeaturePill(Icons.bolt_rounded, 'Fast', 'answers'),
    _FeaturePill(Icons.psychology_rounded, 'Reasoning', 'multi-turn'),
  ],
);

const _bonsaiConfig = _ModelConfig(
  name: 'Bonsai',
  subtitle: 'Ultra-efficient 1-bit model',
  paramTag: '8B PARAMS',
  bgColor: Color(0xFFFFF8E1),
  accentColor: Color(0xFFD97706),
  icon: Icons.bolt_rounded,
  downloadSizeLabel: '~1.2 GB',
  tips: [
    'Bonsai uses 1-bit quantization — radical efficiency without quality loss.',
    '8 billion parameters in a fraction of the usual storage.',
    'Built by PrismML for peak on-device and real-time performance.',
    'Your data never leaves your device. True privacy.',
    'Faster inference than most 7B models at a fraction of the size.',
  ],
  features: [
    _FeaturePill(Icons.shield_outlined, 'Private', 'on your device'),
    _FeaturePill(Icons.bolt_rounded, 'Ultra-fast', '1-bit model'),
    _FeaturePill(Icons.memory_rounded, 'Efficient', '8B params'),
  ],
);

// ── Page widget ───────────────────────────────────────────────────────────────

class ModelDownloadPage extends StatefulWidget {
  final HomeModel model;
  const ModelDownloadPage({super.key, required this.model});

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage> {
  int _currentTip = 0;
  Timer? _tipTimer;

  _ModelConfig get _config =>
      widget.model == HomeModel.gemma4 ? _gemma4Config : _bonsaiConfig;

  LocalAIStatus _statusFor(HomeState s) =>
      widget.model == HomeModel.gemma4 ? s.gemma4Status : s.bonsaiStatus;

  double _progressFor(HomeState s) => widget.model == HomeModel.gemma4
      ? s.gemma4DownloadProgress
      : s.bonsaiDownloadProgress;

  String _phaseFor(HomeState s) => widget.model == HomeModel.gemma4
      ? s.gemma4DownloadPhase
      : s.bonsaiDownloadPhase;

  void _startTips() {
    if (_tipTimer != null) return;
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(
          () => _currentTip = (_currentTip + 1) % _config.tips.length);
    });
  }

  void _stopTips() {
    _tipTimer?.cancel();
    _tipTimer = null;
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  void _triggerDownload(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (widget.model == HomeModel.gemma4) {
      context.read<HomeBloc>().add(HomeGemma4DownloadAndLoad());
    } else {
      context.read<HomeBloc>().add(HomeBonsaiDownloadAndLoad());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    return Scaffold(
      backgroundColor: cfg.bgColor,
      body: BlocConsumer<HomeBloc, HomeState>(
        buildWhen: (prev, curr) =>
            _statusFor(prev) != _statusFor(curr) ||
            _progressFor(prev) != _progressFor(curr) ||
            _phaseFor(prev) != _phaseFor(curr),
        listenWhen: (prev, curr) => _statusFor(prev) != _statusFor(curr),
        listener: (context, state) {
          final status = _statusFor(state);
          if (status == LocalAIStatus.downloading ||
              status == LocalAIStatus.loading) {
            _startTips();
          } else {
            _stopTips();
          }
          if (status == LocalAIStatus.ready) {
            // Small delay so the user sees the ready state briefly
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) Navigator.of(context).pop();
            });
          }
        },
        builder: (context, state) {
          final status = _statusFor(state);
          final progress = _progressFor(state);
          final phase = _phaseFor(state);

          return Column(
            children: [
              // ── Top section ────────────────────────────────────────────────
              Expanded(
                flex: 55,
                child: Container(
                  width: double.infinity,
                  color: cfg.bgColor,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Back button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      cfg.accentColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 16,
                                  color: cfg.accentColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Tag pills
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _TagPill('ON-DEVICE', cfg.accentColor),
                              const SizedBox(width: 8),
                              _TagPill(cfg.paramTag, cfg.accentColor),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Model icon + name
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: cfg.accentColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Icon(
                              cfg.icon,
                              size: 38,
                              color: cfg.accentColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            cfg.name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: cfg.accentColor,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cfg.subtitle,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: cfg.accentColor.withOpacity(0.65),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Feature pills
                          Row(
                            children: cfg.features
                                .map((f) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        child: _FeaturePillWidget(
                                          icon: f.icon,
                                          label: f.label,
                                          sublabel: f.sublabel,
                                          accentColor: cfg.accentColor,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Bottom section ────────────────────────────────────────────
              Expanded(
                flex: 45,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  transform: Matrix4.translationValues(0, -28, 0),
                  padding:
                      const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (status == LocalAIStatus.idle ||
                          status == LocalAIStatus.error ||
                          status == LocalAIStatus.noStorage) ...[
                        Text(
                          'Download ${cfg.name}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          status == LocalAIStatus.noStorage
                              ? const TextSpan(
                                  text:
                                      'Not enough storage. Free up at least 2 GB to download.',
                                )
                              : TextSpan(children: [
                                  const TextSpan(text: 'Requires a '),
                                  TextSpan(
                                    text: cfg.downloadSizeLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const TextSpan(
                                      text:
                                          ' download.\nWe recommend using Wi-Fi.'),
                                ]),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
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
                          phase.isNotEmpty
                              ? phase
                              : 'Downloading ${cfg.name}...',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor:
                                      const Color(0xFFf3eafc),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF8A2BE2)),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(progress * _sizeGb(cfg)).toStringAsFixed(2)} GB of ${cfg.downloadSizeLabel}',
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
                      ],
                      if (status == LocalAIStatus.ready) ...[
                        const Text(
                          'Ready!',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF059669),
                          size: 40,
                        ),
                      ],
                      // Tips (shown during download / loading)
                      if (status == LocalAIStatus.downloading ||
                          status == LocalAIStatus.loading) ...[
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Padding(
                            key: ValueKey(_currentTip),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
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
                                    cfg.tips[_currentTip %
                                        cfg.tips.length],
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
                      if (status == LocalAIStatus.idle ||
                          status == LocalAIStatus.error ||
                          status == LocalAIStatus.noStorage) ...[
                        const Spacer(),
                        _buildButton(context, status, cfg),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _sizeGb(_ModelConfig cfg) {
    // Parse the label like "~1.5 GB" → 1.5
    final match = RegExp(r'[\d.]+').firstMatch(cfg.downloadSizeLabel);
    return match != null ? double.tryParse(match.group(0)!) ?? 1.5 : 1.5;
  }

  Widget _buildButton(
      BuildContext context, LocalAIStatus status, _ModelConfig cfg) {
    switch (status) {
      case LocalAIStatus.idle:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _triggerDownload(context),
                icon: const Icon(Iconsax.document_download_outline,
                    size: 20),
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
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
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
      case LocalAIStatus.noStorage:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _triggerDownload(context),
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
            onPressed: () => _triggerDownload(context),
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
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Small helper widgets ──────────────────────────────────────────────────────

class _TagPill extends StatelessWidget {
  final String text;
  final Color accentColor;
  const _TagPill(this.text, this.accentColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accentColor,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _FeaturePillWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color accentColor;
  const _FeaturePillWidget({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 20),
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
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

// ── App-wide colour constants (matches Intelligence picker) ───────────────────

const _kAccent = Color(0xFF8A2BE2);
const _kBg = Color(0xFFF7F3FF);

// ── Per-model config ──────────────────────────────────────────────────────────

class _ModelConfig {
  final String name;
  final String subtitle;
  final String paramTag;
  final String logoAsset;
  final String downloadSizeLabel;
  final List<String> tips;
  final List<_FeaturePill> features;
  final List<String> tweetImages;

  const _ModelConfig({
    required this.name,
    required this.subtitle,
    required this.paramTag,
    required this.logoAsset,
    required this.downloadSizeLabel,
    required this.tips,
    required this.features,
    required this.tweetImages,
  });
}

class _FeaturePill {
  final IconData icon;
  final String label;
  final String sublabel;
  const _FeaturePill(this.icon, this.label, this.sublabel);
}

const _qwenConfig = _ModelConfig(
  name: 'Drissy Qwen',
  subtitle: 'Fine-tuned Qwen 3.5 2b model by Drissy',
  paramTag: '2B PARAMS',
  logoAsset: 'assets/images/logo/qwen.jpg',
  downloadSizeLabel: '~1.86 GB',
  tips: [
    'Drissy Qwen is a fine-tuned Qwen 3.5 2B model optimised for on-device RAG answers.',
    'Grounded responses mean fewer hallucinations — it cites what it knows.',
    'Your data stays private — all processing happens on your device.',
    'Built for speed: compact 2B parameters that run smoothly on modern phones.',
    'Runs fully offline after download — no internet needed.',
  ],
  features: [
    _FeaturePill(Icons.shield_outlined, 'Private', 'on your device'),
    _FeaturePill(Icons.bolt_rounded, 'Fast', 'answers'),
    _FeaturePill(Icons.image_outlined, 'Vision', 'text + images'),
  ],
  tweetImages: [
    'assets/images/onboarding/qwen/tweet_1.png',
    'assets/images/onboarding/qwen/tweet_2.png',
  ],
);

const _gemma4Config = _ModelConfig(
  name: 'Gemma 4',
  subtitle: "Google's latest open model",
  paramTag: '2B PARAMS',
  logoAsset: 'assets/images/logo/gemma.jpg',
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
  tweetImages: [
    'assets/images/onboarding/gemma/tweet_1.png',
    'assets/images/onboarding/gemma/tweet_2.png',
    'assets/images/onboarding/gemma/tweet_3.png',
  ],
);

const _liquidAIConfig = _ModelConfig(
  name: 'Liquid AI',
  subtitle: 'Compact multimodal model by Liquid AI',
  paramTag: '1.6B PARAMS',
  logoAsset: 'assets/images/logo/liquid_ai.jpg',
  downloadSizeLabel: '~2.1 GB',
  tips: [
    'LFM2.5-VL is a compact vision-language model built by Liquid AI.',
    'Understands both text and images — all running on your device.',
    'Only 1.6B parameters, optimised for speed without sacrificing quality.',
    'Your data stays private — no cloud, no servers, just your phone.',
    'Runs fully offline after download — no internet needed.',
  ],
  features: [
    _FeaturePill(Icons.shield_outlined, 'Private', 'on your device'),
    _FeaturePill(Icons.image_outlined, 'Vision', 'text + images'),
    _FeaturePill(Icons.bolt_rounded, 'Compact', '1.6B params'),
  ],
  tweetImages: [
    'assets/images/onboarding/liquid-ai/tweet_1.png',
    'assets/images/onboarding/liquid-ai/tweet_2.png',
    'assets/images/onboarding/liquid-ai/tweet_3.png',
  ],
);

const _bonsaiConfig = _ModelConfig(
  name: 'Bonsai',
  subtitle: 'Ultra-compact 1-bit 8B model by Prism ML',
  paramTag: '8B PARAMS',
  logoAsset: 'assets/images/logo/prism_ml.jpg',
  downloadSizeLabel: '~1.16 GB',
  tips: [
    'Bonsai is a 1-bit quantised 8B model by Prism ML, pushing the limits of compression.',
    'Despite being 8B parameters, the 1-bit format makes it extremely compact.',
    'Your data stays private — all processing happens on your device.',
    'Optimised for fast, high-quality text responses on-device.',
    'Runs fully offline after download — no internet needed.',
  ],
  features: [
    _FeaturePill(Icons.shield_outlined, 'Private', 'on your device'),
    _FeaturePill(Icons.compress_rounded, '1-bit', 'ultra compact'),
    _FeaturePill(Icons.text_fields_rounded, 'Text', 'only'),
  ],
  tweetImages: [
    'assets/images/onboarding/prism-ml/tweet_1.png',
    'assets/images/onboarding/prism-ml/tweet_2.png',
    'assets/images/onboarding/prism-ml/tweet_3.png',
    'assets/images/onboarding/prism-ml/tweet_4.png',
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

  int _currentImage = 0;
  Timer? _imageTimer;
  late final PageController _pageController;

  _ModelConfig get _config {
    if (widget.model == HomeModel.localAI) return _qwenConfig;
    if (widget.model == HomeModel.gemma4) return _gemma4Config;
    if (widget.model == HomeModel.bonsai) return _bonsaiConfig;
    return _liquidAIConfig;
  }

  LocalAIStatus _statusFor(HomeState s) {
    if (widget.model == HomeModel.localAI) return s.localAIStatus;
    if (widget.model == HomeModel.gemma4) return s.gemma4Status;
    if (widget.model == HomeModel.bonsai) return s.bonsaiStatus;
    return s.liquidAIStatus;
  }

  double _progressFor(HomeState s) {
    if (widget.model == HomeModel.localAI) return s.localAIDownloadProgress;
    if (widget.model == HomeModel.gemma4) return s.gemma4DownloadProgress;
    if (widget.model == HomeModel.bonsai) return s.bonsaiDownloadProgress;
    return s.liquidAIDownloadProgress;
  }

  String _phaseFor(HomeState s) {
    if (widget.model == HomeModel.localAI) return s.localAIDownloadPhase;
    if (widget.model == HomeModel.gemma4) return s.gemma4DownloadPhase;
    if (widget.model == HomeModel.bonsai) return s.bonsaiDownloadPhase;
    return s.liquidAIDownloadPhase;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startImageCarousel();
  }

  void _startImageCarousel() {
    _imageTimer = Timer.periodic(const Duration(milliseconds: 3600), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_pageController.page?.round() ?? 0) + 1;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _startTips() {
    if (_tipTimer != null) return;
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _currentTip = (_currentTip + 1) % _config.tips.length);
    });
  }

  void _stopTips() {
    _tipTimer?.cancel();
    _tipTimer = null;
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _imageTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _triggerDownload(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (widget.model == HomeModel.localAI) {
      context.read<HomeBloc>().add(HomeLocalAIDownloadAndLoad());
    } else if (widget.model == HomeModel.gemma4) {
      context.read<HomeBloc>().add(HomeGemma4DownloadAndLoad());
    } else if (widget.model == HomeModel.bonsai) {
      context.read<HomeBloc>().add(HomeBonsaiDownloadAndLoad());
    } else {
      context.read<HomeBloc>().add(HomeLiquidAIDownloadAndLoad());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    return Scaffold(
      backgroundColor: _kBg,
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
              // ── Top section: tweet carousel ───────────────────────────────
              Expanded(
                flex: 55,
                child: Container(
                  width: double.infinity,
                  color: _kBg,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back button + tag pills row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 20, 0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _kAccent.withValues(alpha: 0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 16,
                                    color: _kAccent,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              _TagPill('ON-DEVICE'),
                              const SizedBox(width: 6),
                              _TagPill(cfg.paramTag),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Tweet image carousel — full-width, infinite
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (page) {
                              setState(() {
                                _currentImage =
                                    page % cfg.tweetImages.length;
                              });
                            },
                            itemBuilder: (context, index) {
                              final imgPath = cfg.tweetImages[
                                  index % cfg.tweetImages.length];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _kAccent
                                              .withValues(alpha: 0.14),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      imgPath,
                                      width: double.infinity,
                                      fit: BoxFit.fitWidth,
                                      alignment: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Animated pill dot indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            cfg.tweetImages.length,
                            (i) {
                              final isActive = _currentImage == i;
                              return AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 280),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 3),
                                width: isActive ? 22 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? _kAccent
                                      : _kAccent.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
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
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Model identity row (logo + name + subtitle)
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              cfg.logoAsset,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cfg.name,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                    height: 1.15,
                                  ),
                                ),
                                Text(
                                  cfg.subtitle,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      // Download status content
                      if (status == LocalAIStatus.idle ||
                          status == LocalAIStatus.error ||
                          status == LocalAIStatus.noStorage) ...[
                        if (status == LocalAIStatus.noStorage)
                          const Text(
                            'Not enough storage. Free up at least 2 GB to download.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.redAccent,
                            ),
                          )
                        else
                          Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'Requires a '),
                              TextSpan(
                                text: cfg.downloadSizeLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(
                                  text: ' download. We recommend Wi-Fi.'),
                            ]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        if (status == LocalAIStatus.error) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Download failed. Check your connection.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
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
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                      _kAccent.withValues(alpha: 0.10),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          _kAccent),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(progress * _sizeGb(cfg)).toStringAsFixed(2)} GB of ${cfg.downloadSizeLabel}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
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
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: _kAccent,
                            strokeWidth: 3,
                          ),
                        ),
                      ],
                      if (status == LocalAIStatus.ready) ...[
                        const Text(
                          'Ready!',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF059669),
                          size: 36,
                        ),
                      ],
                      // Tips shown while downloading / loading
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
                                  color: _kAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cfg.tips[
                                        _currentTip % cfg.tips.length],
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF6B7280),
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
                  backgroundColor: _kAccent,
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
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
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
              backgroundColor: _kAccent,
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
              backgroundColor: _kAccent,
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
  const _TagPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kAccent,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _FeaturePillWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  const _FeaturePillWidget({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _kAccent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kAccent, size: 18),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          Text(
            sublabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModelPickerBottomSheet extends StatelessWidget {
  final HomeModel selectedModel;
  final LocalAIStatus localAIStatus;
  final double localAIDownloadProgress;
  final LocalAIStatus gemma4Status;
  final double gemma4DownloadProgress;
  final LocalAIStatus liquidAIStatus;
  final double liquidAIDownloadProgress;
  final LocalAIStatus bonsaiStatus;
  final double bonsaiDownloadProgress;
  final Function(HomeModel) onModelSelected;
  final VoidCallback onGemma4Tap;
  final VoidCallback onLiquidAITap;
  final VoidCallback onBonsaiTap;

  const ModelPickerBottomSheet({
    super.key,
    required this.selectedModel,
    required this.onModelSelected,
    required this.onGemma4Tap,
    required this.onLiquidAITap,
    required this.onBonsaiTap,
    this.localAIStatus = LocalAIStatus.idle,
    this.localAIDownloadProgress = 0.0,
    this.gemma4Status = LocalAIStatus.idle,
    this.gemma4DownloadProgress = 0.0,
    this.liquidAIStatus = LocalAIStatus.idle,
    this.liquidAIDownloadProgress = 0.0,
    this.bonsaiStatus = LocalAIStatus.idle,
    this.bonsaiDownloadProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Intelligence',
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the model powering your assistant',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // ── Qwen 3.5 ────────────────────────────────────────────────
                _ModelTile(
                  logoAsset: 'assets/images/logo/qwen.jpg',
                  title: 'Drissy Qwen',
                  subtitle: 'Fine-tuned Qwen 3.5 2b model for grounded on-device RAG answers',
                  tags: const ['Text', 'Vision', 'Recommended'],
                  tagColors: const [Color(0xFF7C3AED), Color(0xFF7C3AED), Color(0xFF7C3AED)],
                  isSelected: selectedModel == HomeModel.localAI,
                  localAIStatus: localAIStatus,
                  downloadProgress: localAIStatus == LocalAIStatus.downloading
                      ? localAIDownloadProgress
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onModelSelected(HomeModel.localAI);
                    Navigator.pop(context);
                  },
                ),
                _Divider(),
                // ── Gemma 4 ─────────────────────────────────────────────────
                _ModelTile(
                  logoAsset: 'assets/images/logo/gemma.jpg',
                  title: 'Gemma 4',
                  subtitle: "Google's latest open model that offers maximum versatility across all tasks and modalities",
                  tags: const ['Text', 'Vision', 'Best'],
                  tagColors: const [Color(0xFF7C3AED), Color(0xFF7C3AED), Color(0xFF7C3AED)],
                  isSelected: selectedModel == HomeModel.gemma4,
                  localAIStatus: gemma4Status,
                  downloadProgress:
                      gemma4Status == LocalAIStatus.downloading
                          ? gemma4DownloadProgress
                          : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onGemma4Tap();
                  },
                ),
                _Divider(),
                // ── Liquid AI ─────────────────────────────────────────────────
                _ModelTile(
                  logoAsset: 'assets/images/logo/liquid_ai.jpg',
                  title: 'Liquid AI',
                  subtitle: 'Ultra-efficient LFM2.5-VL-1.6B multimodal model optimised for mobiles with limited resources',
                  tags: const ['Text', 'Vision', 'Lightweight'],
                  tagColors: const [Color(0xFF7C3AED), Color(0xFF7C3AED), Color(0xFF7C3AED)],
                  isSelected: selectedModel == HomeModel.liquidAI,
                  localAIStatus: liquidAIStatus,
                  downloadProgress:
                      liquidAIStatus == LocalAIStatus.downloading
                          ? liquidAIDownloadProgress
                          : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onLiquidAITap();
                  },
                ),
                _Divider(),
                // ── Bonsai ───────────────────────────────────────────────────
                _ModelTile(
                  logoAsset: 'assets/images/logo/prism_ml.jpg',
                  title: 'Bonsai',
                  subtitle: "Prism ML's 1-bit quantised 8B model — ultra-compact on-device intelligence",
                  tags: const ['Text', 'Vision', '1-bit'],
                  tagColors: const [Color(0xFF7C3AED), Color(0xFF7C3AED), Color(0xFF7C3AED)],
                  isSelected: selectedModel == HomeModel.bonsai,
                  localAIStatus: bonsaiStatus,
                  downloadProgress:
                      bonsaiStatus == LocalAIStatus.downloading
                          ? bonsaiDownloadProgress
                          : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onBonsaiTap();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final String logoAsset;
  final String title;
  final String subtitle;
  final List<String> tags;
  final List<Color> tagColors;
  final bool isSelected;
  final LocalAIStatus localAIStatus;
  final double? downloadProgress;
  final VoidCallback? onTap;

  const _ModelTile({
    required this.logoAsset,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.tagColors,
    required this.isSelected,
    required this.localAIStatus,
    this.downloadProgress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = localAIStatus == LocalAIStatus.downloading;
    final isLoading = localAIStatus == LocalAIStatus.loading;
    final isReady = localAIStatus == LocalAIStatus.ready;
    // A model is "not yet obtained" if it's idle/error/noStorage and NOT the one
    // currently in the engine (i.e. not selected+ready)
    final notDownloaded = !isDownloading &&
        !isLoading &&
        !isReady &&
        !isSelected;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Opacity(
                  opacity: notDownloaded ? 0.35 : 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      logoAsset,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: notDownloaded
                              ? const Color(0xFFBEC3CC)
                              : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleText(),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          color: notDownloaded
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right badge
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8A2BE2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  )
                else if (!isReady)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Download',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
              ],
            ),
            // Tags
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: List.generate(tags.length, (i) {
                  final color =
                      i < tagColors.length ? tagColors[i] : Colors.grey;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(notDownloaded ? 0.05 : 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tags[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: notDownloaded
                            ? color.withOpacity(0.3)
                            : color,
                      ),
                    ),
                  );
                }),
              ),
            ],
            // Progress bar (during download)
            if (downloadProgress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: downloadProgress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF8A2BE2)),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitleText() {
    return subtitle;
  }
}

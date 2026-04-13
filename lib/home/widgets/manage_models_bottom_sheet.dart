import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ManageModelsBottomSheet extends StatefulWidget {
  const ManageModelsBottomSheet({super.key});

  @override
  State<ManageModelsBottomSheet> createState() =>
      _ManageModelsBottomSheetState();
}

class _ManageModelsBottomSheetState extends State<ManageModelsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      buildWhen: (prev, curr) =>
          prev.localAIStatus != curr.localAIStatus ||
          prev.gemma4Status != curr.gemma4Status ||
          prev.liquidAIStatus != curr.liquidAIStatus ||
          prev.bonsaiStatus != curr.bonsaiStatus,
      listener: (context, state) {},
      builder: (context, state) {
        final readyModels = <_ModelEntry>[];

        if (state.localAIStatus == LocalAIStatus.ready) {
          readyModels.add(const _ModelEntry(
            model: HomeModel.localAI,
            logoAsset: 'assets/images/logo/qwen.jpg',
            title: 'Qwen',
            subtitle: 'Fine-tuned Qwen 3.5 2b model for grounded on-device RAG answers',
            tags: ['Text', 'Vision', 'Recommended'],
            tagColors: [Color(0xFF7C3AED), Color(0xFF7C3AED), Color(0xFF7C3AED)],
          ));
        }
        if (state.gemma4Status == LocalAIStatus.ready) {
          readyModels.add(const _ModelEntry(
            model: HomeModel.gemma4,
            logoAsset: 'assets/images/logo/gemma.jpg',
            title: 'Gemma 4',
            subtitle: "Google's latest open model that offers maximum versatility across all tasks and modalities",
            tags: ['Text', 'Vision', 'Best'],
            tagColors: [Color(0xFF7C3AED), Color(0xFF7C3AED), Color(0xFF7C3AED)],
          ));
        }
        if (state.liquidAIStatus == LocalAIStatus.ready) {
          readyModels.add(const _ModelEntry(
            model: HomeModel.liquidAI,
            logoAsset: 'assets/images/logo/liquid_ai.jpg',
            title: 'Liquid AI',
            subtitle: 'Ultra-efficient LFM2.5-VL-1.6B multimodal model optimised for mobiles with limited resources',
            tags: ['Text', 'Vision', 'Lightweight'],
            tagColors: [Color(0xFF7C3AED), Color(0xFF7C3AED), Color(0xFF7C3AED)],
          ));
        }
        if (state.bonsaiStatus == LocalAIStatus.ready) {
          readyModels.add(const _ModelEntry(
            model: HomeModel.bonsai,
            logoAsset: 'assets/images/logo/prism_ml.jpg',
            title: 'Bonsai',
            subtitle: "Prism ML's 1-bit quantised 8B model — ultra-compact on-device intelligence",
            tags: ['Text', 'Vision', '1-bit'],
            tagColors: [Color(0xFF7C3AED), Color(0xFF7C3AED), Color(0xFF7C3AED)],
          ));
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * (3 / 4),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
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
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Manage Models',
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
                  'Delete downloaded on-device models to free storage',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 20),
                if (readyModels.isEmpty)
                  _EmptyState()
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < readyModels.length; i++) ...[
                              if (i > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Divider(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              _ModelManageTile(
                                entry: readyModels[i],
                                onDeleteTap: () => _showDeleteConfirmation(
                                  context,
                                  readyModels[i],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext sheetContext, _ModelEntry entry) {
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: sheetContext,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Delete ${entry.title}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will permanently remove the model files from your device. You can re-download it later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _dispatchDelete(sheetContext, entry.model);
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _dispatchDelete(BuildContext context, HomeModel model) {
    final bloc = context.read<HomeBloc>();
    switch (model) {
      case HomeModel.localAI:
        bloc.add(HomeDeleteLocalAIModel());
      case HomeModel.gemma4:
        bloc.add(HomeDeleteGemma4Model());
      case HomeModel.liquidAI:
        bloc.add(HomeDeleteLiquidAIModel());
      case HomeModel.bonsai:
        bloc.add(HomeDeleteBonsaiModel());
      default:
        break;
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No models downloaded',
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Download a model from the Intelligence picker.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _ModelEntry {
  final HomeModel model;
  final String logoAsset;
  final String title;
  final String subtitle;
  final List<String> tags;
  final List<Color> tagColors;

  const _ModelEntry({
    required this.model,
    required this.logoAsset,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.tagColors,
  });
}

// ── Row widget ────────────────────────────────────────────────────────────────

class _ModelManageTile extends StatelessWidget {
  final _ModelEntry entry;
  final VoidCallback onDeleteTap;

  const _ModelManageTile({
    required this.entry,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  entry.logoAsset,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              GestureDetector(
                onTap: onDeleteTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          // Tags row
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: List.generate(entry.tags.length, (i) {
                final color =
                    i < entry.tagColors.length ? entry.tagColors[i] : Colors.grey;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.tags[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

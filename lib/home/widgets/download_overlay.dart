import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

class DownloadOverlay extends StatelessWidget {
  const DownloadOverlay({super.key});

  String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (previous, current) =>
          previous.gemmaDownloadStatus != current.gemmaDownloadStatus ||
          previous.gemmaDownloadProgress != current.gemmaDownloadProgress ||
          previous.gemmaDownloadMessage != current.gemmaDownloadMessage,
      builder: (context, state) {
        // Only show overlay when actively downloading
        if (state.gemmaDownloadStatus != GemmaDownloadStatus.loading) {
          return const SizedBox.shrink();
        }

        final progress = state.gemmaDownloadProgress;
        final totalSizeBytes = 420 * 1024 * 1024; // ~420 MB total
        final downloadedBytes = progress * totalSizeBytes;

        return Material(
          color: Colors.black.withOpacity(0.95),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated download icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, child) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFB388FF).withOpacity(0.3),
                              const Color(0xFF8A2BE2).withOpacity(0.3),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.arrow_down_2_bold,
                          color: Colors.white,
                          size: 48,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),

                  // Title
                  const Text(
                    "Downloading AI Model",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle - show current model being downloaded
                  Text(
                    state.currentDownloadingModel ==
                            LocalMemoryModelType.embedding
                        ? "Setting up embedding model (1/2)..."
                        : "Setting up query model (2/2)...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF8A2BE2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Progress stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatBytes(downloadedBytes),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      Text(
                        "${(progress * 100).toStringAsFixed(1)}%",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB388FF),
                        ),
                      ),
                      Text(
                        "~420 MB",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<HomeBloc>().add(HomeCancelGemmaDownload());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Cancel Download",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

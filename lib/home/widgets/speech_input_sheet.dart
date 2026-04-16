import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Inline speech-to-text panel — NOT a modal bottom sheet.
/// Embed inside an [AnimatedSize] to get the slide-up animation.
class SpeechInputSheet extends StatefulWidget {
  final TextEditingController textController;
  /// Called when the panel should close (Cancel or Use).
  final VoidCallback onDismiss;

  const SpeechInputSheet({
    super.key,
    required this.textController,
    required this.onDismiss,
  });

  @override
  State<SpeechInputSheet> createState() => _SpeechInputSheetState();
}

class _SpeechInputSheetState extends State<SpeechInputSheet>
    with TickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();

  bool _isListening = false;
  bool _isInitializing = true;
  bool _isManuallyStopped = false;

  String _committedText = '';
  String _currentText = '';

  String get _displayText => [_committedText, _currentText]
      .where((s) => s.trim().isNotEmpty)
      .join(' ')
      .trim();

  void _syncToController() {
    final text = _displayText;
    widget.textController.text = text;
    widget.textController.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length));
  }

  double _currentLevel = 0.0;

  late AnimationController _waveController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _decayTimer;
  Timer? _restartDebounce;


  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _decayTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      if (_currentLevel > 0.01) {
        setState(() {
          _currentLevel = (_currentLevel * 0.82).clamp(0.0, 1.0);
        });
      }
    });

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final bool available = await _speech.initialize(
      onError: (_) {
        if (!mounted || _isManuallyStopped) return;
        _scheduleRestart();
      },
      onStatus: (status) {
        if (!mounted || _isManuallyStopped) return;
        if (status == 'done' || status == 'notListening') {
          _commitCurrentSession();
          if (mounted) setState(() => _isListening = false);
          _scheduleRestart();
        }
      },
    );

    if (!mounted) return;
    setState(() => _isInitializing = false);

    if (available) {
      _startListening();
    } else {
      widget.onDismiss();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission required for voice input.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _commitCurrentSession() {
    final merged = _displayText;
    _committedText = merged;
    _currentText = '';
    _syncToController();
  }

  void _scheduleRestart() {
    _restartDebounce?.cancel();
    _restartDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isManuallyStopped) _startListening();
    });
  }

  Future<void> _startListening() async {
    if (!mounted || _isManuallyStopped) return;
    _currentText = '';

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!mounted || _isManuallyStopped) return;
        final String prev = _currentText;
        setState(() {
          _currentText = result.recognizedWords;
          if (_currentText.length > prev.length) {
            _currentLevel = (_currentLevel + 0.45).clamp(0.0, 1.0);
          }
        });
        _syncToController();
      },
      onSoundLevelChange: (double level) {
        if (!mounted || _isManuallyStopped) return;
        final double raw = Platform.isIOS
            ? ((level + 50.0) / 50.0).clamp(0.0, 1.0)
            : ((level + 2.0) / 12.0).clamp(0.0, 1.0);
        setState(() {
          _currentLevel = _currentLevel * 0.3 + raw * 0.7;
        });
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 8),
      partialResults: true,
      listenMode: ListenMode.dictation,
    );

    if (mounted && !_isManuallyStopped) {
      setState(() => _isListening = true);
    }
  }

  void _stopManually() {
    _commitCurrentSession();
    _isManuallyStopped = true;
    _restartDebounce?.cancel();
    _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _resumeListening() {
    _isManuallyStopped = false;
    _startListening();
  }

  void _useTranscription() {
    _stopManually();
    widget.onDismiss();
  }

  void _cancel() {
    _isManuallyStopped = true;
    _restartDebounce?.cancel();
    _speech.stop();
    widget.textController.clear();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    _restartDebounce?.cancel();
    _waveController.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = _displayText.isNotEmpty;

    return Container(
      // Fixed height so AnimatedSize knows the target size to animate toward.
      height: 160,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0533), Color(0xFF2D0A5E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Waveform
            SizedBox(
              height: 60,
              width: double.infinity,
              child: _isInitializing
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _waveController,
                      builder: (_, __) => CustomPaint(
                        painter: _AudioWaveformPainter(
                          level: _currentLevel,
                          phase: _waveController.value,
                          isListening: _isListening,
                        ),
                        size: Size.infinite,
                      ),
                    ),
            ),

            const SizedBox(height: 14),

            // Bottom row: Cancel | Mic orb (centered) | Use
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cancel — pinned left
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: _cancel,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Mic orb — always centered
                  AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final double glowRadius =
                        _isListening ? 14 + 10 * _pulseAnimation.value : 0;
                    final double glowOpacity =
                        _isListening ? 0.3 + 0.2 * _pulseAnimation.value : 0;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (_isListening) {
                          _stopManually();
                        } else {
                          _resumeListening();
                        }
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF8A2BE2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2)
                                  .withOpacity(glowOpacity),
                              blurRadius: glowRadius,
                              spreadRadius: glowRadius * 0.4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_off,
                          color: const Color(0xFFDFFF00),
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),

                  // Use button — pinned right
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: hasText ? _useTranscription : null,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Text(
                          'Use',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: hasText
                                ? const Color(0xFFDFFF00)
                                : Colors.white.withOpacity(0.2),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioWaveformPainter extends CustomPainter {
  final double level;
  final double phase;
  final bool isListening;

  const _AudioWaveformPainter({
    required this.level,
    required this.phase,
    required this.isListening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int count = 30;
    const double barWidth = 4.0;
    const double gap = 3.0;
    const double maxBarHeight = 48.0;
    const double minBarHeight = 3.0;

    final double totalWidth = count * barWidth + (count - 1) * gap;
    final double startX = (size.width - totalWidth) / 2;
    final double centerY = size.height / 2;

    final double phaseRad = phase * 2 * pi;
    final double amplitude = isListening ? 0.18 + level * 0.77 : 0.12;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final double w1 = sin(phaseRad + i * 0.45);
      final double w2 = sin(phaseRad * 0.65 + i * 1.0 + 1.3);
      final double combined = w1 * 0.65 + w2 * 0.35;

      final double env = 0.3 + 0.7 * sin((i / (count - 1)) * pi);
      final double frac =
          (combined * amplitude * env + amplitude * 0.5).clamp(0.0, 1.0);
      final double barHeight = max(minBarHeight, frac * maxBarHeight);

      final double opacity = (0.28 + frac * 0.72).clamp(0.0, 1.0);
      paint.color = const Color(0xFFDFFF00).withOpacity(opacity);

      final double left = startX + i * (barWidth + gap);
      final double top = centerY - barHeight / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AudioWaveformPainter old) =>
      level != old.level || phase != old.phase || isListening != old.isListening;
}

import 'dart:io' show Platform;
import 'package:llamadart/llamadart.dart';

class DrissyEngine {
  LlamaEngine? _engine;
  bool _isLoaded = false;
  bool _isVisionLoaded = false;

  bool get isLoaded => _isLoaded;
  bool get isVisionLoaded => _isVisionLoaded;

  static const String systemPrompt =
      '''You are Drissy, a private, conversational, and insightful answer engine. You do not save user data and keep as much processing as possible strictly on-device.

You answer user questions using a list of web sources.
Rules:
- Always answer in Markdown.
- Structure your response with clear headings and bullet points as needed.
- Always **bold key insights** and highlight notable places, dishes, or experiences.
- Be Conversational: Write naturally, like a knowledgeable friend.
- Only use the sources that directly answer the query.
- If no strong matches are found, say: "There isn't a perfect match for that, but here are a few options that might still interest you."
- Do not repeat the question or use generic filler lines.
- Keep your language engaging, detailed, and exhaustive.''';

  /// Generation params: max context, low stress, fast TTFT
  static const _generationParams = GenerationParams(
    maxTokens: 1024,
    temp: 0.6,
    topK: 10,
    topP: 0.9,
    minP: 0.0,
    penalty: 1.0,
    reusePromptPrefix: true,
    streamBatchTokenThreshold: 4,
    streamBatchByteThreshold: 64,
  );

  /// Load the GGUF model
  Future<bool> loadModel(String modelPath) async {
    try {
      _engine = LlamaEngine(LlamaBackend());
      await _engine!.loadModel(
        modelPath,
        modelParams: ModelParams(
          contextSize: 8192,
          gpuLayers: ModelParams.maxGpuLayers,
          numberOfThreads: 2,
          numberOfThreadsBatch: 4,
          batchSize: 2048,
          microBatchSize: 512,
          preferredBackend: Platform.isIOS ? GpuBackend.metal : GpuBackend.vulkan,
        ),
      );
      _isLoaded = true;

      // Pre-warm: run the system prompt through the model so the KV cache
      // is already populated before the first real query.
      await _warmup();

      return true;
    } catch (e) {
      print('Failed to load model: $e');
      _isLoaded = false;
      return false;
    }
  }

  /// Load the multimodal projector for vision support
  Future<bool> loadVisionProjector(String mmProjPath) async {
    if (_engine == null || !_isLoaded) return false;
    try {
      await _engine!.loadMultimodalProjector(mmProjPath);
      _isVisionLoaded = true;
      print('Vision projector loaded successfully');
      return true;
    } catch (e) {
      print('Failed to load vision projector: $e');
      _isVisionLoaded = false;
      return false;
    }
  }

  /// Pre-process the system prompt so it's cached in KV for reuse.
  Future<void> _warmup() async {
    if (_engine == null) return;
    try {
      final messages = [
        LlamaChatMessage.fromText(
          role: LlamaChatRole.system,
          text: systemPrompt,
        ),
        LlamaChatMessage.fromText(
          role: LlamaChatRole.user,
          text: 'hi',
        ),
      ];
      await for (final _ in _engine!.create(
        messages,
        params: const GenerationParams(maxTokens: 1),
        enableThinking: false,
      )) {
        break;
      }
    } catch (_) {
      // Warmup failure is non-fatal
    }
  }

  /// Ask Drissy a question with source context
  Stream<String> answer({
    required String query,
    required List<String> sources,
  }) async* {
    if (!_isLoaded || _engine == null) {
      yield 'Model not loaded.';
      return;
    }

    // Build sources context
    final sourcesText = sources
        .asMap()
        .entries
        .map((e) => 'Source ${e.key + 1}:\n${e.value}')
        .join('\n\n');

    final userMessage = sources.isNotEmpty
        ? 'Sources:\n$sourcesText\n\nUser question: $query'
        : query;

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: systemPrompt,
      ),
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: userMessage,
      ),
    ];

    try {
      await for (final chunk in _engine!.create(
        messages,
        params: _generationParams,
        enableThinking: false,
      )) {
        final content = chunk.choices.firstOrNull?.delta.content;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      }
    } catch (e) {
      print('DrissyEngine answer error: $e');
    }
  }

  /// Non-streaming completion for utility tasks (query rewriting, etc.)
  Future<String?> complete({
    required String systemMessage,
    required String userMessage,
    int maxTokens = 300,
    double temperature = 0.3,
  }) async {
    if (!_isLoaded || _engine == null) return null;

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: systemMessage,
      ),
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: userMessage,
      ),
    ];

    String result = '';
    await for (final chunk in _engine!.create(
      messages,
      params: GenerationParams(
        maxTokens: maxTokens,
        temp: temperature,
        topK: 10,
        topP: 0.9,
        minP: 0.0,
        penalty: 1.0,
        reusePromptPrefix: true,
        streamBatchTokenThreshold: 4,
        streamBatchByteThreshold: 64,
      ),
      enableThinking: false,
    )) {
      final content = chunk.choices.firstOrNull?.delta.content;
      if (content != null && content.isNotEmpty) {
        result += content;
      }
    }

    return result.trim().isNotEmpty ? result.trim() : null;
  }

  /// Streaming answer with image (vision) support for search mode
  Stream<String> answerWithImage({
    required String query,
    required String imagePath,
    required List<String> sources,
  }) async* {
    if (!_isLoaded || _engine == null) {
      yield 'Model not loaded.';
      return;
    }

    if (!_isVisionLoaded) {
      yield 'Vision is not available on this device. Please try again without an image.';
      return;
    }

    final sourcesText = sources
        .asMap()
        .entries
        .map((e) => 'Source ${e.key + 1}:\n${e.value}')
        .join('\n\n');

    final userMessage = sources.isNotEmpty
        ? 'Sources:\n$sourcesText\n\nUser question: $query'
        : query;

    final messages = <LlamaChatMessage>[
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: systemPrompt,
      ),
      LlamaChatMessage.withContent(
        role: LlamaChatRole.user,
        content: [
          LlamaImageContent(path: imagePath),
          LlamaTextContent(userMessage),
        ],
      ),
    ];

    try {
      await for (final chunk in _engine!.create(
        messages,
        params: _generationParams,
        enableThinking: false,
      )) {
        final content = chunk.choices.firstOrNull?.delta.content;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      }
    } catch (e) {
      print('DrissyEngine answerWithImage error: $e');
    }
  }

  /// Streaming chat with conversation history and optional image
  Stream<String> chat({
    required String systemMessage,
    required List<Map<String, String>> conversationMessages,
    String? imagePath,
  }) async* {
    if (!_isLoaded || _engine == null) {
      yield 'Model not loaded.';
      return;
    }

    final messages = <LlamaChatMessage>[
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: systemMessage,
      ),
    ];

    // Add previous conversation history (text only)
    for (int i = 0; i < conversationMessages.length - 1; i++) {
      final m = conversationMessages[i];
      final role = m['role'] == 'assistant'
          ? LlamaChatRole.assistant
          : LlamaChatRole.user;
      messages.add(LlamaChatMessage.fromText(
        role: role,
        text: m['content'] ?? '',
      ));
    }

    // Add the last user message — with image if provided and vision is loaded
    if (conversationMessages.isNotEmpty) {
      final lastMsg = conversationMessages.last;
      if (imagePath != null && _isVisionLoaded) {
        messages.add(LlamaChatMessage.withContent(
          role: LlamaChatRole.user,
          content: [
            LlamaImageContent(path: imagePath),
            LlamaTextContent(lastMsg['content'] ?? ''),
          ],
        ));
      } else {
        messages.add(LlamaChatMessage.fromText(
          role: LlamaChatRole.user,
          text: lastMsg['content'] ?? '',
        ));
      }
    }

    try {
      await for (final chunk in _engine!.create(
        messages,
        params: _generationParams,
        enableThinking: false,
      )) {
        final content = chunk.choices.firstOrNull?.delta.content;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      }
    } catch (e) {
      print('DrissyEngine chat error: $e');
    }
  }

  /// Stop current generation
  void stop() {
    _engine?.cancelGeneration();
  }

  /// Release model from memory
  void dispose() {
    _engine?.dispose();
    _engine = null;
    _isLoaded = false;
  }
}

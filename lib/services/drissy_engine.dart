import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:llamadart/llamadart.dart';
import 'pea_service.dart';
import 'pea_builder.dart';

class DrissyEngine {
  static final DrissyEngine _instance = DrissyEngine._internal();
  factory DrissyEngine() => _instance;
  DrissyEngine._internal();

  LlamaEngine? _engine;
  bool _isLoaded = false;
  bool _isVisionLoaded = false;

  bool get isLoaded => _isLoaded;
  bool get isVisionLoaded => _isVisionLoaded;

  final PeaService _peaService = PeaService();
  bool get isPeaLoaded => _peaService.isLoaded;

  String? _personalizationContext;


  void setPersonalization(String? context) {
    final trimmed = context?.trim();
    _personalizationContext =
        (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  }

  String _buildSystemPrompt() {
    if (_personalizationContext == null) return systemPrompt;
    return '$systemPrompt\n\nAbout the user: $_personalizationContext';
  }

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

  static const _storageChannel = MethodChannel('com.example.bavi/storage');

  Future<GpuBackend> _resolveAndroidGpuBackend() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();
    const chineseOems = {
      'xiaomi', 'redmi', 'poco',
      'oppo', 'realme', 'oneplus',
      'vivo', 'iqoo',
      'huawei', 'honor',
      'meizu', 'zte', 'nubia', 'tcl', 'lenovo',
    };
    final isChinese = chineseOems.any((brand) => manufacturer.contains(brand));
    return isChinese ? GpuBackend.opencl : GpuBackend.vulkan;
  }

  Future<bool> loadModel(String modelPath) async {
    try {
      int physicalBytes = 0;
      try {
        physicalBytes =
            await _storageChannel.invokeMethod<int>('getPhysicalMemoryBytes') ??
                0;
      } catch (_) {}
      final isLowRam =
          physicalBytes == 0 || physicalBytes < 6 * 1024 * 1024 * 1024;

      _engine = LlamaEngine(LlamaBackend());
      await _engine!.loadModel(
        modelPath,
        modelParams: ModelParams(
          contextSize: isLowRam ? 4096 : 8192,
          gpuLayers: ModelParams.maxGpuLayers,
          numberOfThreads: 2,
          numberOfThreadsBatch: isLowRam ? 2 : 4,
          batchSize: isLowRam ? 512 : 2048,
          microBatchSize: isLowRam ? 128 : 512,
          preferredBackend: Platform.isIOS
              ? GpuBackend.metal
              : await _resolveAndroidGpuBackend(),
        ),
      );
      _isLoaded = true;

      await _warmup();

      // Load personal engram if available
      await _peaService.load();
      if (_peaService.isLoaded) {
        print('PEA: personal engram loaded successfully');
        final backend = _engine!.backend;
        if (backend is NativeLlamaBackend) {
          await backend.setPeaAdapter(
            _peaService.nativeHandle.address,
          );
          print('PEA: inject hook wired into generation loop');
        }
      } else {
        print('PEA: no engram found, running without personalisation');
      }

      return true;
    } catch (e) {
      print('Failed to load model: $e');
      _isLoaded = false;
      return false;
    }
  }

  Future<bool> loadPeaFromBytes(List<int> bytes) async {
    await _peaService.saveFromBytes(bytes);
    return _peaService.load();
  }

  Future<List<int>> tokenize(String text) async {
    if (!_isLoaded || _engine == null) return [];
    return _engine!.tokenize(text, addSpecial: false);
  }


  Future<bool> savePreferences({
  required List<String> likes,
  required List<String> dislikes,
  }) async {
    // Tokenize each concept using the actual model tokenizer
    final likeTokens = <List<int>>[];
    for (final concept in likes) {
      final tokens = await tokenize(concept);
      likeTokens.add(tokens);
    }

    final dislikeTokens = <List<int>>[];
    for (final concept in dislikes) {
      final tokens = await tokenize(concept);
      dislikeTokens.add(tokens);
    }

    final path = await PeaBuilder.buildFromTokens(
      likeTokens: likeTokens,
      dislikeTokens: dislikeTokens,
      likeLabels: likes,
      dislikeLabels: dislikes,
    );
    return _peaService.loadFromPath(path);
  }

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
    } catch (_) {}
  }

  Stream<String> answer({
    required String query,
    required List<String> sources,
  }) async* {
    if (!_isLoaded || _engine == null) {
      yield 'Model not loaded.';
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

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: _buildSystemPrompt(),
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
        text: _buildSystemPrompt(),
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

  void stop() {
    _engine?.cancelGeneration();
  }

  void dispose() {
    _peaService.dispose();
    _engine?.dispose();
    _engine = null;
    _isLoaded = false;
  }
}
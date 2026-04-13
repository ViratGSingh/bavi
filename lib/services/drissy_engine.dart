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
  String? _loadedModelPath;

  bool get isLoaded => _isLoaded;
  bool get isVisionLoaded => _isVisionLoaded;
  String? get loadedModelPath => _loadedModelPath;

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
      // < 5 GB covers iPhone 13 and older (4 GB RAM).
      final isVeryLowRam =
          physicalBytes == 0 || physicalBytes < 5 * 1024 * 1024 * 1024;
      final isLowRam =
          physicalBytes == 0 || physicalBytes < 6 * 1024 * 1024 * 1024;

      // On iOS, any GPU layers >0 triggers Metal buffer allocation AND KV-cache
      // offload to Metal.  On 4 GB devices (iPhone 13), the combined Metal
      // allocation + mmap read during loading peaks at ~2 GB and hits the
      // jetsam limit.  CPU backend avoids all Metal allocation; the model is
      // mmap-paged lazily, keeping the loading peak under ~500 MB.
      // reusePromptPrefix caches the KV state so only the first query pays
      // full prefill cost; generation speed on A15 (4 threads) is ~10-15 t/s.
      final backend = Platform.isIOS && isVeryLowRam
          ? GpuBackend.cpu
          : (Platform.isIOS ? GpuBackend.metal : await _resolveAndroidGpuBackend());
      final gpuLayers = (Platform.isIOS && isVeryLowRam)
          ? 0
          : ModelParams.maxGpuLayers;

      // Await dispose so native Metal buffers are freed before allocating new
      // ones.  Without await the old engine's memory overlaps with the new
      // load, doubling peak usage during model switches.
      if (_engine != null) {
        print('[ModelSwitch] Unloading previous model from memory...');
        await _engine!.dispose();
        _engine = null;
        _isLoaded = false;
        _isVisionLoaded = false;
        _loadedModelPath = null;
      }

      _engine = LlamaEngine(LlamaBackend());
      await _engine!.loadModel(
        modelPath,
        modelParams: ModelParams(
          contextSize: isVeryLowRam ? 2048 : (isLowRam ? 4096 : 8192),
          gpuLayers: gpuLayers,
          numberOfThreads: isVeryLowRam ? 4 : 2,
          numberOfThreadsBatch: isLowRam ? 2 : 4,
          batchSize: isLowRam ? 512 : 2048,
          microBatchSize: isLowRam ? 128 : 512,
          preferredBackend: backend,
        ),
      );
      _isLoaded = true;
      _loadedModelPath = modelPath;

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
    int maxTokens = 1024,
    String? systemPromptSuffix,
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

    final basePrompt = _buildSystemPrompt();
    final finalSystemPrompt = systemPromptSuffix != null
        ? '$basePrompt\n\n$systemPromptSuffix'
        : basePrompt;

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: finalSystemPrompt,
      ),
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: userMessage,
      ),
    ];

    final params = maxTokens == 1024
        ? _generationParams
        : GenerationParams(
            maxTokens: maxTokens,
            temp: _generationParams.temp,
            topK: _generationParams.topK,
            topP: _generationParams.topP,
            minP: _generationParams.minP,
            penalty: _generationParams.penalty,
            reusePromptPrefix: _generationParams.reusePromptPrefix,
            streamBatchTokenThreshold:
                _generationParams.streamBatchTokenThreshold,
            streamBatchByteThreshold: _generationParams.streamBatchByteThreshold,
          );

    try {
      await for (final chunk in _engine!.create(
        messages,
        params: params,
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

  void unload() {
    _peaService.dispose();
    _engine?.dispose();
    _engine = null;
    _isLoaded = false;
    _isVisionLoaded = false;
    _loadedModelPath = null;
  }

  void dispose() {
    _peaService.dispose();
    _engine?.dispose();
    _engine = null;
    _isLoaded = false;
    _loadedModelPath = null;
  }
}
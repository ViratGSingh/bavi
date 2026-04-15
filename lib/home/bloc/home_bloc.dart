import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


import 'package:bavi/models/question_answer.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/models/thread.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart' as drift;
import 'package:bavi/app_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bavi/services/drissy_engine.dart';
import 'package:bavi/services/storage_checker.dart';
// import 'package:bavi/services/profile_stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final http.Client httpClient;
  final DrissyEngine _drissyEngine = DrissyEngine();
  String _personalizationText = '';

  static const String _modelFileName = 'drissy-qwen3.5-2b.Q4_K_M.gguf';
  static const String _modelDownloadUrl =
      'https://huggingface.co/drissea-ai/drissy-qwen3.5-2b-GGUF/resolve/main/drissy-qwen3.5-2b.Q4_K_M.gguf';
  static const String _mmProjFileName = 'drissy-qwen3.5-2b.BF16-mmproj.gguf';
  static const String _mmProjDownloadUrl =
      'https://huggingface.co/drissea-ai/drissy-qwen3.5-2b-GGUF/resolve/main/drissy-qwen3.5-2b.BF16-mmproj.gguf';

  static const String _gemma4FileName = 'gemma-4-E2B-it-Q4_K_M.gguf';
  static const String _gemma4DownloadUrl =
      'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf?download=true';
  static const String _gemma4MmProjFileName = 'gemma-4-E2B-it-mmproj-BF16.gguf';
  static const String _gemma4MmProjDownloadUrl =
      'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/mmproj-BF16.gguf';
  static const String _liquidAIFileName = 'LFM2.5-VL-1.6B-Q8_0.gguf';
  static const String _liquidAIDownloadUrl =
      'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/main/LFM2.5-VL-1.6B-Q8_0.gguf';
  static const String _liquidAIMmProjFileName = 'mmproj-LFM2.5-VL-1.6b-BF16.gguf';
  static const String _liquidAIMmProjDownloadUrl =
      'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/main/mmproj-LFM2.5-VL-1.6b-BF16.gguf';
  static const String _bonsaiFileName = 'Bonsai-8B.gguf';
  static const String _bonsaiDownloadUrl =
      'https://huggingface.co/prism-ml/Bonsai-8B-gguf/resolve/main/Bonsai-8B.gguf';
  // Bonsai has no multimodal projector — text-only model.
  // @override
  // void onTransition(Transition<HomeEvent, HomeState> transition) {
  //   super.onTransition(transition);
  //   print(
  //       "DEBUG: HomeBloc Transition: Event=${transition.event.runtimeType}, NextState.selectedImage=${transition.nextState.selectedImage?.path}, NextState.status=${transition.nextState.imageStatus}");
  // }

  Future<void> _loadPersonalization() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('personalization_enabled') ?? false;
    _personalizationText =
        enabled ? (prefs.getString('personalization_text') ?? '') : '';
    _drissyEngine.setPersonalization(
        _personalizationText.isNotEmpty ? _personalizationText : null);
  }

  HomeBloc({required this.httpClient}) : super(HomeState()) {
    _loadPersonalization();
    //Show Me
    on<HomeSwitchType>(_switchType);
    on<HomeSwitchPrivacyType>(_switchPrivacyType);
    on<HomeSwitchActionType>(_switchActionType);
    on<HomeGetAnswer>(_getFastAnswer);
    //on<HomeUpdateAnswer>(_updateGeneralGoogleAnswer);

    on<HomeCancelTaskGen>(_cancelTaskSearchQuery);
    on<HomeStartNewThread>(_startNewThread);
    //on<HomePortalSearch>(_portalSearch);
    on<HomeInitialUserData>(_getUserInfo);

    on<HomeModelSelect>(_handleModelSelect);
    on<HomeRetrieveSearchData>(_retrieveSearchData);
    on<HomeRefreshReply>(_refreshReply);
    on<HomeImageSelected>(_handleImageSelected);
    on<HomeImageUnselected>(_handleImageUnselected);
    on<HomeCancelOCRExtraction>(_handleCancelOCRExtraction);
    // on<HomeGenScreenshot>(_genScreenshot);
    //on<HomeNavToReply>(_navToReply);

    on<HomeSearchTypeSelected>(_handleSearchTypeSelected);
    //on<HomeExtractUrlData>(_extractUrlData);

    on<HomeToggleMapStatus>(_toggleMapStatus);
    on<HomeToggleYoutubeStatus>(_toggleYoutubeStatus);
    on<HomeToggleSpicyStatus>(_toggleSpicyStatus);
    on<HomeToggleInstagramStatus>(_toggleInstagramStatus);
    on<HomeToggleGeneralStatus>(_toggleGeneralStatus);
    on<HomeToggleChatMode>(_toggleChatMode);
    on<HomeCheckLocationAndAnswer>(_checkLocationAndAnswer);
    //on<HomeRequestLocationPermission>(_requestLocationPermission);
    on<HomeRetryPendingSearch>(_retryPendingSearch);
    on<HomeWebSearchResultsReceived>(_handleWebSearchResults);
    on<HomeToggleDeepDrissy>(_toggleDeepDrissy);
    on<HomeDeepDrissyGetAnswer>(_getDeepDrissyAnswer);
    on<HomeDeepDrissyWebSearchResultsReceived>(
        _handleDeepDrissyWebSearchResults);
    on<HomeLocalAIDownloadAndLoad>(_downloadAndLoadLocalModel);
    on<HomeLocalAIDownloadProgress>(_handleLocalAIDownloadProgress);
    on<HomeLocalAILoadIfDownloaded>(_loadModelIfDownloaded);
    on<HomeGemma4DownloadAndLoad>(_downloadAndLoadGemma4);
    on<HomeGemma4LoadIfDownloaded>(_loadGemma4IfDownloaded);
    on<HomeLiquidAIDownloadAndLoad>(_downloadAndLoadLiquidAI);
    on<HomeLiquidAILoadIfDownloaded>(_loadLiquidAIIfDownloaded);
    on<HomeCheckSecondaryModelsDownloaded>(_checkSecondaryModelsDownloaded);
    on<HomeDeleteAllHistory>(_deleteAllHistory);
    on<HomeObsidianNoteSelected>(_handleObsidianNoteSelected);
    on<HomeObsidianNoteCleared>(_handleObsidianNoteCleared);
    on<HomeVisualBrowseCompleted>(_handleVisualBrowseCompleted);
    on<HomeToggleVisualBrowse>(_toggleVisualBrowse);
    on<HomeVisualBrowseStart>(_handleVisualBrowseStart);
    on<HomeVisualBrowseImagesExtracted>(_handleVisualBrowseImagesExtracted);
    on<HomeToggleMoodboard>(_toggleMoodboard);
    on<HomeMoodboardStart>(_handleMoodboardStart);
    on<HomeMoodboardImagesExtracted>(_handleMoodboardImagesExtracted);
    on<HomeMoodboardCompleted>(_handleMoodboardCompleted);
    on<HomeDeleteLocalAIModel>(_deleteLocalAIModel);
    on<HomeDeleteGemma4Model>(_deleteGemma4Model);
    on<HomeDeleteLiquidAIModel>(_deleteLiquidAIModel);
    on<HomeBonsaiDownloadAndLoad>(_downloadAndLoadBonsai);
    on<HomeBonsaiLoadIfDownloaded>(_loadBonsaiIfDownloaded);
    on<HomeDeleteBonsaiModel>(_deleteBonsaiModel);
    on<HomeLoadSavedModel>(_loadSavedModel);
  }

  Completer<BrowseSearchResult>? _webSearchCompleter;
  Completer<List<ExtractedResultInfo>>? _deepDrissyWebSearchCompleter;
  Completer<List<VisualBrowseImageData>>? _visualBrowseCompleter;
  Completer<List<VisualBrowseImageData>>? _moodboardCompleter;

  void _handleWebSearchResults(
    HomeWebSearchResultsReceived event,
    Emitter<HomeState> emit,
  ) {
    if (_webSearchCompleter != null && !_webSearchCompleter!.isCompleted) {
      _webSearchCompleter!.complete(
        BrowseSearchResult(webResults: event.results, images: event.browseImages),
      );
    }
    emit(state.copyWith(webSearchQuery: null));
  }

  void _handleDeepDrissyWebSearchResults(
    HomeDeepDrissyWebSearchResultsReceived event,
    Emitter<HomeState> emit,
  ) {
    if (_deepDrissyWebSearchCompleter != null &&
        !_deepDrissyWebSearchCompleter!.isCompleted) {
      _deepDrissyWebSearchCompleter!.complete(event.results);
    }
    emit(state.copyWith(deepDrissyWebSearchQueries: null));
  }

  Future<void> _checkLocationAndAnswer(
    HomeCheckLocationAndAnswer event,
    Emitter<HomeState> emit,
  ) async {
    add(HomeGetAnswer(
      event.query,
      event.streamedText,
      event.extractedUrlDescription,
      event.extractedUrlTitle,
      event.extractedUrl,
      event.extractedImageUrl,
      event.imageDescription,
      event.imageDescriptionNotifier,
    ));
  }

  Future<void> _retryPendingSearch(
    HomeRetryPendingSearch event,
    Emitter<HomeState> emit,
  ) async {}

  // late Mixpanel mixpanel;
  // Future<void> initMixpanel() async {
  //   // initialize Mixpanel
  //   mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
  //       trackAutomaticEvents: false);
  //   mixpanel.track("home_view");
  // }

  // Future<void> _requestLocationPermission(
  //   HomeRequestLocationPermission event,
  //   Emitter<HomeState> emit,
  // ) async {}


  Future<void> _handleSearchTypeSelected(
    HomeSearchTypeSelected event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(searchType: event.searchType));
  }

  Future<void> _toggleMapStatus(
    HomeToggleMapStatus event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      mapStatus: state.mapStatus == HomeMapStatus.enabled
          ? HomeMapStatus.disabled
          : HomeMapStatus.enabled,
    ));
  }

  Future<void> _toggleYoutubeStatus(
    HomeToggleYoutubeStatus event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      youtubeStatus: state.youtubeStatus == HomeYoutubeStatus.enabled
          ? HomeYoutubeStatus.disabled
          : HomeYoutubeStatus.enabled,
    ));
  }

  Future<void> _toggleSpicyStatus(
    HomeToggleSpicyStatus event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      spicyStatus: state.spicyStatus == HomeSpicyStatus.enabled
          ? HomeSpicyStatus.disabled
          : HomeSpicyStatus.enabled,
    ));
  }

  Future<void> _toggleInstagramStatus(
    HomeToggleInstagramStatus event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      instagramStatus: state.instagramStatus == HomeInstagramStatus.enabled
          ? HomeInstagramStatus.disabled
          : HomeInstagramStatus.enabled,
    ));
  }

  Future<void> _toggleGeneralStatus(
    HomeToggleGeneralStatus event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      generalStatus: state.generalStatus == HomeGeneralStatus.enabled
          ? HomeGeneralStatus.disabled
          : HomeGeneralStatus.enabled,
    ));
  }

  Future<void> _toggleChatMode(
    HomeToggleChatMode event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      isChatModeActive: !state.isChatModeActive,
    ));
  }

  Future<void> _toggleDeepDrissy(
    HomeToggleDeepDrissy event,
    Emitter<HomeState> emit,
  ) async {
    final newStatus =
        state.deepDrissyStatus == HomeDeepDrissyStatus.enabled
            ? HomeDeepDrissyStatus.disabled
            : HomeDeepDrissyStatus.enabled;
    // When Deep Drissy is enabled, ensure web search is also enabled
    if (newStatus == HomeDeepDrissyStatus.enabled) {
      emit(state.copyWith(
        deepDrissyStatus: newStatus,
        generalStatus: HomeGeneralStatus.enabled,
      ));
    } else {
      emit(state.copyWith(deepDrissyStatus: newStatus));
    }
  }

  Future<void> _switchActionType(
    HomeSwitchActionType event,
    Emitter<HomeState> emit,
  ) async {
    bool isProperSentence = _isProperSentence(event.query);
    if (state.searchType != HomeSearchType.general) {
      isProperSentence = true;
    }
    emit(state.copyWith(
        actionType:
            isProperSentence ? HomeActionType.general : HomeActionType.agent));
  }

  Future<void> _handleImageSelected(
    HomeImageSelected event,
    Emitter<HomeState> emit,
  ) async {
    print("DEBUG: HomeBloc received HomeImageSelected: ${event.image.path}");
    emit(state.copyWith(
        selectedImage: event.image,
        imageStatus: HomeImageStatus.selected,
        isAnalyzingImage: true,
        ocrExtractionStatus: OCRExtractionStatus.loading));

    print(
        "DEBUG: HomeBloc after received HomeImageSelected: ${event.image.path}");

    await _analyzeImage(event.image, event.imageDescription, emit);
  }

  Future<void> _uploadImageToR2(XFile image, Emitter<HomeState> emit) async {
    try {
      final bytes = await File(image.path).readAsBytes();
      final fileName = "${const Uuid().v4()}.jpg";

      final accessKey = dotenv.get("R2_ACCESS_KEY_ID");
      final secretKey = dotenv.get("R2_SECRET_ACCESS_KEY");
      final endpoint = dotenv.get("R2_ENDPOINT");
      final publicBaseUrl = dotenv.get("R2_PUBLIC_BASE_URL");

      // Bucket: drissea
      // Folder: drissea_uploads
      // Path: drissea/drissea_uploads/filename.jpg

      // Ensure endpoint doesn't have trailing slash
      final cleanEndpoint = endpoint.endsWith('/')
          ? endpoint.substring(0, endpoint.length - 1)
          : endpoint;

      // Construct URI for the specific bucket and key
      final uri = Uri.parse("$cleanEndpoint/drissea/drissea_uploads/$fileName");

      await _uploadWithSigV4(
        uri: uri,
        method: 'PUT',
        payload: bytes,
        accessKey: accessKey,
        secretKey: secretKey,
        region: 'auto', // R2 uses 'auto'
      );

      // Public URL construction
      // Assuming publicBaseUrl points to the domain mapped to the bucket or folder
      // If publicBaseUrl is just the domain, we append the folder and filename.
      // If publicBaseUrl already includes the folder, we just append filename.
      // Let's assume publicBaseUrl is the domain root for now, so we append folder/filename.
      // Or if it's mapped to the bucket root.

      final cleanPublicBaseUrl = publicBaseUrl.endsWith('/')
          ? publicBaseUrl.substring(0, publicBaseUrl.length - 1)
          : publicBaseUrl;
      final publicUrl = "$cleanPublicBaseUrl/drissea_uploads/$fileName";

      print("DEBUG: Image upload success: $publicUrl");

      emit(state.copyWith(
        selectedImage: state.selectedImage,
        imageStatus: state.imageStatus,
        uploadedImageUrl: publicUrl,
        isAnalyzingImage: false,
      ));
    } catch (e) {
      print("DEBUG: Image upload error: $e");
      emit(state.copyWith(
        selectedImage: state.selectedImage,
        imageStatus: state.imageStatus,
        isAnalyzingImage: false,
      ));
    }
  }

  Future<void> _analyzeImage(XFile image,
      ValueNotifier<String> imageDescription, Emitter<HomeState> emit) async {
    // Initialize imageDescription to empty string
    imageDescription.value = "";

    try {
      // Verify the image file exists and is readable
      final file = File(image.path);
      if (!await file.exists()) {
        throw Exception('Image file not found');
      }

      // On-device vision will analyze the image when the user sends a query.
      // Just mark the image as ready.
      imageDescription.value = "Image selected for on-device analysis";

      emit(state.copyWith(
        selectedImage: state.selectedImage,
        imageStatus: state.imageStatus,
        uploadedImageUrl: "",
        isAnalyzingImage: false,
        ocrExtractionStatus: OCRExtractionStatus.success,
      ));
    } catch (e) {
      print("DEBUG: Image analysis error: $e");
      emit(state.copyWith(
        selectedImage: null,
        imageStatus: HomeImageStatus.unselected,
        uploadedImageUrl: "",
        isAnalyzingImage: false,
        ocrExtractionStatus: OCRExtractionStatus.failed,
      ));
      imageDescription.value = "";

      await Future.delayed(const Duration(milliseconds: 100));
      emit(state.copyWith(ocrExtractionStatus: OCRExtractionStatus.idle));
    }
  }

  Future<String> _describeImageWithAI(List<int> imageBytes) async {
    try {
      if (!_drissyEngine.isLoaded || !_drissyEngine.isVisionLoaded) {
        return "Image description not available (vision model not loaded)";
      }
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/describe_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      String result = "";
      await for (final token in _drissyEngine.chat(
        systemMessage: "You are a helpful assistant that describes images in detail. Describe what you see clearly and concisely.",
        conversationMessages: [
          {'role': 'user', 'content': 'Describe this image in detail.'},
        ],
        imagePath: tempFile.path,
      )) {
        result += token;
      }

      try { await tempFile.delete(); } catch (_) {}
      return result.isNotEmpty ? result : "No description available";
    } catch (e) {
      print("DEBUG: Image description error: $e");
      return "Error describing image";
    }
  }

  /// Extract text from image using PaddleOCR-VL-1.5 local model
  /// [task] can be: ocr, table, formula, chart, spotting, seal
  /// Falls back to Gemini if PaddleOCR server is unavailable
  Future<String> _extractTextWithPaddleOCR(
    List<int> imageBytes, {
    String task = 'ocr',
    int maxTokens = 2048,
  }) async {
    try {
      // Check file size limit (5MB)
      const int maxFileSizeBytes = 5 * 1024 * 1024;
      if (imageBytes.length > maxFileSizeBytes) {
        print(
            "DEBUG: File too large for PaddleOCR: ${imageBytes.length} bytes");
        return "Error: File too large. Maximum size is 5MB.";
      }

      final base64Image = base64Encode(imageBytes);

      // Call the Modal PaddleOCR server
      final ocrServerUrl = dotenv.maybeGet("PADDLE_OCR_SERVER_URL");

      // If no server URL configured, fallback to Gemini
      if (ocrServerUrl == null || ocrServerUrl.isEmpty) {
        print(
            "DEBUG: PADDLE_OCR_SERVER_URL not configured, falling back to Gemini");
        return await _describeImageWithAI(imageBytes);
      }

      final url = Uri.parse(ocrServerUrl);
      print("DEBUG: Calling PaddleOCR at: $url");

      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "image": base64Image,
              "task": task,
              "max_tokens": maxTokens,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check for errors
        if (data['error'] != null && data['error'].toString().isNotEmpty) {
          print("DEBUG: PaddleOCR error: ${data['error']}");
          return "Error: ${data['error']}";
        }

        final extractedText = data['extracted_text'] ?? "";
        print("DEBUG: PaddleOCR extracted ${extractedText.length} characters");
        return extractedText;
      } else {
        print(
            "DEBUG: PaddleOCR request failed: ${response.statusCode} - ${response.body}");
        // Fallback to Gemini
        print("DEBUG: Falling back to Gemini for image description");
        return await _describeImageWithAI(imageBytes);
      }
    } catch (e) {
      print("DEBUG: PaddleOCR error: $e");
      // Fallback to Gemini on any error
      print("DEBUG: Falling back to Gemini for image description");
      try {
        return await _describeImageWithAI(imageBytes);
      } catch (fallbackError) {
        return "Error extracting text: $e";
      }
    }
  }

  Future<void> _uploadWithSigV4({
    required Uri uri,
    required String method,
    required List<int> payload,
    required String accessKey,
    required String secretKey,
    required String region,
  }) async {
    // Basic SigV4 implementation
    // This requires 'crypto' package.
    // I'll add imports for crypto and convert.

    // ... Implementation details ...
    // Since I cannot easily add imports in this block without seeing the top of the file,
    // I will assume imports are needed and add them in a separate step if missing.
    // But I can't add imports here.

    // Actually, `aws_client` is in pubspec.
    // Let's try to use `minio` style simpler upload if possible? No.

    // I'll implement a VERY basic SigV4 signer here.
    // It's verbose but standard.

    // Imports needed:
    // import 'package:crypto/crypto.dart';
    // import 'dart:convert';

    // I will add the imports in the next step.

    final now = DateTime.now().toUtc();
    final dateStamp =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final amzDate =
        "${dateStamp}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z";

    final service = 's3';
    final host = uri.host;
    final canonicalUri = uri.path;
    final canonicalQueryString = '';
    final payloadHash = sha256.convert(payload).toString();

    final canonicalHeaders =
        'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
    final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
        '$method\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

    final algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign =
        '$algorithm\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest))}';

    final signingKey = _getSignatureKey(secretKey, dateStamp, region, service);
    final signature =
        Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authorizationHeader =
        '$algorithm Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    final response = await http.put(
      uri,
      headers: {
        'Authorization': authorizationHeader,
        'x-amz-date': amzDate,
        'x-amz-content-sha256': payloadHash,
        'Host': host,
      },
      body: payload,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }
  }

  List<int> _getSignatureKey(
      String key, String dateStamp, String regionName, String serviceName) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$key'))
        .convert(utf8.encode(dateStamp))
        .bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService =
        Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    final kSigning =
        Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }

  Future<void> _handleImageUnselected(
    HomeImageUnselected event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      uploadedImageUrl: "",
      selectedImage: null,
      imageStatus: HomeImageStatus.unselected,
      ocrExtractionStatus: OCRExtractionStatus.idle,
      isAnalyzingImage: false,
    ));
    event.imageDescription.value = "";
  }

  Future<void> _handleCancelOCRExtraction(
    HomeCancelOCRExtraction event,
    Emitter<HomeState> emit,
  ) async {
    print("DEBUG: OCR extraction cancelled by user");
    emit(state.copyWith(
      uploadedImageUrl: "",
      selectedImage: null,
      imageStatus: HomeImageStatus.unselected,
      ocrExtractionStatus: OCRExtractionStatus.cancelled,
      isAnalyzingImage: false,
    ));
    event.imageDescription.value = "";

    // Reset status after a short delay
    await Future.delayed(const Duration(milliseconds: 100));
    emit(state.copyWith(ocrExtractionStatus: OCRExtractionStatus.idle));
  }

  Future<void> _handleModelSelect(
    HomeModelSelect event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(selectedModel: event.model));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_model', event.model.name);
    if (event.model == HomeModel.localAI &&
        state.localAIStatus == LocalAIStatus.ready) {
      // File already downloaded — reload into engine (e.g. switching back from another model)
      add(HomeLocalAILoadIfDownloaded());
    } else if (event.model == HomeModel.localAI &&
        state.localAIStatus != LocalAIStatus.downloading &&
        state.localAIStatus != LocalAIStatus.loading) {
      add(HomeLocalAIDownloadAndLoad());
    } else if (event.model == HomeModel.gemma4 &&
        state.gemma4Status == LocalAIStatus.ready) {
      // File already downloaded — just load into engine
      add(HomeGemma4LoadIfDownloaded());
    } else if (event.model == HomeModel.liquidAI &&
        state.liquidAIStatus == LocalAIStatus.ready) {
      add(HomeLiquidAILoadIfDownloaded());
    } else if (event.model == HomeModel.bonsai &&
        state.bonsaiStatus == LocalAIStatus.ready) {
      add(HomeBonsaiLoadIfDownloaded());
    }
  }

  void _handleLocalAIDownloadProgress(
    HomeLocalAIDownloadProgress event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(localAIDownloadProgress: event.progress));
  }

  Future<void> _downloadAndLoadLocalModel(
    HomeLocalAIDownloadAndLoad event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');

      // Combined download size is ~1855 MB (model + vision projector).
      // Track total received bytes across both downloads for a single progress bar.
      const combinedEstimate = 1855 * 1024 * 1024; // fallback estimate
      int combinedReceivedBytes = 0;
      int combinedTotalBytes = combinedEstimate;

      final mmProjFile = File('${dir.path}/$_mmProjFileName');
      final needsModel = !await modelFile.exists();
      final needsVision = !await mmProjFile.exists();

      if (needsModel || needsVision) {
        // Check available storage before downloading
        final availableBytes = await StorageChecker.getAvailableBytes();
        const requiredBytes = 2 * 1024 * 1024 * 1024; // 2 GB
        if (availableBytes != null && availableBytes < requiredBytes) {
          emit(state.copyWith(localAIStatus: LocalAIStatus.noStorage));
          return;
        }

        emit(state.copyWith(
          localAIStatus: LocalAIStatus.downloading,
          localAIDownloadProgress: 0.0,
          localAIDownloadPhase: 'Downloading model...',
        ));
      }

      // Step 1: Download main model
      if (needsModel) {
        final request = http.Request('GET', Uri.parse(_modelDownloadUrl));
        final client = http.Client();
        final response = await client.send(request);

        if (response.statusCode != 200) {
          print('Model download failed: ${response.statusCode}');
          client.close();
          emit(state.copyWith(localAIStatus: LocalAIStatus.error));
          return;
        }

        final modelContentLength = response.contentLength ?? 0;
        if (modelContentLength > 0) {
          // Use actual model size + estimate for vision (~155 MB)
          combinedTotalBytes = modelContentLength + (155 * 1024 * 1024);
        }
        final sink = modelFile.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          combinedReceivedBytes += chunk.length;
          final progress = combinedReceivedBytes / combinedTotalBytes;
          if ((progress * 100).floor() >
              (state.localAIDownloadProgress * 100).floor()) {
            emit(state.copyWith(localAIDownloadProgress: progress.clamp(0.0, 0.99)));
          }
        }
        await sink.flush();
        await sink.close();
        client.close();
      }

      // Step 2: Download vision projector
      if (needsVision) {
        emit(state.copyWith(
          localAIDownloadPhase: 'Downloading vision model...',
        ));
        try {
          final mmRequest = http.Request('GET', Uri.parse(_mmProjDownloadUrl));
          final mmClient = http.Client();
          final mmResponse = await mmClient.send(mmRequest);
          if (mmResponse.statusCode == 200) {
            final mmContentLength = mmResponse.contentLength ?? 0;
            // Refine combined total with actual vision size
            if (mmContentLength > 0 && combinedReceivedBytes > 0) {
              combinedTotalBytes = combinedReceivedBytes + mmContentLength;
            }
            final mmSink = mmProjFile.openWrite();
            await for (final chunk in mmResponse.stream) {
              mmSink.add(chunk);
              combinedReceivedBytes += chunk.length;
              final progress = combinedReceivedBytes / combinedTotalBytes;
              if ((progress * 100).floor() >
                  (state.localAIDownloadProgress * 100).floor()) {
                emit(state.copyWith(localAIDownloadProgress: progress.clamp(0.0, 0.99)));
              }
            }
            await mmSink.flush();
            await mmSink.close();
            print('Vision projector downloaded');
          }
          mmClient.close();
        } catch (e) {
          print('mmproj download error (non-fatal): $e');
        }
      }

      if (needsModel || needsVision) {
        emit(state.copyWith(localAIDownloadProgress: 1.0));
      }

      // Step 3: Load model into engine
      // Brief pause to let the system reclaim download memory before loading
      // the model — prevents OOM on low-RAM (4 GB) devices.
      await Future.delayed(const Duration(seconds: 2));

      emit(state.copyWith(
        localAIStatus: LocalAIStatus.loading,
        localAIDownloadPhase: '',
      ));

      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        // Load vision projector if available
        if (await mmProjFile.exists()) {
          await _drissyEngine.loadVisionProjector(mmProjFile.path);
        }
        emit(state.copyWith(localAIStatus: LocalAIStatus.ready));
        print('Local AI model loaded successfully');
        print('[ModelSwitch] Active model → Qwen 3.5');
      } else {
        emit(state.copyWith(localAIStatus: LocalAIStatus.error));
      }
    } catch (e) {
      print('Local AI download/load error: $e');
      emit(state.copyWith(localAIStatus: LocalAIStatus.error));
    }
  }

  Future<void> _loadModelIfDownloaded(
    HomeLocalAILoadIfDownloaded event,
    Emitter<HomeState> emit,
  ) async {
    // Skip if already in-progress
    if (state.localAIStatus == LocalAIStatus.loading ||
        state.localAIStatus == LocalAIStatus.downloading) {
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');
      if (!await modelFile.exists()) return;

      // Engine already has Qwen loaded — no reload needed
      if (_drissyEngine.loadedModelPath == modelFile.path) {
        emit(state.copyWith(
          localAIStatus: LocalAIStatus.ready,
          selectedModel: HomeModel.localAI,
        ));
        print('[ModelSwitch] Active model → Qwen 3.5 (already in engine)');
        return;
      }

      emit(state.copyWith(localAIStatus: LocalAIStatus.loading));
      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        // Load vision projector if available
        final mmProjFile = File('${dir.path}/$_mmProjFileName');
        if (await mmProjFile.exists()) {
          await _drissyEngine.loadVisionProjector(mmProjFile.path);
        }
        emit(state.copyWith(
          localAIStatus: LocalAIStatus.ready,
          selectedModel: HomeModel.localAI,
        ));
        print('[ModelSwitch] Active model → Qwen 3.5');
      } else {
        emit(state.copyWith(localAIStatus: LocalAIStatus.error));
      }
    } catch (e) {
      print('Local AI load error: $e');
      emit(state.copyWith(localAIStatus: LocalAIStatus.error));
    }
  }

  // ── Startup: check secondary model files on disk ───────────────────────────

  Future<void> _checkSecondaryModelsDownloaded(
    HomeCheckSecondaryModelsDownloaded event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final gemma4File = File('${dir.path}/$_gemma4FileName');
      final liquidAIFile = File('${dir.path}/$_liquidAIFileName');
      final bonsaiFile = File('${dir.path}/$_bonsaiFileName');
      final gemma4Exists = await gemma4File.exists();
      final liquidAIExists = await liquidAIFile.exists();
      final bonsaiExists = await bonsaiFile.exists();
      if (gemma4Exists || liquidAIExists || bonsaiExists) {
        emit(state.copyWith(
          gemma4Status:
              gemma4Exists ? LocalAIStatus.ready : state.gemma4Status,
          liquidAIStatus:
              liquidAIExists ? LocalAIStatus.ready : state.liquidAIStatus,
          bonsaiStatus:
              bonsaiExists ? LocalAIStatus.ready : state.bonsaiStatus,
        ));
      }
    } catch (e) {
      print('Secondary model file check error: $e');
    }
  }

  // ── Restore last selected model on startup ─────────────────────────────────

  Future<void> _loadSavedModel(
    HomeLoadSavedModel event,
    Emitter<HomeState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('last_selected_model');
    HomeModel model = HomeModel.localAI;
    if (savedName != null) {
      try {
        model = HomeModel.values.byName(savedName);
      } catch (_) {
        model = HomeModel.localAI;
      }
    }

    switch (model) {
      case HomeModel.localAI:
        add(HomeLocalAILoadIfDownloaded());
      case HomeModel.gemma4:
        add(HomeGemma4LoadIfDownloaded());
      case HomeModel.liquidAI:
        add(HomeLiquidAILoadIfDownloaded());
      case HomeModel.bonsai:
        add(HomeBonsaiLoadIfDownloaded());
      default:
        // Cloud model — no local file to load, just restore the selection
        emit(state.copyWith(selectedModel: model));
    }
  }

  // ── Gemma 4 ────────────────────────────────────────────────────────────────

  Future<void> _downloadAndLoadGemma4(
    HomeGemma4DownloadAndLoad event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_gemma4FileName');
      final mmProjFile = File('${dir.path}/$_gemma4MmProjFileName');
      final needsModel = !await modelFile.exists();
      final needsVision = !await mmProjFile.exists();

      const combinedEstimate = 4258 * 1024 * 1024; // ~3.11 GB model + ~987 MB mmproj
      int combinedReceivedBytes = 0;
      int combinedTotalBytes = combinedEstimate;

      if (needsModel || needsVision) {
        final availableBytes = await StorageChecker.getAvailableBytes();
        const requiredBytes = 2 * 1024 * 1024 * 1024;
        if (availableBytes != null && availableBytes < requiredBytes) {
          emit(state.copyWith(gemma4Status: LocalAIStatus.noStorage));
          return;
        }
        emit(state.copyWith(
          gemma4Status: LocalAIStatus.downloading,
          gemma4DownloadProgress: 0.0,
          gemma4DownloadPhase: 'Downloading Gemma 4...',
        ));
      }

      // Step 1: Download main model
      if (needsModel) {
        final request = http.Request('GET', Uri.parse(_gemma4DownloadUrl));
        final client = http.Client();
        final response = await client.send(request);
        if (response.statusCode != 200) {
          print('Gemma 4 model download failed: ${response.statusCode}');
          client.close();
          emit(state.copyWith(gemma4Status: LocalAIStatus.error));
          return;
        }
        final modelContentLength = response.contentLength ?? 0;
        if (modelContentLength > 0) {
          combinedTotalBytes = modelContentLength + (600 * 1024 * 1024);
        }
        final sink = modelFile.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          combinedReceivedBytes += chunk.length;
          final progress = combinedReceivedBytes / combinedTotalBytes;
          if ((progress * 100).floor() >
              (state.gemma4DownloadProgress * 100).floor()) {
            emit(state.copyWith(
                gemma4DownloadProgress: progress.clamp(0.0, 0.99)));
          }
        }
        await sink.flush();
        await sink.close();
        client.close();
      }

      // Step 2: Download vision projector
      if (needsVision) {
        emit(state.copyWith(
          gemma4DownloadPhase: 'Downloading vision model...',
        ));
        try {
          final mmRequest =
              http.Request('GET', Uri.parse(_gemma4MmProjDownloadUrl));
          final mmClient = http.Client();
          final mmResponse = await mmClient.send(mmRequest);
          if (mmResponse.statusCode == 200) {
            final mmContentLength = mmResponse.contentLength ?? 0;
            if (mmContentLength > 0 && combinedReceivedBytes > 0) {
              combinedTotalBytes = combinedReceivedBytes + mmContentLength;
            }
            final mmSink = mmProjFile.openWrite();
            await for (final chunk in mmResponse.stream) {
              mmSink.add(chunk);
              combinedReceivedBytes += chunk.length;
              final progress = combinedReceivedBytes / combinedTotalBytes;
              if ((progress * 100).floor() >
                  (state.gemma4DownloadProgress * 100).floor()) {
                emit(state.copyWith(
                    gemma4DownloadProgress: progress.clamp(0.0, 0.99)));
              }
            }
            await mmSink.flush();
            await mmSink.close();
            print('Gemma 4 vision projector downloaded');
          }
          mmClient.close();
        } catch (e) {
          print('Gemma 4 mmproj download error (non-fatal): $e');
        }
      }

      if (needsModel || needsVision) {
        emit(state.copyWith(gemma4DownloadProgress: 1.0));
      }

      // Step 3: Load model into engine
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(
        gemma4Status: LocalAIStatus.loading,
        gemma4DownloadPhase: '',
      ));
      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        if (await mmProjFile.exists()) {
          await _drissyEngine.loadVisionProjector(mmProjFile.path);
        }
        emit(state.copyWith(
          gemma4Status: LocalAIStatus.ready,
          selectedModel: HomeModel.gemma4,
        ));
        print('Gemma 4 loaded successfully');
        print('[ModelSwitch] Active model → Gemma 4');
      } else {
        emit(state.copyWith(gemma4Status: LocalAIStatus.error));
      }
    } catch (e) {
      print('Gemma 4 download/load error: $e');
      emit(state.copyWith(gemma4Status: LocalAIStatus.error));
    }
  }

  Future<void> _loadGemma4IfDownloaded(
    HomeGemma4LoadIfDownloaded event,
    Emitter<HomeState> emit,
  ) async {
    if (state.gemma4Status == LocalAIStatus.loading ||
        state.gemma4Status == LocalAIStatus.downloading) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_gemma4FileName');
      final mmProjFile = File('${dir.path}/$_gemma4MmProjFileName');
      if (!await modelFile.exists()) return;
      // Skip if this model is already loaded in the engine
      if (_drissyEngine.loadedModelPath == modelFile.path) {
        emit(state.copyWith(
          gemma4Status: LocalAIStatus.ready,
          selectedModel: HomeModel.gemma4,
        ));
        print('[ModelSwitch] Active model → Gemma 4 (already in engine)');
        return;
      }
      emit(state.copyWith(gemma4Status: LocalAIStatus.loading));
      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        if (await mmProjFile.exists()) {
          await _drissyEngine.loadVisionProjector(mmProjFile.path);
        }
        emit(state.copyWith(
          gemma4Status: LocalAIStatus.ready,
          selectedModel: HomeModel.gemma4,
        ));
        print('[ModelSwitch] Active model → Gemma 4');
      } else {
        emit(state.copyWith(gemma4Status: LocalAIStatus.error));
      }
    } catch (e) {
      print('Gemma 4 load error: $e');
      emit(state.copyWith(gemma4Status: LocalAIStatus.error));
    }
  }

  // ── Liquid AI ──────────────────────────────────────────────────────────────

  Future<void> _downloadAndLoadLiquidAI(
    HomeLiquidAIDownloadAndLoad event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_liquidAIFileName');
      final mmProjFile = File('${dir.path}/$_liquidAIMmProjFileName');
      final needsModel = !await modelFile.exists();
      final needsVision = !await mmProjFile.exists();

      const combinedEstimate = 2106 * 1024 * 1024; // ~1.25 GB model + ~856 MB mmproj
      int combinedReceivedBytes = 0;
      int combinedTotalBytes = combinedEstimate;

      if (needsModel || needsVision) {
        final availableBytes = await StorageChecker.getAvailableBytes();
        const requiredBytes = 2 * 1024 * 1024 * 1024;
        if (availableBytes != null && availableBytes < requiredBytes) {
          emit(state.copyWith(liquidAIStatus: LocalAIStatus.noStorage));
          return;
        }
        emit(state.copyWith(
          liquidAIStatus: LocalAIStatus.downloading,
          liquidAIDownloadProgress: 0.0,
          liquidAIDownloadPhase: 'Downloading Liquid AI...',
        ));
      }

      // Step 1: Download main model
      if (needsModel) {
        final request = http.Request('GET', Uri.parse(_liquidAIDownloadUrl));
        final client = http.Client();
        final response = await client.send(request);
        if (response.statusCode != 200) {
          print('Liquid AI model download failed: ${response.statusCode}');
          client.close();
          emit(state.copyWith(liquidAIStatus: LocalAIStatus.error));
          return;
        }
        final modelContentLength = response.contentLength ?? 0;
        if (modelContentLength > 0) {
          combinedTotalBytes = modelContentLength + (856 * 1024 * 1024);
        }
        final sink = modelFile.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          combinedReceivedBytes += chunk.length;
          final progress = combinedReceivedBytes / combinedTotalBytes;
          if ((progress * 100).floor() >
              (state.liquidAIDownloadProgress * 100).floor()) {
            emit(state.copyWith(
                liquidAIDownloadProgress: progress.clamp(0.0, 0.99)));
          }
        }
        await sink.flush();
        await sink.close();
        client.close();
      }

      // Step 2: Download vision projector
      if (needsVision) {
        emit(state.copyWith(
          liquidAIDownloadPhase: 'Downloading vision model...',
        ));
        try {
          final mmRequest =
              http.Request('GET', Uri.parse(_liquidAIMmProjDownloadUrl));
          final mmClient = http.Client();
          final mmResponse = await mmClient.send(mmRequest);
          if (mmResponse.statusCode == 200) {
            final mmContentLength = mmResponse.contentLength ?? 0;
            if (mmContentLength > 0 && combinedReceivedBytes > 0) {
              combinedTotalBytes = combinedReceivedBytes + mmContentLength;
            }
            final mmSink = mmProjFile.openWrite();
            await for (final chunk in mmResponse.stream) {
              mmSink.add(chunk);
              combinedReceivedBytes += chunk.length;
              final progress = combinedReceivedBytes / combinedTotalBytes;
              if ((progress * 100).floor() >
                  (state.liquidAIDownloadProgress * 100).floor()) {
                emit(state.copyWith(
                    liquidAIDownloadProgress: progress.clamp(0.0, 0.99)));
              }
            }
            await mmSink.flush();
            await mmSink.close();
            print('Liquid AI vision projector downloaded');
          }
          mmClient.close();
        } catch (e) {
          print('Liquid AI mmproj download error (non-fatal): $e');
        }
      }

      if (needsModel || needsVision) {
        emit(state.copyWith(liquidAIDownloadProgress: 1.0));
      }

      // Step 3: Load model into engine
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(
        liquidAIStatus: LocalAIStatus.loading,
        liquidAIDownloadPhase: '',
      ));
      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        if (await mmProjFile.exists()) {
          await _drissyEngine.loadVisionProjector(mmProjFile.path);
        }
        emit(state.copyWith(
          liquidAIStatus: LocalAIStatus.ready,
          selectedModel: HomeModel.liquidAI,
        ));
        print('Liquid AI loaded successfully');
        print('[ModelSwitch] Active model → Liquid AI');
      } else {
        emit(state.copyWith(liquidAIStatus: LocalAIStatus.error));
      }
    } catch (e) {
      print('Liquid AI download/load error: $e');
      emit(state.copyWith(liquidAIStatus: LocalAIStatus.error));
    }
  }

  Future<void> _loadLiquidAIIfDownloaded(
    HomeLiquidAILoadIfDownloaded event,
    Emitter<HomeState> emit,
  ) async {
    if (state.liquidAIStatus == LocalAIStatus.loading ||
        state.liquidAIStatus == LocalAIStatus.downloading) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_liquidAIFileName');
      final mmProjFile = File('${dir.path}/$_liquidAIMmProjFileName');
      if (!await modelFile.exists()) return;
      if (_drissyEngine.loadedModelPath == modelFile.path) {
        emit(state.copyWith(
          liquidAIStatus: LocalAIStatus.ready,
          selectedModel: HomeModel.liquidAI,
        ));
        print('[ModelSwitch] Active model → Liquid AI (already in engine)');
        return;
      }
      emit(state.copyWith(liquidAIStatus: LocalAIStatus.loading));
      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        if (await mmProjFile.exists()) {
          await _drissyEngine.loadVisionProjector(mmProjFile.path);
        }
        emit(state.copyWith(
          liquidAIStatus: LocalAIStatus.ready,
          selectedModel: HomeModel.liquidAI,
        ));
        print('[ModelSwitch] Active model → Liquid AI');
      } else {
        emit(state.copyWith(liquidAIStatus: LocalAIStatus.error));
      }
    } catch (e) {
      print('Liquid AI load error: $e');
      emit(state.copyWith(liquidAIStatus: LocalAIStatus.error));
    }
  }

  //Switch Search Type
  Future<void> _switchType(
    HomeSwitchType event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isSearchMode: !event.type));
  }

  //Switch Privacy Type
  Future<void> _switchPrivacyType(
    HomeSwitchPrivacyType event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isIncognito: event.isIncognito));
  }

  /// Function to retrieve search data and redirect to reply page
  Future<void> _retrieveSearchData(
    HomeRetrieveSearchData event,
    Emitter<HomeState> emit,
  ) async {
    ThreadSessionData fetchedSessionData = event.sessionData;
    print("");
    print(fetchedSessionData.results.first.knowledgeGraph);
    print("");
    emit(
      state.copyWith(
          status: HomePageStatus.success,
          threadData: fetchedSessionData,
          loadingIndex: fetchedSessionData.results.length),
    );
    // mixpanel.track("fetch_saved_session");
  }

  //Refresh Reply
  Future<void> _refreshReply(
      HomeRefreshReply event, Emitter<HomeState> emit) async {
    emit(state.copyWith(replyStatus: HomeReplyStatus.loading));

    //Format watchedVideos to different json structure
    ThreadResultData initialresultData = state.threadData.results[event.index];
    List<Map<String, String>> formattedResults = [];
    formattedResults = initialresultData.influence.map((video) {
      return {
        "title": video.title,
        "url": video.url,
        "snippet": video.snippet.trim(),
      };
    }).toList();

    //Get user details using ipapi
    final userData = await _getUserLocation();

    //Come up with Reply
    String? answer;
    try {
      //Image — use on-device Drissy vision
      if (initialresultData.sourceImage != null) {
        if (_drissyEngine.isLoaded && _drissyEngine.isVisionLoaded) {
          // Write stored bytes to temp file for on-device vision
          final tempDir = await Directory.systemTemp.createTemp('drissy_img');
          final tempFile = File('${tempDir.path}/image.jpg');
          await tempFile.writeAsBytes(initialresultData.sourceImage!);
          try {
            String finalContent = "";
            await for (final token in _drissyEngine.answerWithImage(
              query: initialresultData.userQuery,
              imagePath: tempFile.path,
              sources: [],
            )) {
              finalContent += token;
              event.streamedText.value = finalContent;
              emit(state.copyWith(replyStatus: HomeReplyStatus.success));
            }
            answer = finalContent.isNotEmpty ? finalContent : null;
          } catch (e) {
            print('Drissy vision error: $e');
            answer =
                "Sorry, I couldn't analyze this image. Please try again.";
            event.streamedText.value = answer!;
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
          } finally {
            try { await tempFile.delete(); await tempDir.delete(); } catch (_) {}
          }
        } else {
          answer =
              "Image analysis isn't available right now. Please make sure the AI model is loaded in settings.";
          event.streamedText.value = answer!;
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        }
      }
      //Extracted Url
      else if (initialresultData.extractedUrlData?.link != "" &&
          initialresultData.extractedUrlData?.link != null) {
        answer = await vercelNewGenerateReply(
          initialresultData.userQuery,
          [],
          event.streamedText,
          emit,
          initialresultData.sourceImageDescription,
          state.threadData.results
              .getRange(0, state.threadData.results.length - 1)
              .toList(),
          initialresultData.extractedUrlData,
          userData.city,
          userData.region,
          userData.country,
        );
      } else {
        answer = await vercelNewGenerateReply(
            initialresultData.userQuery,
            formattedResults,
            event.streamedText,
            emit,
            initialresultData.sourceImageDescription,
            state.threadData.results
                .getRange(0, state.threadData.results.length - 1)
                .toList(),
            initialresultData.extractedUrlData,
            userData.city,
            userData.region,
            userData.country);
      }

      ThreadResultData updResultData = ThreadResultData(
          youtubeVideos: initialresultData.youtubeVideos,
          searchType: initialresultData.searchType,
          sourceImageDescription: initialresultData.sourceImageDescription,
          sourceImageLink: initialresultData.sourceImageLink,
          sourceImage: initialresultData.sourceImage,
          web: initialresultData.web,
          shortVideos: initialresultData.shortVideos,
          videos: initialresultData.videos,
          news: initialresultData.news,
          images: initialresultData.images,
          createdAt: initialresultData.createdAt,
          updatedAt: initialresultData.updatedAt,
          userQuery: initialresultData.userQuery,
          searchQuery: initialresultData.searchQuery,
          answer: answer ?? initialresultData.answer,
          influence: initialresultData.influence,
          isSearchMode: initialresultData.isSearchMode,
          extractedUrlData: initialresultData.extractedUrlData,
          local: initialresultData.local,
          obsidianNoteName: initialresultData.obsidianNoteName,
          browseImages: initialresultData.browseImages);

      final updatedResults =
          List<ThreadResultData>.from(state.threadData.results)
            ..removeAt(event.index)
            ..insert(event.index, updResultData);

      final updThreadData = ThreadSessionData(
        id: state.threadData.id,
        results: updatedResults,
        isIncognito: state.threadData.isIncognito,
        createdAt: state.threadData.createdAt,
        updatedAt: Timestamp.now(),
      );

      emit(
        state.copyWith(
            replyStatus: HomeReplyStatus.success,
            threadData: updThreadData,
            loadingIndex: event.index),
      );
      await updateSession(updThreadData, state.threadData.id);
    } catch (err) {
      emit(state.copyWith(
          replyStatus: HomeReplyStatus.success, loadingIndex: event.index));
    }
  }

  Future<List<LocalResultData>> _getMapSearchData(String query) async {
    try {
      print("DEBUG: Fetching map search results for: $query");
      String drisseaApiHost = dotenv.get('API_HOST');
      final url = Uri.parse("https://$drisseaApiHost/api/search/map");

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"userQuery": query}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['results'] != null) {
          final List<dynamic> results = data['results'];
          return results.map((e) => LocalResultData.fromJson(e)).toList();
        }
      } else {
        print(
            "DEBUG: Drissea map search request failed: ${response.statusCode}");
      }
    } catch (e) {
      print("DEBUG: Error fetching map search data: $e");
    }
    return [];
  }

  // Future<void> _portalSearch(
  //     HomePortalSearch event, Emitter<HomeState> emit) async {
  //   String query = event.query;

  //   final sessionId = Uuid().v4();
  //   final threadId = sessionId;

  //   final initialResults = [
  //     ThreadResultData(
  //       youtubeVideos: [],
  //       searchType: state.searchType,
  //       sourceImageDescription: "",
  //       sourceImageLink: state.uploadedImageUrl ?? "",
  //       sourceImage: state.selectedImage != null
  //           ? await state.selectedImage!.readAsBytes()
  //           : null,
  //       isSearchMode: true,
  //       web: [],
  //       shortVideos: [],
  //       videos: [],
  //       news: [],
  //       images: [],
  //       createdAt: Timestamp.now(),
  //       updatedAt: Timestamp.now(),
  //       userQuery: query,
  //       searchQuery: "",
  //       answer: "",
  //       influence: [],
  //       local: [],
  //     )
  //   ];

  //   ThreadSessionData updThreadData = ThreadSessionData(
  //       id: threadId,
  //       isIncognito: state.isIncognito,
  //       results: initialResults,
  //       createdAt: Timestamp.now(),
  //       updatedAt: Timestamp.now());

  //   // If there's an existing thread, we need to update it
  //   if (state.threadData.id != "") {
  //     final tempUpdatedResults =
  //         List<ThreadResultData>.from(state.threadData.results)
  //           ..add(initialResults[0]);

  //     updThreadData = ThreadSessionData(
  //         id: state.threadData.id,
  //         isIncognito: state.isIncognito,
  //         results: tempUpdatedResults,
  //         createdAt: Timestamp.now(),
  //         updatedAt: Timestamp.now());
  //   }

  //   // Understand the query
  //   emit(state.copyWith(
  //       imageStatus: HomeImageStatus.unselected,
  //       status: HomePageStatus.loading,
  //       threadData: updThreadData,
  //       loadingIndex: updThreadData.results.length - 1));

  //   // Use SerpAPI Google Light to get first search result
  //   final String altSerpApiKey = dotenv.get("ALT_SERP_API_KEY");
  //   final serpUrl = Uri.parse("https://serpapi.com/search").replace(
  //     queryParameters: {
  //       'q': event.query,
  //       'api_key': altSerpApiKey,
  //       'engine': 'google_light',
  //       'gl': 'in',
  //       'location': 'India',
  //       'safe': 'off',
  //       'device': 'mobile',
  //     },
  //   );

  //   final webRes = await http.get(serpUrl);

  //   if (webRes.statusCode == 200) {
  //     final serpJson = jsonDecode(webRes.body);

  //     // Get the first organic result URL
  //     if (serpJson['organic_results'] != null &&
  //         (serpJson['organic_results'] as List).isNotEmpty) {
  //       String resultPageUrl = serpJson['organic_results'][0]['link'] as String;

  //       if (await canLaunchUrl(Uri.parse(resultPageUrl))) {
  //         print("Navigating to first result: $resultPageUrl");

  //         emit(
  //           state.copyWith(
  //             status: HomePageStatus.idle,
  //             threadData: ThreadSessionData(
  //               id: "",
  //               results: [],
  //               isIncognito: false,
  //               createdAt: Timestamp.now(),
  //               updatedAt: Timestamp.now(),
  //             ),
  //           ),
  //         );
  //         navService.goTo("/webview", extra: {"url": resultPageUrl});

  //         return;
  //       }
  //     }
  //   } else {
  //     print("SerpAPI request failed: ${webRes.statusCode}");
  //   }
  // }

//   Future<({String type, String searchQuery})> _altUnderstandQuery(
//     List<ThreadResultData> previousResults,
//     String query,
//     String imageDescription,
//     HomeSearchType searchType,
//     String extractedUrlDescription,
//     String city,
//     String region,
//     String country,
//   ) async {
//     try {
//       // Check if query is a proper sentence
//       // bool isProperSentence = true;
//       // if (searchType == HomeSearchType.general) {
//       //   isProperSentence = _isProperSentence(query);
//       // }

//       // if (!isProperSentence) {
//       //   // Not a proper sentence - return agent type and skip search query generation
//       //   print("DEBUG: Query is not a proper sentence, using agent type");
//       //   return (type: "agent", searchQuery: query);
//       // }

//       // It's a proper sentence - proceed with search query generation
//       // Build context from previous results
//       String conversationContext = "";
//       if (previousResults.isNotEmpty) {
//         conversationContext = "Previous conversation:\n";
//         for (var result in previousResults.take(3)) {
//           // Only take last 3 for context
//           conversationContext +=
//               "Q: ${result.userQuery}\nA: ${result.answer}\n\n";
//         }
//       }

//       // Step 2: IP lookup and user context
//       String formattedUserContext =
//           "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

//       // Build the prompt
//       String prompt = """
// You are a search query optimizer. Your task is to generate the best Google search query to find information needed to answer the user's question.

// ${conversationContext != "" ? conversationContext : ""}
// Current user question: $query
// ${imageDescription != "" ? "Context from uploaded image: $imageDescription\n" : ""}
// ${extractedUrlDescription != "" ? "Context from extracted URL: $extractedUrlDescription\n" : ""}
// $formattedUserContext

// Rules:
// 1. If the user mentions "right now" or "today" or time-sensitive terms, use the current date and time from the context to determine the part of the day (morning, afternoon, evening, night) or specific date in the query.
// 2. If the user mentions "near me" or "nearby", use the provided location in the context (City, Region, Country) to make the query specific to that location.
// 3. If the query consists primarily of a URL (e.g., youtube.com/...), use the URL to generate a search query relevant to that video or page.
// 4. Generate a concise, effective Google search query (max 10 words).
// 5. Return ONLY the search query, nothing else.
// """;

//       if (_drissyEngine.isLoaded) {
//         final searchQuery = await _drissyEngine.complete(
//           systemMessage: "You are a search query optimizer. Generate a concise, effective Google search query. Return ONLY the search query, nothing else.",
//           userMessage: prompt,
//           maxTokens: 50,
//           temperature: 0.1,
//         );
//         if (searchQuery != null && searchQuery.isNotEmpty) {
//           print("DEBUG: Generated search query: $searchQuery");
//           return (type: "general", searchQuery: searchQuery);
//         }
//       }
//       print("DEBUG: Search query generation skipped: local AI not loaded");
//       return (type: "general", searchQuery: query);
//     } catch (e) {
//       print("DEBUG: Search query generation error: $e");
//       return (type: "general", searchQuery: query);
//     }
//   }

  bool _isProperSentence(String query) {
    // Trim whitespace
    String trimmedQuery = query.trim();

    // Check minimum length
    if (trimmedQuery.length < 3) {
      return false;
    }

    // Check if it has at least 2 words
    List<String> words = trimmedQuery.split(RegExp(r'\s+'));
    if (words.length < 2) {
      return false;
    }

    // Check if it contains at least one alphabetic character
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmedQuery)) {
      return false;
    }

    // Convert to lowercase for checking (used in word comparisons below)

    // Common question words that indicate a proper question
    final questionWords = [
      'what',
      'when',
      'where',
      'who',
      'whom',
      'whose',
      'why',
      'which',
      'how',
      'can',
      'could',
      'would',
      'should',
      'will',
      'is',
      'are',
      'was',
      'were',
      'do',
      'does',
      'did',
      'has',
      'have',
      'had'
    ];

    // Common sentence starters that indicate proper sentences
    final sentenceStarters = [
      'tell',
      'show',
      'find',
      'search',
      'get',
      'give',
      'explain',
      'describe',
      'list',
      'compare',
      'analyze',
      'help',
      'please'
    ];

    // Common verbs that indicate action/query intent
    final commonVerbs = [
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'make',
      'get',
      'go',
      'know',
      'think',
      'take',
      'see',
      'come',
      'want',
      'use',
      'find',
      'give',
      'tell',
      'work',
      'call',
      'try',
      'need',
      'feel'
    ];

    // Check if it starts with a question word
    String firstWord = words[0].toLowerCase();
    if (questionWords.contains(firstWord)) {
      return true;
    }

    // Check if it starts with a common sentence starter
    if (sentenceStarters.contains(firstWord)) {
      return true;
    }

    // Check if it contains a question mark (likely a question)
    if (trimmedQuery.contains('?')) {
      return true;
    }

    // Check if any word is a common verb (indicates sentence structure)
    bool hasVerb =
        words.any((word) => commonVerbs.contains(word.toLowerCase()));
    if (hasVerb && words.length >= 3) {
      return true;
    }

    // Check for common sentence patterns with prepositions/articles
    final connectingWords = [
      'the',
      'a',
      'an',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'from',
      'by'
    ];
    bool hasConnectingWord =
        words.any((word) => connectingWords.contains(word.toLowerCase()));

    // If it has connecting words and is reasonably long, likely a sentence
    if (hasConnectingWord && words.length >= 3) {
      return true;
    }

    // Check if it looks like a command (verb + object pattern)
    // e.g., "show me", "tell me", "find restaurants"
    if (words.length >= 2 && sentenceStarters.contains(firstWord)) {
      return true;
    }

    // If none of the above patterns match, it's likely just random words
    // or a very short phrase that doesn't constitute a proper sentence
    return false;
  }

  Future<String> _nsfwUnderstandQuery(List<ThreadResultData> previousResults,
      String query, String imageDescription) async {
    // Heuristic approach: Remove filler words to extract keywords

    // 1. Define common filler/stop words to remove
    final Set<String> stopWords = {
      "a",
      "an",
      "the",
      "in",
      "on",
      "at",
      "for",
      "to",
      "of",
      "is",
      "are",
      "was",
      "were",
      "be",
      "been",
      "being",
      "have",
      "has",
      "had",
      "do",
      "does",
      "did",
      "can",
      "could",
      "will",
      "would",
      "shall",
      "should",
      "may",
      "might",
      "must",
      "i",
      "you",
      "he",
      "she",
      "it",
      "we",
      "they",
      "what",
      "which",
      "who",
      "whom",
      "whose",
      "where",
      "when",
      "why",
      "how",
      "please",
      "tell",
      "show",
      "give",
      "find",
      "search",
      "looking",
      "look",
      "me",
      "us",
      "my",
      "your",
      "his",
      "her",
      "its",
      "our",
      "their",
      "about",
      "with",
      "by",
      "from",
      "up",
      "down",
      "out"
    };

    // 2. Normalize and tokenize the query
    // Remove punctuation and convert to lowercase for checking
    String cleanQuery = query.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
    List<String> tokens = cleanQuery.split(' ');

    // 3. Filter tokens
    List<String> keywords = tokens.where((token) {
      return token.isNotEmpty && !stopWords.contains(token);
    }).toList();

    // 4. Reconstruct query
    // If we filtered everything out (e.g. "What is it?"), fall back to original query
    String finalQuery = keywords.isEmpty ? query : keywords.join(' ');

    // 5. Append image description if present
    if (imageDescription.isNotEmpty) {
      finalQuery += " $imageDescription";
    }

    finalQuery = finalQuery.trim();

    print("DEBUG: Generated heuristic search query: $finalQuery");
    return finalQuery;
  }

  /// Check if the query requires location context
  bool _queryNeedsLocation(String query) {
    final lowerQuery = query.toLowerCase();
    final locationKeywords = [
      'near me',
      'nearby',
      'close to me',
      'around me',
      'in my area',
      'local',
      'closest',
      'nearest',
      'around here',
      'this area',
      'my location',
      'where i am',
      'places near',
      'restaurants near',
      'shops near',
      'bars near',
      'cafes near',
      'hotels near',
      'stores near',
    ];
    for (final keyword in locationKeywords) {
      if (lowerQuery.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// Check if the query requires a web search
  bool _queryNeedsWebSearch(String query) {
    if (query.trim().isEmpty) return false;

    // Always search for long queries as they are likely specific questions
    if (query.length > 20) return true;

    final lowerQuery = query.toLowerCase();

    // Direct questions
    final questionWords = [
      'who',
      'what',
      'where',
      'when',
      'why',
      'how',
      'which',
      'can',
      'could',
      'should',
      'would',
      'is',
      'are',
      'do',
      'does'
    ];
    for (final word in questionWords) {
      if (lowerQuery.startsWith('$word ')) return true;
    }

    // Specific search patterns
    final searchKeywords = [
      'weather',
      'price',
      'cost',
      'news',
      'latest',
      'vs',
      'versus',
      'meaning',
      'define',
      'definition',
      'synonym',
      'antonym',
      'review',
      'rating',
      'score',
      'top',
      'best',
      'list',
      'schedule',
      'calendar',
      'time',
      'date',
      'map',
      'location',
      'navigate',
      'direction',
      'video',
      'image',
      'photo',
      'movie',
      'film',
      'cast',
      'plot',
      'ticket',
      'buy',
      'sell',
      'stock',
      'market',
      'forecast'
    ];
    for (final keyword in searchKeywords) {
      if (lowerQuery.contains(keyword)) return true;
    }

    // Check for location signals as well (reuse existing logic)
    if (_queryNeedsLocation(query)) return true;

    // If it's a very short query without keywords (e.g., "hello", "thanks"), assume chat
    if (query.split(' ').length < 3) return false;

    // Default to true for robust search coverage if unsure
    return true;
  }

  Future<bool> _checkLocationPermissionForQuery(
      HomeGetAnswer event, Emitter<HomeState> emit) async {
    return true;
  }

  

  /// Check if a query is a simple factual question suitable for quick search
  /// Use AI Gateway to condense enriched source snippets for on-device context.
  /// Returns a single condensed string of the most relevant information.

  bool _isSimpleFactualQuery(String query) {
    final lower = query.toLowerCase().trim();
    final words = lower.split(RegExp(r'\s+'));

    if (words.length < 3 || words.length > 15) return false;
    if (state.selectedImage != null) return false;
    if (state.searchType == HomeSearchType.extractUrl) return false;

    final factualStarters = [
      'who ', 'what ', 'when ', 'where ', 'which ',
      'how old ', 'how tall ', 'how many ', 'how much ',
      'how long ', 'how far ', 'how big ',
      'define ', 'meaning of ',
    ];
    if (!factualStarters.any((s) => lower.startsWith(s))) return false;

    final complexPatterns = [
      'compare', 'difference between', 'pros and cons',
      'explain why', 'explain how', 'how to ', 'how do i',
      'how can i', 'why does', 'why is', 'why are',
      'list all', 'tell me about', 'and also',
    ];
    if (complexPatterns.any((p) => lower.contains(p))) return false;

    return true;
  }

  Future<void> _getFastAnswer(
      HomeGetAnswer event, Emitter<HomeState> emit) async {
    await _loadPersonalization();
    print(
        "=== DEBUG _watchGeneralGoogleAnswer ENTRY: query='${event.query}' ===");
    // Check location permission ONLY if the query needs location context
    String query = event.query;
    String searchQuery = event.query;
    String city = state.userCity;
    String region = state.userRegion;
    String country = state.userCountry;
    String countryCode = state.userCountryCode;

    //Check if query need web search or not

    String threadId = Uuid().v4().substring(0, 8);
    _cancelTaskGen = false;
    List<YoutubeVideoData> youtubeVideos = [];

    //String country = userData.countryCode.toLowerCase();

    // Capture image path and bytes if available
    final imagePath = state.selectedImage?.path;
    Uint8List? imageBytes;
    if (state.selectedImage != null) {
      try {
        imageBytes = await File(state.selectedImage!.path).readAsBytes();
      } catch (e) {
        print("Error reading image bytes: $e");
      }
    }

    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
      youtubeVideos: [],
      searchType: state.searchType,
      sourceImageDescription: event.imageDescription,
      sourceImageLink: state.uploadedImageUrl ?? "",
      sourceImage: imageBytes,
      isSearchMode: false,
      extractedUrlData: ExtractedUrlResultData(
        snippet: event.extractedUrlDescription.value,
        title: event.extractedUrlTitle.value,
        link: event.extractedUrl.value,
        thumbnail: event.extractedImageUrl.value,
      ),
      web: [],
      shortVideos: [],
      videos: [],
      news: [],
      images: [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      userQuery: query,
      searchQuery: searchQuery,
      answer: "",
      influence: [],
      local: [],
      obsidianNoteName: state.pendingObsidianNoteName,
    );
    List<ExtractedResultInfo> extractedResults = [];

    ThreadSessionData updThreadData = state.threadData;

    event.extractedUrlTitle.value = "";
    event.extractedUrlDescription.value = "";
    event.extractedImageUrl.value = "";
    event.extractedUrl.value = "";

    // Set Initial Result Data
    List<ThreadResultData> tempUpdatedResults =
        List<ThreadResultData>.from(state.threadData.results)..add(resultData);
    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          isIncognito: state.threadData.isIncognito,
          results: tempUpdatedResults,
          obsidianNoteName: state.threadData.obsidianNoteName,
          obsidianNoteContent: state.threadData.obsidianNoteContent,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
          obsidianNoteName: state.pendingObsidianNoteName,
          obsidianNoteContent: state.pendingObsidianNoteContent,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    String? answer;
    List<LocalResultData> mapResults = [];
    List<ShortVideoResultData> instagramShortVideos = [];
    List<VisualBrowseResultData> pendingBrowseImages = [];

    // Search memory for relevant content to enhance the answer
    List<({String text, String sourceQuery, double score})> memoryChunks = [];
    // try {
    //   memoryChunks = await AnswerMemoryService.instance.searchRelevantMemory(
    //     query,
    //     maxResults: 10,
    //     minScore: 0.3,
    //   );
    // } catch (e) {
    //   print("Error searching memory: $e");
    // }

    if (_queryNeedsLocation(query)) {
      // Check location permission ONLY if the query needs location context
      final shouldProceed = await _checkLocationPermissionForQuery(event, emit);
      if (!shouldProceed) {
        return; // Stop here, location rationale is being shown
      }

      if (city.isEmpty) {
        //Understand the query
        emit(
          state.copyWith(
            status: HomePageStatus.generateQuery,
            imageStatus: HomeImageStatus.unselected,
            threadData: updThreadData,
            loadingIndex: updThreadData.results.length - 1,
          ),
        );
        final userData = await _getUserLocation();
        city = userData.city;
        region = userData.region;
        country = userData.country;
        countryCode = userData.countryCode;
      }

      if (city.isNotEmpty) {
        final replaceWithIn = [
          'near me',
          'nearby',
          'close to me',
          'around me',
          'in my area',
          'around here',
          'this area',
          'my location',
          'where i am'
        ];
        final appendIn = ['local', 'closest', 'nearest'];
        final appendCity = [
          'places near',
          'restaurants near',
          'shops near',
          'bars near',
          'cafes near',
          'hotels near',
          'stores near'
        ];

        String lowerQuery = searchQuery.toLowerCase();
        bool modified = false;

        for (final keyword in replaceWithIn) {
          if (lowerQuery.contains(keyword)) {
            final pattern =
                RegExp(RegExp.escape(keyword), caseSensitive: false);
            searchQuery = searchQuery.replaceAll(pattern, "in $city");
            modified = true;
            break;
          }
        }

        if (!modified) {
          for (final keyword in appendIn) {
            if (lowerQuery.contains(keyword)) {
              searchQuery = "$searchQuery in $city";
              modified = true;
              break;
            }
          }
        }

        if (!modified) {
          for (final keyword in appendCity) {
            if (lowerQuery.contains(keyword)) {
              searchQuery = "$searchQuery $city";
              modified = true;
              break;
            }
          }
        }
      }
    }

    // Chat mode: skip web search, generate AI reply directly (with optional image)
    if (state.isChatModeActive) {
      // Capture image path before clearing state
      final chatImagePath = state.selectedImage?.path;

      emit(state.copyWith(
          status: HomePageStatus.success,
          searchType: state.searchType == HomeSearchType.extractUrl
              ? HomeSearchType.general
              : state.searchType,
          imageStatus: HomeImageStatus.unselected,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
          selectedImage: null,
          replyStatus: HomeReplyStatus.loading));

      event.imageDescriptionNotifier.value = "";

      if (_drissyEngine.isLoaded) {
        final userData = await _getUserLocation();
        final hasVision = _drissyEngine.isVisionLoaded && chatImagePath != null;
        final chatNoteContent = state.pendingObsidianNoteContent ??
            state.threadData.obsidianNoteContent;
        final chatNoteName = state.pendingObsidianNoteName ??
            state.threadData.obsidianNoteName;
        final chatSystemPrompt =
            """You are Drissy, a helpful, friendly AI assistant.

Rules:
- Always respond in Markdown format.
- Be conversational and warm.
- **Bold key insights** and important information.
- Keep responses concise and optimized for mobile readability.
- If the user asks something you don't know, be honest about it.
${hasVision ? "- The user has shared an image. Describe and analyze it as part of your response." : ""}

The user is located in ${userData.city}, ${userData.region}, ${userData.country}. The current date and time is ${DateTime.now()}.
${_personalizationText.isNotEmpty ? '\nAbout the user: $_personalizationText' : ''}${!hasVision && event.imageDescription.isNotEmpty ? "\nImage description: ${event.imageDescription}" : ""}${chatNoteContent != null ? '\n\nThe user has attached a note called "${chatNoteName ?? 'Note'}". Use its content to inform your answers and reference it explicitly when relevant.\n\nNote content:\n$chatNoteContent' : ''}""";

        final allPrevious = state.threadData.results
            .getRange(0, state.threadData.results.length - 1)
            .toList();
        const maxHistory = 4;
        final previousResults = allPrevious.length > maxHistory
            ? allPrevious.sublist(allPrevious.length - maxHistory)
            : allPrevious;
        final conversationMessages = <Map<String, String>>[];
        for (final item in previousResults) {
          conversationMessages.add({
            'role': 'user',
            'content': item.userQuery,
          });
          conversationMessages.add({
            'role': 'assistant',
            'content': item.answer,
          });
        }
        conversationMessages.add({
          'role': 'user',
          'content': query,
        });

        try {
          String finalContent = "";
          await for (final token in _drissyEngine.chat(
            systemMessage: chatSystemPrompt,
            conversationMessages: conversationMessages,
            imagePath: hasVision ? chatImagePath : null,
          )) {
            finalContent += token;
            event.streamedText.value = finalContent;
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
          }
          if (finalContent.isNotEmpty) {
            answer = finalContent;
          } else {
            answer = 'Something went wrong generating a response. Please try again.';
            event.streamedText.value = answer!;
          }
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        } catch (e) {
          print('Drissy inference error: $e');
          answer = 'Something went wrong generating a response. Please try again.';
          event.streamedText.value = answer!;
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        }
      } else {
        answer =
            'Local AI model not loaded. Please enable Local AI in settings.';
        event.streamedText.value = answer!;
        emit(state.copyWith(replyStatus: HomeReplyStatus.success));
      }
    }
    // Continue with search flow for non-chat action types
    //Get Search Results
    //Image Response — use on-device Drissy vision
    else if (imagePath != null) {
      emit(state.copyWith(
          status: HomePageStatus.success,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
          searchType: state.searchType == HomeSearchType.extractUrl
              ? HomeSearchType.general
              : state.searchType,
          replyStatus: HomeReplyStatus.loading,
          selectedImage: null,
          imageStatus: HomeImageStatus.unselected));

      event.imageDescriptionNotifier.value = "";

      if (_drissyEngine.isLoaded && _drissyEngine.isVisionLoaded) {
        try {
          String finalContent = "";
          await for (final token in _drissyEngine.answerWithImage(
            query: query,
            imagePath: imagePath,
            sources: [],
          )) {
            finalContent += token;
            event.streamedText.value = finalContent;
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
          }
          if (finalContent.isNotEmpty) {
            answer = finalContent;
          } else {
            answer = "Sorry, I couldn't analyze this image. Please try again.";
            event.streamedText.value = answer!;
          }
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        } catch (e) {
          print('Drissy vision error: $e');
          answer = "Sorry, I couldn't analyze this image. Please try again.";
          event.streamedText.value = answer!;
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        }
      } else {
        answer =
            "Image analysis isn't available right now. Please make sure the AI model is loaded in settings.";
        event.streamedText.value = answer!;
        emit(state.copyWith(replyStatus: HomeReplyStatus.success));
      }
    } else {
      //Understand the query
      emit(
        state.copyWith(
          status: HomePageStatus.generateQuery,
          imageStatus: HomeImageStatus.unselected,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
          selectedImage: null,
        ),
      );

      //Understand query - Rewrite query with context from previous messages
      if (state.threadData.results.isNotEmpty) {
        searchQuery = await _rewriteQueryWithContext(
          query,
          state.threadData.results,
        );
        print("📝 Original query: $query");
        print("📝 Rewritten query: $searchQuery");
      }

      emit(state.copyWith(status: HomePageStatus.getSearchResults));

      try {
        // --- Web search via Google WebView ---
        final searchStartTime = DateTime.now();

        if (state.generalStatus == HomeGeneralStatus.enabled) {
          _webSearchCompleter = Completer<BrowseSearchResult>();
          emit(state.copyWith(webSearchQuery: searchQuery, isQuickSearch: _isSimpleFactualQuery(query)));

          // Wait for the UI to open WebView and return results
          final browseResult = await _webSearchCompleter!.future;
          _webSearchCompleter = null;
          pendingBrowseImages = browseResult.images;

          int totalChars = 0;
          const int charLimit = 120000;
          for (final result in browseResult.webResults) {
            final int resultChars = result.url.length +
                result.title.length +
                result.excerpts.length;
            if (totalChars + resultChars > charLimit) break;
            extractedResults.add(result);
            totalChars += resultChars;
          }
          print(
              "Web results found (Google WebView): ${extractedResults.length}");

          // Enrich snippets via batch extract API
          if (extractedResults.isNotEmpty) {
            try {
              final batchItems = extractedResults
                  .map((r) => {
                        'url': r.url,
                        'excerpt': r.excerpts,
                      })
                  .toList();

              final batchResponse = await httpClient.post(
                Uri.parse('https://browser-api.drissea.com/extract-batch'),
                headers: {
                  'Content-Type': 'application/json',
                  "Authorization": "Bearer ${dotenv.get('API_SECRET')}"
                },
                body: jsonEncode({'items': batchItems}),
              );

              if (batchResponse.statusCode == 200) {
                final batchJson = jsonDecode(batchResponse.body);
                final List<dynamic> batchResults = batchJson['results'] ?? [];

                final Map<String, String> enrichedSnippets = {};
                final Set<String> verifiedUrls = {};
                for (final item in batchResults) {
                  if (item['found'] == true && item['url'] != null) {
                    verifiedUrls.add(item['url'] as String);
                    final text =
                        (item['extractedText'] ?? '').toString().trim();
                    if (text.isNotEmpty) {
                      enrichedSnippets[item['url']] = text;
                    }
                  }
                }

                extractedResults = extractedResults.map((r) {
                  final enriched = enrichedSnippets[r.url];
                  final isVerified = verifiedUrls.contains(r.url);
                  if (enriched != null && enriched.isNotEmpty) {
                    return ExtractedResultInfo(
                      url: r.url,
                      title: r.title,
                      excerpts: enriched,
                      thumbnailUrl: r.thumbnailUrl,
                      isVerified: true,
                    );
                  }
                  return ExtractedResultInfo(
                    url: r.url,
                    title: r.title,
                    excerpts: r.excerpts,
                    thumbnailUrl: r.thumbnailUrl,
                    isVerified: isVerified,
                  );
                }).toList();

                print(
                    "Enriched ${enrichedSnippets.length}/${extractedResults.length} results via batch extract API");
              } else {
                print("Batch extract API failed: ${batchResponse.statusCode}");
              }
            } catch (e) {
              print("Error calling batch extract API: $e");
            }
          }
        }

        final searchDuration = DateTime.now().difference(searchStartTime);
        print("");
        print("Search duration: ${searchDuration.inMilliseconds} ms");
        print("");

        // COMMENTED OUT: Drissea API call
        // final drisseaApiHost = dotenv.get('API_HOST');
        // final apiSecret = dotenv.get('API_SECRET');
        // final unifiedSearchUrl =
        //     Uri.parse("https://$drisseaApiHost/api/search");
        //
        // final searchResponse = await http.post(
        //   unifiedSearchUrl,
        //   headers: {
        //     'Content-Type': 'application/json',
        //     'Authorization': 'Bearer $apiSecret',
        //   },
        //   body: jsonEncode({
        //     'query': searchQuery,
        //     'country': countryCode.toLowerCase(),
        //   }),
        // );
        //
        // if (searchResponse.statusCode == 200) {
        //   final Map<String, dynamic> respJson = jsonDecode(searchResponse.body);
        //   if (respJson["success"] == true) {
        //     if (state.generalStatus == HomeGeneralStatus.enabled) {
        //       final webResults = respJson['web'] is List
        //           ? List<dynamic>.from(respJson['web'])
        //           : [];
        //       int totalChars = 0;
        //       const int charLimit = 120000;
        //       for (final e in webResults) {
        //         final String url = (e['url'] ?? '').toString();
        //         final String title = (e['title'] ?? '').toString();
        //         final String excerpts = (e['excerpts'] ?? '').toString();
        //         final int resultChars = url.length + title.length + excerpts.length;
        //         if (totalChars + resultChars > charLimit) break;
        //         extractedResults.add(ExtractedResultInfo(
        //           url: url, title: title, excerpts: excerpts, thumbnailUrl: '',
        //         ));
        //         totalChars += resultChars;
        //       }
        //     }
        //     if (state.youtubeStatus == HomeYoutubeStatus.enabled) {
        //       final youtubeResults = respJson['youtube'] is List
        //           ? List<dynamic>.from(respJson['youtube']) : [];
        //       youtubeVideos = youtubeResults
        //           .map((e) => YoutubeVideoData.fromJson(e as Map<String, dynamic>))
        //           .toList();
        //     }
        //     if (state.mapStatus == HomeMapStatus.enabled) {
        //       final mapResultsJson = respJson['map'] is List
        //           ? List<dynamic>.from(respJson['map']) : [];
        //       mapResults = mapResultsJson
        //           .map((e) => LocalResultData.fromJson(e as Map<String, dynamic>))
        //           .toList();
        //     }
        //     if (state.instagramStatus == HomeInstagramStatus.enabled) {
        //       final instagramResults = respJson['instagram'] is List
        //           ? List<dynamic>.from(respJson['instagram']) : [];
        //       final seenUrls = <String>{};
        //       final uniqueInstagramResults = instagramResults.where((e) {
        //         final url = e['permalink'] ?? '';
        //         if (url.isEmpty || seenUrls.contains(url)) return false;
        //         seenUrls.add(url);
        //         return true;
        //       }).toList();
        //       extractedResults.addAll(uniqueInstagramResults.map((e) => ExtractedResultInfo(
        //         url: e['permalink'] ?? '', title: 'Instagram Reel',
        //         excerpts: '${e['transcription'] ?? ''} ${e['caption'] ?? ''}'.trim(),
        //         thumbnailUrl: e['thumbnail_url'] ?? '',
        //       )));
        //       instagramShortVideos = uniqueInstagramResults.map((e) => ShortVideoResultData(
        //         title: (e['caption'] ?? 'Instagram Reel').toString(),
        //         link: e['permalink'] ?? '', thumbnail: e['thumbnail_url'] ?? '',
        //         clip: '', source: 'Instagram',
        //         sourceIcon: 'https://www.instagram.com/favicon.ico',
        //         channel: '', duration: '',
        //       )).toList();
        //     }
        //   }
        // }

        print(
            "Finsihed processing: ${DateTime.now().difference(searchStartTime).inMilliseconds} ms");
        emit(state.copyWith(
            status: HomePageStatus.success,
            searchType: state.searchType == HomeSearchType.extractUrl
                ? HomeSearchType.general
                : state.searchType,
            replyStatus: HomeReplyStatus.loading));
        print(
            "Finsihed changing state: ${DateTime.now().difference(searchStartTime).inMilliseconds} ms");
      } catch (e) {
        print("Error in parallel search: $e");
      }
      if (_cancelTaskGen) {
        //emit(state.copyWith(status: HomePageStatus.idle));
        return;
      }

      print("Starting to get answer");
      final formatSourceStartTime = DateTime.now();

      // Get Answer
      //Format watchedVideos to different json structure
      final List<Map<String, String>> formattedResults =
          extractedResults.map((searchResult) {
        return {
          "title": searchResult.title,
          "url": searchResult.url,
          "snippet": searchResult.excerpts.trim(),
        };
      }).toList();

      formattedResults.addAll(youtubeVideos.map((video) {
        return {
          "title": video.title,
          "url": "https://www.youtube.com/watch?v=${video.videoId}",
          "snippet": "${video.snippet} ${video.description}",
        };
      }));

      formattedResults.addAll(mapResults.map((result) {
        return {
          "title": result.title,
          "url":
              "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${result.title} ${result.address}")}&query_place_id=${result.placeId}",
          "snippet":
              "Local Place: ${result.title}. Address: ${result.address}. Rating: ${result.rating} (${result.reviews} reviews). ${result.snippet}",
        };
      }));

      // Add memory chunks as context for the AI (high priority - add first)
      if (memoryChunks.isNotEmpty) {
        print("📚 Adding ${memoryChunks.length} memory chunks to context");
        final memoryResults = memoryChunks.map((chunk) {
          return {
            "title": "[Memory] Previously learned from: ${chunk.sourceQuery}",
            "url": "memory://local",
            "snippet": chunk.text,
          };
        }).toList();
        // Insert memory at beginning for higher priority
        formattedResults.insertAll(0, memoryResults);
      }

      final formatSourceEndTime = DateTime.now();

      print(
          "Finished formatting sources: ${formatSourceEndTime.difference(formatSourceStartTime).inMilliseconds} ms");

      print("");

      print("Starting to generate answer");

      // Local AI: use on-device model
      if (_drissyEngine.isLoaded) {
        // Emit sources being condensed so UI can show reading progress
        emit(state.copyWith(condensingSources: formattedResults.take(6).toList()));

        List<String> sourcesForDrissy = [];

        // Call /summarize-query to get a pre-built summary from the browser API
        try {
          final summarizeBody = {
            'query': query,
            'maxTokens': 1024,
            'results': extractedResults.map((r) => {
              'found': r.isVerified,
              'title': r.title,
              'url': r.url,
              'extractedText': r.excerpts,
            }).toList(),
          };

          final summarizeResponse = await httpClient.post(
            Uri.parse('https://browser-api.drissea.com/summarize-query'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${dotenv.get('API_SECRET')}',
            },
            body: jsonEncode(summarizeBody),
          );

          if (summarizeResponse.statusCode == 200) {
            final summarizeJson = jsonDecode(summarizeResponse.body);
            final summary = (summarizeJson['summary'] ?? '').toString().trim();
            if (summary.isNotEmpty) {
              sourcesForDrissy = [summary];
              print('Got summary from /summarize-query (${summary.length} chars)');
            }
          } else {
            print('summarize-query API failed: ${summarizeResponse.statusCode}');
          }
        } catch (e) {
          print('Error calling summarize-query: $e');
        }

        // Fallback: if summary unavailable, use truncated formatted results
        if (sourcesForDrissy.isEmpty) {
          sourcesForDrissy = formattedResults
              .take(6)
              .map((s) => '${s["title"]}: ${s["snippet"]}')
              .toList();
        }

        // Prepend Obsidian note as highest-priority source
        final obsidianSource = await _prepareObsidianNoteSource();
        if (obsidianSource != null) {
          sourcesForDrissy.insert(0, 'Obsidian Note:\n$obsidianSource');
        }

        // Clear condensing sources after summary is ready
        emit(state.copyWith(condensingSources: const []));

        try {
          String finalContent = "";
          await for (final token in _drissyEngine.answer(
            query: query,
            sources: sourcesForDrissy,
          )) {
            finalContent += token;
            event.streamedText.value = finalContent;
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
          }
          if (finalContent.isNotEmpty) {
            answer = finalContent;
          } else {
            answer = 'Something went wrong generating a response. Please try again.';
            event.streamedText.value = answer!;
          }
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        } catch (e) {
          print('Drissy inference error: $e');
          answer = 'Something went wrong generating a response. Please try again.';
          event.streamedText.value = answer!;
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        }
      } else {
        answer = 'Local AI model not loaded. Please enable Local AI in settings.';
        event.streamedText.value = answer!;
        emit(state.copyWith(replyStatus: HomeReplyStatus.success));
      }
    }

    //Update ThreadData
    ThreadResultData updResultData = ThreadResultData(
      youtubeVideos: youtubeVideos,
      searchType: resultData.searchType,
      extractedUrlData: resultData.extractedUrlData,
      sourceImageDescription: resultData.sourceImageDescription,
      sourceImageLink: resultData.sourceImageLink,
      sourceImage: resultData.sourceImage,
      isSearchMode: resultData.isSearchMode,
      web: resultData.web,
      shortVideos: instagramShortVideos,
      videos: resultData.videos,
      news: resultData.news,
      images: resultData.images,
      createdAt: resultData.createdAt,
      updatedAt: resultData.updatedAt,
      userQuery: query,
      searchQuery: searchQuery,
      answer: answer ?? "",
      browseImages: pendingBrowseImages,
      influence: extractedResults.map((searchResult) {
        return InfluenceData(
            url: searchResult.url,
            snippet: searchResult.excerpts,
            title: searchResult.title,
            similarity: 0,
            isVerified: searchResult.isVerified);
      }).toList()
        ..addAll(mapResults.map((searchResult) {
          final locationQuery = Uri.encodeComponent(
              "${searchResult.title} ${searchResult.address}");
          return InfluenceData(
              url:
                  "https://www.google.com/maps/search/?api=1&query=$locationQuery&query_place_id=${searchResult.placeId}",
              snippet: searchResult.snippet,
              title: searchResult.title,
              similarity: 0);
        })),
      local: mapResults,
      obsidianNoteName: resultData.obsidianNoteName,
    );

    final updatedResults = List<ThreadResultData>.from(state.threadData.results)
      ..removeLast()
      ..add(updResultData);

    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          isIncognito: state.threadData.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          isIncognito: state.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    // Commit pending Obsidian note on first message; preserve on subsequent ones
    if (updatedResults.length == 1 && state.pendingObsidianNoteContent != null) {
      updThreadData = updThreadData.copyWith(
        obsidianNoteName: state.pendingObsidianNoteName,
        obsidianNoteContent: state.pendingObsidianNoteContent,
      );
    } else if (updatedResults.length > 1) {
      updThreadData = updThreadData.copyWith(
        obsidianNoteName: state.threadData.obsidianNoteName,
        obsidianNoteContent: state.threadData.obsidianNoteContent,
      );
    }
    if (_cancelTaskGen) {
      return;
    }
    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        threadData: updThreadData,
        uploadedImageUrl: "",
        selectedImage: null,
        imageStatus: HomeImageStatus.unselected,
        pendingObsidianNoteName: null,
        pendingObsidianNoteContent: null));
    event.imageDescriptionNotifier.value = "";

    // Generate thread title and summary using AI Gateway before saving
    final titleSummary =
        await _generateThreadTitleAndSummary(updThreadData.results);
    updThreadData = updThreadData.copyWith(
      title: titleSummary['title'],
      summary: titleSummary['summary'],
    );

    if (updThreadData.results.length == 1) {
      await createSession(updThreadData, threadId,
          skipMemoryProcessing: state.isChatModeActive);
    } else {
      await updateSession(updThreadData, state.threadData.id,
          skipMemoryProcessing: state.isChatModeActive);
    }

    // Refresh history
    add(HomeInitialUserData());
  }

  /// Generate multiple search queries from user input for Deep Drissy mode
  /// Uses the /generate-search-queries API endpoint with conversation context.
  Future<List<String>> _generateMultipleSearchQueries(String query) async {
    print("trying to generate multiple search queries for Deep Drissy...");
    try {
      // Build context from last 3 messages
      print("Building context for query generation from previous messages...");
      final previousResults = state.threadData.results;
      print("Total previous messages: ${previousResults.length}");
      final recentResults = previousResults.length > 3
          ? previousResults.sublist(previousResults.length - 3)
          : previousResults;

      print("Context messages for query generation:");
      final List<Map<String, String>> contextMessages = [];
      for (final r in recentResults) {
        if (r.userQuery.isNotEmpty) {
          contextMessages.add({"role": "user", "content": r.userQuery});
        }
        if (r.answer.isNotEmpty) {
          contextMessages.add({"role": "assistant", "content": r.answer});
        }
      }

      //final drisseaApiHost = dotenv.get('API_HOST');
      final apiSecret = dotenv.get('API_SECRET');
      final url = Uri.parse("https://browser-api.drissea.com/generate-search-queries");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiSecret',
        },
        body: jsonEncode({
          'query': query,
          'context': contextMessages,
          'maxTokens': 256,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> queries = json['queries'] ?? [];
        final result = queries
            .map((q) => q.toString().trim())
            .where((q) => q.isNotEmpty && q.length > 3)
            .take(5)
            .toList();

        if (result.isNotEmpty) {
          print("Deep Drissy: Generated ${result.length} search queries: $result");
          return result;
        }
      } else {
        print("Deep Drissy: generate-search-queries API error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("Error generating multiple search queries: $e");
    }
    // Fallback: return the original query
    return [query];
  }

  /// Deep Drissy answer flow - multi-query deep research
  Future<void> _getDeepDrissyAnswer(
      HomeDeepDrissyGetAnswer event, Emitter<HomeState> emit) async {
    await _loadPersonalization();
    print("=== DEBUG _getDeepDrissyAnswer ENTRY: query='${event.query}' ===");

    String query = event.query;
    String searchQuery = event.query;
    String city = state.userCity;
    String region = state.userRegion;
    String country = state.userCountry;
    String countryCode = state.userCountryCode;

    String threadId = Uuid().v4().substring(0, 8);
    _cancelTaskGen = false;
    List<YoutubeVideoData> youtubeVideos = [];

    final imagePath = state.selectedImage?.path;
    Uint8List? imageBytes;
    if (state.selectedImage != null) {
      try {
        imageBytes = await File(state.selectedImage!.path).readAsBytes();
      } catch (e) {
        print("Error reading image bytes: $e");
      }
    }

    ThreadResultData resultData = ThreadResultData(
      youtubeVideos: [],
      searchType: state.searchType,
      sourceImageDescription: event.imageDescription,
      sourceImageLink: state.uploadedImageUrl ?? "",
      sourceImage: imageBytes,
      isSearchMode: false,
      extractedUrlData: ExtractedUrlResultData(
        snippet: event.extractedUrlDescription.value,
        title: event.extractedUrlTitle.value,
        link: event.extractedUrl.value,
        thumbnail: event.extractedImageUrl.value,
      ),
      web: [],
      shortVideos: [],
      videos: [],
      news: [],
      images: [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      userQuery: query,
      searchQuery: searchQuery,
      answer: "",
      influence: [],
      local: [],
      obsidianNoteName: state.pendingObsidianNoteName,
    );
    List<ExtractedResultInfo> extractedResults = [];

    ThreadSessionData updThreadData = state.threadData;

    event.extractedUrlTitle.value = "";
    event.extractedUrlDescription.value = "";
    event.extractedImageUrl.value = "";
    event.extractedUrl.value = "";

    List<ThreadResultData> tempUpdatedResults =
        List<ThreadResultData>.from(state.threadData.results)
          ..add(resultData);
    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          isIncognito: state.threadData.isIncognito,
          results: tempUpdatedResults,
          obsidianNoteName: state.threadData.obsidianNoteName,
          obsidianNoteContent: state.threadData.obsidianNoteContent,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
          obsidianNoteName: state.pendingObsidianNoteName,
          obsidianNoteContent: state.pendingObsidianNoteContent,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    String? answer;
    List<LocalResultData> mapResults = [];
    List<ShortVideoResultData> instagramShortVideos = [];
    List<({String text, String sourceQuery, double score})> memoryChunks = [];

    // Location processing
    if (_queryNeedsLocation(query)) {
      final shouldProceed =
          await _checkLocationPermissionForQuery(
        HomeGetAnswer(
          event.query,
          event.streamedText,
          event.extractedUrlDescription,
          event.extractedUrlTitle,
          event.extractedUrl,
          event.extractedImageUrl,
          event.imageDescription,
          event.imageDescriptionNotifier,
        ),
        emit,
      );
      if (!shouldProceed) return;

      if (city.isEmpty) {
        emit(state.copyWith(
          status: HomePageStatus.generateQuery,
          imageStatus: HomeImageStatus.unselected,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
        ));
        final userData = await _getUserLocation();
        city = userData.city;
        region = userData.region;
        country = userData.country;
        countryCode = userData.countryCode;
      }

      if (city.isNotEmpty) {
        final replaceWithIn = [
          'near me', 'nearby', 'close to me', 'around me',
          'in my area', 'around here', 'this area', 'my location',
          'where i am'
        ];
        final appendIn = ['local', 'closest', 'nearest'];
        final appendCity = [
          'places near', 'restaurants near', 'shops near', 'bars near',
          'cafes near', 'hotels near', 'stores near'
        ];

        String lowerQuery = searchQuery.toLowerCase();
        bool modified = false;

        for (final keyword in replaceWithIn) {
          if (lowerQuery.contains(keyword)) {
            final pattern =
                RegExp(RegExp.escape(keyword), caseSensitive: false);
            searchQuery =
                searchQuery.replaceAll(pattern, "in $city");
            modified = true;
            break;
          }
        }
        if (!modified) {
          for (final keyword in appendIn) {
            if (lowerQuery.contains(keyword)) {
              searchQuery = "$searchQuery in $city";
              modified = true;
              break;
            }
          }
        }
        if (!modified) {
          for (final keyword in appendCity) {
            if (lowerQuery.contains(keyword)) {
              searchQuery = "$searchQuery $city";
              modified = true;
              break;
            }
          }
        }
      }
    }

    // Image handling — use on-device Drissy vision
    if (imagePath != null) {
      emit(state.copyWith(
          status: HomePageStatus.success,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
          searchType: state.searchType == HomeSearchType.extractUrl
              ? HomeSearchType.general
              : state.searchType,
          replyStatus: HomeReplyStatus.loading,
          selectedImage: null,
          imageStatus: HomeImageStatus.unselected));

      event.imageDescriptionNotifier.value = "";

      if (_drissyEngine.isLoaded && _drissyEngine.isVisionLoaded) {
        try {
          String finalContent = "";
          await for (final token in _drissyEngine.answerWithImage(
            query: query,
            imagePath: imagePath,
            sources: [],
          )) {
            finalContent += token;
            event.streamedText.value = finalContent;
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
          }
          if (finalContent.isNotEmpty) {
            answer = finalContent;
          } else {
            answer = "Sorry, I couldn't analyze this image. Please try again.";
            event.streamedText.value = answer!;
          }
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        } catch (e) {
          print('Drissy vision error: $e');
          answer = "Sorry, I couldn't analyze this image. Please try again.";
          event.streamedText.value = answer!;
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        }
      } else {
        answer =
            "Image analysis isn't available right now. Please make sure the AI model is loaded in settings.";
        event.streamedText.value = answer!;
        emit(state.copyWith(replyStatus: HomeReplyStatus.success));
      }
    } else {
      emit(state.copyWith(
        status: HomePageStatus.generateQuery,
        imageStatus: HomeImageStatus.unselected,
        threadData: updThreadData,
        loadingIndex: updThreadData.results.length - 1,
        selectedImage: null,
      ));

      // Rewrite query with context
      // if (state.threadData.results.isNotEmpty) {
      //   searchQuery = await _rewriteQueryWithContext(
      //     query,
      //     state.threadData.results,
      //   );
      //   print("Deep Drissy - Original query: $query");
      //   print("Deep Drissy - Rewritten query: $searchQuery");
      // }

print("Starting Deep Drissy search with query: $searchQuery");
      try {

        final searchStartTime = DateTime.now();
        
        // Generate multiple search queries
        print("Generating multiple search queries for Deep Drissy...");
        final searchQueries =
            await _generateMultipleSearchQueries(searchQuery);
            print("Generated search queries for Deep Drissy: $searchQueries");
        
      emit(state.copyWith(status: HomePageStatus.getSearchResults));

        // Trigger Deep Drissy multi-query webview
        _deepDrissyWebSearchCompleter =
            Completer<List<ExtractedResultInfo>>();
        emit(state.copyWith(
            deepDrissyWebSearchQueries: searchQueries));

        final webResults =
            await _deepDrissyWebSearchCompleter!.future;
        _deepDrissyWebSearchCompleter = null;

        int totalChars = 0;
        const int charLimit = 200000; // Higher limit for deep drissy
        for (final result in webResults) {
          final int resultChars = result.url.length +
              result.title.length +
              result.excerpts.length;
          if (totalChars + resultChars > charLimit) break;
          extractedResults.add(result);
          totalChars += resultChars;
        }
        print(
            "Deep Drissy web results: ${extractedResults.length}");

        // Enrich snippets via batch extract API, grouped by source query
        if (extractedResults.isNotEmpty) {
          // Group results by sourceQuery
          final Map<String, List<int>> queryGroupIndices = {};
          for (int i = 0; i < extractedResults.length; i++) {
            final key = extractedResults[i].sourceQuery.isNotEmpty
                ? extractedResults[i].sourceQuery
                : 'general';
            queryGroupIndices.putIfAbsent(key, () => []).add(i);
          }

          final queryKeys = queryGroupIndices.keys.toList();
          final Map<String, String> allEnrichedSnippets = {};
          final Set<String> allVerifiedUrls = {};

          for (int qi = 0; qi < queryKeys.length; qi++) {
            final queryKey = queryKeys[qi];
            final indices = queryGroupIndices[queryKey]!;

            emit(state.copyWith(
              deepDrissyReadingStatus:
                  'Reading ${qi + 1}/${queryKeys.length}: $queryKey',
            ));

            try {
              final batchItems = indices
                  .map((i) => {
                        'url': extractedResults[i].url,
                        'excerpt': extractedResults[i].excerpts,
                      })
                  .toList();

              final batchResponse = await http.post(
                Uri.parse(
                    'https://browser-api.drissea.com/extract-batch'),
                headers: {
                  'Content-Type': 'application/json',
                  "Authorization":
                      "Bearer ${dotenv.get('API_SECRET')}"
                },
                body: jsonEncode({'items': batchItems}),
              );

              if (batchResponse.statusCode == 200) {
                final batchJson = jsonDecode(batchResponse.body);
                final List<dynamic> batchResults =
                    batchJson['results'] ?? [];

                for (final item in batchResults) {
                  if (item['found'] == true && item['url'] != null) {
                    allVerifiedUrls.add(item['url'] as String);
                    final text = (item['extractedText'] ?? '')
                        .toString()
                        .trim();
                    if (text.isNotEmpty) {
                      allEnrichedSnippets[item['url']] = text;
                    }
                  }
                }
              }

              print(
                  "Deep Drissy batch ${qi + 1}/${queryKeys.length} ('$queryKey'): enriched ${indices.length} results");
            } catch (e) {
              print(
                  "Deep Drissy batch extract error for '$queryKey': $e");
            }
          }

          // Apply all enrichments
          extractedResults = extractedResults.map((r) {
            final enriched = allEnrichedSnippets[r.url];
            final isVerified = allVerifiedUrls.contains(r.url);
            if (enriched != null && enriched.isNotEmpty) {
              return ExtractedResultInfo(
                url: r.url,
                title: r.title,
                excerpts: enriched,
                thumbnailUrl: r.thumbnailUrl,
                isVerified: true,
                sourceQuery: r.sourceQuery,
              );
            }
            return ExtractedResultInfo(
              url: r.url,
              title: r.title,
              excerpts: r.excerpts,
              thumbnailUrl: r.thumbnailUrl,
              isVerified: isVerified,
              sourceQuery: r.sourceQuery,
            );
          }).toList();

          emit(state.copyWith(deepDrissyReadingStatus: null));

          print(
              "Deep Drissy enriched ${allEnrichedSnippets.length}/${extractedResults.length} results across ${queryKeys.length} batches");
        }

        final searchDuration =
            DateTime.now().difference(searchStartTime);
        print(
            "Deep Drissy search duration: ${searchDuration.inMilliseconds} ms");

        emit(state.copyWith(
            status: HomePageStatus.success,
            searchType: state.searchType == HomeSearchType.extractUrl
                ? HomeSearchType.general
                : state.searchType,
            replyStatus: HomeReplyStatus.loading));
      } catch (e) {
        print("Deep Drissy search error: $e");
      }

      if (_cancelTaskGen) return;

      // Format sources (used for influence/citations)
      final List<Map<String, String>> formattedResults =
          extractedResults.map((searchResult) {
        return {
          "title": searchResult.title,
          "url": searchResult.url,
          "snippet": searchResult.excerpts.trim(),
        };
      }).toList();

      formattedResults.addAll(youtubeVideos.map((video) {
        return {
          "title": video.title,
          "url":
              "https://www.youtube.com/watch?v=${video.videoId}",
          "snippet": "${video.snippet} ${video.description}",
        };
      }));

      formattedResults.addAll(mapResults.map((result) {
        return {
          "title": result.title,
          "url":
              "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${result.title} ${result.address}")}&query_place_id=${result.placeId}",
          "snippet":
              "Local Place: ${result.title}. Address: ${result.address}. Rating: ${result.rating} (${result.reviews} reviews). ${result.snippet}",
        };
      }));

      if (memoryChunks.isNotEmpty) {
        final memoryResults = memoryChunks.map((chunk) {
          return {
            "title":
                "[Memory] Previously learned from: ${chunk.sourceQuery}",
            "url": "memory://local",
            "snippet": chunk.text,
          };
        }).toList();
        formattedResults.insertAll(0, memoryResults);
      }

      // Summarize each search query's results independently, then feed to on-device AI
      print("Deep Drissy: Summarizing results per query via /summarize-query");
      final List<String> sourcesForDrissy = [];

      // Group enriched results by sourceQuery
      final Map<String, List<ExtractedResultInfo>> groupedByQuery = {};
      for (final r in extractedResults) {
        final key = r.sourceQuery.isNotEmpty ? r.sourceQuery : query;
        groupedByQuery.putIfAbsent(key, () => []).add(r);
      }

      int groupIndex = 0;
      for (final entry in groupedByQuery.entries) {
        groupIndex++;
        final groupQuery = entry.key;
        final groupResults = entry.value;

        final groupSourceItems = groupResults.take(6).map((r) => {
          'title': r.title,
          'url': r.url,
          'snippet': r.excerpts.trim(),
        }).toList();

        emit(state.copyWith(
          deepDrissyReadingStatus:
              'Summarizing $groupIndex/${groupedByQuery.length}: $groupQuery',
          condensingSources: groupSourceItems,
        ));

        try {
          final summarizeResponse = await http.post(
            Uri.parse('https://browser-api.drissea.com/summarize-query'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${dotenv.get('API_SECRET')}',
            },
            body: jsonEncode({
              'query': groupQuery,
              'maxTokens': 1024,
              'results': groupResults.map((r) => {
                'url': r.url,
                'title': r.title,
                'snippet': r.excerpts,
                'extractedText': r.excerpts,
              }).toList(),
            }),
          );

          if (summarizeResponse.statusCode == 200) {
            final summarizeJson = jsonDecode(summarizeResponse.body);
            final summary = (summarizeJson['summary'] ?? '').toString().trim();
            if (summary.isNotEmpty) {
              sourcesForDrissy.add(summary);
              print('Deep Drissy: Summary for "$groupQuery" (${summary.length} chars)');
            } else {
              // Fallback to raw snippets for this group
              sourcesForDrissy.addAll(
                groupResults.take(3).map((r) => '${r.title}: ${r.excerpts.trim()}'),
              );
            }
          } else {
            print('Deep Drissy: summarize-query failed for "$groupQuery": ${summarizeResponse.statusCode}');
            sourcesForDrissy.addAll(
              groupResults.take(3).map((r) => '${r.title}: ${r.excerpts.trim()}'),
            );
          }
        } catch (e) {
          print('Deep Drissy: summarize-query error for "$groupQuery": $e');
          sourcesForDrissy.addAll(
            groupResults.take(3).map((r) => '${r.title}: ${r.excerpts.trim()}'),
          );
        }

        emit(state.copyWith(condensingSources: const []));
      }

      emit(state.copyWith(deepDrissyReadingStatus: null));

      // Final fallback if nothing was summarized
      if (sourcesForDrissy.isEmpty) {
        sourcesForDrissy.addAll(
          formattedResults.take(6).map((s) => '${s["title"]}: ${s["snippet"]}'),
        );
      }

      // Prepend Obsidian note as highest-priority source
      final obsidianSourceDeep = await _prepareObsidianNoteSource();
      if (obsidianSourceDeep != null) {
        sourcesForDrissy.insert(0, 'Obsidian Note:\n$obsidianSourceDeep');
      }

      print("Deep Drissy: Starting answer generation via on-device AI with ${sourcesForDrissy.length} summaries");

      if (_drissyEngine.isLoaded) {
        try {
          String finalContent = "";
          await for (final token in _drissyEngine.answer(
            query: query,
            sources: sourcesForDrissy,
            maxTokens: 2048,
            systemPromptSuffix:
                'This is a deep research response. Be COMPREHENSIVE and EXHAUSTIVE. '
                'Cover every angle from the sources with detailed sections and subsections. '
                'Do not truncate — write a thorough, complete research summary.',
          )) {
            finalContent += token;
            event.streamedText.value = finalContent;
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
          }
          if (finalContent.isNotEmpty) {
            answer = finalContent;
          } else {
            answer = 'Something went wrong generating a response. Please try again.';
            event.streamedText.value = answer;
          }
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        } catch (e) {
          print('Deep Drissy inference error: $e');
          answer = 'Something went wrong generating a response. Please try again.';
          event.streamedText.value = answer;
          emit(state.copyWith(replyStatus: HomeReplyStatus.success));
        }
      } else {
        answer = 'Local AI model not loaded. Please enable Local AI in settings.';
        event.streamedText.value = answer;
        emit(state.copyWith(replyStatus: HomeReplyStatus.success));
      }
    }

    // Update ThreadData (Deep Drissy)
    ThreadResultData updResultData = ThreadResultData(
      youtubeVideos: youtubeVideos,
      searchType: resultData.searchType,
      extractedUrlData: resultData.extractedUrlData,
      sourceImageDescription: resultData.sourceImageDescription,
      sourceImageLink: resultData.sourceImageLink,
      sourceImage: resultData.sourceImage,
      isSearchMode: resultData.isSearchMode,
      web: resultData.web,
      shortVideos: instagramShortVideos,
      videos: resultData.videos,
      news: resultData.news,
      images: resultData.images,
      createdAt: resultData.createdAt,
      updatedAt: resultData.updatedAt,
      userQuery: query,
      searchQuery: searchQuery,
      answer: answer,
      influence: extractedResults.map((searchResult) {
        return InfluenceData(
            url: searchResult.url,
            snippet: searchResult.excerpts,
            title: searchResult.title,
            similarity: 0,
            isVerified: searchResult.isVerified,
            sourceQuery: searchResult.sourceQuery);
      }).toList()
        ..addAll(mapResults.map((searchResult) {
          final locationQuery = Uri.encodeComponent(
              "${searchResult.title} ${searchResult.address}");
          return InfluenceData(
              url:
                  "https://www.google.com/maps/search/?api=1&query=$locationQuery&query_place_id=${searchResult.placeId}",
              snippet: searchResult.snippet,
              title: searchResult.title,
              similarity: 0);
        })),
      local: mapResults,
      obsidianNoteName: resultData.obsidianNoteName,
    );

    final updatedResults =
        List<ThreadResultData>.from(state.threadData.results)
          ..removeLast()
          ..add(updResultData);

    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          isIncognito: state.threadData.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          isIncognito: state.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    // Commit pending Obsidian note on first message; preserve on subsequent ones
    if (updatedResults.length == 1 && state.pendingObsidianNoteContent != null) {
      updThreadData = updThreadData.copyWith(
        obsidianNoteName: state.pendingObsidianNoteName,
        obsidianNoteContent: state.pendingObsidianNoteContent,
      );
    } else if (updatedResults.length > 1) {
      updThreadData = updThreadData.copyWith(
        obsidianNoteName: state.threadData.obsidianNoteName,
        obsidianNoteContent: state.threadData.obsidianNoteContent,
      );
    }
    if (_cancelTaskGen) return;

    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        threadData: updThreadData,
        uploadedImageUrl: "",
        selectedImage: null,
        imageStatus: HomeImageStatus.unselected,
        pendingObsidianNoteName: null,
        pendingObsidianNoteContent: null));
    event.imageDescriptionNotifier.value = "";

    final titleSummary =
        await _generateThreadTitleAndSummary(updThreadData.results);
    updThreadData = updThreadData.copyWith(
      title: titleSummary['title'],
      summary: titleSummary['summary'],
    );

    if (updThreadData.results.length == 1) {
      await createSession(updThreadData, threadId,
          skipMemoryProcessing: state.isChatModeActive);
    } else {
      await updateSession(updThreadData, state.threadData.id,
          skipMemoryProcessing: state.isChatModeActive);
    }

    add(HomeInitialUserData());
  }



  /// Generate a reply from Drissea API given a query and search results.
  Future<String?> generateReply(
      String query, List<Map<String, String>> results) async {
    // Provided implementation: replaces all previous prompt/user context logic.
    // Step 1: Format sources with token counting, skip if would exceed 125,000 tokens.
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      // Simple token estimate: 1 token ≈ 4 chars (for GPT-3/4 family, rough approximation)
      int tokens = ((result["title"]!.length +
              result["url"]!.length +
              result["snippet"]!.length) ~/
          4);
      if (totalTokens + tokens > 125000) {
        break;
      }
      formattedSources.add({
        "title": result["title"]!,
        "url": result["url"]!,
        "snippet": result["snippet"]!,
      });
      totalTokens += tokens;
    }

    // Step 2: IP lookup and user context
    Map<String, dynamic> userContext = {};
    try {
      final ipRes = await http.get(Uri.parse("https://ipapi.co/json/"));
      if (ipRes.statusCode == 200) {
        final ipJson = jsonDecode(ipRes.body);
        userContext = {
          "city": ipJson["city"] ?? "",
          "region": ipJson["region"] ?? "",
          "country_name": ipJson["country_name"] ?? "",
          "country_code": ipJson["country_code"] ?? "",
          "timezone": ipJson["timezone"] ?? "",
          "org": ipJson["org"] ?? "",
          "postal": ipJson["postal"] ?? "",
          "latitude": ipJson["latitude"]?.toString() ?? "",
          "longitude": ipJson["longitude"]?.toString() ?? "",
          "ip": ipJson["ip"] ?? "",
        };
      }
    } catch (e) {
      userContext = {};
    }

    // Step 3: Build systemPrompt as provided
    final systemPrompt = """
You are a helpful, concise, and insightful assistant. You answer user questions using a list of web sources, each with a title, url, and snippet.

Rules:
- Always answer in Markdown.
- Structure your response with clear headings and bullet points as needed.
- Always **bold key insights** and highlight notable places, dishes, or experiences.
- For any place, food item, or experience that was featured in a source, wrap the main word or phrase in this format: `[text to show](<link>)` (e.g., Try the **[Dum Pukht Biryani](https://example.com/food)**).
- Write naturally as if you're recommending or informing—never say “based on search results” or “these sources say.”
- Only use the sources that directly answer the query.
- If no strong or direct matches are found, gracefully say: _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_
- Do not repeat the question or use generic filler lines.
- Keep your language short, engaging, and optimized for mobile readability.

You may use the following user context for additional personalization (if relevant):
${jsonEncode(userContext)}
""";

    // Step 4: Make the API request to Drissea with the new prompt, sources, and user context
    final url = Uri.parse("https://api.drissea.com/api/generate/answer");
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${dotenv.get("API_SECRET")}",
      },
      body: jsonEncode({
        "query": query,
        "results": formattedSources,
        "user_context": userContext,
        "system_prompt": systemPrompt,
      }),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> jsonRes = jsonDecode(decodedBody);
      String? content = jsonRes["content"] as String?;
      if (content != null && content.contains("</think>")) {
        final parts = content.split("</think>");
        content = parts.length > 1
            ? parts.sublist(1).join("</think>").trim()
            : parts[0].trim();
      }
      return content?.toString();
    } else {
      print(results);
      print(
          "❌ Generate reply failed: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  // Generate a reply from Drissea API given a query and search results.
  Future<String?> altGenerateReply(
      String query,
      List<Map<String, String>> results,
      ValueNotifier<String> streamedText,
      Emitter<HomeState> emit,
      List<ThreadResultData> previousResults) async {
    streamedText.value = "";
    // Provided implementation: replaces all previous prompt/user context logic.
    // Step 1: Format sources with token counting, skip if would exceed 125,000 tokens.
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      // Simple token estimate: 1 token ≈ 4 chars (for GPT-3/4 family, rough approximation)
      int tokens = ((result["title"]!.length +
              result["url"]!.length +
              result["snippet"]!.length) ~/
          4);
      if (totalTokens + tokens > 125000) {
        break;
      }
      formattedSources.add({
        "title": result["title"]!,
        "url": result["url"]!,
        "snippet": result["snippet"]!,
      });
      totalTokens += tokens;
    }

    // Step 2: IP lookup and user context
    Map<String, dynamic> userContext = {};
    try {
      final ipRes = await http.get(Uri.parse("https://ipapi.co/json/"));
      if (ipRes.statusCode == 200) {
        final ipJson = jsonDecode(ipRes.body);
        userContext = {
          "city": ipJson["city"] ?? "",
          "region": ipJson["region"] ?? "",
          "country_name": ipJson["country_name"] ?? "",
          "country_code": ipJson["country_code"] ?? "",
          "timezone": ipJson["timezone"] ?? "",
          "org": ipJson["org"] ?? "",
          "postal": ipJson["postal"] ?? "",
          "latitude": ipJson["latitude"]?.toString() ?? "",
          "longitude": ipJson["longitude"]?.toString() ?? "",
          "ip": ipJson["ip"] ?? "",
        };
      }
    } catch (e) {
      userContext = {};
    }

    // Step 3: Build systemPrompt as provided
    final systemPrompt = """
You are a helpful, concise, and insightful assistant. You answer user questions using a list of web sources, each with a title, url, and snippet.

Rules:
- Always answer in Markdown.
- Structure your response with clear headings and bullet points as needed.
- Always **bold key insights** and highlight notable places, dishes, or experiences.
- For any place, food item, or experience that was featured in a source, wrap the main word or phrase in this format: `[text to show](<link>)` (e.g., Try the **[Dum Pukht Biryani](https://example.com/food)**).
- Write naturally as if you're recommending or informing—never say “based on search results” or “these sources say.”
- Only use the sources that directly answer the query.
- If no strong or direct matches are found, gracefully say: _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_
- Do not repeat the question or use generic filler lines.
- Keep your language short, engaging, and optimized for mobile readability.

You may use the following user context for additional personalization (if relevant):
${jsonEncode(userContext)}
""";

    // Step 4: Make the streaming API request to Drissea with the new prompt, sources, and user context
    final url = Uri.parse("https://api.deepseek.com/chat/completions");

    final request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer ${dotenv.get("DEEPSEEK_API_KEY")}",
    });

    request.body = jsonEncode({
      "model": "deepseek-chat",
      "stream": true,
      "messages": [
        {"role": "system", "content": systemPrompt},
        // Add previous queries and answers as context
        ...previousResults.expand((item) => [
              {"role": "user", "content": item.userQuery},
              {
                "role": "assistant",
                "content": item.isSearchMode
                    ? jsonEncode({
                        "previous_web_results": item.web
                            .map((inf) => {
                                  "title": inf.title,
                                  "url": inf.link,
                                  "snippet": inf.snippet,
                                })
                            .toList(),
                      })
                    : item.answer,
              },
            ]),

        {"role": "user", "content": query},
        {
          "role": "user",
          "content": jsonEncode(
              {"results": formattedSources, "user_context": userContext})
        }
      ],
    });
    print("");
    print("Starting streaming request...");
    print("");

    final streamedResponse = await httpClient.send(request);
    final stream = streamedResponse.stream.transform(utf8.decoder);

    String finalContent = "";

    String buffer = "";
    print("Listening to stream...");
    await for (final rawChunk in stream) {
      try {
        String cleaned = rawChunk.trim();
        //print("Received chunk: $cleaned");

        // Split into SSE lines
        final lines = cleaned.split("\n");

        for (final line in lines) {
          String l = line.trim();
          if (!l.startsWith("data:")) continue;

          l = l.substring(5).trim(); // Remove "data:"

          if (l == "[DONE]") continue;

          // Append to buffer
          buffer += l;

          try {
            final decoded = jsonDecode(buffer);
            buffer = ""; // reset after successful parse

            final delta = decoded["choices"]?[0]?["delta"];
            if (delta == null) continue;
            //print("Parsed delta: $delta");
            // Ignore reasoning
            if (delta["reasoning_content"] != null) continue;
            //print("reasoning_content skipped");

            if (delta["content"] != null) {
              emit(state.copyWith(replyStatus: HomeReplyStatus.success));
              final chunkText = delta["content"];
              //print(chunkText);
              streamedText.value += chunkText;
              finalContent += chunkText;
            }
          } catch (e) {
            // Partial JSON, keep buffering
            continue;
          }
        }
      } catch (e) {
        print("Streaming parse error: $e");
      }
    }

    if (finalContent.isNotEmpty) {
      if (finalContent.contains("</think>")) {
        final parts = finalContent.split("</think>");
        finalContent = parts.length > 1
            ? parts.sublist(1).join("</think>").trim()
            : parts[0].trim();
      }
      return finalContent;
    } else {
      print("❌ Streaming failed or empty content");
      return null;
    }
  }


  /// Rewrites a query to be self-contained by replacing context-dependent parts
  /// (pronouns, references like "it", "that", "this", etc.) with actual entities
  /// from previous messages in the thread.
  /// Returns the rewritten query, or the original query if no rewriting is needed.
  /// Limits conversation history to ~4k tokens (approx 16k characters).
  Future<String> _rewriteQueryWithContext(
      String query, List<ThreadResultData> previousResults) async {
    if (previousResults.isEmpty) {
      return query;
    }

    // Build a minimal context: only the user queries (not full answers)
    // to stay well within the small model's 4096 context window.
    final recentResults = previousResults.length > 3
        ? previousResults.sublist(previousResults.length - 3)
        : previousResults;
    final contextLines = recentResults
        .map((r) => r.userQuery)
        .where((q) => q.isNotEmpty)
        .toList();

    final systemPrompt =
        """Generate a concise search query to find information that answers the USER QUERY, using the CONTEXT for reference. Output ONLY the search query. No explanation.""";

    final userMessage =
        """Generate a concise search query to find information that answers the USER QUERY, using the CONTEXT for reference. Output ONLY the search query. No explanation.\nCONTEXT:\n${contextLines.join('\n')}\n\nUSER QUERY: $query\n\nSEARCH QUERY:""";

    try {
      if (_drissyEngine.isLoaded) {
        final result = await _drissyEngine.complete(
          systemMessage: systemPrompt,
          userMessage: userMessage,
          maxTokens: 60,
          temperature: 0.1,
        );
        if (result != null && result.isNotEmpty) {
          // Guard: if the model produced something way longer than the
          // original query it likely answered instead of rewriting.
          if (result.length <= query.length * 3) {
            return result;
          }
          print(result);
          print("❌ Query rewrite too long, using original");
        }
      } else {
        print("❌ Query rewrite skipped: local AI not loaded");
      }
    } catch (e) {
      print("❌ Query rewrite failed: $e");
    }

    // Return original query if rewriting fails
    return query;
  }

  /// Generates thread title and summary using AI Gateway based on all user inputs in the thread.
  /// Returns a map with 'title' and 'summary' keys.
  /// Summary is limited to 150 characters.
  Future<Map<String, String>> _generateThreadTitleAndSummary(
      List<ThreadResultData> results) async {
    if (results.isEmpty) {
      return {'title': '', 'summary': ''};
    }

    // Collect all user queries from the thread
    final userQueries =
        results.map((r) => r.userQuery).where((q) => q.isNotEmpty).toList();

    if (userQueries.isEmpty) {
      return {'title': '', 'summary': ''};
    }

    final queriesText = userQueries.join('\n- ');

    final systemPrompt =
        """You are a helpful assistant that generates concise titles and summaries for conversation threads.

Given the user's queries in a thread, generate:
1. A short, descriptive title (max 50 characters) that captures the main topic
2. A brief summary (max 150 characters) that describes what the conversation is about

Respond ONLY in this exact JSON format, no other text:
{"title": "your title here", "summary": "your summary here"}""";

    final userMessage = """User queries in this thread:
- $queriesText

Generate a title and summary for this thread.""";

    try {
      if (_drissyEngine.isLoaded) {
        final content = await _drissyEngine.complete(
          systemMessage: systemPrompt,
          userMessage: userMessage,
          maxTokens: 200,
          temperature: 0.3,
        );

        if (content != null && content.isNotEmpty) {
          // Parse the JSON response
          String jsonStr = content;
          if (content.contains('```')) {
            final match =
                RegExp(r'```(?:json)?\s*(\{.*?\})\s*```', dotAll: true)
                    .firstMatch(content);
            if (match != null) {
              jsonStr = match.group(1) ?? content;
            }
          }

          final parsed = jsonDecode(jsonStr);
          String title = parsed["title"] ?? "";
          String summary = parsed["summary"] ?? "";

          if (summary.length > 150) {
            summary = "${summary.substring(0, 147)}...";
          }
          if (title.length > 50) {
            title = "${title.substring(0, 47)}...";
          }

          print("📝 Generated thread title: $title");
          print("📝 Generated thread summary: $summary");

          return {'title': title, 'summary': summary};
        }
      }
    } catch (e) {
      print("❌ Error generating thread title/summary: $e");
    }

    // Fallback: use first query as title
    final fallbackTitle = userQueries.first.length > 50
        ? "${userQueries.first.substring(0, 47)}..."
        : userQueries.first;
    return {'title': fallbackTitle, 'summary': ''};
  }

  Future<String?> vercelNewGenerateReply(
    String query,
    List<Map<String, String>> results,
    ValueNotifier<String> streamedText,
    Emitter<HomeState> emit,
    String imageDescription,
    List<ThreadResultData> previousResults,
    ExtractedUrlResultData? extractedUrlData,
    String city,
    String region,
    String country,
  ) async {
    final generateAnswerStartTime = DateTime.now();
    streamedText.value = "";

    // Step 1: Format sources with token counting for on-device context window
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      int tokens = ((result["title"]!.length +
              result["url"]!.length +
              result["snippet"]!.length) ~/
          4);
      if (totalTokens + tokens > 4000) {
        break;
      }
      formattedSources.add({
        "title": result["title"]!,
        "url": result["url"]!,
        "snippet": result["snippet"]!,
      });
      totalTokens += tokens;
    }

    // Step 2: User context
    String formattedUserContext = city == "" && region == "" && country == ""
        ? "The current date and time is ${DateTime.now()}."
        : "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

    // Step 3: Build systemPrompt
    bool isChat = formattedSources.isEmpty;
    final systemPrompt = """You are Drissea, a private, conversational, and insightful answer engine. You do not save user data and keep as much processing as possible strictly on-device.

${isChat ? "" : """You answer user questions using a list of web sources, each with a title, url, and snippet.
Rules:
- Always answer in Markdown.
- Structure your response with clear headings and bullet points as needed.
- Always **bold key insights** and highlight notable places, dishes, or experiences.
- For any place, food item, or experience that was featured in a source, wrap the main word or phrase in this format: [text to show](<link>).
- **Be Conversational**: Write naturally, like a knowledgeable friend. Avoid robotic phrases like "based on search results" or "these sources say."
- Only use the sources that directly answer the query.
- If no strong or direct matches are found, gracefully say: _"There isn't a perfect match for that, but here are a few options that might still interest you."_
- Do not repeat the question or use generic filler lines.
- Keep your language engaging, be as detailed and exhaustive as possible, ensuring no relevant detail from the sources is omitted, while still maintaining clarity and readability.
- If the query consists primarily of a URL (e.g., youtube.com/...), use the provided content from the extracted URL to summarize what the page or video is about.

"""}Use the following user context for additional personalization (if relevant):
$formattedUserContext
${_personalizationText.isNotEmpty ? '\nAbout the user: $_personalizationText' : ''}
Don't reveal any personal information you have in your context unless asked about it.
""";

    // Step 4: Build conversation messages for on-device model
    // Trim to last 4 messages for context window
    final recentPrevious = previousResults.length > 4
        ? previousResults.sublist(previousResults.length - 4)
        : previousResults;

    final conversationMessages = <Map<String, String>>[];

    for (final item in recentPrevious) {
      conversationMessages.add({
        'role': 'user',
        'content': item.sourceImageDescription != ""
            ? "${item.userQuery} | Here's the image description: ${item.sourceImageDescription}"
            : item.userQuery,
      });
      conversationMessages.add({
        'role': 'assistant',
        'content': item.answer,
      });
    }

    // Build the current user message with sources embedded
    String currentUserMessage = query;
    if (imageDescription.isNotEmpty) {
      currentUserMessage += " | Here's the image description: $imageDescription";
    }
    if (extractedUrlData?.snippet != null && extractedUrlData!.snippet!.isNotEmpty) {
      currentUserMessage += " | Here's the extracted url page description: ${extractedUrlData.snippet}";
    }

    if (!isChat && formattedSources.isNotEmpty) {
      final sourcesText = formattedSources
          .asMap()
          .entries
          .map((e) => 'Source ${e.key + 1} [${e.value["title"]}] (${e.value["url"]}):\n${e.value["snippet"]}')
          .join('\n\n');
      currentUserMessage += "\n\nWeb Sources:\n$sourcesText";
    }

    conversationMessages.add({
      'role': 'user',
      'content': currentUserMessage,
    });

    print("");
    print("Starting on-device streaming request...");
    print("");

    try {
      String finalContent = "";
      print("TTFT: ${DateTime.now().difference(generateAnswerStartTime).inMilliseconds}");

      await for (final token in _drissyEngine.chat(
        systemMessage: systemPrompt,
        conversationMessages: conversationMessages,
      )) {
        finalContent += token;
        streamedText.value = finalContent;
        emit(state.copyWith(replyStatus: HomeReplyStatus.success));
      }

      if (finalContent.isNotEmpty) {
        if (finalContent.contains("</think>")) {
          final parts = finalContent.split("</think>");
          finalContent = parts.length > 1
              ? parts.sublist(1).join("</think>").trim()
              : parts[0].trim();
        }
        return finalContent;
      } else {
        print("On-device streaming returned empty content");
        return null;
      }
    } catch (e) {
      print("On-device generation failed: $e");
      return null;
    }
  }

//   //Chowmein API
//   Future<String?> chowmeinGenerateReply(
//     String query,
//     List<Map<String, String>> results,
//     ValueNotifier<String> streamedText,
//     Emitter<HomeState> emit,
//     String imageDescription,
//     List<ThreadResultData> previousResults,
//     ExtractedUrlResultData? extractedUrlData,
//     String city,
//     String region,
//     String country,
//   ) async {
//     final generateAnswerStartTime = DateTime.now();
//     streamedText.value = "";
//     // Step 1: Format sources with token counting - ONLY YouTube results, limit 2k tokens.
//     int totalTokens = 0;
//     List<Map<String, String>> formattedSources = [];
//     for (final result in results) {
//       if (result["title"] == null ||
//           result["url"] == null ||
//           result["snippet"] == null) {
//         continue;
//       }
//       // Simple token estimate: 1 token ≈ 4 chars
//       int tokens = ((result["title"]!.length +
//               result["url"]!.length +
//               result["snippet"]!.length) ~/
//           4);
//       if (totalTokens + tokens > 8000) {
//         break;
//       }
//       formattedSources.add({
//         "title": result["title"]!,
//         "url": result["url"]!,
//         "snippet": result["snippet"]!,
//       });
//       totalTokens += tokens;
//     }

//     // Step 2: Determine if this is a chat request (no search results)
//     bool isChat = formattedSources.isEmpty;

//     // Step 3: Check for Cold Start & Fallback
//     final baseUrl = dotenv.get("QWEN_SARVAM_API_URL");

//     // Determine the URL to check (same logic as below)
//     final checkUrlStr = isChat
//         ? baseUrl.replaceFirst('.modal.run', '-chat.modal.run')
//         : baseUrl.replaceFirst('.modal.run', '-search.modal.run');
//     final checkUrl = Uri.parse(checkUrlStr);

//     try {
//       print("DEBUG: Checking Drissy status at $checkUrl...");

//       // Attempt a lightweight GET request with a short timeout.
//       // If the container is warm, it should respond instantly (405 Method Not Allowed is expected for POST endpoints).
//       // If it takes longer than 2 seconds, we assume it's cold/waking up.
//       await http.get(checkUrl).timeout(const Duration(seconds: 2));
//       print("DEBUG: Drissy is warm. Proceeding.");
//     } catch (e) {
//       print(
//           "DEBUG: Drissy is cold (or timeout: $e). Switching to Vercel fallback & warming up in background.");

//       // Explicit fire-and-forget warmup to ensure container boots
//       // We use a longer timeout here (or no timeout) to let it complete in background
//       http.get(checkUrl).then((_) {
//         print("DEBUG: Drissy background warmup completed");
//       }).catchError((err) {
//         print(
//             "DEBUG: Drissy background warmup completed with error (expected if just waking up): $err");
//       });

//       // Fallback to Vercel
//       return vercelNewGenerateReply(
//         query,
//         results,
//         streamedText,
//         emit,
//         imageDescription,
//         previousResults,
//         extractedUrlData,
//         city,
//         region,
//         country,
//       );
//     }

//     // Step 4: Build the full query with context
//     String fullQuery =
//         "$query ${imageDescription == "" ? "" : "| Here's the image description: $imageDescription"}  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}"
//             .trim();

//     // Step 5: Make the API request to Qwen-Sarvam vLLM server
//     // final baseUrl = dotenv.get("QWEN_SARVAM_API_URL"); // Already retrieved above

//     print("");
//     print("Starting request to Qwen-Sarvam vLLM API...");
//     print("");

//     try {
//       final Uri url;
//       final String body;

//       if (isChat) {
//         // Use /chat endpoint for pure chat (no search results)
//         // Modal URL format: endpoint name is in the hostname
//         // e.g., https://viratgsingh99--qwen-sarvam-vllm-v2-chat.modal.run
//         final chatUrl = baseUrl.replaceFirst('.modal.run', '-chat.modal.run');
//         url = Uri.parse(chatUrl);

//         // Build messages array with previous context
//         List<Map<String, String>> messages = [];
//         for (final item in previousResults) {
//           messages.add({
//             "role": "user",
//             "content": item.sourceImageDescription != ""
//                 ? "${item.userQuery} | Here's the image description:${item.sourceImageDescription}"
//                 : item.userQuery
//           });
//           messages.add({
//             "role": "assistant",
//             "content": item.answer,
//           });
//         }
//         messages.add({
//           "role": "user",
//           "content": fullQuery,
//         });

//         body = jsonEncode({
//           "messages": messages,
//           "max_tokens": 1000,
//           "thinking": false,
//           "stream": true,
//         });
//       } else {
//         // Use /search endpoint for search-augmented generation
//         // Modal URL format: endpoint name is in the hostname
//         // e.g., https://viratgsingh99--qwen-sarvam-vllm-v2-search.modal.run
//         final searchUrl =
//             baseUrl.replaceFirst('.modal.run', '-search.modal.run');
//         url = Uri.parse(searchUrl);

//         // Format search results in Source/Title/Snippet format
//         String searchResultsStr =
//             "User Query: $query\n\n Search Results:\nHere are search result snippets for \"$query\":\n";
//         for (final src in formattedSources) {
//           // Extract domain as source name
//           String sourceName = "Unknown";
//           try {
//             final uri = Uri.parse(src["url"] ?? "");
//             sourceName = uri.host.replaceFirst("www.", "");
//           } catch (_) {}

//           searchResultsStr += "\n---\n\n";
//           searchResultsStr += "**Source:** *$sourceName*\n";
//           searchResultsStr += "**Title:** **\"${src["title"]}\"**\n";
//           searchResultsStr += "**Snippet:** ${src["snippet"]}\n";
//         }
//         searchResultsStr += "\n---";

//         // Step 2: IP lookup and user context
//         String formattedUserContext = city == "" &&
//                 region == "" &&
//                 country == ""
//             ? "The current date and time is ${DateTime.now()}."
//             : "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

//         // Step 3: Build systemPrompt
//         bool isChat = formattedSources.isEmpty;
//         final systemPrompt = """
// You are Drissy, a private, conversational, and insightful answer engine. You do not save user data and keep as much processing as possible strictly on-device. 

// ${isChat ? "" : """
// You answer user questions using a list of web sources, each with a title, url, and snippet.
// Rules:
// - Always answer in Markdown.
// - Structure your response in mobile-friendly way.
// - Always **bold key insights** and highlight notable places, dishes, or experiences.
// - For any place, food item, or experience that was featured in a source, wrap the main word or phrase in this format: `[text to show](<link>)` (e.g., Try the **[Dum Pukht Biryani](https://example.com/food)**).
// - **Be Conversational**: Write naturally, like a knowledgeable friend. Avoid robotic phrases like “based on search results” or “these sources say.”
// - Only use the sources that directly answer the query.
// - If no strong or direct matches are found, gracefully say: _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_
// - Do not repeat the question or use generic filler lines.
// - Keep your language engaging, be as detailed and exhaustive as possible, ensuring no relevant detail from the sources is omitted, while still maintaining clarity and readability.
// - If the query consists primarily of a URL (e.g., youtube.com/...), use the provided content from the extracted URL to summarize what the page or video is about.
// """}
// Use the following user context for additional personalization (if relevant):
// $formattedUserContext

// Don't reveal any personal information you have in your context unless asked about it.
// """;

//         body = jsonEncode({
//           "query": fullQuery,
//           "search_results": searchResultsStr,
//           "system_prompt": systemPrompt,
//           "max_tokens": 6000,
//           "temperature": 0.7,
//           "thinking": false,
//           "stream": true,
//         });
//       }

//       print("🔗 Calling URL: $url");
//       final request = http.Request("POST", url);
//       request.headers.addAll({"Content-Type": "application/json"});
//       request.body = body;
//       print("📤 Request Body: $body");

//       final streamedResponse = await httpClient
//           .send(request)
//           .timeout(const Duration(seconds: 90));
//       print("Response Status Code: ${streamedResponse.statusCode}");

//       if (streamedResponse.statusCode != 200) {
//         final errorBody =
//             await streamedResponse.stream.transform(utf8.decoder).join();
//         print("❌ Error Body: $errorBody");
//         return null;
//       }

//       final stream = streamedResponse.stream
//           .transform(utf8.decoder)
//           .transform(const LineSplitter());

//       String finalContent = "";
//       print("Listening to stream...");
//       print(
//           "TTFT:${DateTime.now().difference(generateAnswerStartTime).inMilliseconds}");

//       await for (final line in stream) {
//         if (!line.startsWith("data:")) continue;
//         final chunk = line.substring(5).trim();
//         if (chunk == "[DONE]") continue;

//         try {
//           final decoded = jsonDecode(chunk);
//           final delta = decoded["choices"]?[0]?["delta"];
//           if (delta == null) continue;

//           if (delta["content"] != null) {
//             final chunkText = delta["content"];
//             streamedText.value += chunkText;
//             finalContent += chunkText;
//             emit(state.copyWith(replyStatus: HomeReplyStatus.success));
//           }
//         } catch (e) {
//           print("Streaming parse error: \$e");
//         }
//       }

//       if (finalContent.isNotEmpty) {
//         if (finalContent.contains("</think>")) {
//           final parts = finalContent.split("</think>");
//           finalContent = parts.length > 1
//               ? parts.sublist(1).join("</think>").trim()
//               : parts[0].trim();
//         }
//         return finalContent;
//       } else {
//         print("❌ Streaming failed or empty content");
//         return null;
//       }
//     } catch (e) {
//       print("❌ Qwen-Sarvam API Request failed: $e");
//       return null;
//     }
//   }

  //Get relevant search query from task
  bool _cancelTaskGen = false;
  //Cancel Gen Task
  Future<void> _cancelTaskSearchQuery(
      HomeCancelTaskGen event, Emitter<HomeState> emit) async {
    _cancelTaskGen = true;
    if (state.threadData.results.isEmpty) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    } else {
      List<ThreadResultData> updResultData = [];
      if (state.editStatus == HomeEditStatus.loading) {
        updResultData =
            List<ThreadResultData>.from(state.cacheThreadData.results);
      } else {
        updResultData = List<ThreadResultData>.from(state.threadData.results)
          ..removeLast();
      }
      ThreadSessionData updThreadData = ThreadSessionData(
          id: state.threadData.id,
          isIncognito: state.threadData.isIncognito,
          results: updResultData,
          createdAt: state.threadData.createdAt,
          updatedAt: state.threadData.updatedAt);

      emit(state.copyWith(
          status: updResultData.isEmpty
              ? HomePageStatus.idle
              : HomePageStatus.success,
          threadData: updThreadData,
          replyStatus: state.editStatus == HomeEditStatus.loading
              ? HomeReplyStatus.idle
              : state.replyStatus,
          loadingIndex: state.editStatus == HomeEditStatus.loading
              ? -1
              : state.loadingIndex));
    }
  }

  //Close Thread
  Future<void> _startNewThread(
      HomeStartNewThread event, Emitter<HomeState> emit) async {
    emit(
      state.copyWith(
        status: HomePageStatus.idle,
        threadData: ThreadSessionData(
          id: "",
          isIncognito: false,
          results: [],
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        ),
        pendingObsidianNoteName: null,
        pendingObsidianNoteContent: null,
      ),
    );
  }

  FutureOr<void> _handleObsidianNoteSelected(
      HomeObsidianNoteSelected event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      pendingObsidianNoteName: event.noteName,
      pendingObsidianNoteContent: event.noteContent,
    ));
  }

  FutureOr<void> _handleObsidianNoteCleared(
      HomeObsidianNoteCleared event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      pendingObsidianNoteName: null,
      pendingObsidianNoteContent: null,
      threadData: state.threadData.copyWith(
        obsidianNoteName: null,
        obsidianNoteContent: null,
      ),
    ));
  }

  /// Resolves the Obsidian note content for the current inference call,
  /// truncating to fit within the token budget if needed.
  Future<String?> _prepareObsidianNoteSource() async {
    final rawContent = state.threadData.results.isEmpty
        ? state.pendingObsidianNoteContent
        : state.threadData.obsidianNoteContent;

    if (rawContent == null || rawContent.isEmpty) return null;

    const int maxNoteTokens = 5268; // 8192 - 1024gen - 200sys - 800conv - 800src - 100query

    final tokens = await _drissyEngine.tokenize(rawContent);
    if (tokens.length <= maxNoteTokens) return rawContent;

    final ratio = rawContent.length / tokens.length;
    final charLimit = (maxNoteTokens * ratio).floor();
    return '${rawContent.substring(0, charLimit)}\n\n[...note truncated to fit context]';
  }

  Future<void> _deleteAllHistory(
      HomeDeleteAllHistory event, Emitter<HomeState> emit) async {
    try {
      await AppDatabase().deleteAllThreads();
      emit(state.copyWith(
        threadHistory: [],
        threadData: ThreadSessionData(
          id: "",
          isIncognito: false,
          results: [],
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        ),
      ));
    } catch (e) {
      print("❌ Error deleting all history: $e");
    }
  }

  Future<void> _getUserInfo(
      HomeInitialUserData event, Emitter<HomeState> emit) async {
    emit(state.copyWith(historyStatus: HomeHistoryStatus.loading));

    // 1. Load local data first for instant display
    try {
      final threads = await AppDatabase().getAllThreads();
      final localSessionData = threads.map((thread) {
        return ThreadSessionData.fromJson(jsonDecode(thread.sessionData));
      }).toList();

      emit(state.copyWith(
          threadHistory: localSessionData,
          historyStatus: HomeHistoryStatus.idle));
    } catch (e) {
      print("❌ Error fetching local sessions: $e");
      emit(state.copyWith(
          threadHistory: [], historyStatus: HomeHistoryStatus.idle));
    }

    // // 2. Then sync from Firestore in background if logged in
    // try {
    //   final prefs = await SharedPreferences.getInstance();
    //   final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    //   final email = prefs.getString('email') ?? '';

    //   if (isLoggedIn && email.isNotEmpty) {
    //     final db = FirebaseFirestore.instance;
    //     final userQuery = await db
    //         .collection('users')
    //         .where('email', isEqualTo: email)
    //         .limit(1)
    //         .get();

    //     if (userQuery.docs.isNotEmpty) {
    //       final userDocId = userQuery.docs.first.id;
    //       final threadQuery = await db
    //           .collection('threads')
    //           .where('userId', isEqualTo: userDocId)
    //           .orderBy('updatedAt', descending: true)
    //           .get();

    //       final firestoreSessionData = threadQuery.docs.map((doc) {
    //         return ThreadSessionData.fromJson(doc.data());
    //       }).toList();

    //       emit(state.copyWith(threadHistory: firestoreSessionData));
    //     }
    //   }
    // } catch (e) {
    //   print("❌ Error fetching Firestore threads: $e");
    // }

    // // Get user location silently
    // await _getUserLocation().then((userLocation) {
    //   emit(state.copyWith(
    //     userCity: userLocation.city,
    //     userRegion: userLocation.region,
    //     userCountry: userLocation.country,
    //     userCountryCode: userLocation.countryCode,
    //   ));
    // });
  }

  Future<String?> createSession(ThreadSessionData sessionData, String sessionId,
      {bool skipMemoryProcessing = false}) async {
    // final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      final thread = ThreadsCompanion.insert(
        id: drift.Value(sessionId),
        sessionData: jsonEncode(sessionData.toJson()),
        createdAt: drift.Value(sessionData.createdAt.toDate()),
        updatedAt: drift.Value(sessionData.updatedAt.toDate()),
      );

      await AppDatabase().insertThread(thread);
      print("✅ Session created in local database with ID: $sessionId");

      print(sessionId);
      print("aa");
      print(sessionData.toJson());
      print("aa");

      // final firestoreData = sessionData.toJson();
      // firestoreData['createdAt'] = sessionData.createdAt;
      // firestoreData['updatedAt'] = sessionData.updatedAt;
      // firestoreData['results'] = sessionData.results.map((e) {
      //   final data = e.toJson();
      //   data['createdAt'] = e.createdAt;
      //   data['updatedAt'] = e.updatedAt;
      //   return data;
      // }).toList();

      // // Tag thread with userId if logged in
      // final prefs = await SharedPreferences.getInstance();
      // final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      // final email = prefs.getString('email') ?? '';
      // if (isLoggedIn && email.isNotEmpty) {
      //   final userQuery = await firestore
      //       .collection('users')
      //       .where('email', isEqualTo: email)
      //       .limit(1)
      //       .get();
      //   if (userQuery.docs.isNotEmpty) {
      //     firestoreData['userId'] = userQuery.docs.first.id;
      //   }
      // }

      // await firestore.collection("threads").doc(sessionId).set(firestoreData);
      // print("✅ Session created/updated in Firestore with ID: $sessionId");

      // // Fire-and-forget: update profile stats in background
      // ProfileStatsService.updateStatsInBackground();

      return sessionId;
    } catch (e) {
      print("Error creating session: $e");
      return null;
    }
  }


  Future<
      ({
        String country,
        String countryCode,
        String city,
        String region,
        String timezone,
        String org,
        String postal,
        String latitude,
        String longitude,
        String ip
      })> _getUserLocation() async {
    // try {
    //   Position position = await _determinePosition();

    //   List<Placemark> placemarks = await placemarkFromCoordinates(
    //     position.latitude,
    //     position.longitude,
    //   );

    //   if (placemarks.isNotEmpty) {
    //     Placemark place = placemarks[0];

    //     return (
    //       country: place.country ?? "",
    //       countryCode: place.isoCountryCode ?? "",
    //       city: place.locality ?? "",
    //       region: place.administrativeArea ?? "",
    //       timezone: "", // Not available via placemark directly
    //       org: "", // Not available via basic local location
    //       postal: place.postalCode ?? "",
    //       latitude: position.latitude.toString(),
    //       longitude: position.longitude.toString(),
    //       ip: "", // Not available via local location
    //     );
    //   }
    // } catch (e) {
    //   print("Error fetching user location locally: $e");
    // }
    return (
      country: "",
      countryCode: "in",
      city: "",
      region: "",
      timezone: "",
      org: "",
      postal: "",
      latitude: "",
      longitude: "",
      ip: ""
    );
  }

  Future<String?> updateSession(ThreadSessionData sessionData, String sessionId,
      {bool skipMemoryProcessing = false}) async {
    // final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      final thread = ThreadsCompanion(
        id: drift.Value(sessionId),
        sessionData: drift.Value(jsonEncode(sessionData.toJson())),
        createdAt: drift.Value(sessionData.createdAt.toDate()),
        updatedAt: drift.Value(sessionData.updatedAt.toDate()),
      );

      await AppDatabase().updateThread(sessionId, thread);
      print("✅ Session updated in local database with ID: $sessionId");

      // final docRef = firestore.collection("threads").doc(sessionId);
      // final docSnapshot = await docRef.get();

      // final firestoreData = sessionData.toJson();
      // firestoreData['createdAt'] = sessionData.createdAt;
      // firestoreData['updatedAt'] = Timestamp.now();
      // firestoreData['results'] = sessionData.results.map((e) {
      //   final data = e.toJson();
      //   data['createdAt'] = e.createdAt;
      //   data['updatedAt'] = e.updatedAt;
      //   return data;
      // }).toList();

      // // Tag thread with userId if logged in
      // final prefs = await SharedPreferences.getInstance();
      // final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      // final email = prefs.getString('email') ?? '';
      // if (isLoggedIn && email.isNotEmpty) {
      //   final userQuery = await firestore
      //       .collection('users')
      //       .where('email', isEqualTo: email)
      //       .limit(1)
      //       .get();
      //   if (userQuery.docs.isNotEmpty) {
      //     firestoreData['userId'] = userQuery.docs.first.id;
      //   }
      // }

      // if (docSnapshot.exists) {
      //   await docRef.update(firestoreData);
      //   print("✅ Session updated successfully with ID: $sessionId");
      // } else {
      //   await docRef.set(firestoreData);
      //   print("🆕 Session created with ID: $sessionId");
      // }

      // // Fire-and-forget: update profile stats in background
      // ProfileStatsService.updateStatsInBackground();

      // Process and cache the latest answer for memory system (fire-and-forget, isolated)
      // Skip if chat mode is active
      // if (!skipMemoryProcessing && sessionData.results.isNotEmpty) {
      //   final latestResult = sessionData.results.last;
      //   _processAnswerForMemory(latestResult.answer, latestResult.userQuery);
      // }

      return sessionId;
    } catch (e) {
      print("❌ Session update failed: $e");
      return null;
    }
  }

  void _toggleVisualBrowse(
    HomeToggleVisualBrowse event,
    Emitter<HomeState> emit,
  ) {
    final next = state.visualBrowseStatus == HomeVisualBrowseStatus.enabled
        ? HomeVisualBrowseStatus.disabled
        : HomeVisualBrowseStatus.enabled;
    // Disable other modes when enabling visual browse
    emit(state.copyWith(
      visualBrowseStatus: next,
      deepDrissyStatus: next == HomeVisualBrowseStatus.enabled
          ? HomeDeepDrissyStatus.disabled
          : state.deepDrissyStatus,
      isChatModeActive: next == HomeVisualBrowseStatus.enabled
          ? false
          : state.isChatModeActive,
    ));
  }

  void _handleVisualBrowseImagesExtracted(
    HomeVisualBrowseImagesExtracted event,
    Emitter<HomeState> emit,
  ) {
    if (_visualBrowseCompleter != null && !_visualBrowseCompleter!.isCompleted) {
      _visualBrowseCompleter!.complete(event.images);
    }
    emit(state.copyWith(visualBrowseSearchQuery: null));
  }

  Future<void> _handleVisualBrowseStart(
    HomeVisualBrowseStart event,
    Emitter<HomeState> emit,
  ) async {
    // Create placeholder thread entry
    final newResult = ThreadResultData(
      userQuery: event.query,
      searchQuery: '',
      visualBrowseResults: const [],
      answer: '',
      web: [],
      shortVideos: [],
      videos: [],
      news: [],
      images: [],
      local: [],
      youtubeVideos: [],
      influence: [],
      searchType: HomeSearchType.general,
      isSearchMode: false,
      sourceImageDescription: '',
      sourceImageLink: '',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    final results = [...state.threadData.results, newResult];
    final loadingIndex = results.length - 1;

    event.streamedText.value = '';

    emit(state.copyWith(
      threadData: state.threadData.copyWith(results: results),
      loadingIndex: loadingIndex,
      status: HomePageStatus.loading,
      replyStatus: HomeReplyStatus.loading,
      visualBrowseSearchQuery: event.query,
    ));

    // Wait for WebView to extract images
    _visualBrowseCompleter = Completer<List<VisualBrowseImageData>>();
    List<VisualBrowseImageData> images;
    try {
      images = await _visualBrowseCompleter!.future
          .timeout(const Duration(seconds: 40), onTimeout: () => []);
    } catch (_) {
      images = [];
    }

    if (images.isEmpty) {
      emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        status: HomePageStatus.success,
        deepDrissyReadingStatus: null,
      ));
      return;
    }

    // Accept all images (up to 10) without AI filtering
    final engine = _drissyEngine;
    final tempDir = await getTemporaryDirectory();
    final accepted = <VisualBrowseResultData>[];

    final capped = images.take(10).toList();
    for (final img in capped) {
      accepted.add(VisualBrowseResultData(
        thumbnailDataUri: img.thumbnailDataUri,
        title: img.title,
        sourceLink: img.sourceLink,
      ));
    }
    event.visualBrowseNotifier.value = List<VisualBrowseResultData>.from(accepted);

    // ── Phase 1 done: store filtered images, show album ──────────────────────
    final phase1Results = List<ThreadResultData>.from(state.threadData.results);
    if (loadingIndex < phase1Results.length) {
      final old = phase1Results[loadingIndex];
      phase1Results[loadingIndex] = ThreadResultData(
        userQuery: old.userQuery,
        searchQuery: old.searchQuery,
        visualBrowseResults: accepted,
        answer: '',
        web: old.web,
        shortVideos: old.shortVideos,
        videos: old.videos,
        news: old.news,
        images: old.images,
        local: old.local,
        youtubeVideos: old.youtubeVideos,
        influence: old.influence,
        searchType: old.searchType,
        isSearchMode: old.isSearchMode,
        sourceImageDescription: old.sourceImageDescription,
        sourceImageLink: old.sourceImageLink,
        createdAt: old.createdAt,
        updatedAt: Timestamp.now(),
        obsidianNoteName: old.obsidianNoteName,
      );
    }

    emit(state.copyWith(
      threadData: state.threadData.copyWith(results: phase1Results),
      replyStatus: HomeReplyStatus.success,
      status: HomePageStatus.success,
      deepDrissyReadingStatus: null,
    ));

    // ── Phase 2: describe each accepted image (vision) ────────────────────────
    if (accepted.isEmpty || !engine.isLoaded) return;

    final descriptions = <String>[];

    for (int i = 0; i < accepted.length; i++) {
      emit(state.copyWith(
        visualBrowseAnalysisStatus:
            'Describing image ${i + 1} of ${accepted.length}...',
      ));

      try {
        final bytes = await _resolveVBImageBytes(accepted[i].thumbnailDataUri);
        if (bytes == null) continue;

        final tempFile = File('${tempDir.path}/vb_desc_$i.jpg');
        await tempFile.writeAsBytes(bytes);

        String description = '';
        final descStream = engine.chat(
          systemMessage:
              'Describe this image concisely in under 80 words, focusing on what is visually present.',
          conversationMessages: const [
            {'role': 'user', 'content': 'Describe this image.'}
          ],
          imagePath: tempFile.path,
        );
        await for (final token in descStream) {
          description += token;
          if (description.split(' ').length > 100) break;
        }

        try { await tempFile.delete(); } catch (_) {}

        final label = accepted[i].title.isNotEmpty
            ? accepted[i].title
            : 'Image ${i + 1}';
        descriptions.add('**$label**: $description');
      } catch (e) {
        print('VisualBrowse: description error for image $i: $e');
      }
    }

    // ── Phase 3: generate answer from descriptions ────────────────────────────
    if (descriptions.isEmpty) {
      emit(state.copyWith(visualBrowseAnalysisStatus: null));
      return;
    }

    emit(state.copyWith(
      visualBrowseAnalysisStatus: null,
      deepDrissyReadingStatus: 'Generating answer...',
    ));

    final combinedPrompt = 'The user searched for: "${event.query}"\n\n'
        'Here are descriptions of the found images:\n\n'
        '${descriptions.join('\n\n')}\n\n'
        'Based on these images, provide a helpful, concise answer to the user\'s query.';

    String finalAnswer = '';
    try {
      final answerStream = engine.chat(
        systemMessage:
            'You are a helpful assistant. Answer based on the image descriptions provided.',
        conversationMessages: [
          {'role': 'user', 'content': combinedPrompt}
        ],
      );
      await for (final token in answerStream) {
        finalAnswer += token;
        event.streamedText.value = finalAnswer;
        emit(state.copyWith(replyStatus: HomeReplyStatus.success));
      }
    } catch (e) {
      print('VisualBrowse: answer generation error: $e');
    }

    // ── Phase 4: persist answer + clear status ────────────────────────────────
    final finalResults = List<ThreadResultData>.from(state.threadData.results);
    if (loadingIndex < finalResults.length) {
      final old = finalResults[loadingIndex];
      finalResults[loadingIndex] = ThreadResultData(
        userQuery: old.userQuery,
        searchQuery: old.searchQuery,
        visualBrowseResults: accepted,
        answer: finalAnswer,
        web: old.web,
        shortVideos: old.shortVideos,
        videos: old.videos,
        news: old.news,
        images: old.images,
        local: old.local,
        youtubeVideos: old.youtubeVideos,
        influence: old.influence,
        searchType: old.searchType,
        isSearchMode: old.isSearchMode,
        sourceImageDescription: old.sourceImageDescription,
        sourceImageLink: old.sourceImageLink,
        createdAt: old.createdAt,
        updatedAt: Timestamp.now(),
        obsidianNoteName: old.obsidianNoteName,
      );
    }

    emit(state.copyWith(
      threadData: state.threadData.copyWith(results: finalResults),
      replyStatus: HomeReplyStatus.success,
      status: HomePageStatus.success,
      visualBrowseAnalysisStatus: null,
      deepDrissyReadingStatus: null,
    ));
  }

  Future<Uint8List?> _resolveVBImageBytes(String src) async {
    if (src.startsWith('data:image/')) {
      return base64Decode(src.split(',').last);
    } else if (src.startsWith('http')) {
      final response = await httpClient
          .get(Uri.parse(src))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) return response.bodyBytes;
    }
    return null;
  }

  void _handleVisualBrowseCompleted(
    HomeVisualBrowseCompleted event,
    Emitter<HomeState> emit,
  ) {
    final newResult = ThreadResultData(
      userQuery: event.query,
      searchQuery: '',
      visualBrowseResults: event.images,
      answer: '',
      web: [],
      shortVideos: [],
      videos: [],
      news: [],
      images: [],
      local: [],
      youtubeVideos: [],
      influence: [],
      searchType: HomeSearchType.general,
      isSearchMode: false,
      sourceImageDescription: '',
      sourceImageLink: '',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    final updatedResults = [
      ...state.threadData.results,
      newResult,
    ];
    emit(state.copyWith(
      threadData: state.threadData.copyWith(results: updatedResults),
    ));
  }

  // ── Moodboard handlers ─────────────────────────────────────────────────────

  void _toggleMoodboard(
    HomeToggleMoodboard event,
    Emitter<HomeState> emit,
  ) {
    final next = state.moodboardStatus == HomeMoodboardStatus.enabled
        ? HomeMoodboardStatus.disabled
        : HomeMoodboardStatus.enabled;
    emit(state.copyWith(
      moodboardStatus: next,
      deepDrissyStatus: next == HomeMoodboardStatus.enabled
          ? HomeDeepDrissyStatus.disabled
          : state.deepDrissyStatus,
      visualBrowseStatus: next == HomeMoodboardStatus.enabled
          ? HomeVisualBrowseStatus.disabled
          : state.visualBrowseStatus,
      isChatModeActive: next == HomeMoodboardStatus.enabled
          ? false
          : state.isChatModeActive,
    ));
  }

  void _handleMoodboardImagesExtracted(
    HomeMoodboardImagesExtracted event,
    Emitter<HomeState> emit,
  ) {
    if (_moodboardCompleter != null && !_moodboardCompleter!.isCompleted) {
      _moodboardCompleter!.complete(event.images);
    }
    emit(state.copyWith(moodboardSearchQuery: null));
  }

  /// Helper: rebuild a ThreadResultData with updated moodboard results + answer.
  ThreadResultData _rebuildWithMoodboard(
    ThreadResultData old,
    List<MoodboardResultData> moodboardResults,
    String answer,
  ) {
    return ThreadResultData(
      userQuery: old.userQuery,
      searchQuery: old.searchQuery,
      moodboardResults: moodboardResults,
      visualBrowseResults: old.visualBrowseResults,
      answer: answer.isNotEmpty ? answer : old.answer,
      web: old.web,
      shortVideos: old.shortVideos,
      videos: old.videos,
      news: old.news,
      images: old.images,
      local: old.local,
      youtubeVideos: old.youtubeVideos,
      influence: old.influence,
      searchType: old.searchType,
      isSearchMode: old.isSearchMode,
      sourceImageDescription: old.sourceImageDescription,
      sourceImageLink: old.sourceImageLink,
      createdAt: old.createdAt,
      updatedAt: Timestamp.now(),
      obsidianNoteName: old.obsidianNoteName,
    );
  }

  Future<void> _handleMoodboardStart(
    HomeMoodboardStart event,
    Emitter<HomeState> emit,
  ) async {
    // ── Phase 0: create placeholder thread entry ──────────────────────────────
    final newResult = ThreadResultData(
      userQuery: event.query,
      searchQuery: '',
      moodboardResults: const [],
      visualBrowseResults: const [],
      answer: '',
      web: [],
      shortVideos: [],
      videos: [],
      news: [],
      images: [],
      local: [],
      youtubeVideos: [],
      influence: [],
      searchType: HomeSearchType.general,
      isSearchMode: false,
      sourceImageDescription: '',
      sourceImageLink: '',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    final results = [...state.threadData.results, newResult];
    final loadingIndex = results.length - 1;

    event.moodboardNotifier.value = [];
    event.scanImagesNotifier.value = [];
    event.progressNotifier.value = '';

    // ── Phase 1: generate search queries via the cloud API (fast, like Deep Drissy) ──
    emit(state.copyWith(
      threadData: state.threadData.copyWith(results: results),
      loadingIndex: loadingIndex,
      status: HomePageStatus.generateQuery,  // shows "Understanding" loader
      replyStatus: HomeReplyStatus.loading,
    ));

    List<String> subQueries = await _generateMoodboardSearchQueries(event.query);
    if (subQueries.isEmpty) subQueries = [event.query];

    // ── Phase 2: open ONE MoodboardWebView for all queries ───────────────────
    // MoodboardWebView handles navigation between queries internally and returns
    // all extracted images in a single pop — no flicker between home ↔ webview.
    _moodboardCompleter = Completer<List<VisualBrowseImageData>>();
    emit(state.copyWith(
      status: HomePageStatus.getSearchResults,
      moodboardAllQueries: subQueries,
    ));

    List<VisualBrowseImageData> allExtracted;
    try {
      allExtracted = await _moodboardCompleter!.future
          .timeout(const Duration(seconds: 300), onTimeout: () => []);
    } catch (_) {
      allExtracted = [];
    }

    // Clear the trigger so the BlocListener doesn't refire
    emit(state.copyWith(moodboardAllQueries: null));

    if (allExtracted.isEmpty) {
      event.progressNotifier.value = '';
      emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        status: HomePageStatus.success,
        moodboardAnalysisStatus: null,
      ));
      return;
    }

    // ── Phase 3: skip AI — accept all extracted images directly ─────────────
    event.progressNotifier.value = '';

    final finalImages = allExtracted
        .map((img) => MoodboardResultData(
              thumbnailDataUri: img.thumbnailDataUri,
              title: img.title,
              sourceLink: img.sourceLink,
              searchQuery: event.query,
            ))
        .toList();

    event.moodboardNotifier.value = finalImages;

    final finalResults = List<ThreadResultData>.from(state.threadData.results);
    if (loadingIndex < finalResults.length) {
      finalResults[loadingIndex] =
          _rebuildWithMoodboard(finalResults[loadingIndex], finalImages, '');
    }
    emit(state.copyWith(
      threadData: state.threadData.copyWith(results: finalResults),
      replyStatus: HomeReplyStatus.success,
      status: HomePageStatus.success,
      moodboardAnalysisStatus: null,
    ));
  }

  /// Generate moodboard-optimised image search queries via the cloud API.
  Future<List<String>> _generateMoodboardSearchQueries(String theme) async {
    try {
      final apiSecret = dotenv.get('API_SECRET');
      final url = Uri.parse("https://browser-api.drissea.com/generate-search-queries");
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiSecret',
        },
        body: jsonEncode({
          'query': 'moodboard images for: $theme',
          'context': <Map<String, String>>[],
          'maxTokens': 256,
          'maxQueries': 10,
        }),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> queries = json['queries'] ?? [];
        final result = queries
            .map((q) => q.toString().trim())
            .where((q) => q.isNotEmpty && q.length > 3)
            .take(10)
            .toList();
        if (result.isNotEmpty) return result;
      }
    } catch (e) {
      print('Moodboard: query API error: $e');
    }
    return [];
  }

  void _handleMoodboardCompleted(
    HomeMoodboardCompleted event,
    Emitter<HomeState> emit,
  ) {
    final newResult = ThreadResultData(
      userQuery: event.query,
      searchQuery: '',
      moodboardResults: event.images,
      answer: '',
      web: [],
      shortVideos: [],
      videos: [],
      news: [],
      images: [],
      local: [],
      youtubeVideos: [],
      influence: [],
      searchType: HomeSearchType.general,
      isSearchMode: false,
      sourceImageDescription: '',
      sourceImageLink: '',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    emit(state.copyWith(
      threadData: state.threadData.copyWith(
          results: [...state.threadData.results, newResult]),
    ));
  }

  Future<void> _deleteLocalAIModel(
    HomeDeleteLocalAIModel event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');
      final mmProjFile = File('${dir.path}/$_mmProjFileName');
      if (_drissyEngine.loadedModelPath == modelFile.path) {
        _drissyEngine.unload();
      }
      if (await modelFile.exists()) await modelFile.delete();
      if (await mmProjFile.exists()) await mmProjFile.delete();
      emit(state.copyWith(
        localAIStatus: LocalAIStatus.idle,
        localAIDownloadProgress: 0.0,
        localAIDownloadPhase: '',
        selectedModel: state.selectedModel == HomeModel.localAI
            ? HomeModel.gemini
            : state.selectedModel,
      ));
    } catch (e) {
      debugPrint('Delete Qwen model error: $e');
    }
  }

  Future<void> _deleteGemma4Model(
    HomeDeleteGemma4Model event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_gemma4FileName');
      final mmProjFile = File('${dir.path}/$_gemma4MmProjFileName');
      if (_drissyEngine.loadedModelPath == modelFile.path) {
        _drissyEngine.unload();
      }
      if (await modelFile.exists()) await modelFile.delete();
      if (await mmProjFile.exists()) await mmProjFile.delete();
      emit(state.copyWith(
        gemma4Status: LocalAIStatus.idle,
        gemma4DownloadProgress: 0.0,
        gemma4DownloadPhase: '',
        selectedModel: state.selectedModel == HomeModel.gemma4
            ? HomeModel.gemini
            : state.selectedModel,
      ));
    } catch (e) {
      debugPrint('Delete Gemma 4 model error: $e');
    }
  }

  Future<void> _deleteLiquidAIModel(
    HomeDeleteLiquidAIModel event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_liquidAIFileName');
      final mmProjFile = File('${dir.path}/$_liquidAIMmProjFileName');
      if (_drissyEngine.loadedModelPath == modelFile.path) {
        _drissyEngine.unload();
      }
      if (await modelFile.exists()) await modelFile.delete();
      if (await mmProjFile.exists()) await mmProjFile.delete();
      emit(state.copyWith(
        liquidAIStatus: LocalAIStatus.idle,
        liquidAIDownloadProgress: 0.0,
        liquidAIDownloadPhase: '',
        selectedModel: state.selectedModel == HomeModel.liquidAI
            ? HomeModel.gemini
            : state.selectedModel,
      ));
    } catch (e) {
      debugPrint('Delete Liquid AI model error: $e');
    }
  }

  // ── Bonsai ─────────────────────────────────────────────────────────────────

  Future<void> _downloadAndLoadBonsai(
    HomeBonsaiDownloadAndLoad event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_bonsaiFileName');
      final needsModel = !await modelFile.exists();

      if (needsModel) {
        final availableBytes = await StorageChecker.getAvailableBytes();
        const requiredBytes = 1300 * 1024 * 1024; // ~1.16 GB + headroom
        if (availableBytes != null && availableBytes < requiredBytes) {
          emit(state.copyWith(bonsaiStatus: LocalAIStatus.noStorage));
          return;
        }
        emit(state.copyWith(
          bonsaiStatus: LocalAIStatus.downloading,
          bonsaiDownloadProgress: 0.0,
          bonsaiDownloadPhase: 'Downloading Bonsai...',
        ));

        final request = http.Request('GET', Uri.parse(_bonsaiDownloadUrl));
        final client = http.Client();
        final response = await client.send(request);
        if (response.statusCode != 200) {
          print('Bonsai model download failed: ${response.statusCode}');
          client.close();
          emit(state.copyWith(bonsaiStatus: LocalAIStatus.error));
          return;
        }
        final totalBytes = response.contentLength ?? (1500 * 1024 * 1024);
        int receivedBytes = 0;
        final sink = modelFile.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          final progress = receivedBytes / totalBytes;
          if ((progress * 100).floor() >
              (state.bonsaiDownloadProgress * 100).floor()) {
            emit(state.copyWith(
                bonsaiDownloadProgress: progress.clamp(0.0, 0.99)));
          }
        }
        await sink.flush();
        await sink.close();
        client.close();
        emit(state.copyWith(bonsaiDownloadProgress: 1.0));
      }

      // Load model into engine (text-only — Bonsai has no vision projector)
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(
        bonsaiStatus: LocalAIStatus.loading,
        bonsaiDownloadPhase: '',
      ));
      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        emit(state.copyWith(
          bonsaiStatus: LocalAIStatus.ready,
          selectedModel: HomeModel.bonsai,
        ));
        print('Bonsai loaded successfully');
        print('[ModelSwitch] Active model → Bonsai');
      } else {
        emit(state.copyWith(bonsaiStatus: LocalAIStatus.error));
      }
    } catch (e) {
      print('Bonsai download/load error: $e');
      emit(state.copyWith(bonsaiStatus: LocalAIStatus.error));
    }
  }

  Future<void> _loadBonsaiIfDownloaded(
    HomeBonsaiLoadIfDownloaded event,
    Emitter<HomeState> emit,
  ) async {
    if (state.bonsaiStatus == LocalAIStatus.loading ||
        state.bonsaiStatus == LocalAIStatus.downloading) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_bonsaiFileName');
      if (!await modelFile.exists()) return;
      if (_drissyEngine.loadedModelPath == modelFile.path) {
        emit(state.copyWith(
          bonsaiStatus: LocalAIStatus.ready,
          selectedModel: HomeModel.bonsai,
        ));
        print('[ModelSwitch] Active model → Bonsai (already in engine)');
        return;
      }
      emit(state.copyWith(bonsaiStatus: LocalAIStatus.loading));
      // Text-only — Bonsai has no vision projector
      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        emit(state.copyWith(
          bonsaiStatus: LocalAIStatus.ready,
          selectedModel: HomeModel.bonsai,
        ));
        print('[ModelSwitch] Active model → Bonsai');
      } else {
        emit(state.copyWith(bonsaiStatus: LocalAIStatus.error));
      }
    } catch (e) {
      print('Bonsai load error: $e');
      emit(state.copyWith(bonsaiStatus: LocalAIStatus.error));
    }
  }

  Future<void> _deleteBonsaiModel(
    HomeDeleteBonsaiModel event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_bonsaiFileName');
      if (_drissyEngine.loadedModelPath == modelFile.path) {
        _drissyEngine.unload();
      }
      if (await modelFile.exists()) await modelFile.delete();
      emit(state.copyWith(
        bonsaiStatus: LocalAIStatus.idle,
        bonsaiDownloadProgress: 0.0,
        bonsaiDownloadPhase: '',
        selectedModel: state.selectedModel == HomeModel.bonsai
            ? HomeModel.gemini
            : state.selectedModel,
      ));
    } catch (e) {
      debugPrint('Delete Bonsai model error: $e');
    }
  }
}

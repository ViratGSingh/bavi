import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:bavi/models/question_answer.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart' as drift;
import 'package:bavi/app_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bavi/services/answer_memory_service.dart';
import 'package:bavi/services/drissy_engine.dart';
import 'package:bavi/services/storage_checker.dart';
import 'package:bavi/services/profile_stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final http.Client httpClient;
  final DrissyEngine _drissyEngine = DrissyEngine();

  static const String _modelFileName = 'drissy-qwen3.5-2b.Q4_K_M.gguf';
  static const String _modelDownloadUrl =
      'https://huggingface.co/drissea-ai/drissy-qwen3.5-2b-GGUF/resolve/main/drissy-qwen3.5-2b.Q4_K_M.gguf';
  static const String _mmProjFileName = 'drissy-qwen3.5-2b.BF16-mmproj.gguf';
  static const String _mmProjDownloadUrl =
      'https://huggingface.co/drissea-ai/drissy-qwen3.5-2b-GGUF/resolve/main/drissy-qwen3.5-2b.BF16-mmproj.gguf';
  // @override
  // void onTransition(Transition<HomeEvent, HomeState> transition) {
  //   super.onTransition(transition);
  //   print(
  //       "DEBUG: HomeBloc Transition: Event=${transition.event.runtimeType}, NextState.selectedImage=${transition.nextState.selectedImage?.path}, NextState.status=${transition.nextState.imageStatus}");
  // }

  HomeBloc({required this.httpClient}) : super(HomeState()) {
    //Show Me
    on<HomeSwitchType>(_switchType);
    on<HomeSwitchPrivacyType>(_switchPrivacyType);
    on<HomeSwitchActionType>(_switchActionType);
    on<HomeGetAnswer>(_getFastAnswer);
    on<HomeUpdateAnswer>(_updateGeneralGoogleAnswer);

    on<HomeCancelTaskGen>(_cancelTaskSearchQuery);
    on<HomeStartNewThread>(_startNewThread);
    on<HomePortalSearch>(_portalSearch);
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
    on<HomeExtractUrlData>(_extractUrlData);

    on<HomeToggleMapStatus>(_toggleMapStatus);
    on<HomeToggleYoutubeStatus>(_toggleYoutubeStatus);
    on<HomeToggleSpicyStatus>(_toggleSpicyStatus);
    on<HomeToggleInstagramStatus>(_toggleInstagramStatus);
    on<HomeToggleGeneralStatus>(_toggleGeneralStatus);
    on<HomeToggleChatMode>(_toggleChatMode);
    on<HomeCheckLocationAndAnswer>(_checkLocationAndAnswer);
    on<HomeRequestLocationPermission>(_requestLocationPermission);
    on<HomeRetryPendingSearch>(_retryPendingSearch);
    on<HomeWebSearchResultsReceived>(_handleWebSearchResults);
    on<HomeToggleDeepDrissy>(_toggleDeepDrissy);
    on<HomeDeepDrissyGetAnswer>(_getDeepDrissyAnswer);
    on<HomeDeepDrissyWebSearchResultsReceived>(
        _handleDeepDrissyWebSearchResults);
    on<HomeLocalAIDownloadAndLoad>(_downloadAndLoadLocalModel);
    on<HomeLocalAIDownloadProgress>(_handleLocalAIDownloadProgress);
    on<HomeLocalAILoadIfDownloaded>(_loadModelIfDownloaded);
    on<HomeDeleteAllHistory>(_deleteAllHistory);
  }

  Completer<List<ExtractedResultInfo>>? _webSearchCompleter;
  Completer<List<ExtractedResultInfo>>? _deepDrissyWebSearchCompleter;

  void _handleWebSearchResults(
    HomeWebSearchResultsReceived event,
    Emitter<HomeState> emit,
  ) {
    if (_webSearchCompleter != null && !_webSearchCompleter!.isCompleted) {
      _webSearchCompleter!.complete(event.results);
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

  HomeCheckLocationAndAnswer? _pendingCheckLocationEvent;
  HomeGetAnswer? _pendingGetAnswerEvent;

  Future<void> _checkLocationAndAnswer(
    HomeCheckLocationAndAnswer event,
    Emitter<HomeState> emit,
  ) async {
    // Check location permission ONLY if the query needs location context
    bool queryNeedsLocation = _queryNeedsLocation(event.query);

    if (queryNeedsLocation) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _pendingCheckLocationEvent = event;
        emit(state.copyWith(showLocationRationale: true));
        return;
      }
    }

    // If permission not needed or already granted, proceed to answer
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
  ) async {
    if (_pendingCheckLocationEvent != null) {
      if (event.ignoreLocation) {
        // Proceed without location
        add(HomeGetAnswer(
          _pendingCheckLocationEvent!.query,
          _pendingCheckLocationEvent!.streamedText,
          _pendingCheckLocationEvent!.extractedUrlDescription,
          _pendingCheckLocationEvent!.extractedUrlTitle,
          _pendingCheckLocationEvent!.extractedUrl,
          _pendingCheckLocationEvent!.extractedImageUrl,
          _pendingCheckLocationEvent!.imageDescription,
          _pendingCheckLocationEvent!.imageDescriptionNotifier,
          ignoreLocation: true,
        ));
      } else {
        // Retry the check (it will pass now if granted)
        add(_pendingCheckLocationEvent!);
      }
      _pendingCheckLocationEvent = null;
    }

    if (_pendingGetAnswerEvent != null) {
      // Add the pending event (it already has ignoreLocation: true set)
      add(_pendingGetAnswerEvent!);
      _pendingGetAnswerEvent = null;
    }
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("home_view");
  }

  Future<void> _requestLocationPermission(
    HomeRequestLocationPermission event,
    Emitter<HomeState> emit,
  ) async {
    // Trigger the system permission dialog
    // We assume this is called AFTER the user agrees on the Rationale Sheet
    // OR if we just want to try requesting.

    // First, close the rationale sheet in UI by updating state if needed,
    // or the UI handles popping context.
    // Let's reset the flag.
    emit(state.copyWith(showLocationRationale: false));

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      // Open settings?
      await Geolocator.openAppSettings();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // Permission granted, retry pending search
      add(HomeRetryPendingSearch());
    }
  }

  Future<void> _extractUrlData(
    HomeExtractUrlData event,
    Emitter<HomeState> emit,
  ) async {
    // Emit loading status
    emit(state.copyWith(extractUrlStatus: HomeExtractUrlStatus.loading));

    // Reset all values to empty
    event.extractedImageUrl.value = "";
    event.extractedUrl.value = "";
    event.extractedUrlDescription.value = "";
    event.extractedUrlTitle.value = "";

    try {
      // Get the API key from environment
      final String apiKey = dotenv.env["SERP_API_KEY"]!;

      // Make the API request to Serper
      final url = Uri.parse('https://scrape.serper.dev');
      final response = await http.post(
        url,
        headers: {
          'X-API-KEY': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "url": event.inputUrl,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Extract metadata
        final Map<String, dynamic>? metadata = data['metadata'];
        final String? text = data['text'];

        if (metadata != null) {
          // Extract title - try og:title first, then fall back to other options
          final String title =
              metadata['og:title'] ?? metadata['twitter:title'] ?? '';

          // Extract description - try og:description first, then fall back
          final String description = text ??
              metadata['og:description'] ??
              metadata['twitter:description'] ??
              metadata['description'] ??
              '';

          // Extract image URL - try og:image first, then fall back
          final String imageUrl =
              metadata['og:image'] ?? metadata['twitter:image'] ?? '';

          // Extract the actual URL
          final String extractedUrl = metadata['og:url'] ?? event.inputUrl;

          // Update the ValueNotifiers
          event.extractedUrlTitle.value = title;
          event.extractedUrlDescription.value = description;
          event.extractedImageUrl.value = imageUrl;
          event.extractedUrl.value = event.inputUrl;

          print("DEBUG: URL extraction successful");
          print("DEBUG: Title: $title");
          print("DEBUG: Description: $description");
          print("DEBUG: Image URL: $imageUrl");
        }

        emit(state.copyWith(
            extractUrlStatus: HomeExtractUrlStatus.success,
            searchType: HomeSearchType.extractUrl));
      } else {
        print("DEBUG: Serper API request failed: ${response.statusCode}");
        print("DEBUG: Response body: ${response.body}");
        event.extractedUrlTitle.value = "";
        event.extractedUrlDescription.value = "";
        event.extractedImageUrl.value = "";
        event.extractedUrl.value = "";
        emit(state.copyWith(
          extractUrlStatus: HomeExtractUrlStatus.failure,
        ));
      }
    } catch (e) {
      print("DEBUG: Error extracting URL data: $e");
      emit(state.copyWith(extractUrlStatus: HomeExtractUrlStatus.failure));
    }
  }

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
      final base64Image = base64Encode(imageBytes);
      final url = Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");

      final request = http.Request("POST", url);
      request.headers.addAll({
        "Content-Type": "application/json",
        "Authorization": "Bearer ${dotenv.get("AI_GATEWAY_API_KEY")}",
      });

      request.body = jsonEncode({
        "model": "google/gemini-2.5-flash-image",
        "stream": false,
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": "Describe this image in detail."},
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
              }
            ]
          }
        ],
      });

      final response = await httpClient.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final body = await response.stream
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 30));
        final data = jsonDecode(body);
        final description = data['choices']?[0]?['message']?['content'] ??
            "No description available";
        return description;
      } else {
        print("DEBUG: Image description failed: ${response.statusCode}");
        return "Failed to describe image";
      }
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
    // Auto-trigger download+load when localAI is selected and not ready
    if (event.model == HomeModel.localAI &&
        state.localAIStatus != LocalAIStatus.ready &&
        state.localAIStatus != LocalAIStatus.downloading &&
        state.localAIStatus != LocalAIStatus.loading) {
      add(HomeLocalAIDownloadAndLoad());
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
    // Skip if already loaded or currently loading/downloading
    if (state.localAIStatus == LocalAIStatus.ready ||
        state.localAIStatus == LocalAIStatus.loading ||
        state.localAIStatus == LocalAIStatus.downloading) {
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');
      if (!await modelFile.exists()) return;

      emit(state.copyWith(localAIStatus: LocalAIStatus.loading));
      final success = await _drissyEngine.loadModel(modelFile.path);
      if (success) {
        // Load vision projector if available
        final mmProjFile = File('${dir.path}/$_mmProjFileName');
        if (await mmProjFile.exists()) {
          await _drissyEngine.loadVisionProjector(mmProjFile.path);
        }
        emit(state.copyWith(localAIStatus: LocalAIStatus.ready));
        print('Local AI model loaded on home init');
      } else {
        emit(state.copyWith(localAIStatus: LocalAIStatus.error));
      }
    } catch (e) {
      print('Local AI load error: $e');
      emit(state.copyWith(localAIStatus: LocalAIStatus.error));
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
    mixpanel.track("fetch_saved_session");
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
          local: initialresultData.local);

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

  Future<void> _portalSearch(
      HomePortalSearch event, Emitter<HomeState> emit) async {
    String query = event.query;

    final sessionId = Uuid().v4();
    final threadId = sessionId;

    final initialResults = [
      ThreadResultData(
        youtubeVideos: [],
        searchType: state.searchType,
        sourceImageDescription: "",
        sourceImageLink: state.uploadedImageUrl ?? "",
        sourceImage: state.selectedImage != null
            ? await state.selectedImage!.readAsBytes()
            : null,
        isSearchMode: true,
        web: [],
        shortVideos: [],
        videos: [],
        news: [],
        images: [],
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        userQuery: query,
        searchQuery: "",
        answer: "",
        influence: [],
        local: [],
      )
    ];

    ThreadSessionData updThreadData = ThreadSessionData(
        id: threadId,
        isIncognito: state.isIncognito,
        results: initialResults,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now());

    // If there's an existing thread, we need to update it
    if (state.threadData.id != "") {
      final tempUpdatedResults =
          List<ThreadResultData>.from(state.threadData.results)
            ..add(initialResults[0]);

      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }

    // Understand the query
    emit(state.copyWith(
        imageStatus: HomeImageStatus.unselected,
        status: HomePageStatus.loading,
        threadData: updThreadData,
        loadingIndex: updThreadData.results.length - 1));

    // Use SerpAPI Google Light to get first search result
    final String altSerpApiKey = dotenv.get("ALT_SERP_API_KEY");
    final serpUrl = Uri.parse("https://serpapi.com/search").replace(
      queryParameters: {
        'q': event.query,
        'api_key': altSerpApiKey,
        'engine': 'google_light',
        'gl': 'in',
        'location': 'India',
        'safe': 'off',
        'device': 'mobile',
      },
    );

    final webRes = await http.get(serpUrl);

    if (webRes.statusCode == 200) {
      final serpJson = jsonDecode(webRes.body);

      // Get the first organic result URL
      if (serpJson['organic_results'] != null &&
          (serpJson['organic_results'] as List).isNotEmpty) {
        String resultPageUrl = serpJson['organic_results'][0]['link'] as String;

        if (await canLaunchUrl(Uri.parse(resultPageUrl))) {
          print("Navigating to first result: $resultPageUrl");

          emit(
            state.copyWith(
              status: HomePageStatus.idle,
              threadData: ThreadSessionData(
                id: "",
                results: [],
                isIncognito: false,
                createdAt: Timestamp.now(),
                updatedAt: Timestamp.now(),
              ),
            ),
          );
          navService.goTo("/webview", extra: {"url": resultPageUrl});

          return;
        }
      }
    } else {
      print("SerpAPI request failed: ${webRes.statusCode}");
    }
  }

  Future<({String type, String searchQuery})> _altUnderstandQuery(
    List<ThreadResultData> previousResults,
    String query,
    String imageDescription,
    HomeSearchType searchType,
    String extractedUrlDescription,
    String city,
    String region,
    String country,
  ) async {
    try {
      // Check if query is a proper sentence
      // bool isProperSentence = true;
      // if (searchType == HomeSearchType.general) {
      //   isProperSentence = _isProperSentence(query);
      // }

      // if (!isProperSentence) {
      //   // Not a proper sentence - return agent type and skip search query generation
      //   print("DEBUG: Query is not a proper sentence, using agent type");
      //   return (type: "agent", searchQuery: query);
      // }

      // It's a proper sentence - proceed with search query generation
      // Build context from previous results
      String conversationContext = "";
      if (previousResults.isNotEmpty) {
        conversationContext = "Previous conversation:\n";
        for (var result in previousResults.take(3)) {
          // Only take last 3 for context
          conversationContext +=
              "Q: ${result.userQuery}\nA: ${result.answer}\n\n";
        }
      }

      // Step 2: IP lookup and user context
      String formattedUserContext =
          "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

      // Build the prompt
      String prompt = """
You are a search query optimizer. Your task is to generate the best Google search query to find information needed to answer the user's question.

${conversationContext != "" ? conversationContext : ""}
Current user question: $query
${imageDescription != "" ? "Context from uploaded image: $imageDescription\n" : ""}
${extractedUrlDescription != "" ? "Context from extracted URL: $extractedUrlDescription\n" : ""}
$formattedUserContext

Rules:
1. If the user mentions "right now" or "today" or time-sensitive terms, use the current date and time from the context to determine the part of the day (morning, afternoon, evening, night) or specific date in the query.
2. If the user mentions "near me" or "nearby", use the provided location in the context (City, Region, Country) to make the query specific to that location.
3. If the query consists primarily of a URL (e.g., youtube.com/...), use the URL to generate a search query relevant to that video or page.
4. Generate a concise, effective Google search query (max 10 words).
5. Return ONLY the search query, nothing else.
""";

      if (_drissyEngine.isLoaded) {
        final searchQuery = await _drissyEngine.complete(
          systemMessage: "You are a search query optimizer. Generate a concise, effective Google search query. Return ONLY the search query, nothing else.",
          userMessage: prompt,
          maxTokens: 50,
          temperature: 0.1,
        );
        if (searchQuery != null && searchQuery.isNotEmpty) {
          print("DEBUG: Generated search query: $searchQuery");
          return (type: "general", searchQuery: searchQuery);
        }
      }
      print("DEBUG: Search query generation skipped: local AI not loaded");
      return (type: "general", searchQuery: query);
    } catch (e) {
      print("DEBUG: Search query generation error: $e");
      return (type: "general", searchQuery: query);
    }
  }

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

  /// Check location permission and handle rationale if needed.
  /// Returns true if the search should proceed, false if blocked by location permission.
  Future<bool> _checkLocationPermissionForQuery(
      HomeGetAnswer event, Emitter<HomeState> emit) async {
    bool queryNeedsLocation = _queryNeedsLocation(event.query);
    print(
        "DEBUG: Query='${event.query}', needsLocation=$queryNeedsLocation, ignoreLocation=${event.ignoreLocation}");
    if (!event.ignoreLocation && queryNeedsLocation) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      print("DEBUG: serviceEnabled=$serviceEnabled, permission=$permission");
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("DEBUG: Location not available, showing rationale sheet");
        _pendingGetAnswerEvent = HomeGetAnswer(
          event.query,
          event.streamedText,
          event.extractedUrlDescription,
          event.extractedUrlTitle,
          event.extractedUrl,
          event.extractedImageUrl,
          event.imageDescription,
          event.imageDescriptionNotifier,
          ignoreLocation: true,
        );
        emit(state.copyWith(showLocationRationale: true));
        return false; // Stop here, do not proceed with search
      } else {
        print("DEBUG: Location already granted, proceeding with search");
      }
    }
    return true; // Proceed with search
  }

  /// Function to search using SerpAPI Google results for Instagram Reels
  Future<void> _watchGeneralGoogleAnswer(
      HomeGetAnswer event, Emitter<HomeState> emit) async {
    print(
        "=== DEBUG _watchGeneralGoogleAnswer ENTRY: query='${event.query}' ===");
    // Check location permission ONLY if the query needs location context
    final shouldProceed = await _checkLocationPermissionForQuery(event, emit);
    if (!shouldProceed) {
      return; // Stop here, location rationale is being shown
    }

    String query = event.query;
    String searchQuery = event.query;
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
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    String? answer;
    List<LocalResultData> mapResults = [];

    //Image Response — use on-device Drissy vision
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
    }

    //Extract url response
    else if (resultData.extractedUrlData?.link != "" &&
        resultData.extractedUrlData?.link != null) {
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

      //Get user details using ipapi
      final userData = await _getUserLocation();
      event.imageDescriptionNotifier.value = "";
      answer = await vercelGenerateReply(
        query,
        [],
        event.streamedText,
        emit,
        event.imageDescription,
        state.threadData.results
            .getRange(0, state.threadData.results.length - 1)
            .toList(),
        resultData.extractedUrlData,
        userData.city,
        userData.region,
        userData.country,
      );
    } else {
      event.imageDescriptionNotifier.value = "";

      // Check if chat mode is active - skip search and generate reply directly
      if (state.isChatModeActive) {
        //Understand the query
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

        // If there's an image, use on-device Drissy vision
        if (imagePath != null) {
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
              answer = finalContent.isNotEmpty ? finalContent : null;
            } catch (e) {
              print('Drissy vision error: $e');
              answer =
                  "Sorry, I couldn't analyze this image. Please try again.";
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
          //Get user details
          final userData = await _getUserLocation();
          // Search memory for relevant content to enhance the chat reply
          List<({String text, String sourceQuery, double score})>
              chatMemoryChunks = [];
          try {
            chatMemoryChunks =
                await AnswerMemoryService.instance.searchRelevantMemory(
              query,
              maxResults: 10,
              minScore: 0.3,
            );
          } catch (e) {
            print("Error searching memory for chat: $e");
          }

          // Format memory chunks as context
          final List<Map<String, String>> memoryContext =
              chatMemoryChunks.map((chunk) {
            return {
              "title": "[Memory] Previously learned from: ${chunk.sourceQuery}",
              "url": "memory://local",
              "snippet": chunk.text,
            };
          }).toList();

          if (memoryContext.isNotEmpty) {
            print(
                "📚 Adding ${memoryContext.length} memory chunks to chat context");
          }

          // No image, use local AI for chat reply
          if (_drissyEngine.isLoaded) {
            final chatSystemPrompt = """You are a personal memory assistant that helps users recall and explore information from their saved memories.

Rules:
- Always respond in Markdown format.
- **ONLY use information from the provided memory context** - do NOT make up or hallucinate any information.
- If the memory results don't contain relevant information, honestly say "I don't have that in your memories" rather than guessing.
- Be conversational and warm.
- **Bold key insights** and important information.
- Keep responses concise and optimized for mobile readability.

The user is located in ${userData.city}, ${userData.region}, ${userData.country}. The current date and time is ${DateTime.now()}.
${memoryContext.isNotEmpty ? "\nMemory context:\n${memoryContext.map((m) => '${m["title"]}: ${m["snippet"]}').join('\n')}" : ""}
${event.imageDescription.isNotEmpty ? "\nImage description: ${event.imageDescription}" : ""}
${resultData.extractedUrlData != null && resultData.extractedUrlData!.snippet.isNotEmpty ? "\nExtracted URL: ${resultData.extractedUrlData!.snippet}" : ""}""";

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
              )) {
                finalContent += token;
                event.streamedText.value = finalContent;
                emit(state.copyWith(replyStatus: HomeReplyStatus.success));
              }
              answer = finalContent.isNotEmpty ? finalContent : null;
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
      } else {
        //Understand the query
        emit(
          state.copyWith(
            status: HomePageStatus.getSearchResults,
            imageStatus: HomeImageStatus.unselected,
            threadData: updThreadData,
            loadingIndex: updThreadData.results.length - 1,
            selectedImage: null,
          ),
        );

        //Get user details
        final userData = await _getUserLocation();
        print(userData);

        try {
          if (state.searchType == HomeSearchType.nsfw) {
            searchQuery = await _nsfwUnderstandQuery(
              state.threadData.results
                  .where((r) => !r.isSearchMode)
                  .toList(), // Only pass non-search mode results for context
              query,
              event.imageDescription,
            );
          } else {
            // Generate optimized search query using AI
            final result = await _altUnderstandQuery(
              state.threadData.results
                  .where((r) => !r.isSearchMode)
                  .toList(), // Only pass non-search mode results for context
              query,
              event.imageDescription,
              state.searchType,
              event.extractedUrlDescription.value,
              userData.city,
              userData.region,
              userData.country,
            );
            print("");
            print(userData.city);
            print(userData.region);
            print(userData.country);
            print(result);
            print("");
            searchQuery = result.searchQuery;
          }
        } catch (e) {
          print("Error in understanding query: $e");
        }

        if (_cancelTaskGen) {
          //emit(state.copyWith(status: HomePageStatus.success));
          return;
        }

        // Search memory for relevant content to enhance the answer
        List<({String text, String sourceQuery, double score})> memoryChunks =
            [];
        try {
          memoryChunks =
              await AnswerMemoryService.instance.searchRelevantMemory(
            query,
            maxResults: 10,
            minScore: 0.3,
          );
        } catch (e) {
          print("Error searching memory: $e");
        }

        // Continue with search flow for non-chat action types
        //Get Search Results

        try {
          // Unified search API call

          final drisseaApiHost = dotenv.get('API_HOST');
          final apiSecret = dotenv.get('API_SECRET');
          final unifiedSearchUrl =
              Uri.parse("https://$drisseaApiHost/api/search");

          final searchResponse = await http.post(
            unifiedSearchUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiSecret',
            },
            body: jsonEncode({
              'query': searchQuery,
              'country': userData.countryCode.toLowerCase(),
            }),
          );
          print(searchResponse.body);

          if (searchResponse.statusCode == 200) {
            final Map<String, dynamic> respJson =
                jsonDecode(searchResponse.body);
            print(respJson);
            if (respJson["success"] == true) {
              // Parse web results -> ExtractedResultInfo
              if (state.generalStatus == HomeGeneralStatus.enabled) {
                final webResults = respJson['web'] is List
                    ? List<dynamic>.from(respJson['web'])
                    : [];
                extractedResults.addAll(
                  webResults.map(
                    (e) => ExtractedResultInfo(
                      url: e['url'] ?? '',
                      title: e['title'] ?? '',
                      excerpts: e['excerpts'] ?? '',
                      thumbnailUrl: '',
                    ),
                  ),
                );
                print("Web results found: ${webResults.length}");
              }

              // Parse YouTube results -> YoutubeVideoData
              if (state.youtubeStatus == HomeYoutubeStatus.enabled) {
                final youtubeResults = respJson['youtube'] is List
                    ? List<dynamic>.from(respJson['youtube'])
                    : [];
                youtubeVideos = youtubeResults
                    .map((e) =>
                        YoutubeVideoData.fromJson(e as Map<String, dynamic>))
                    .toList();
                print("YouTube results found: ${youtubeResults.length}");
              }

              // Parse map results -> LocalResultData
              if (state.mapStatus == HomeMapStatus.enabled) {
                final mapResultsJson = respJson['map'] is List
                    ? List<dynamic>.from(respJson['map'])
                    : [];
                mapResults = mapResultsJson
                    .map((e) =>
                        LocalResultData.fromJson(e as Map<String, dynamic>))
                    .toList();
                print("Map results found: ${mapResults.length}");
              }
            }
          } else {
            print("⚠️ Unified search API failed: ${searchResponse.statusCode}");
          }

          emit(state.copyWith(
              status: HomePageStatus.success,
              searchType: state.searchType == HomeSearchType.extractUrl
                  ? HomeSearchType.general
                  : state.searchType,
              replyStatus: HomeReplyStatus.loading));
        } catch (e) {
          print("Error in parallel search: $e");
        }
        if (_cancelTaskGen) {
          //emit(state.copyWith(status: HomePageStatus.idle));
          return;
        }

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

        answer = await vercelNewGenerateReply(
          query,
          formattedResults,
          event.streamedText,
          emit,
          event.imageDescription,
          state.threadData.results
              .getRange(0, state.threadData.results.length - 1)
              .toList(),
          resultData.extractedUrlData,
          userData.city,
          userData.region,
          userData.country,
        );
      } // Close the else block for non-chat action types
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
      shortVideos: resultData.shortVideos,
      videos: resultData.videos,
      news: resultData.news,
      images: resultData.images,
      createdAt: resultData.createdAt,
      updatedAt: resultData.updatedAt,
      userQuery: query,
      searchQuery: searchQuery,
      answer: answer ?? "",
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
    if (_cancelTaskGen) {
      return;
    }
    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        threadData: updThreadData,
        uploadedImageUrl: "",
        selectedImage: null,
        imageStatus: HomeImageStatus.unselected));
    event.imageDescriptionNotifier.value = "";

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

  Future<Map<String, dynamic>> _checkIntent(String query) async {
    // 1. Define stop words (common conversational fillers, question words, etc.)
    // These are words that generally DO NOT indicate a specific search entity on their own in this context.
    final stopWords = {
      "a",
      "an",
      "the",
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
      "out",
      "of",
      "for",
      "to",
      "in",
      "on",
      "at"
    };

    // 2. Normalize and tokenize the query
    // Remove punctuation and convert to lowercase for checking
    String cleanQuery = query.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    List<String> tokens =
        cleanQuery.split(' ').where((t) => t.isNotEmpty).toList();

    // 3. Filter tokens
    // We are looking for "keywords" - anything that is NOT a stop word.
    // This includes nouns, names, specific verbs, etc.
    List<String> keywords = tokens.where((token) {
      return !stopWords.contains(token);
    }).toList();

    // 4. Determine Intent
    if (keywords.isNotEmpty) {
      // Found potential search terms (nouns, names, etc.)
      return {
        'intent': 'search',
        'keywords': keywords,
        'finalQuery':
            keywords.join(' ') // Optional: constructing a keyword-only query
      };
    } else {
      // Only stop words found (e.g. "how are you", "tell me about it")
      return {'intent': 'chat', 'keywords': [], 'finalQuery': query};
    }
  }

  /// Check if a query is a simple factual question suitable for quick search
  /// Use AI Gateway to condense enriched source snippets for on-device context.
  /// Returns a single condensed string of the most relevant information.
  Future<List<String>> _truncateSourcesViaGateway({
    required String query,
    required List<Map<String, String>> sources,
    int maxSources = 6,
    int targetCharsPerSource = 400,
  }) async {
    // Take top sources
    final topSources = sources.take(maxSources).toList();
    if (topSources.isEmpty) return [];

    // Build a compact representation of sources for the LLM
    final sourcesBlock = topSources.asMap().entries.map((e) {
      final s = e.value;
      return 'Source ${e.key + 1} [${s["title"]}]:\n${s["snippet"] ?? ""}';
    }).join('\n\n');

    try {
      final url =
          Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");
      final request = http.Request("POST", url);
      request.headers.addAll({
        "Content-Type": "application/json",
        "Authorization": "Bearer ${dotenv.get("AI_GATEWAY_API_KEY")}",
      });

      request.body = jsonEncode({
        "model": "google/gemini-2.5-flash",
        "stream": false,
        "messages": [
          {
            "role": "system",
            "content":
                "You are a source condensing assistant. Given a user query and web sources, extract ONLY the most relevant facts from each source. Output exactly one condensed snippet per source, separated by |||. Each snippet must be under $targetCharsPerSource characters. Keep key details: names, numbers, ratings, addresses, dates. Remove filler, ads, navigation text. If a source is irrelevant to the query, output SKIP for that source."
          },
          {
            "role": "user",
            "content": "Query: $query\n\n$sourcesBlock"
          }
        ],
      });

      final response = await httpClient.send(request);

      if (response.statusCode == 200) {
        final body = await response.stream.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final content =
            (data['choices']?[0]?['message']?['content'] ?? '').toString();

        final condensed = content
            .split('|||')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != 'SKIP')
            .toList();

        if (condensed.isNotEmpty) {
          // Pair back with titles
          final result = <String>[];
          for (int i = 0; i < condensed.length && i < topSources.length; i++) {
            if (condensed[i] != 'SKIP') {
              result.add('${topSources[i]["title"]}: ${condensed[i]}');
            }
          }
          print("AI Gateway condensed ${topSources.length} sources → ${result.length} snippets");
          return result;
        }
      } else {
        print("AI Gateway truncation failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Error truncating sources via AI Gateway: $e");
    }

    // Fallback: simple char truncation
    return topSources.map((s) {
      final snippet = (s["snippet"] ?? "").length > targetCharsPerSource
          ? s["snippet"]!.substring(0, targetCharsPerSource)
          : s["snippet"] ?? "";
      return '${s["title"]}: $snippet';
    }).toList();
  }

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
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    String? answer;
    List<LocalResultData> mapResults = [];
    List<ShortVideoResultData> instagramShortVideos = [];

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
${!hasVision && event.imageDescription.isNotEmpty ? "\nImage description: ${event.imageDescription}" : ""}""";

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
          _webSearchCompleter = Completer<List<ExtractedResultInfo>>();
          emit(state.copyWith(webSearchQuery: searchQuery, isQuickSearch: _isSimpleFactualQuery(query)));

          // Wait for the UI to open WebView and return results
          final webResults = await _webSearchCompleter!.future;
          _webSearchCompleter = null;

          int totalChars = 0;
          const int charLimit = 120000;
          for (final result in webResults) {
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
        final topSources = formattedResults.take(6).toList();
        emit(state.copyWith(condensingSources: topSources));

        // Use AI Gateway to intelligently condense enriched sources for on-device context
        final trimmedSources = await _truncateSourcesViaGateway(
          query: query,
          sources: formattedResults,
          maxSources: 6,
          targetCharsPerSource: 400,
        );

        // Clear condensing sources after condensing is done
        emit(state.copyWith(condensingSources: const []));

        try {
          String finalContent = "";
          await for (final token in _drissyEngine.answer(
            query: query,
            sources: trimmedSources,
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
    if (_cancelTaskGen) {
      return;
    }
    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        threadData: updThreadData,
        uploadedImageUrl: "",
        selectedImage: null,
        imageStatus: HomeImageStatus.unselected));
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
  /// Uses AI Gateway and includes last 3 messages for context.
  Future<List<String>> _generateMultipleSearchQueries(String query) async {
    try {
      final url =
          Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");

      // Build context from last 3 messages
      final previousResults = state.threadData.results;
      final recentResults = previousResults.length > 3
          ? previousResults.sublist(previousResults.length - 3)
          : previousResults;
      final contextLines = recentResults
          .map((r) => r.userQuery)
          .where((q) => q.isNotEmpty)
          .toList();

      String contextBlock = "";
      if (contextLines.isNotEmpty) {
        contextBlock =
            "Previous messages for context:\n${contextLines.join('\n')}\n\n";
      }

      final request = http.Request("POST", url);
      request.headers.addAll({
        "Content-Type": "application/json",
        "Authorization": "Bearer ${dotenv.get("AI_GATEWAY_API_KEY")}",
      });

      request.body = jsonEncode({
        "model": "google/gemini-2.5-flash-lite",
        "stream": false,
        "messages": [
          {
            "role": "system",
            "content":
                "You generate Google search queries. Given a user question and optional conversation context, output 3 to 5 comma-separated search queries. Output ONLY the queries separated by commas. No explanations, no URLs, no numbering, no markdown."
          },
          {
            "role": "user",
            "content": "${contextBlock}Current question: $query"
          }
        ],
      });

      final response = await httpClient.send(request).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final body = await response.stream
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 10));
        final data = jsonDecode(body);
        final content =
            data['choices']?[0]?['message']?['content'] as String? ?? "";

        if (content.isNotEmpty) {
          List<String> result = content
              .split(',')
              .map((q) => q.replaceAll(RegExp(r'https?://\S+'), '').trim())
              .where((q) => q.isNotEmpty && q.length > 3)
              .take(5)
              .toList();

          if (result.isNotEmpty) {
            print(
                "Deep Drissy: Generated ${result.length} search queries: $result");
            return result;
          }
        }
      } else {
        print(
            "Error generating search queries: status ${response.statusCode}");
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
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
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
      if (state.threadData.results.isNotEmpty) {
        searchQuery = await _rewriteQueryWithContext(
          query,
          state.threadData.results,
        );
        print("Deep Drissy - Original query: $query");
        print("Deep Drissy - Rewritten query: $searchQuery");
      }

      emit(state.copyWith(status: HomePageStatus.getSearchResults));

      try {
        final searchStartTime = DateTime.now();

        // Generate multiple search queries
        final searchQueries =
            await _generateMultipleSearchQueries(searchQuery);

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

      // Format sources
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

      print("Deep Drissy: Starting answer generation via AI Gateway");

      // Use AI Gateway (vercelNewGenerateReply) for Deep Browse answers
      answer = await vercelNewGenerateReply(
        query,
        formattedResults,
        event.streamedText,
        emit,
        resultData.sourceImageDescription,
        state.threadData.results,
        resultData.extractedUrlData,
        city,
        region,
        country,
      );
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
      answer: answer ?? "",
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
    if (_cancelTaskGen) return;

    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        threadData: updThreadData,
        uploadedImageUrl: "",
        selectedImage: null,
        imageStatus: HomeImageStatus.unselected));
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

  /// Deep Drissy answer generation with higher token limit and enhanced prompt
  Future<String?> vercelDeepDrissyGenerateReply(
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
      if (totalTokens + tokens > 200000) {
        break;
      }
      formattedSources.add({
        "title": result["title"]!,
        "url": result["url"]!,
        "snippet": result["snippet"]!,
      });
      totalTokens += tokens;
    }

    String formattedUserContext = city == "" && region == "" && country == ""
        ? "The current date and time is ${DateTime.now()}."
        : "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

    bool isChat = formattedSources.isEmpty;
    final systemPrompt = """
You are Drissea, a private, conversational, and insightful answer engine operating in Deep Research mode. You do not save user data and keep as much processing as possible strictly on-device.

${isChat ? "" : """
You are in DEEP RESEARCH mode. You have been provided with results from multiple diverse search queries to comprehensively address the user's question.

Rules:
- Always answer in Markdown.
- Write in-depth, nuanced paragraphs — NOT a list of headlines or bullet-point summaries. Each section should have substantial prose that explains context, reasoning, and details. Think long-form article, not listicle.
- Use headings sparingly to organize major sections. Under each heading, write full paragraphs with flowing narrative. Bullet points should only be used for truly list-like content (e.g., ingredients, specs, steps), not as a substitute for explanation.
- Always **bold key insights** and highlight notable places, dishes, or experiences.
- For any place, food item, or experience that was featured in a source, wrap the main word or phrase in this format: `[text to show](<link>)` (e.g., Try the **[Dum Pukht Biryani](https://example.com/food)**).
- **Be Conversational**: Write naturally, like a knowledgeable friend. Avoid robotic phrases like "based on search results" or "these sources say."
- Only use the sources that directly answer the query.
- If no strong or direct matches are found, gracefully say: _"There isn't a perfect match for that, but here are a few options that might still interest you."_
- Do not repeat the question or use generic filler lines.
- Go deep: explain the *why* behind things, provide historical context, compare different perspectives, discuss tradeoffs, and surface non-obvious insights. Don't just state facts — analyze them.
- Synthesize information across multiple sources into a cohesive narrative rather than summarizing each source separately.
- If the query consists primarily of a URL (e.g., youtube.com/...), use the provided content from the extracted URL to summarize what the page or video is about.

"""}
Use the following user context for additional personalization (if relevant):
$formattedUserContext

Don't reveal any personal information you have in your context unless asked about it.
""";

    String modelName;
    switch (state.selectedModel) {
      case HomeModel.deepseek:
        modelName = "deepseek/deepseek-v3.2";
        break;
      case HomeModel.gemini:
        modelName = "google/gemini-2.5-flash";
        break;
      case HomeModel.claude:
        modelName = "anthropic/claude-haiku-4.5";
        break;
      case HomeModel.openAI:
        modelName = "openai/gpt-5-nano";
        break;
      case HomeModel.flashThink:
        modelName = "google/gemini-2.0-flash-thinking-exp";
        break;
      case HomeModel.localAI:
        modelName = "deepseek/deepseek-v3.2";
        break;
    }

    final url =
        Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");

    final request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer ${dotenv.get("AI_GATEWAY_API_KEY")}",
    });

    request.body = jsonEncode({
      "model": modelName,
      "stream": true,
      "max_tokens": 32768,
      "messages": [
        {"role": "system", "content": systemPrompt},
        ...previousResults.expand((item) => [
              {
                "role": "user",
                "content": item.sourceImageDescription != ""
                    ? "${item.userQuery} | Here's the image description:${item.sourceImageDescription}"
                    : item.userQuery
              },
              {
                "role": "assistant",
                "content": item.answer,
              },
            ]),
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "$query ${imageDescription == "" ? "" : "| Here's the image description: $imageDescription"}  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}"
                      .trim()
            },
          ]
        },
        isChat == false
            ? {
                "role": "user",
                "content":
                    jsonEncode(city == "" && region == "" && country == ""
                        ? {
                            "results": formattedSources,
                            "date": DateTime.now().toIso8601String(),
                            "day": DateTime.now().day,
                            "month": DateTime.now().month,
                            "year": DateTime.now().year,
                            "hour": DateTime.now().hour,
                            "minute": DateTime.now().minute,
                            "second": DateTime.now().second,
                            "timezone": DateTime.now().timeZoneName,
                          }
                        : {
                            "results": formattedSources,
                            "city": city,
                            "region": region,
                            "country": country,
                            "date": DateTime.now().toIso8601String(),
                            "day": DateTime.now().day,
                            "month": DateTime.now().month,
                            "year": DateTime.now().year,
                            "hour": DateTime.now().hour,
                            "minute": DateTime.now().minute,
                            "second": DateTime.now().second,
                            "timezone": DateTime.now().timeZoneName,
                          })
              }
            : {
                "role": "user",
                "content":
                    jsonEncode(city == "" && region == "" && country == ""
                        ? {
                            "date": DateTime.now().toIso8601String(),
                            "day": DateTime.now().day,
                            "month": DateTime.now().month,
                            "year": DateTime.now().year,
                            "hour": DateTime.now().hour,
                            "minute": DateTime.now().minute,
                            "second": DateTime.now().second,
                            "timezone": DateTime.now().timeZoneName,
                          }
                        : {
                            "city": city,
                            "region": region,
                            "country": country,
                            "date": DateTime.now().toIso8601String(),
                            "day": DateTime.now().day,
                            "month": DateTime.now().month,
                            "year": DateTime.now().year,
                            "hour": DateTime.now().hour,
                            "minute": DateTime.now().minute,
                            "second": DateTime.now().second,
                            "timezone": DateTime.now().timeZoneName,
                          })
              }
      ],
    });

    print("Deep Drissy: Starting streaming request ($modelName)...");

    try {
      final streamedResponse = await httpClient.send(request);
      print(
          "Deep Drissy Response Status: ${streamedResponse.statusCode}");

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream
            .transform(utf8.decoder)
            .join();
        print("Deep Drissy Error: $body");
        return null;
      }

      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String finalContent = "";
      print(
          "Deep Drissy TTFT:${DateTime.now().difference(generateAnswerStartTime).inMilliseconds}");

      await for (final line in stream) {
        if (!line.startsWith("data:")) continue;
        final chunk = line.substring(5).trim();
        if (chunk == "[DONE]") continue;

        try {
          final decoded = jsonDecode(chunk);
          final delta = decoded["choices"]?[0]?["delta"];
          if (delta == null) continue;

          if (delta["content"] != null) {
            final chunkText = delta["content"];
            streamedText.value += chunkText;
            finalContent += chunkText;
            emit(state.copyWith(
                replyStatus: HomeReplyStatus.success));
          }
        } catch (e) {
          print("Deep Drissy streaming parse error: $e");
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
        print("Deep Drissy: Streaming failed or empty content");
        return null;
      }
    } catch (e) {
      print("Deep Drissy request failed: $e");
      return null;
    }
  }

  /// Function to search using SerpAPI Google results for Instagram Reels
  Future<void> _updateGeneralGoogleAnswer(
      HomeUpdateAnswer event, Emitter<HomeState> emit) async {
    //Remove the previous result at index and all results after it
    int editIndex = state.editIndex;
    final initialResults = List<ThreadResultData>.from(state.threadData.results)
      ..removeRange(editIndex, state.threadData.results.length);

    String query = event.query;

    String searchQuery = event.query;
    String threadId = state.threadData.id;
    String drisseaApiHost = dotenv.get('API_HOST');
    _cancelTaskGen = false;

    // Capture image path and bytes if available
    final imagePath = state.selectedImage?.path;
    Uint8List? imageBytes;
    if (state.selectedImage != null) {
      try {
        imageBytes = await File(state.selectedImage!.path).readAsBytes();
      } catch (e) {
        print("Error reading image bytes: $e");
      }
    } else if (state.threadData.results[editIndex].sourceImage != null) {
      imageBytes = state.threadData.results[editIndex].sourceImage;
    }

    //Get user details using ipapi
    final userData = await _getUserLocation();

    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
      youtubeVideos: state.threadData.results[editIndex].youtubeVideos,
      extractedUrlData: event.extractedUrl.value != ""
          ? ExtractedUrlResultData(
              title: event.extractedUrlTitle.value,
              link: event.extractedUrl.value,
              thumbnail: event.extractedImageUrl.value,
              snippet: event.extractedUrlDescription.value,
            )
          : state.threadData.results[editIndex].extractedUrlData,
      searchType: state.threadData.results[editIndex].searchType,
      sourceImageDescription: event.imageDescription,
      sourceImageLink: state.uploadedImageUrl ?? "",
      sourceImage: imageBytes,
      isSearchMode: false,
      web: [],
      shortVideos: [],
      videos: [],
      news: [],
      images: [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      userQuery: query,
      searchQuery: searchQuery,
      answer: state.threadData.results[editIndex].answer,
      influence: [],
      local: [],
    );
    List<ExtractedResultInfo> extractedResults = [];
    List<YoutubeVideoData> youtubeVideos = [];
    String? answer;

    List<LocalResultData> mapResults = [];
    ThreadSessionData updThreadData = state.threadData;

    event.extractedUrlTitle.value = "";
    event.extractedUrlDescription.value = "";
    event.extractedImageUrl.value = "";
    event.extractedUrl.value = "";
    //Check if previous query or answer is present
    Map<String, dynamic> genSearchReqBody = {};

    if (initialResults.length > 1) {
      if (initialResults[initialResults.length - 2].isSearchMode == false) {
        genSearchReqBody = {
          "task": query,
          "previousQuestion":
              initialResults[initialResults.length - 2].userQuery,
          "previousAnswer": initialResults[initialResults.length - 2].answer,
        };
      }
    } else {
      genSearchReqBody = {"task": query};
    }

    // Set Initial Result Data
    List<ThreadResultData> tempUpdatedResults = initialResults..add(resultData);
    print("");
    print("Temp Results Length: ${tempUpdatedResults.length}");
    print("Initial Results Length: ${initialResults.length}");
    print("");

    updThreadData = ThreadSessionData(
        id: state.threadData.id,
        isIncognito: state.isIncognito,
        results: tempUpdatedResults,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now());

    //Image Response — use on-device Drissy vision
    if (imagePath != null) {
      emit(state.copyWith(
          status: HomePageStatus.success,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
          searchType: state.searchType == HomeSearchType.extractUrl
              ? HomeSearchType.general
              : state.searchType,
          replyStatus: HomeReplyStatus.loading));

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
    }

    //Extract url response
    else if (resultData.extractedUrlData?.link != "" &&
        resultData.extractedUrlData?.link != null) {
      emit(state.copyWith(
          status: HomePageStatus.success,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
          searchType: state.searchType == HomeSearchType.extractUrl
              ? HomeSearchType.general
              : state.searchType,
          replyStatus: HomeReplyStatus.loading));
      answer = await vercelGenerateReply(
        query,
        [],
        event.streamedText,
        emit,
        event.imageDescription,
        state.threadData.results
            .getRange(0, state.threadData.results.length - 1)
            .toList(),
        resultData.extractedUrlData,
        userData.city,
        userData.region,
        userData.country,
      );
    } else {
      //Understand the query
      emit(state.copyWith(
          status: HomePageStatus.generateQuery,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
          editStatus: HomeEditStatus.loading));
      try {
        final body = jsonEncode(genSearchReqBody);
        final resp = await http.post(
          Uri.parse("https://$drisseaApiHost/api/generate/query"),
          headers: {
            'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
            'Content-Type': 'application/json',
          },
          body: body,
        );
        if (resp.statusCode == 200) {
          final Map<String, dynamic> respJson = jsonDecode(resp.body);
          if (respJson["success"] == true && respJson.containsKey("query")) {
            searchQuery = respJson["query"];
          }
        }
      } catch (e) {
        print("Error in understanding query: $e");
      }

      if (_cancelTaskGen) {
        //emit(state.copyWith(status: HomePageStatus.success));
        return;
      }

      //Get Search Results
      emit(
        state.copyWith(status: HomePageStatus.getSearchResults),
      );
      List<LocalResultData> mapResults = [];
      try {
        final algoliaAppId = dotenv.get('ALGOLIA_APP_ID');
        final algoliaApiKey = dotenv.get('ALGOLIA_API_KEY');
        final algoliaIndexName = 'ig_reels';
        final algoliaUrl = Uri.parse(
            "https://${algoliaAppId}-dsn.algolia.net/1/indexes/${algoliaIndexName}/query");

        final drisseaGeneralUrl = Uri.parse(
            "https://$drisseaApiHost/dev/api/search/source/general?query=${Uri.encodeComponent(searchQuery)}");

        final youtubeExcerptUrl =
            Uri.parse("https://$drisseaApiHost/api/search/youtube");

        Future<http.Response> algoliaFuture;
        if (state.instagramStatus == HomeInstagramStatus.enabled) {
          algoliaFuture = http.post(
            algoliaUrl,
            headers: {
              'X-Algolia-Application-Id': algoliaAppId,
              'X-Algolia-API-Key': algoliaApiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'params': 'query=${Uri.encodeComponent(query)}'}),
          );
        } else {
          algoliaFuture = Future.value(http.Response("{}", 400));
        }

        Future<http.Response> drisseaFuture;
        if (state.generalStatus == HomeGeneralStatus.enabled) {
          drisseaFuture = http.get(
            drisseaGeneralUrl,
            headers: {
              'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
              'Content-Type': 'application/json',
            },
          );
        } else {
          drisseaFuture = Future.value(http.Response("{}", 400));
        }

        Future<http.Response> youtubeFuture;
        if (state.youtubeStatus == HomeYoutubeStatus.enabled) {
          youtubeFuture = http.post(
            youtubeExcerptUrl,
            headers: {
              'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'query': searchQuery,
              "userQuery": query,
              "country": userData.countryCode
            }),
          );
        } else {
          youtubeFuture = Future.value(http.Response("{}", 400));
        }

        Future<List<LocalResultData>> mapFuture;
        if (state.mapStatus == HomeMapStatus.enabled) {
          mapFuture = _getMapSearchData(searchQuery);
        } else {
          mapFuture = Future.value([]);
        }

        final futures = await Future.wait([
          algoliaFuture,
          drisseaFuture,
          youtubeFuture,
          mapFuture,
        ]);

        final algoliaResponse = futures[0] as http.Response;
        final drisseaResponse = futures[1] as http.Response;
        final youtubeExcerptResponse = futures[2] as http.Response;
        mapResults = futures[3] as List<LocalResultData>;

        // Parse Algolia Reels Results (reels → ExtractedResultInfo)
        if (algoliaResponse.statusCode == 200) {
          final Map<String, dynamic> algoliaJson =
              jsonDecode(algoliaResponse.body);
          final List hits = algoliaJson['hits'] ?? [];

          if (hits.isNotEmpty) {
            print("Algolia hits found: ${hits.length}");
            hits.asMap().forEach((i, entry) {
              final hit = entry as Map<String, dynamic>;
              extractedResults.add(
                ExtractedResultInfo(
                  url: hit['permalink'] ?? '',
                  title: '${hit['full_name'] ?? ''}',
                  excerpts:
                      "Creator Username: ${hit['username']}| Creator Full Name: ${hit['full_name'] ?? ''}| Caption: ${hit['caption'] ?? ''} | Likes: ${hit['like_count'] ?? 0}| Comments: ${hit['comment_count'] ?? 0}| Views: ${hit['view_count'] ?? 0}| Posted on: ${hit['taken_at'] ?? ''}| Transcription: ${hit['transcription'] ?? ''}| Video Overview: ${hit['framewatch'] ?? ''}"
                          .trim(),
                  thumbnailUrl:
                      hit['thumbnail_url'] ?? hit['profile_pic_url'] ?? '',
                ),
              );
            });
          }
        } else {
          print("⚠️ Algolia search failed: ${algoliaResponse.statusCode}");
        }

        // Parse Drissea general results
        if (drisseaResponse.statusCode == 200) {
          final Map<String, dynamic> respJson =
              jsonDecode(drisseaResponse.body);

          if (respJson["success"] == true) {
            final rawResults = respJson['results'] is List
                ? List<dynamic>.from(respJson['results'])
                : [];
            extractedResults.addAll(
              rawResults.map(
                (e) => ExtractedResultInfo.fromJson(e as Map<String, dynamic>),
              ),
            );
          }
        }

        // Parse Youtube Data
        if (youtubeExcerptResponse.statusCode == 200) {
          final Map<String, dynamic> respJson =
              jsonDecode(youtubeExcerptResponse.body);

          if (respJson["success"] == true) {
            final rawResults = respJson['data'] is List
                ? List<dynamic>.from(respJson['data'])
                : [];
            youtubeVideos = rawResults
                .map(
                    (e) => YoutubeVideoData.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }

        emit(state.copyWith(
            status: HomePageStatus.success,
            replyStatus: HomeReplyStatus.loading));
      } catch (e) {
        print("Error in understanding query: $e");
      }
      if (_cancelTaskGen) {
        //emit(state.copyWith(status: HomePageStatus.idle));
        return;
      }

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

      // Add map results to formatted results
      formattedResults.addAll(mapResults.map((mapResult) {
        final locationQuery =
            Uri.encodeComponent("${mapResult.title} ${mapResult.address}");

        return {
          "title": mapResult.title,
          "url":
              "https://www.google.com/maps/search/?api=1&query=$locationQuery&query_place_id=${mapResult.placeId}",
          "snippet":
              "${mapResult.address}${mapResult.rating > 0 ? ' | Rating: ${mapResult.rating} (${mapResult.reviews} reviews)' : ''}${mapResult.phone.isNotEmpty ? ' | Phone: ${mapResult.phone}' : ''}${mapResult.snippet.isNotEmpty ? '\n\nReviews:\n${mapResult.snippet}' : ''}${mapResult.images.isNotEmpty ? '\n\nImages:\n${mapResult.images.join('\n')}' : ''}",
        };
      }));

      answer = await vercelGenerateReply(
        query,
        formattedResults,
        event.streamedText,
        emit,
        event.imageDescription,
        initialResults,
        resultData.extractedUrlData,
        userData.city,
        userData.region,
        userData.country,
      );
    }

    final influenceList = extractedResults.map((searchResult) {
      return InfluenceData(
          url: searchResult.url,
          snippet: searchResult.excerpts,
          title: searchResult.title,
          similarity: 0,
          isVerified: searchResult.isVerified);
    }).toList();

    influenceList.addAll(mapResults.map((searchResult) {
      final locationQuery =
          Uri.encodeComponent("${searchResult.title} ${searchResult.address}");
      return InfluenceData(
          url:
              "https://www.google.com/maps/search/?api=1&query=$locationQuery&query_place_id=${searchResult.placeId}",
          snippet: searchResult.snippet,
          title: searchResult.title,
          similarity: 0);
    }));

    ThreadResultData updResultData = ThreadResultData(
      youtubeVideos: youtubeVideos,
      searchType: resultData.searchType,
      sourceImageDescription: resultData.sourceImageDescription,
      sourceImageLink: resultData.sourceImageLink,
      sourceImage: resultData.sourceImage,
      isSearchMode: resultData.isSearchMode,
      web: resultData.web,
      shortVideos: resultData.shortVideos,
      videos: resultData.videos,
      news: resultData.news,
      images: resultData.images,
      createdAt: resultData.createdAt,
      updatedAt: resultData.updatedAt,
      userQuery: query,
      searchQuery: searchQuery,
      answer: answer ?? "",
      influence: influenceList,
      local: mapResults,
      extractedUrlData: resultData.extractedUrlData,
    );

    final updatedResults = initialResults
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
    if (_cancelTaskGen) {
      return;
    }
    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        threadData: updThreadData,
        editIndex: -1,
        editQuery: "",
        uploadedImageUrl: "",
        editStatus: HomeEditStatus.idle));
    event.imageDescriptionNotifier.value = "";

    await updateSession(updThreadData, state.threadData.id);

    // Refresh history
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

  // Generate a reply from Vercel AI SDK API given a query and search results.
  Future<String?> imageVercelGenerateChatReply(
    String query,
    List<Map<String, String>> results,
    ValueNotifier<String> streamedText,
    Emitter<HomeState> emit,
    Uint8List imageData,
    List<ThreadResultData> previousResults,
    ExtractedUrlResultData? extractedUrlData,
    String city,
    String region,
    String country,
  ) async {
    streamedText.value = "";
    // Step 1: Format sources with token counting, skip if would exceed 125,000 tokens.
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      // Simple token estimate: 1 token ≈ 4 chars
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
    String formattedUserContext =
        "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

    // Step 3: Build systemPrompt
    final systemPrompt = """
You are a friendly and knowledgeable conversational assistant. You engage in natural, helpful dialogue with users, analyzing any images they share and providing thoughtful, personalized responses.

Rules:
- Always respond in Markdown format.
- Be conversational and warm - respond as a helpful friend would.
- When analyzing images, describe what you see clearly and answer any questions about them.
- **Bold key insights** and important information to make responses scannable.
- Use bullet points or numbered lists when presenting multiple items or steps.
- Keep responses concise and optimized for mobile readability.
- Never use phrases like "As an AI" or "I don't have personal opinions" - just be helpful and natural.
- If the user shares an image, acknowledge it and provide relevant observations or answers based on what you see.
- Draw on the conversation history to maintain context and provide coherent follow-up responses.
- If you're unsure about something in an image, say so honestly rather than guessing.
- Be proactive in offering helpful suggestions or related information when appropriate.

User context for personalization:
$formattedUserContext
""";

    // Step 4: Determine Model
    // Force Gemini Flash for image analysis as requested
    String modelName = "google/gemini-2.5-flash-image";

    // Step 5: Make the streaming API request to Vercel AI SDK Gateway
    // Correct Vercel AI Gateway URL found via search.
    final url = Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");

    final request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer ${dotenv.get("AI_GATEWAY_API_KEY")}",
    });

    request.body = jsonEncode({
      "model": modelName,
      "stream": true,
      "messages": [
        {"role": "system", "content": systemPrompt},
        // Add previous queries and answers as context
        ...previousResults.expand((item) => [
              {
                "role": "user",
                "content": item.sourceImageDescription != ""
                    ? "${item.userQuery} | Here's the image description:${item.sourceImageDescription}"
                    : item.userQuery
              },
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

        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "$query  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}"
                      .trim()
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,${base64Encode(imageData)}"
              }
            }
          ]
        },

        {
          "role": "user",
          "content": jsonEncode({
            "results": formattedSources,
            "city": city,
            "region": region,
            "country": country,
          })
        }
      ],
    });
    print("");
    print("Starting streaming request to Vercel AI SDK ($modelName)...");
    print("");

    try {
      final streamedResponse = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 90));
      print("Response Status Code: ${streamedResponse.statusCode}");

      if (streamedResponse.statusCode != 200) {
        final body =
            await streamedResponse.stream.transform(utf8.decoder).join();
        print("❌ Error Body: $body");
        if (body.contains("OIDC")) {
          print(
              "⚠️ Vercel AI Gateway Auth Error: The Gateway attempted OIDC verification because the provided API Key was either missing or invalid.");
          print(
              "   - Ensure 'AI_GATEWAY_API_KEY' in your .env file is a valid Vercel AI Gateway API Key (starts with 'vak_').");
          print(
              "   - Do NOT use provider keys (like 'sk-...') directly with the Vercel AI Gateway URL.");
        }
        return null;
      }

      final stream = streamedResponse.stream.transform(utf8.decoder);

      String finalContent = "";
      String buffer = "";
      print("Listening to stream...");

      await for (final rawChunk in stream) {
        // print("Raw Chunk: $rawChunk"); // DEBUG: Print raw chunk
        try {
          String cleaned = rawChunk.trim();
          final lines = cleaned.split("\n");

          for (final line in lines) {
            String l = line.trim();
            if (!l.startsWith("data:")) continue;

            l = l.substring(5).trim(); // Remove "data:"
            if (l == "[DONE]") continue;

            buffer += l;

            try {
              final decoded = jsonDecode(buffer);
              buffer = ""; // reset after successful parse

              final delta = decoded["choices"]?[0]?["delta"];
              if (delta == null) continue;

              if (delta["content"] != null) {
                emit(state.copyWith(replyStatus: HomeReplyStatus.success));
                final chunkText = delta["content"];
                streamedText.value += chunkText;
                finalContent += chunkText;
              }
            } catch (e) {
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
    } catch (e) {
      print("❌ Vercel AI SDK Request failed: $e");
      return null;
    }
  }

  // Generate a reply from Vercel AI SDK API given a query and search results.
  Future<String?> imageVercelGenerateReply(
    String query,
    List<Map<String, String>> results,
    ValueNotifier<String> streamedText,
    Emitter<HomeState> emit,
    Uint8List imageData,
    List<ThreadResultData> previousResults,
    ExtractedUrlResultData? extractedUrlData,
    String city,
    String region,
    String country,
  ) async {
    streamedText.value = "";
    // Step 1: Format sources with token counting, skip if would exceed 125,000 tokens.
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      // Simple token estimate: 1 token ≈ 4 chars
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
    String formattedUserContext =
        "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

    // Step 3: Build systemPrompt
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
- If the query consists primarily of a URL (e.g., youtube.com/...), use the provided content from the extracted URL to summarize what the page or video is about.

You may use the following user context for additional personalization (if relevant):
$formattedUserContext
""";

    // Step 4: Determine Model
    // Force Gemini Flash for image analysis as requested
    String modelName = "google/gemini-2.5-flash-image";

    // Step 5: Make the streaming API request to Vercel AI SDK Gateway
    // Correct Vercel AI Gateway URL found via search.
    final url = Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");

    final request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer ${dotenv.get("AI_GATEWAY_API_KEY")}",
    });

    request.body = jsonEncode({
      "model": modelName,
      "stream": true,
      "messages": [
        {"role": "system", "content": systemPrompt},
        // Add previous queries and answers as context
        ...previousResults.expand((item) => [
              {
                "role": "user",
                "content": item.sourceImageDescription != ""
                    ? "${item.userQuery} | Here's the image description:${item.sourceImageDescription}"
                    : item.userQuery
              },
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

        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "$query  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}"
                      .trim()
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,${base64Encode(imageData)}"
              }
            }
          ]
        },

        {
          "role": "user",
          "content": jsonEncode({
            "results": formattedSources,
            "city": city,
            "region": region,
            "country": country,
          })
        }
      ],
    });
    print("");
    print("Starting streaming request to Vercel AI SDK ($modelName)...");
    print("");

    try {
      final streamedResponse = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 90));
      print("Response Status Code: ${streamedResponse.statusCode}");

      if (streamedResponse.statusCode != 200) {
        final body =
            await streamedResponse.stream.transform(utf8.decoder).join();
        print("❌ Error Body: $body");
        if (body.contains("OIDC")) {
          print(
              "⚠️ Vercel AI Gateway Auth Error: The Gateway attempted OIDC verification because the provided API Key was either missing or invalid.");
          print(
              "   - Ensure 'AI_GATEWAY_API_KEY' in your .env file is a valid Vercel AI Gateway API Key (starts with 'vak_').");
          print(
              "   - Do NOT use provider keys (like 'sk-...') directly with the Vercel AI Gateway URL.");
        }
        return null;
      }

      final stream = streamedResponse.stream.transform(utf8.decoder);

      String finalContent = "";
      String buffer = "";
      print("Listening to stream...");

      await for (final rawChunk in stream) {
        // print("Raw Chunk: $rawChunk"); // DEBUG: Print raw chunk
        try {
          String cleaned = rawChunk.trim();
          final lines = cleaned.split("\n");

          for (final line in lines) {
            String l = line.trim();
            if (!l.startsWith("data:")) continue;

            l = l.substring(5).trim(); // Remove "data:"
            if (l == "[DONE]") continue;

            buffer += l;

            try {
              final decoded = jsonDecode(buffer);
              buffer = ""; // reset after successful parse

              final delta = decoded["choices"]?[0]?["delta"];
              if (delta == null) continue;

              if (delta["content"] != null) {
                emit(state.copyWith(replyStatus: HomeReplyStatus.success));
                final chunkText = delta["content"];
                streamedText.value += chunkText;
                finalContent += chunkText;
              }
            } catch (e) {
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
    } catch (e) {
      print("❌ Vercel AI SDK Request failed: $e");
      return null;
    }
  }

  Future<String?> vercelGenerateReply(
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
    // Step 1: Format sources with token counting, skip if would exceed 125,000 tokens.
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      // Simple token estimate: 1 token ≈ 4 chars
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
    String formattedUserContext =
        "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

    // Step 3: Build systemPrompt
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
- Keep your language engaging, be as detailed and exhaustive as possible, ensuring no relevant detail from the sources is omitted, while still maintaining clarity and readability.
- If the query consists primarily of a URL (e.g., youtube.com/...), use the provided content from the extracted URL to summarize what the page or video is about.

Use the following user context for additional personalization (if relevant):
$formattedUserContext
""";

    // Step 4: Determine Model
    // Using Sarvam AI sarvam-m model as requested

    // Step 5: Make the streaming API request to Sarvam AI
    final url = Uri.parse("https://api.sarvam.ai/v1/chat/completions");

    final request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer ${dotenv.get("SARVAM_API_KEY")}",
    });

    request.body = jsonEncode({
      "model": "sarvam-m",
      "stream": true,
      "max_tokens": 1000,
      "temperature": 0.5,
      "top_p": 1,
      "messages": [
        {"role": "system", "content": systemPrompt},
        // Add previous queries and answers as context
        ...previousResults.expand((item) => [
              {
                "role": "user",
                "content": item.sourceImageDescription != ""
                    ? "${item.userQuery} | Here's the image description:${item.sourceImageDescription}"
                    : item.userQuery
              },
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

        {
          "role": "user",
          "content": """
$query ${imageDescription == "" ? "" : "| Here's the image description: $imageDescription"}  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}

Context:
${jsonEncode({
                "results": formattedSources,
                "city": city,
                "region": region,
                "country": country,
              })}
"""
              .trim()
        }
      ],
    });
    print("");
    print("Starting streaming request to Sarvam AI (sarvam-m)...");
    print("");

    try {
      final streamedResponse = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 90));
      print("Response Status Code: ${streamedResponse.statusCode}");

      if (streamedResponse.statusCode != 200) {
        final body =
            await streamedResponse.stream.transform(utf8.decoder).join();
        print("❌ Error Body: $body");
        return null;
      }

      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String finalContent = "";
      print("Listening to stream...");
      print(
          "TTFT:${DateTime.now().difference(generateAnswerStartTime).inMilliseconds}");

      await for (final line in stream) {
        if (!line.startsWith("data:")) continue;
        final chunk = line.substring(5).trim();
        if (chunk == "[DONE]") continue;

        try {
          final decoded = jsonDecode(chunk);
          final delta = decoded["choices"]?[0]?["delta"];
          if (delta == null) continue;

          if (delta["content"] != null) {
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
            final chunkText = delta["content"];
            streamedText.value += chunkText;
            finalContent += chunkText;
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
    } catch (e) {
      print("❌ Groq Request failed: $e");
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
        """Rewrite the QUERY by replacing pronouns and references using the CONTEXT. Output ONLY the rewritten query. No explanation.""";

    final userMessage =
        """CONTEXT:\n${contextLines.join('\n')}\n\nQUERY: $query\n\nREWRITTEN QUERY:""";

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
    // Step 1: Format sources with token counting, skip if would exceed 125,000 tokens.
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      // Simple token estimate: 1 token ≈ 4 chars
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
    String formattedUserContext = city == "" && region == "" && country == ""
        ? "The current date and time is ${DateTime.now()}."
        : "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

    // Step 3: Build systemPrompt
    bool isChat = formattedSources.isEmpty;
    final systemPrompt = """
You are Drissea, a private, conversational, and insightful answer engine. You do not save user data and keep as much processing as possible strictly on-device. 

${isChat ? "" : """
You answer user questions using a list of web sources, each with a title, url, and snippet.
Rules:
- Always answer in Markdown.
- Structure your response with clear headings and bullet points as needed.
- Always **bold key insights** and highlight notable places, dishes, or experiences.
- For any place, food item, or experience that was featured in a source, wrap the main word or phrase in this format: `[text to show](<link>)` (e.g., Try the **[Dum Pukht Biryani](https://example.com/food)**).
- **Be Conversational**: Write naturally, like a knowledgeable friend. Avoid robotic phrases like “based on search results” or “these sources say.”
- Only use the sources that directly answer the query.
- If no strong or direct matches are found, gracefully say: _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_
- Do not repeat the question or use generic filler lines.
- Keep your language engaging, be as detailed and exhaustive as possible, ensuring no relevant detail from the sources is omitted, while still maintaining clarity and readability.
- If the query consists primarily of a URL (e.g., youtube.com/...), use the provided content from the extracted URL to summarize what the page or video is about.

"""}
Use the following user context for additional personalization (if relevant):
$formattedUserContext

Don't reveal any personal information you have in your context unless asked about it.
""";

    // Step 4: Determine Model
    String modelName = "deepseek/deepseek-v3.2";
     

    // Step 5: Make the streaming API request to Vercel AI SDK Gateway
    // Correct Vercel AI Gateway URL found via search.
    final url = Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");

    final request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer ${dotenv.get("AI_GATEWAY_API_KEY")}",
    });

    request.body = jsonEncode({
      "model": modelName,
      "stream": true,
      "messages": [
        {"role": "system", "content": systemPrompt},
        // Add previous queries and answers as context
        ...previousResults.expand((item) => [
              {
                "role": "user",
                "content": item.sourceImageDescription != ""
                    ? "${item.userQuery} | Here's the image description:${item.sourceImageDescription}"
                    : item.userQuery
              },
              {
                "role": "assistant",
                "content":
                    // item.isSearchMode
                    //     ? jsonEncode({
                    //         "previous_web_results": item.web
                    //             .map((inf) => {
                    //                   "title": inf.title,
                    //                   "url": inf.link,
                    //                   "snippet": inf.snippet,
                    //                 })
                    //             .toList(),
                    //       })
                    //     :
                    item.answer,
              },
            ]),

        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "$query ${imageDescription == "" ? "" : "| Here's the image description: $imageDescription"}  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}"
                      .trim()
            },
          ]
        },

        isChat == false
            ? {
                "role": "user",
                "content":
                    jsonEncode(city == "" && region == "" && country == ""
                        ? {
                            "results": formattedSources,
                            "date": DateTime.now().toIso8601String(),
                            "day": DateTime.now().day,
                            "month": DateTime.now().month,
                            "year": DateTime.now().year,
                            "hour": DateTime.now().hour,
                            "minute": DateTime.now().minute,
                            "second": DateTime.now().second,
                            "timezone": DateTime.now().timeZoneName,
                          }
                        : {
                            "results": formattedSources,
                            "city": city,
                            "region": region,
                            "country": country,
                            "date": DateTime.now().toIso8601String(),
                            "day": DateTime.now().day,
                            "month": DateTime.now().month,
                            "year": DateTime.now().year,
                            "hour": DateTime.now().hour,
                            "minute": DateTime.now().minute,
                            "second": DateTime.now().second,
                            "timezone": DateTime.now().timeZoneName,
                          })
              }
            : {
                "role": "user",
                "content":
                    jsonEncode(city == "" && region == "" && country == ""
                        ? {
                            "date": DateTime.now().toIso8601String(),
                            "day": DateTime.now().day,
                            "month": DateTime.now().month,
                            "year": DateTime.now().year,
                            "hour": DateTime.now().hour,
                            "minute": DateTime.now().minute,
                            "second": DateTime.now().second,
                            "timezone": DateTime.now().timeZoneName,
                          }
                        : {
                            "city": city,
                            "region": region,
                            "country": country,
                            "date": DateTime.now().toIso8601String(),
                            "day": DateTime.now().day,
                            "month": DateTime.now().month,
                            "year": DateTime.now().year,
                            "hour": DateTime.now().hour,
                            "minute": DateTime.now().minute,
                            "second": DateTime.now().second,
                            "timezone": DateTime.now().timeZoneName,
                          })
              }
      ],
    });
    print("");
    print("Starting streaming request to Vercel AI SDK (\$modelName)...");
    print("");

    try {
      final streamedResponse = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 90));
      print("Response Status Code: ${streamedResponse.statusCode}");

      if (streamedResponse.statusCode != 200) {
        final body =
            await streamedResponse.stream.transform(utf8.decoder).join();
        print("❌ Error Body: \$body");
        if (body.contains("OIDC")) {
          print(
              "⚠️ Vercel AI Gateway Auth Error: The Gateway attempted OIDC verification because the provided API Key was either missing or invalid.");
          print(
              "   - Ensure 'AI_GATEWAY_API_KEY' in your .env file is a valid Vercel AI Gateway API Key (starts with 'vak_').");
          print(
              "   - Do NOT use provider keys (like 'sk-...') directly with the Vercel AI Gateway URL.");
        }
        return null;
      }

      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String finalContent = "";
      print("Listening to stream...");
      print(
          "TTFT:${DateTime.now().difference(generateAnswerStartTime).inMilliseconds}");

      await for (final line in stream) {
        if (!line.startsWith("data:")) continue;
        final chunk = line.substring(5).trim();
        if (chunk == "[DONE]") continue;

        try {
          final decoded = jsonDecode(chunk);
          final delta = decoded["choices"]?[0]?["delta"];
          if (delta == null) continue;

          if (delta["content"] != null) {
            final chunkText = delta["content"];
            streamedText.value += chunkText;
            finalContent += chunkText;
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
          }
        } catch (e) {
          print("Streaming parse error: \$e");
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
    } catch (e) {
      print("❌ Vercel AI SDK Request failed: \$e");
      return null;
    }
  }

  //Chowmein API
  Future<String?> chowmeinGenerateReply(
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
    // Step 1: Format sources with token counting - ONLY YouTube results, limit 2k tokens.
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      // Simple token estimate: 1 token ≈ 4 chars
      int tokens = ((result["title"]!.length +
              result["url"]!.length +
              result["snippet"]!.length) ~/
          4);
      if (totalTokens + tokens > 8000) {
        break;
      }
      formattedSources.add({
        "title": result["title"]!,
        "url": result["url"]!,
        "snippet": result["snippet"]!,
      });
      totalTokens += tokens;
    }

    // Step 2: Determine if this is a chat request (no search results)
    bool isChat = formattedSources.isEmpty;

    // Step 3: Check for Cold Start & Fallback
    final baseUrl = dotenv.get("QWEN_SARVAM_API_URL");

    // Determine the URL to check (same logic as below)
    final checkUrlStr = isChat
        ? baseUrl.replaceFirst('.modal.run', '-chat.modal.run')
        : baseUrl.replaceFirst('.modal.run', '-search.modal.run');
    final checkUrl = Uri.parse(checkUrlStr);

    try {
      print("DEBUG: Checking Drissy status at $checkUrl...");

      // Attempt a lightweight GET request with a short timeout.
      // If the container is warm, it should respond instantly (405 Method Not Allowed is expected for POST endpoints).
      // If it takes longer than 2 seconds, we assume it's cold/waking up.
      await http.get(checkUrl).timeout(const Duration(seconds: 2));
      print("DEBUG: Drissy is warm. Proceeding.");
    } catch (e) {
      print(
          "DEBUG: Drissy is cold (or timeout: $e). Switching to Vercel fallback & warming up in background.");

      // Explicit fire-and-forget warmup to ensure container boots
      // We use a longer timeout here (or no timeout) to let it complete in background
      http.get(checkUrl).then((_) {
        print("DEBUG: Drissy background warmup completed");
      }).catchError((err) {
        print(
            "DEBUG: Drissy background warmup completed with error (expected if just waking up): $err");
      });

      // Fallback to Vercel
      return vercelNewGenerateReply(
        query,
        results,
        streamedText,
        emit,
        imageDescription,
        previousResults,
        extractedUrlData,
        city,
        region,
        country,
      );
    }

    // Step 4: Build the full query with context
    String fullQuery =
        "$query ${imageDescription == "" ? "" : "| Here's the image description: $imageDescription"}  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}"
            .trim();

    // Step 5: Make the API request to Qwen-Sarvam vLLM server
    // final baseUrl = dotenv.get("QWEN_SARVAM_API_URL"); // Already retrieved above

    print("");
    print("Starting request to Qwen-Sarvam vLLM API...");
    print("");

    try {
      final Uri url;
      final String body;

      if (isChat) {
        // Use /chat endpoint for pure chat (no search results)
        // Modal URL format: endpoint name is in the hostname
        // e.g., https://viratgsingh99--qwen-sarvam-vllm-v2-chat.modal.run
        final chatUrl = baseUrl.replaceFirst('.modal.run', '-chat.modal.run');
        url = Uri.parse(chatUrl);

        // Build messages array with previous context
        List<Map<String, String>> messages = [];
        for (final item in previousResults) {
          messages.add({
            "role": "user",
            "content": item.sourceImageDescription != ""
                ? "${item.userQuery} | Here's the image description:${item.sourceImageDescription}"
                : item.userQuery
          });
          messages.add({
            "role": "assistant",
            "content": item.answer,
          });
        }
        messages.add({
          "role": "user",
          "content": fullQuery,
        });

        body = jsonEncode({
          "messages": messages,
          "max_tokens": 1000,
          "thinking": false,
          "stream": true,
        });
      } else {
        // Use /search endpoint for search-augmented generation
        // Modal URL format: endpoint name is in the hostname
        // e.g., https://viratgsingh99--qwen-sarvam-vllm-v2-search.modal.run
        final searchUrl =
            baseUrl.replaceFirst('.modal.run', '-search.modal.run');
        url = Uri.parse(searchUrl);

        // Format search results in Source/Title/Snippet format
        String searchResultsStr =
            "User Query: $query\n\n Search Results:\nHere are search result snippets for \"$query\":\n";
        for (final src in formattedSources) {
          // Extract domain as source name
          String sourceName = "Unknown";
          try {
            final uri = Uri.parse(src["url"] ?? "");
            sourceName = uri.host.replaceFirst("www.", "");
          } catch (_) {}

          searchResultsStr += "\n---\n\n";
          searchResultsStr += "**Source:** *$sourceName*\n";
          searchResultsStr += "**Title:** **\"${src["title"]}\"**\n";
          searchResultsStr += "**Snippet:** ${src["snippet"]}\n";
        }
        searchResultsStr += "\n---";

        // Step 2: IP lookup and user context
        String formattedUserContext = city == "" &&
                region == "" &&
                country == ""
            ? "The current date and time is ${DateTime.now()}."
            : "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

        // Step 3: Build systemPrompt
        bool isChat = formattedSources.isEmpty;
        final systemPrompt = """
You are Drissy, a private, conversational, and insightful answer engine. You do not save user data and keep as much processing as possible strictly on-device. 

${isChat ? "" : """
You answer user questions using a list of web sources, each with a title, url, and snippet.
Rules:
- Always answer in Markdown.
- Structure your response in mobile-friendly way.
- Always **bold key insights** and highlight notable places, dishes, or experiences.
- For any place, food item, or experience that was featured in a source, wrap the main word or phrase in this format: `[text to show](<link>)` (e.g., Try the **[Dum Pukht Biryani](https://example.com/food)**).
- **Be Conversational**: Write naturally, like a knowledgeable friend. Avoid robotic phrases like “based on search results” or “these sources say.”
- Only use the sources that directly answer the query.
- If no strong or direct matches are found, gracefully say: _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_
- Do not repeat the question or use generic filler lines.
- Keep your language engaging, be as detailed and exhaustive as possible, ensuring no relevant detail from the sources is omitted, while still maintaining clarity and readability.
- If the query consists primarily of a URL (e.g., youtube.com/...), use the provided content from the extracted URL to summarize what the page or video is about.
"""}
Use the following user context for additional personalization (if relevant):
$formattedUserContext

Don't reveal any personal information you have in your context unless asked about it.
""";

        body = jsonEncode({
          "query": fullQuery,
          "search_results": searchResultsStr,
          "system_prompt": systemPrompt,
          "max_tokens": 6000,
          "temperature": 0.7,
          "thinking": false,
          "stream": true,
        });
      }

      print("🔗 Calling URL: $url");
      final request = http.Request("POST", url);
      request.headers.addAll({"Content-Type": "application/json"});
      request.body = body;
      print("📤 Request Body: $body");

      final streamedResponse = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 90));
      print("Response Status Code: ${streamedResponse.statusCode}");

      if (streamedResponse.statusCode != 200) {
        final errorBody =
            await streamedResponse.stream.transform(utf8.decoder).join();
        print("❌ Error Body: $errorBody");
        return null;
      }

      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String finalContent = "";
      print("Listening to stream...");
      print(
          "TTFT:${DateTime.now().difference(generateAnswerStartTime).inMilliseconds}");

      await for (final line in stream) {
        if (!line.startsWith("data:")) continue;
        final chunk = line.substring(5).trim();
        if (chunk == "[DONE]") continue;

        try {
          final decoded = jsonDecode(chunk);
          final delta = decoded["choices"]?[0]?["delta"];
          if (delta == null) continue;

          if (delta["content"] != null) {
            final chunkText = delta["content"];
            streamedText.value += chunkText;
            finalContent += chunkText;
            emit(state.copyWith(replyStatus: HomeReplyStatus.success));
          }
        } catch (e) {
          print("Streaming parse error: \$e");
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
    } catch (e) {
      print("❌ Qwen-Sarvam API Request failed: $e");
      return null;
    }
  }

  // Generate a reply from Drissea API given a query and search results.
  // Generate a reply from Vercel AI SDK API given a query and search results.
  Future<String?> vercelGenerateChatReply(
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
    streamedText.value = "";
    // Step 1: Format sources with token counting, skip if would exceed 125,000 tokens.
    int totalTokens = 0;
    List<Map<String, String>> formattedSources = [];
    for (final result in results) {
      if (result["title"] == null ||
          result["url"] == null ||
          result["snippet"] == null) {
        continue;
      }
      // Simple token estimate: 1 token ≈ 4 chars
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
    String formattedUserContext =
        "The user is located in $city, $region, $country. The current date and time is ${DateTime.now()}.";

    // Step 3: Build systemPrompt
    final systemPrompt = """
You are a personal memory assistant that helps users recall and explore information from their saved memories. Your primary purpose is to help users remember things they've previously searched, learned, or saved.

Rules:
- Always respond in Markdown format.
- **ONLY use information from the provided memory_recall_results** - do NOT make up or hallucinate any information.
- If the memory results don't contain relevant information, honestly say "I don't have that in your memories" rather than guessing.
- Be conversational and warm - respond as a helpful friend would.
- When analyzing images, describe what you see clearly and answer any questions about them.
- **Bold key insights** and important information to make responses scannable.
- Use bullet points or numbered lists when presenting multiple items or steps.
- Keep responses concise and optimized for mobile readability.
- Draw on the conversation history and memory results to maintain context.
- When recalling memories, cite the source or context when available.
- If you're unsure about something, say so honestly rather than guessing.
- Never fabricate information that isn't in the user's memories.

User context for personalization:
$formattedUserContext
""";

    // Step 4: Determine Model
    String modelName;
    switch (state.selectedModel) {
      case HomeModel.deepseek:
        modelName = "deepseek/deepseek-v3.2";
        break;
      case HomeModel.gemini:
        modelName = "google/gemini-2.5-flash";
        break;
      case HomeModel.claude:
        modelName = "anthropic/claude-haiku-4.5";
        break;
      case HomeModel.openAI:
        modelName = "openai/gpt-5-nano";
        break;
      case HomeModel.flashThink:
        modelName =
            "google/gemini-2.0-flash-thinking-exp"; // Placeholder or appropriate model
        break;
      case HomeModel.localAI:
        modelName = "deepseek/deepseek-v3.2";
        break;
    }

    // Step 5: Make the streaming API request to Vercel AI SDK Gateway
    // Correct Vercel AI Gateway URL found via search.
    final url = Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");

    final request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer ${dotenv.get("AI_GATEWAY_API_KEY")}",
    });

    request.body = jsonEncode({
      "model": modelName,
      "stream": true,
      "messages": [
        {"role": "system", "content": systemPrompt},
        // Add previous queries and answers as context
        ...previousResults.expand((item) => [
              {
                "role": "user",
                "content": item.sourceImageDescription != ""
                    ? "${item.userQuery} | Here's the image description:${item.sourceImageDescription}"
                    : item.userQuery
              },
              {
                "role": "assistant",
                "content": item.isSearchMode
                    ? jsonEncode({
                        "memory_recall_results": item.web
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

        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "$query ${imageDescription == "" ? "" : "| Here's the image description: $imageDescription"}  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}"
                      .trim()
            },
          ]
        },

        {
          "role": "user",
          "content": jsonEncode({
            "results": formattedSources,
            "city": city,
            "region": region,
            "country": country,
          })
        }
      ],
    });
    print("");
    print("Starting streaming request to Vercel AI SDK ($modelName)...");
    print("");

    try {
      final streamedResponse = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 90));
      print("Response Status Code: ${streamedResponse.statusCode}");

      if (streamedResponse.statusCode != 200) {
        final body =
            await streamedResponse.stream.transform(utf8.decoder).join();
        print("❌ Error Body: $body");
        if (body.contains("OIDC")) {
          print(
              "⚠️ Vercel AI Gateway Auth Error: The Gateway attempted OIDC verification because the provided API Key was either missing or invalid.");
          print(
              "   - Ensure 'AI_GATEWAY_API_KEY' in your .env file is a valid Vercel AI Gateway API Key (starts with 'vak_').");
          print(
              "   - Do NOT use provider keys (like 'sk-...') directly with the Vercel AI Gateway URL.");
        }
        return null;
      }

      final stream = streamedResponse.stream.transform(utf8.decoder);

      String finalContent = "";
      String buffer = "";
      print("Listening to stream...");

      await for (final rawChunk in stream) {
        // print("Raw Chunk: $rawChunk"); // DEBUG: Print raw chunk
        try {
          String cleaned = rawChunk.trim();
          final lines = cleaned.split("\n");

          for (final line in lines) {
            String l = line.trim();
            if (!l.startsWith("data:")) continue;

            l = l.substring(5).trim(); // Remove "data:"
            if (l == "[DONE]") continue;

            buffer += l;

            try {
              final decoded = jsonDecode(buffer);
              buffer = ""; // reset after successful parse

              final delta = decoded["choices"]?[0]?["delta"];
              if (delta == null) continue;

              if (delta["content"] != null) {
                emit(state.copyWith(replyStatus: HomeReplyStatus.success));
                final chunkText = delta["content"];
                streamedText.value += chunkText;
                finalContent += chunkText;
              }
            } catch (e) {
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
    } catch (e) {
      print("❌ Vercel AI SDK Request failed: $e");
      return null;
    }
  }

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
      ),
    );
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
    if (state.historyStatus == HomeHistoryStatus.loading) {
      initMixpanel();
    }

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
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
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

      final firestoreData = sessionData.toJson();
      firestoreData['createdAt'] = sessionData.createdAt;
      firestoreData['updatedAt'] = sessionData.updatedAt;
      firestoreData['results'] = sessionData.results.map((e) {
        final data = e.toJson();
        data['createdAt'] = e.createdAt;
        data['updatedAt'] = e.updatedAt;
        return data;
      }).toList();

      // Tag thread with userId if logged in
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final email = prefs.getString('email') ?? '';
      if (isLoggedIn && email.isNotEmpty) {
        final userQuery = await firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          firestoreData['userId'] = userQuery.docs.first.id;
        }
      }

      await firestore.collection("threads").doc(sessionId).set(firestoreData);
      print("✅ Session created/updated in Firestore with ID: $sessionId");

      // Fire-and-forget: update profile stats in background
      ProfileStatsService.updateStatsInBackground();

      return sessionId;
    } catch (e) {
      print("Error creating session: $e");
      return null;
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // Do NOT call requestPermission here. We handle that via the UI flow.
      return Future.error('Location permissions are denied');
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
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
    try {
      Position position = await _determinePosition();

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        return (
          country: place.country ?? "",
          countryCode: place.isoCountryCode ?? "",
          city: place.locality ?? "",
          region: place.administrativeArea ?? "",
          timezone: "", // Not available via placemark directly
          org: "", // Not available via basic local location
          postal: place.postalCode ?? "",
          latitude: position.latitude.toString(),
          longitude: position.longitude.toString(),
          ip: "", // Not available via local location
        );
      }
    } catch (e) {
      print("Error fetching user location locally: $e");
    }
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
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      final thread = ThreadsCompanion(
        id: drift.Value(sessionId),
        sessionData: drift.Value(jsonEncode(sessionData.toJson())),
        createdAt: drift.Value(sessionData.createdAt.toDate()),
        updatedAt: drift.Value(sessionData.updatedAt.toDate()),
      );

      await AppDatabase().updateThread(sessionId, thread);
      print("✅ Session updated in local database with ID: $sessionId");

      final docRef = firestore.collection("threads").doc(sessionId);
      final docSnapshot = await docRef.get();

      final firestoreData = sessionData.toJson();
      firestoreData['createdAt'] = sessionData.createdAt;
      firestoreData['updatedAt'] = Timestamp.now();
      firestoreData['results'] = sessionData.results.map((e) {
        final data = e.toJson();
        data['createdAt'] = e.createdAt;
        data['updatedAt'] = e.updatedAt;
        return data;
      }).toList();

      // Tag thread with userId if logged in
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final email = prefs.getString('email') ?? '';
      if (isLoggedIn && email.isNotEmpty) {
        final userQuery = await firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          firestoreData['userId'] = userQuery.docs.first.id;
        }
      }

      if (docSnapshot.exists) {
        await docRef.update(firestoreData);
        print("✅ Session updated successfully with ID: $sessionId");
      } else {
        await docRef.set(firestoreData);
        print("🆕 Session created with ID: $sessionId");
      }

      // Fire-and-forget: update profile stats in background
      ProfileStatsService.updateStatsInBackground();

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

  //Sign in

  // ============================================
  // ANSWER MEMORY HELPERS (Isolated, fire-and-forget)
  // ============================================

  /// Process multiple results for memory caching. Runs in background, won't block.
  void _processAnswersForMemory(List<ThreadResultData> results) {
    debugPrint(
        '🧠 _processAnswersForMemory called with ${results.length} results');
    Future(() async {
      try {
        debugPrint('🧠 Starting memory processing loop...');
        for (final result in results) {
          debugPrint(
              '🧠 Checking result: answer length=${result.answer.length}, query="${result.userQuery}"');
          if (result.answer.isNotEmpty) {
            debugPrint('🧠 Processing answer for memory...');
            await AnswerMemoryService.instance.processAndCacheAnswer(
              result.answer,
              result.userQuery,
            );
            debugPrint('🧠 Finished processing answer for memory');
          }
        }
        debugPrint('🧠 Memory processing loop complete');
      } catch (e) {
        debugPrint('⚠️ Answer memory processing error (ignored): $e');
        // Don't rethrow - this is fire-and-forget
      }
    });
  }

  /// Process a single answer for memory caching. Runs in background, won't block.
  void _processAnswerForMemory(String answer, String query) {
    debugPrint(
        '🧠 _processAnswerForMemory called: answer length=${answer.length}, query="$query"');
    if (answer.isEmpty) {
      debugPrint('🧠 Answer empty, skipping');
      return;
    }

    Future(() async {
      try {
        debugPrint('🧠 Starting single answer memory processing...');
        await AnswerMemoryService.instance.processAndCacheAnswer(answer, query);
        debugPrint('🧠 Single answer memory processing complete');
      } catch (e) {
        debugPrint('⚠️ Answer memory processing error (ignored): $e');
        // Don't rethrow - this is fire-and-forget
      }
    });
  }
}

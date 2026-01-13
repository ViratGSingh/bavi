import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
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
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model_management/cancel_token.dart';
import 'package:bavi/services/answer_memory_service.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final http.Client httpClient;
  InferenceModel? _activeGemmaModel;
  InferenceChat?
      _activeGemmaChat; // Cached chat session to avoid createChat() on each query
  CancelToken? _gemmaCancelToken = CancelToken();
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
    on<HomeDownloadGemmaModel>(_downloadGemmaModels);
    on<HomeCancelGemmaDownload>(_cancelGemmaDownload);
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
        isAnalyzingImage: true));

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
      final bytes = await File(image.path).readAsBytes();
      final fileName = "${const Uuid().v4()}.jpg";

      final accessKey = dotenv.get("R2_ACCESS_KEY_ID");
      final secretKey = dotenv.get("R2_SECRET_ACCESS_KEY");
      final endpoint = dotenv.get("R2_ENDPOINT");
      final publicBaseUrl = dotenv.get("R2_PUBLIC_BASE_URL");

      // Ensure endpoint doesn't have trailing slash
      final cleanEndpoint = endpoint.endsWith('/')
          ? endpoint.substring(0, endpoint.length - 1)
          : endpoint;

      // Construct URI for the specific bucket and key
      final uri = Uri.parse("$cleanEndpoint/drissea/drissea_uploads/$fileName");

      final cleanPublicBaseUrl = publicBaseUrl.endsWith('/')
          ? publicBaseUrl.substring(0, publicBaseUrl.length - 1)
          : publicBaseUrl;
      final publicUrl = "$cleanPublicBaseUrl/drissea_uploads/$fileName";

      // Run both upload and description in parallel
      final results = await Future.wait([
        // Upload to R2
        _uploadWithSigV4(
          uri: uri,
          method: 'PUT',
          payload: bytes,
          accessKey: accessKey,
          secretKey: secretKey,
          region: 'auto',
        ).then((_) => publicUrl),

        // Get image description from Vercel AI
        _describeImageWithAI(bytes),
      ]);

      final uploadedUrl = results[0] as String;
      final description = results[1] as String;

      print("DEBUG: Image upload success: $uploadedUrl");
      print("DEBUG: Image description: $description");

      // Update the imageDescription ValueNotifier
      imageDescription.value = description;

      emit(state.copyWith(
        selectedImage: state.selectedImage,
        imageStatus: state.imageStatus,
        uploadedImageUrl: uploadedUrl,
        isAnalyzingImage: false,
      ));
    } catch (e) {
      print("DEBUG: Image upload/analysis error: $e");
      emit(state.copyWith(
        selectedImage: state.selectedImage,
        imageStatus: state.imageStatus,
        isAnalyzingImage: false,
      ));
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

      final response = await httpClient.send(request);

      if (response.statusCode == 200) {
        final body = await response.stream.transform(utf8.decoder).join();
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
    ));
    event.imageDescription.value = "";
  }

  Future<void> _handleModelSelect(
    HomeModelSelect event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(selectedModel: event.model));
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
      //Image
      if (initialresultData.sourceImage != null) {
        //reply for image
        answer = await imageVercelGenerateReply(
          initialresultData.userQuery,
          [],
          event.streamedText,
          emit,
          initialresultData.sourceImage!,
          state.threadData.results
              .getRange(0, state.threadData.results.length - 1)
              .toList(),
          initialresultData.extractedUrlData,
          userData.city,
          userData.region,
          userData.country,
        );
      }
      //Extracted Url
      else if (initialresultData.extractedUrlData?.link != "" &&
          initialresultData.extractedUrlData?.link != null) {
        answer = await vercelGenerateReply(
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
        answer = await vercelGenerateReply(
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

      final url = Uri.parse("https://api.groq.com/openai/v1/chat/completions");
      final request = http.Request("POST", url);
      request.headers.addAll({
        "Content-Type": "application/json",
        "Authorization": "Bearer ${dotenv.get("GROQ_API_KEY")}",
      });

      request.body = jsonEncode({
        "model": "llama-3.1-8b-instant",
        "stream": false,
        "messages": [
          {"role": "user", "content": prompt}
        ],
      });

      final response = await httpClient.send(request);

      if (response.statusCode == 200) {
        final body = await response.stream.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final String searchQuery =
            data['choices']?[0]?['message']?['content']?.trim() ?? query;
        print("DEBUG: Generated search query: $searchQuery");
        return (type: "general", searchQuery: searchQuery);
      } else {
        print("DEBUG: Search query generation failed: ${response.statusCode}");
        return (
          type: "general",
          searchQuery: query
        ); // Fallback to original query
      }
    } catch (e) {
      print("DEBUG: Search query generation error: $e");
      return (
        type: "general",
        searchQuery: query
      ); // Fallback to original query
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

  // Helper to get or initialize the Gemma model instance
  Future<InferenceModel> _getGemmaModel() async {
    if (_activeGemmaModel != null) return _activeGemmaModel!;

    print("DEBUG: Initializing new Gemma model instance");
    final bool isEmulator = await _isEmulator();

    _activeGemmaModel = await FlutterGemma.getActiveModel(
      maxTokens: 512,
      preferredBackend:
          isEmulator ? PreferredBackend.cpu : PreferredBackend.gpu,
    );
    return _activeGemmaModel!;
  }

  // Helper to check if the app is running on an emulator
  Future<bool> _isEmulator() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return !androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return !iosInfo.isPhysicalDevice;
    }
    return false; // Default to false for other platforms
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

    // Read image bytes if available
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

    //Image Response
    if (state.selectedImage != null) {
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

      print("asdasdas");
      print("");

      //reply for image
      answer = await imageVercelGenerateReply(
        query,
        [],
        event.streamedText,
        emit,
        resultData.sourceImage!,
        state.threadData.results
            .getRange(0, state.threadData.results.length - 1)
            .toList(),
        resultData.extractedUrlData,
        userData.city,
        userData.region,
        userData.country,
      );
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

        //Get user details
        final userData = await _getUserLocation();

        // If there's an image, use imageVercelGenerateReply
        if (imageBytes != null) {
          answer = await imageVercelGenerateChatReply(
            query,
            [],
            event.streamedText,
            emit,
            imageBytes,
            state.threadData.results
                .getRange(0, state.threadData.results.length - 1)
                .toList(),
            resultData.extractedUrlData,
            userData.city,
            userData.region,
            userData.country,
          );
        } else {
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

          // No image, use vercelGenerateChatReply with memory context
          answer = await vercelGenerateChatReply(
            query,
            memoryContext,
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
            similarity: 0);
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

  /// Function to search using SerpAPI Google results for Instagram Reels
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

    // Read image bytes if available
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

    // Continue with search flow for non-chat action types
    //Get Search Results
    //Image Response
    if (state.selectedImage != null) {
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

      print("asdasdas");
      print("");

      //reply for image
      answer = await imageVercelGenerateReply(
        query,
        [],
        event.streamedText,
        emit,
        resultData.sourceImage!,
        state.threadData.results
            .getRange(0, state.threadData.results.length - 1)
            .toList(),
        resultData.extractedUrlData,
        city,
        region,
        country,
      );
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

      //Understand query - Rewrite query with context from previous messages
      if (state.threadData.results.isNotEmpty) {
        searchQuery = await _rewriteQueryWithContext(
          query,
          state.threadData.results,
        );
        print("📝 Original query: $query");
        print("📝 Rewritten query: $searchQuery");
      }

      try {
        // Unified search API call

        final drisseaApiHost = dotenv.get('API_HOST');
        final apiSecret = dotenv.get('API_SECRET');
        final unifiedSearchUrl =
            Uri.parse("https://$drisseaApiHost/api/search");

        final searchStartTime = DateTime.now();
        final searchResponse = await http.post(
          unifiedSearchUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiSecret',
          },
          body: jsonEncode({
            'query': searchQuery,
            'country': countryCode.toLowerCase(),
          }),
        );
        final searchEndTime = DateTime.now();
        final searchDuration = searchEndTime.difference(searchStartTime);

        print("");
        print("Search duration: ${searchDuration.inMilliseconds} ms");
        print("");

        if (searchResponse.statusCode == 200) {
          final Map<String, dynamic> respJson = jsonDecode(searchResponse.body);
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

            // Parse Instagram results -> ExtractedResultInfo and ShortVideoResultData
            if (state.instagramStatus == HomeInstagramStatus.enabled) {
              final instagramResults = respJson['instagram'] is List
                  ? List<dynamic>.from(respJson['instagram'])
                  : [];

              // Deduplicate Instagram results by permalink
              final seenUrls = <String>{};
              final uniqueInstagramResults = instagramResults.where((e) {
                final url = e['permalink'] ?? '';
                if (url.isEmpty || seenUrls.contains(url)) {
                  return false;
                }
                seenUrls.add(url);
                return true;
              }).toList();

              extractedResults.addAll(
                uniqueInstagramResults.map(
                  (e) => ExtractedResultInfo(
                    url: e['permalink'] ?? '',
                    title: 'Instagram Reel',
                    // Combine transcription and caption for richer context
                    excerpts:
                        '${e['transcription'] ?? ''} ${e['caption'] ?? ''}'
                            .trim(),
                    thumbnailUrl: e['thumbnail_url'] ?? '',
                  ),
                ),
              );
              // Also add to shortVideos for display
              instagramShortVideos = uniqueInstagramResults
                  .map(
                    (e) => ShortVideoResultData(
                      title: (e['caption'] ?? 'Instagram Reel').toString(),
                      link: e['permalink'] ?? '',
                      thumbnail: e['thumbnail_url'] ?? '',
                      clip: '',
                      source: 'Instagram',
                      sourceIcon: 'https://www.instagram.com/favicon.ico',
                      channel: '',
                      duration: '',
                    ),
                  )
                  .toList();
              print(
                  "Instagram results found: ${uniqueInstagramResults.length} (deduplicated from ${instagramResults.length})");
            }
          }
        } else {
          print("⚠️ Unified search API failed: ${searchResponse.statusCode}");
        }

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
        city,
        region,
        country,
      );
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
            similarity: 0);
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

    // Generate thread title and summary using Sarvam AI before saving
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

    // Read image bytes if available
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

    //Image Response
    if (imageBytes != null) {
      emit(state.copyWith(
          status: HomePageStatus.success,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1,
          searchType: state.searchType == HomeSearchType.extractUrl
              ? HomeSearchType.general
              : state.searchType,
          replyStatus: HomeReplyStatus.loading));
      print("asdasdas");
      print("");

      //reply for image
      answer = await imageVercelGenerateReply(
        query,
        [],
        event.streamedText,
        emit,
        resultData.sourceImage!,
        state.threadData.results
            .getRange(0, state.threadData.results.length - 1)
            .toList(),
        resultData.extractedUrlData,
        userData.city,
        userData.region,
        userData.country,
      );
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
          similarity: 0);
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
      final streamedResponse = await httpClient.send(request);
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
      final streamedResponse = await httpClient.send(request);
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
      final streamedResponse = await httpClient.send(request);
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

    // This is a follow-up query (has previous messages), so we rewrite it

    // Build conversation history from previous results (most recent first for truncation)
    final conversationParts = previousResults.reversed.map((r) {
      return "User: ${r.userQuery}\nAssistant: ${r.answer}";
    }).toList();

    // Limit to ~4k tokens (approximately 4 chars per token, so ~16k chars)
    const maxChars = 16000;
    var totalChars = 0;
    final limitedParts = <String>[];

    for (final part in conversationParts) {
      if (totalChars + part.length > maxChars) {
        // Truncate this part if needed to fit
        final remaining = maxChars - totalChars;
        if (remaining > 100) {
          limitedParts.add(part.substring(0, remaining) + "...[truncated]");
        }
        break;
      }
      limitedParts.add(part);
      totalChars += part.length;
    }

    // Reverse back to chronological order
    final conversationHistory = limitedParts.reversed.join("\n\n");

    final systemPrompt =
        """You are a query rewriting assistant. Your task is to rewrite user queries to be completely self-contained.

Given a conversation history and the current query, rewrite the current query so that:
1. All pronouns (it, this, that, they, he, she, etc.) are replaced with the actual entities they refer to from the conversation
2. All context-dependent references are replaced with explicit information
3. The meaning and intent of the query remains exactly the same
4. Everything else in the query stays unchanged
5. If the query is already self-contained and doesn't need any context, return it as-is

IMPORTANT: Only output the rewritten query, nothing else. No explanations, no quotes, just the query.""";

    final userMessage = """Conversation history:
$conversationHistory

Current query to rewrite: $query

Rewrite this query to be self-contained:""";

    try {
      final url = Uri.parse("https://api.sarvam.ai/v1/chat/completions");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${dotenv.get("SARVAM_API_KEY")}",
        },
        body: jsonEncode({
          "model": "sarvam-m",
          "stream": false,
          "max_tokens": 300,
          "temperature": 0.1,
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userMessage},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final content = decoded["choices"]?[0]?["message"]?["content"] ?? "";
        final rewrittenQuery = content.toString().trim();

        if (rewrittenQuery.isNotEmpty) {
          return rewrittenQuery;
        }
      } else {
        print("❌ Query rewrite API failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Query rewrite failed: $e");
    }

    // Return original query if rewriting fails
    return query;
  }

  /// Generates thread title and summary using Sarvam AI based on all user inputs in the thread.
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
      final url = Uri.parse("https://api.sarvam.ai/v1/chat/completions");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${dotenv.get("SARVAM_API_KEY")}",
        },
        body: jsonEncode({
          "model": "sarvam-m",
          "stream": false,
          "max_tokens": 200,
          "temperature": 0.3,
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userMessage},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final content = decoded["choices"]?[0]?["message"]?["content"] ?? "";

        // Parse the JSON response
        try {
          // Try to extract JSON from the response (handle potential markdown code blocks)
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

          // Ensure summary is max 150 characters
          if (summary.length > 150) {
            summary = "${summary.substring(0, 147)}...";
          }

          // Ensure title is max 50 characters
          if (title.length > 50) {
            title = "${title.substring(0, 47)}...";
          }

          print("📝 Generated thread title: $title");
          print("📝 Generated thread summary: $summary");

          return {'title': title, 'summary': summary};
        } catch (parseError) {
          print("❌ Failed to parse title/summary JSON: $parseError");
          // Fallback: use first query as title
          final fallbackTitle = userQueries.first.length > 50
              ? "${userQueries.first.substring(0, 47)}..."
              : userQueries.first;
          return {'title': fallbackTitle, 'summary': ''};
        }
      } else {
        print("❌ Sarvam AI request failed: ${response.statusCode}");
        // Fallback: use first query as title
        final fallbackTitle = userQueries.first.length > 50
            ? "${userQueries.first.substring(0, 47)}..."
            : userQueries.first;
        return {'title': fallbackTitle, 'summary': ''};
      }
    } catch (e) {
      print("❌ Error generating thread title/summary: $e");
      // Fallback: use first query as title
      final fallbackTitle = userQueries.first.length > 50
          ? "${userQueries.first.substring(0, 47)}..."
          : userQueries.first;
      return {'title': fallbackTitle, 'summary': ''};
    }
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
    String modelName;
    switch (state.selectedModel) {
      case HomeModel.deepseek:
        modelName = "deepseek/deepseek-v3";
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
      final streamedResponse = await httpClient.send(request);
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
        modelName = "deepseek/deepseek-v3";
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
      final streamedResponse = await httpClient.send(request);
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

  Future<void> _getUserInfo(
      HomeInitialUserData event, Emitter<HomeState> emit) async {
    if (state.historyStatus == HomeHistoryStatus.loading) {
      initMixpanel();
    }

    //Get Local History Data from Drift
    try {
      await AppDatabase().getAllThreads().then((threads) {
        final userSessionData = threads.map((thread) {
          return ThreadSessionData.fromJson(jsonDecode(thread.sessionData));
        }).toList();

        emit(state.copyWith(
            threadHistory: userSessionData,
            historyStatus: HomeHistoryStatus.idle));
      });
    } catch (e) {
      print("❌ Error fetching local sessions: $e");
      emit(state
          .copyWith(threadHistory: [], historyStatus: HomeHistoryStatus.idle));
    }

    // Get user location silently
    await _getUserLocation().then((userLocation) {
      emit(state.copyWith(
        userCity: userLocation.city,
        userRegion: userLocation.region,
        userCountry: userLocation.country,
        userCountryCode: userLocation.countryCode,
      ));
    });
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

      await firestore.collection("threads").doc(sessionId).set(firestoreData);
      print("✅ Session created/updated in Firestore with ID: $sessionId");

      // Process and cache answers for memory system (fire-and-forget, isolated)
      // Skip if chat mode is active
      if (!skipMemoryProcessing) {
        _processAnswersForMemory(sessionData.results);
      }

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

      if (docSnapshot.exists) {
        await docRef.update(firestoreData);
        print("✅ Session updated successfully with ID: $sessionId");
      } else {
        await docRef.set(firestoreData);
        print("🆕 Session created with ID: $sessionId");
      }

      // Process and cache the latest answer for memory system (fire-and-forget, isolated)
      // Skip if chat mode is active
      if (!skipMemoryProcessing && sessionData.results.isNotEmpty) {
        final latestResult = sessionData.results.last;
        _processAnswerForMemory(latestResult.answer, latestResult.userQuery);
      }

      return sessionId;
    } catch (e) {
      print("❌ Session update failed: $e");
      return null;
    }
  }

  //Sign in

  // Gemma Model Download Handlers
  Future<void> _downloadGemmaModels(
    HomeDownloadGemmaModel event,
    Emitter<HomeState> emit,
  ) async {
    print("DEBUG: _downloadGemmaModels handler called");
    // Create a new cancel token for this download session
    _gemmaCancelToken = CancelToken();

    final hfToken = dotenv.env['HUGGINGFACE_TOKEN'];

    try {
      // ========== Download EmbeddingGemma-300M Embedding Model (~183 MB) ==========
      print("DEBUG: Starting EmbeddingGemma-300M embedding model download");
      emit(state.copyWith(
        gemmaDownloadStatus: GemmaDownloadStatus.loading,
        gemmaDownloadProgress: 0.0,
        gemmaDownloadMessage: "Downloading memory model...",
        currentDownloadingModel: LocalMemoryModelType.embedding,
      ));

      // Download EmbeddingGemma-300M model (.tflite) and tokenizer
      // Using seq1024 variant for good balance of context length and performance
      await FlutterGemma.installEmbedder()
          .modelFromNetwork(
            'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq1024_mixed-precision.tflite',
            token: hfToken,
          )
          .tokenizerFromNetwork(
            // Using Gecko's sentencepiece tokenizer which is compatible
            'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/sentencepiece.model',
          )
          .withModelProgress((progress) {
        emit(state.copyWith(
          gemmaDownloadProgress: progress / 100,
          gemmaDownloadMessage:
              "Downloading memory model: ${progress.toStringAsFixed(1)}%",
        ));
      }).install();

      print("DEBUG: EmbeddingGemma-300M model downloaded successfully");

      // ========== Download Complete ==========
      emit(state.copyWith(
        gemmaDownloadStatus: GemmaDownloadStatus.success,
        gemmaDownloadProgress: 1.0,
        gemmaDownloadMessage: "Download complete!",
        currentDownloadingModel: null,
      ));
    } catch (e) {
      if (CancelToken.isCancel(e)) {
        emit(state.copyWith(
          gemmaDownloadStatus: GemmaDownloadStatus.cancelled,
          gemmaDownloadProgress: 0.0,
          gemmaDownloadMessage: "",
          currentDownloadingModel: null,
        ));
      } else {
        print("DEBUG: Model download error: $e");
        emit(state.copyWith(
          gemmaDownloadStatus: GemmaDownloadStatus.failure,
          gemmaDownloadProgress: 0.0,
          gemmaDownloadMessage: "Download failed: ${e.toString()}",
          currentDownloadingModel: null,
        ));
      }
    }
  }

  Future<void> _cancelGemmaDownload(
    HomeCancelGemmaDownload event,
    Emitter<HomeState> emit,
  ) async {
    _gemmaCancelToken?.cancel('User cancelled download');
    emit(state.copyWith(
      gemmaDownloadStatus: GemmaDownloadStatus.cancelled,
      gemmaDownloadProgress: 0.0,
      gemmaDownloadMessage: "",
    ));
  }

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

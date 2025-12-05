import 'dart:convert';
import 'dart:io';

import 'package:bavi/models/api/retrieve_answer.dart';
import 'package:bavi/models/collection.dart';
import 'package:bavi/models/question_answer.dart';
import 'package:bavi/models/session.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final http.Client httpClient;
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
    //on<HomeWatchSearchVideos>(_watchGoogleAnswer);
    on<HomeGetAnswer>(_watchGeneralGoogleAnswer);
    on<HomeGetMapAnswer>(_watchMapsGoogleAnswer);
    on<HomeUpdateAnswer>(_updateGeneralGoogleAnswer);
    on<HomeUpdateMapAnswer>(_updateMapGoogleAnswer);
    on<SelectEditInputOption>(_selectEditInputOption);

    on<HomeCancelTaskGen>(_cancelTaskSearchQuery);
    on<HomeStartNewThread>(_startNewThread);
    on<HomeInitialUserData>(_getUserInfo);
    on<HomeAttemptGoogleSignIn>(_handleGoogleSignIn);
    on<HomeRetrieveSearchData>(_retrieveSearchData);
    on<HomeRefreshReply>(_refreshReply);
    on<HomeImageSelected>(_handleImageSelected);
    on<HomeImageUnselected>(_handleImageUnselected);
    on<HomeModelSelect>(_handleModelSelect);
    // on<HomeGenScreenshot>(_genScreenshot);
    //on<HomeNavToReply>(_navToReply);

    on<HomeSearchTypeSelected>(_handleSearchTypeSelected);
    on<HomeExtractUrlData>(_extractUrlData);
    on<HomePortalSearch>(_portalSearch);
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("home_view");
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
          event.extractedUrl.value = extractedUrl;

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
        "Authorization": "Bearer ${dotenv.get("VERCEL_AI_KEY")}",
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
        imageStatus: HomeImageStatus.unselected));
    event.imageDescription.value = "";
  }

  Future<void> _handleModelSelect(
    HomeModelSelect event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(selectedModel: event.model));
  }

  //Alt Gen Reply
  Future<void> _getAltReply(
      String query, List<ThreadResultData> previousResultsData) async {}

  //Switch Search Type
  Future<void> _switchType(
    HomeSwitchType event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isSearchMode: !event.type));
  }

  //Select Edit Type
  Future<void> _selectEditInputOption(
    SelectEditInputOption event,
    Emitter<HomeState> emit,
  ) async {
    event.isEditMode == true
        ? emit(state.copyWith(
            editStatus: HomeEditStatus.selected,
            imageStatus: event.uploadedImageUrl != ""
                ? HomeImageStatus.selected
                : HomeImageStatus.unselected,
            uploadedImageUrl: event.uploadedImageUrl,
            cacheThreadData: state.threadData,
            editQuery: event.query,
            editIndex: event.index,
            searchType: state.threadData.results[event.index].local.isNotEmpty
                ? HomeSearchType.map
                : HomeSearchType.general,
            isSearchMode: event.isSearchMode))
        : emit(state.copyWith(
            editStatus: HomeEditStatus.idle,
            editQuery: "",
            editIndex: -1,
            imageStatus: HomeImageStatus.unselected,
            uploadedImageUrl: ""));
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

    //Come up with Reply
    String? answer;
    try {
      answer = await vercelGenerateReply(
          initialresultData.userQuery,
          formattedResults,
          event.streamedText,
          emit,
          initialresultData.sourceImageDescription,
          state.threadData.results
              .getRange(0, state.threadData.results.length - 1)
              .toList(),
          initialresultData.extractedUrlData);
      ThreadResultData updResultData = ThreadResultData(
          searchType: initialresultData.searchType,
          sourceImageDescription: initialresultData.sourceImageDescription,
          sourceImageLink: initialresultData.sourceImageLink,
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
        email: state.threadData.email,
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

  Future<({String reviews, List<String> images})> _getLocalReviewsData(
      String dataId) async {
    try {
      print("DEBUG: Fetching reviews for data_id: $dataId");

      final url = Uri.parse("https://serpapi.com/search");
      // Using the key provided by the user
      final String apiKey = dotenv.env["GOOGLE_SERP_API_KEY"]!;

      final response = await http.get(url.replace(queryParameters: {
        "api_key": apiKey,
        "engine": "google_maps_reviews",
        "hl": "en",
        "data_id": dataId,
        "sort_by": "qualityScore",
      }));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        List<String> images = [];

        if (data['reviews'] != null) {
          final List<dynamic> reviews = data['reviews'];

          String reviewsText =
              "Reviews for ${data['place_info']?['title'] ?? 'this place'}:\n\n";

          for (var review in reviews) {
            if (review['images'] != null) {
              final photos = review['images'] as List;
              images = photos
                  .map((photo) => photo as String?)
                  .where((img) => img != null && img.isNotEmpty)
                  .cast<String>()
                  .toList();
            }
            if (review['snippet'] != null) {
              reviewsText += "- ${review['snippet']}\n\n";
            }
          }
          print("");
          print(images);
          print("");
          return (reviews: reviewsText, images: images);
        }
        return (reviews: "", images: images);
      } else {
        print("DEBUG: SerpAPI request failed: ${response.statusCode}");
      }
    } catch (e) {
      print("DEBUG: Error fetching local reviews: $e");
    }
    return (reviews: "", images: <String>[]);
  }

  Future<List<LocalResultData>> _getMapSearchData(String query) async {
    try {
      print("DEBUG: Fetching map search results for: $query");

      final url = Uri.parse("https://serpapi.com/search");
      final String apiKey = dotenv.env["GOOGLE_SERP_API_KEY"]!;

      final response = await http.get(url.replace(queryParameters: {
        "api_key": apiKey,
        "engine": "google_maps",
        "type": "search",
        "google_domain": "google.com",
        "q": query,
        "hl": "en",
      }));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['local_results'] != null) {
          final List<dynamic> results = data['local_results'];
          return results.map((e) => LocalResultData.fromJson(e)).toList();
        }
      } else {
        print(
            "DEBUG: SerpAPI map search request failed: ${response.statusCode}");
      }
    } catch (e) {
      print("DEBUG: Error fetching map search data: $e");
    }
    return [];
  }

  Future<void> _portalSearch(
      HomePortalSearch event, Emitter<HomeState> emit) async {
    String query = event.query;

    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
      searchType: state.searchType,
      sourceImageDescription: "",
      sourceImageLink: "",
      isSearchMode: false,
      extractedUrlData: ExtractedUrlResultData(
        snippet: "",
        title: "",
        link: "",
        thumbnail: "",
      ),
      web: [],
      shortVideos: [],
      videos: [],
      news: [],
      images: [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      userQuery: query,
      searchQuery: query,
      answer: "",
      influence: [],
      local: [],
    );
    List<ExtractedResultInfo> extractedResults = [];

    ThreadSessionData updThreadData = state.threadData;

    // Set Initial Result Data
    List<ThreadResultData> tempUpdatedResults = [resultData];

    updThreadData = ThreadSessionData(
        id: state.threadData.id,
        isIncognito: state.threadData.isIncognito,
        email: state.threadData.email,
        results: tempUpdatedResults,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now());

    //Understand the query
    emit(state.copyWith(
        imageStatus: HomeImageStatus.unselected,
        status: HomePageStatus.getSearchResults,
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
                email: "",
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
      HomeSearchType searchType) async {
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

      // Build the prompt
      String prompt = """
You are a search query optimizer. Your task is to generate the best Google search query to find information needed to answer the user's question.

${conversationContext != "" ? conversationContext : ""}
Current user question: $query
${imageDescription != "" ? "Context from uploaded image: $imageDescription\n" : ""}

Generate a concise, effective Google search query (max 10 words) that will help find the most relevant information to answer the user's question. Return ONLY the search query, nothing else.
""";

      final url = Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");
      final request = http.Request("POST", url);
      request.headers.addAll({
        "Content-Type": "application/json",
        "Authorization": "Bearer ${dotenv.get("VERCEL_AI_KEY")}",
      });

      request.body = jsonEncode({
        "model": "google/gemini-2.5-flash-lite",
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

  /// Function to search using SerpAPI Google results for Instagram Reels
  Future<void> _watchGeneralGoogleAnswer(
      HomeGetAnswer event, Emitter<HomeState> emit) async {
    String query = event.query;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";

    String searchQuery = event.query;
    String threadId = Uuid().v4().substring(0, 8);
    String drisseaApiHost = dotenv.get('API_HOST');
    _cancelTaskGen = false;

    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
      searchType: state.searchType,
      sourceImageDescription: event.imageDescription,
      sourceImageLink: state.uploadedImageUrl ?? "",
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
          email: userEmail,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          email: userEmail,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }

    //Understand the query
    emit(state.copyWith(
        imageStatus: HomeImageStatus.unselected,
        status: HomePageStatus.generateQuery,
        threadData: updThreadData,
        loadingIndex: updThreadData.results.length - 1));
    String searchActionType = "general";
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
        );
        print("");
        print(result);
        print("");
        searchQuery = result.searchQuery;
        searchActionType = result.type;
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
    //List<LocalResultData> mapResults = [];
    try {
      final algoliaAppId = dotenv.get('ALGOLIA_APP_ID');
      final algoliaApiKey = dotenv.get('ALGOLIA_API_KEY');
      final algoliaIndexName = 'ig_reels';
      final algoliaUrl = Uri.parse(
          "https://${algoliaAppId}-dsn.algolia.net/1/indexes/${algoliaIndexName}/query");

      final drisseaGeneralUrl = Uri.parse(
          "https://$drisseaApiHost/dev/api/search/source/general?query=${Uri.encodeComponent(searchQuery)}");

      final drisseaWebUrl = Uri.parse(
          "https://$drisseaApiHost/api/search/web?gl=in&location=India&query=${Uri.encodeComponent(searchQuery)}");

      if (searchActionType == "agent") {
        print("");
        print("agent");
        print("");
        // Use SerpAPI Google Light to get first search result
        final String altSerpApiKey = dotenv.get("ALT_SERP_API_KEY");
        final serpUrl = Uri.parse("https://serpapi.com/search").replace(
          queryParameters: {
            'q': query,
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
            String resultPageUrl =
                serpJson['organic_results'][0]['link'] as String;

            if (await canLaunchUrl(Uri.parse(resultPageUrl))) {
              print("Navigating to first result: $resultPageUrl");
              navService.goTo("/webview", extra: {"url": resultPageUrl});
              updThreadData = ThreadSessionData(
                  id: threadId,
                  email: userEmail,
                  isIncognito: state.isIncognito,
                  results: [],
                  createdAt: Timestamp.now(),
                  updatedAt: Timestamp.now());
              emit(
                state.copyWith(
                    status: HomePageStatus.idle, threadData: updThreadData),
              );

              return;
            }
          }
        } else {
          print("SerpAPI request failed: ${webRes.statusCode}");
        }
      }

      final futures = await Future.wait([
        http.post(
          algoliaUrl,
          headers: {
            'X-Algolia-Application-Id': algoliaAppId,
            'X-Algolia-API-Key': algoliaApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'params': 'query=${Uri.encodeComponent(query)}'}),
        ),
        http.get(
          drisseaGeneralUrl,
          headers: {
            'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
            'Content-Type': 'application/json',
          },
        ),
        http.get(
          drisseaWebUrl,
          headers: {
            'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
            'Content-Type': 'application/json',
          },
        ),
        //_getMapSearchData(searchQuery),
      ]);

      final algoliaResponse = futures[0] as http.Response;
      final drisseaGeneralResponse = futures[1] as http.Response;
      final drisseaWebResponse = futures[2] as http.Response;
      //mapResults = futures[3] as List<LocalResultData>;

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
      if (drisseaGeneralResponse.statusCode == 200) {
        final Map<String, dynamic> respJson =
            jsonDecode(drisseaGeneralResponse.body);

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

      // Parse Drissea web results
      if (drisseaWebResponse.statusCode == 200) {
        final Map<String, dynamic> respJson =
            jsonDecode(drisseaWebResponse.body);
        if (respJson["success"] == true) {
          final webResults = (respJson['data'] as List<dynamic>)
              .map((entry) => ExtractedResultInfo.fromJson({
                    'url': entry['link'] ?? '',
                    'title': entry['title'] ?? '',
                    'excerpts': entry['snippet'] ?? '',
                    'thumbnailUrl': entry['thumbnail'] ?? '',
                  }))
              .toList();
          extractedResults.addAll(webResults);
        }
      }

      emit(state.copyWith(
          status: HomePageStatus.success,
          replyStatus: HomeReplyStatus.loading));
    } catch (e) {
      print("Error in parallel search: $e");
    }
    if (_cancelTaskGen) {
      //emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    DateTime searchEndDatetime = DateTime.now();

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

    String? answer = await vercelGenerateReply(
      query,
      formattedResults,
      event.streamedText,
      emit,
      event.imageDescription,
      state.threadData.results
          .getRange(0, state.threadData.results.length - 1)
          .toList(),
      resultData.extractedUrlData,
    );

    ThreadResultData updResultData = ThreadResultData(
      searchType: resultData.searchType,
      extractedUrlData: resultData.extractedUrlData,
      sourceImageDescription: resultData.sourceImageDescription,
      sourceImageLink: resultData.sourceImageLink,
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
      }).toList(),
      local: [],
    );

    final updatedResults = List<ThreadResultData>.from(state.threadData.results)
      ..removeLast()
      ..add(updResultData);

    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          email: userEmail,
          isIncognito: state.threadData.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          email: userEmail,
          isIncognito: state.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    if (_cancelTaskGen) {
      //emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    emit(state.copyWith(
      replyStatus: HomeReplyStatus.success,
      threadData: updThreadData,
      uploadedImageUrl: "",
    ));
    event.imageDescriptionNotifier.value = "";

    if (updThreadData.results.length == 1) {
      await createSession(updThreadData, threadId);
    } else {
      await updateSession(updThreadData, state.threadData.id);
    }

    //Get User Data
    if (userEmail != "") {
      try {
        final db = FirebaseFirestore.instance;

        final querySnapshot = await db
            .collection("threads")
            .where("email", isEqualTo: userEmail)
            .orderBy("createdAt",
                descending: true) // assumes createdAt is stored
            .limit(20)
            .get();

        final userSessionData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return ThreadSessionData.fromJson(data);
        }).toList();
        emit(state.copyWith(threadHistory: userSessionData));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
      }
    }
  }

  /// Function to search using SerpAPI Google results for Instagram Reels
  Future<void> _watchMapsGoogleAnswer(
      HomeGetMapAnswer event, Emitter<HomeState> emit) async {
    String query = event.query;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";

    String searchQuery = event.query;
    String threadId = Uuid().v4().substring(0, 8);
    String drisseaApiHost = dotenv.get('API_HOST');
    _cancelTaskGen = false;

    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
      searchType: state.searchType,
      sourceImageDescription: event.imageDescription,
      sourceImageLink: state.uploadedImageUrl ?? "",
      isSearchMode: false,
      extractedUrlData: ExtractedUrlResultData(
          link: event.extractedUrl.value,
          title: event.extractedUrlTitle.value,
          snippet: event.extractedUrlDescription.value,
          thumbnail: event.extractedImageUrl.value),
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
          email: userEmail,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          email: userEmail,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }

    //Understand the query
    emit(state.copyWith(
        imageStatus: HomeImageStatus.unselected,
        status: HomePageStatus.generateQuery,
        threadData: updThreadData,
        loadingIndex: updThreadData.results.length - 1));
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
        );
        searchQuery = result.searchQuery;
        // TODO: Use result.type to determine if it's "agent" or "general"
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
      final futures = await Future.wait([
        _getMapSearchData(searchQuery),
      ]);

      mapResults = futures[0] as List<LocalResultData>;

      // Map results are already fetched and will be stored in local field
      print("Map results found: ${mapResults.length}");

      //Get local reviews for top 5 results
      if (mapResults.isNotEmpty) {
        final top5Results = mapResults.take(5).toList();
        final reviewFutures = top5Results
            .where((result) => result.dataId.isNotEmpty)
            .map((result) => _getLocalReviewsData(result.dataId));

        final reviewsData = await Future.wait(reviewFutures);

        // Update mapResults with reviews
        for (int i = 0; i < top5Results.length && i < reviewsData.length; i++) {
          final reviewData = reviewsData[i];
          if (reviewData.reviews.isNotEmpty) {
            final originalResult = top5Results[i];
            final updatedResult = LocalResultData(
              images: reviewData.images.isNotEmpty
                  ? reviewData.images
                  : originalResult.images,
              position: originalResult.position,
              title: originalResult.title,
              placeId: originalResult.placeId,
              dataId: originalResult.dataId,
              dataCid: originalResult.dataCid,
              gpsCoordinates: originalResult.gpsCoordinates,
              placeIdSearch: originalResult.placeIdSearch,
              providerId: originalResult.providerId,
              rating: originalResult.rating,
              reviews: originalResult.reviews,
              price: originalResult.price,
              type: originalResult.type,
              types: originalResult.types,
              typeId: originalResult.typeId,
              typeIds: originalResult.typeIds,
              address: originalResult.address,
              openState: originalResult.openState,
              hours: originalResult.hours,
              operatingHours: originalResult.operatingHours,
              phone: originalResult.phone,
              website: originalResult.website,
              snippet: reviewData.reviews,
            );

            // Replace in mapResults
            final index =
                mapResults.indexWhere((r) => r.dataId == originalResult.dataId);
            if (index != -1) {
              mapResults[index] = updatedResult;
            }
          }
        }
        print(
            "Updated ${reviewsData.where((r) => r.reviews.isNotEmpty).length} results with reviews");
      }

      emit(state.copyWith(
          status: HomePageStatus.success,
          replyStatus: HomeReplyStatus.loading));
    } catch (e) {
      print("Error in parallel search: $e");
    }
    if (_cancelTaskGen) {
      //emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    DateTime searchEndDatetime = DateTime.now();

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

    String? answer = await vercelGenerateReply(
        query,
        formattedResults,
        event.streamedText,
        emit,
        event.imageDescription,
        state.threadData.results
            .getRange(0, state.threadData.results.length - 1)
            .toList(),
        resultData.extractedUrlData);

    ThreadResultData updResultData = ThreadResultData(
      searchType: resultData.searchType,
      extractedUrlData: resultData.extractedUrlData,
      sourceImageDescription: resultData.sourceImageDescription,
      sourceImageLink: resultData.sourceImageLink,
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
      influence: mapResults.map((searchResult) {
        final locationQuery = Uri.encodeComponent(
            "${searchResult.title} ${searchResult.address}");
        return InfluenceData(
            url:
                "https://www.google.com/maps/search/?api=1&query=$locationQuery&query_place_id=${searchResult.placeId}",
            snippet: searchResult.snippet,
            title: searchResult.title,
            similarity: 0);
      }).toList(),
      local: mapResults,
    );

    final updatedResults = List<ThreadResultData>.from(state.threadData.results)
      ..removeLast()
      ..add(updResultData);

    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          email: userEmail,
          isIncognito: state.threadData.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          email: userEmail,
          isIncognito: state.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    if (_cancelTaskGen) {
      //emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        threadData: updThreadData,
        uploadedImageUrl: ""));

    event.imageDescriptionNotifier.value = "";

    if (updThreadData.results.length == 1) {
      await createSession(updThreadData, threadId);
    } else {
      await updateSession(updThreadData, state.threadData.id);
    }

    //Get User Data
    if (userEmail != "") {
      try {
        final db = FirebaseFirestore.instance;

        final querySnapshot = await db
            .collection("threads")
            .where("email", isEqualTo: userEmail)
            .orderBy("createdAt",
                descending: true) // assumes createdAt is stored
            .limit(20)
            .get();

        final userSessionData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return ThreadSessionData.fromJson(data);
        }).toList();
        emit(state.copyWith(threadHistory: userSessionData));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
      }
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";

    String searchQuery = event.query;
    String threadId = state.threadData.id;
    String drisseaApiHost = dotenv.get('API_HOST');
    _cancelTaskGen = false;

    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
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
        isIncognito: state.threadData.isIncognito,
        email: userEmail,
        results: tempUpdatedResults,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now());

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
    try {
      final algoliaAppId = dotenv.get('ALGOLIA_APP_ID');
      final algoliaApiKey = dotenv.get('ALGOLIA_API_KEY');
      final algoliaIndexName = 'ig_reels';
      final algoliaUrl = Uri.parse(
          "https://${algoliaAppId}-dsn.algolia.net/1/indexes/${algoliaIndexName}/query");

      final drisseaUrl = Uri.parse(
          "https://$drisseaApiHost/dev/api/search/source/general?query=${Uri.encodeComponent(searchQuery)}");

      final futures = await Future.wait([
        http.post(
          algoliaUrl,
          headers: {
            'X-Algolia-Application-Id': algoliaAppId,
            'X-Algolia-API-Key': algoliaApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'params': 'query=${Uri.encodeComponent(query)}'}),
        ),
        http.get(
          drisseaUrl,
          headers: {
            'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
            'Content-Type': 'application/json',
          },
        ),
      ]);

      final algoliaResponse = futures[0];
      final drisseaResponse = futures[1];

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
        final Map<String, dynamic> respJson = jsonDecode(drisseaResponse.body);

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
    DateTime searchEndDatetime = DateTime.now();

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

    String? answer = await vercelGenerateReply(
      query,
      formattedResults,
      event.streamedText,
      emit,
      event.imageDescription,
      initialResults,
      resultData.extractedUrlData,
    );

    ThreadResultData updResultData = ThreadResultData(
      searchType: resultData.searchType,
      sourceImageDescription: resultData.sourceImageDescription,
      sourceImageLink: resultData.sourceImageLink,
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
      }).toList(),
      local: resultData.local,
      extractedUrlData: resultData.extractedUrlData,
    );

    final updatedResults = initialResults
      ..removeLast()
      ..add(updResultData);

    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          email: userEmail,
          isIncognito: state.threadData.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          email: userEmail,
          isIncognito: state.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    if (_cancelTaskGen) {
      //emit(state.copyWith(status: HomePageStatus.idle));
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

    //Get User Data
    if (userEmail != "") {
      try {
        final db = FirebaseFirestore.instance;

        final querySnapshot = await db
            .collection("threads")
            .where("email", isEqualTo: userEmail)
            .orderBy("createdAt",
                descending: true) // assumes createdAt is stored
            .limit(20)
            .get();

        final userSessionData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return ThreadSessionData.fromJson(data);
        }).toList();
        emit(state.copyWith(threadHistory: userSessionData));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
      }
    }
  }

  /// Function to search using SerpAPI Google results for Instagram Reels
  Future<void> _updateMapGoogleAnswer(
      HomeUpdateMapAnswer event, Emitter<HomeState> emit) async {
    //Remove the previous result at index and all results after it
    int editIndex = state.editIndex;
    final initialResults = List<ThreadResultData>.from(state.threadData.results)
      ..removeRange(editIndex, state.threadData.results.length);

    String query = event.query;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";

    String searchQuery = event.query;
    String threadId = Uuid().v4().substring(0, 8);
    String drisseaApiHost = dotenv.get('API_HOST');
    _cancelTaskGen = false;

    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
      searchType: state.searchType,
      sourceImageDescription: event.imageDescription,
      sourceImageLink: state.uploadedImageUrl ??
          state.threadData.results[editIndex].sourceImageLink,
      isSearchMode: false,
      extractedUrlData: ExtractedUrlResultData(
        title: event.extractedUrlTitle.value,
        link: event.extractedUrl.value,
        thumbnail: event.extractedImageUrl.value,
        snippet: event.extractedUrlDescription.value,
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
      answer: state.threadData.results[editIndex].answer,
      influence: [],
      local: [],
    );
    List<ExtractedResultInfo> extractedResults = [];

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

    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          isIncognito: state.threadData.isIncognito,
          email: userEmail,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          email: userEmail,
          isIncognito: state.isIncognito,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }

    //Understand the query
    emit(state.copyWith(
        status: HomePageStatus.generateQuery,
        threadData: updThreadData,
        loadingIndex: updThreadData.results.length - 1,
        editStatus: HomeEditStatus.loading));
    try {
      // Generate optimized search query using AI
      final result = await _altUnderstandQuery(
        state.threadData.results
            .where((r) => !r.isSearchMode)
            .toList(), // Only pass non-search mode results for context
        query,
        event.imageDescription,
        state.searchType,
      );
      searchQuery = result.searchQuery;
      // TODO: Use result.type to determine if it's "agent" or "general"
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
      final futures = await Future.wait([
        _getMapSearchData(searchQuery),
      ]);

      mapResults = futures[0];

      // Map results are already fetched and will be stored in local field
      print("Map results found: ${mapResults.length}");

      //Get local reviews for top 5 results
      if (mapResults.isNotEmpty) {
        final top5Results = mapResults.take(5).toList();
        final reviewFutures = top5Results
            .where((result) => result.dataId.isNotEmpty)
            .map((result) => _getLocalReviewsData(result.dataId));

        final reviewsData = await Future.wait(reviewFutures);

        // Update mapResults with reviews
        for (int i = 0; i < top5Results.length && i < reviewsData.length; i++) {
          final reviewData = reviewsData[i];
          if (reviewData.reviews.isNotEmpty) {
            final originalResult = top5Results[i];
            final updatedResult = LocalResultData(
              images: reviewData.images.isNotEmpty
                  ? reviewData.images
                  : originalResult.images,
              position: originalResult.position,
              title: originalResult.title,
              placeId: originalResult.placeId,
              dataId: originalResult.dataId,
              dataCid: originalResult.dataCid,
              gpsCoordinates: originalResult.gpsCoordinates,
              placeIdSearch: originalResult.placeIdSearch,
              providerId: originalResult.providerId,
              rating: originalResult.rating,
              reviews: originalResult.reviews,
              price: originalResult.price,
              type: originalResult.type,
              types: originalResult.types,
              typeId: originalResult.typeId,
              typeIds: originalResult.typeIds,
              address: originalResult.address,
              openState: originalResult.openState,
              hours: originalResult.hours,
              operatingHours: originalResult.operatingHours,
              phone: originalResult.phone,
              website: originalResult.website,
              snippet: reviewData.reviews,
            );

            // Replace in mapResults
            final index =
                mapResults.indexWhere((r) => r.dataId == originalResult.dataId);
            if (index != -1) {
              mapResults[index] = updatedResult;
            }
          }
        }
        print(
            "Updated ${reviewsData.where((r) => r.reviews.isNotEmpty).length} results with reviews");
      }

      emit(state.copyWith(
          status: HomePageStatus.success,
          replyStatus: HomeReplyStatus.loading));
    } catch (e) {
      print("Error in parallel search: $e");
    }
    if (_cancelTaskGen) {
      //emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    DateTime searchEndDatetime = DateTime.now();

    // Get Answer
    //Format watchedVideos to different json structure
    final List<Map<String, String>> formattedResults =
        mapResults.map((searchResult) {
      final locationQuery =
          Uri.encodeComponent("${searchResult.title} ${searchResult.address}");
      return {
        "title": searchResult.title,
        "url":
            "https://www.google.com/maps/search/?api=1&query=$locationQuery&query_place_id=${searchResult.placeId}",
        "snippet": searchResult.snippet.trim(),
      };
    }).toList();

    String? answer = await vercelGenerateReply(
      query,
      formattedResults,
      event.streamedText,
      emit,
      event.imageDescription,
      state.threadData.results
          .getRange(0, state.threadData.results.length - 1)
          .toList(),
      resultData.extractedUrlData,
    );

    ThreadResultData updResultData = ThreadResultData(
      searchType: resultData.searchType,
      extractedUrlData: resultData.extractedUrlData,
      sourceImageDescription: resultData.sourceImageDescription,
      sourceImageLink: resultData.sourceImageLink,
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
      influence: mapResults.map((searchResult) {
        final locationQuery = Uri.encodeComponent(
            "${searchResult.title} ${searchResult.address}");
        return InfluenceData(
            url:
                "https://www.google.com/maps/search/?api=1&query=$locationQuery&query_place_id=${searchResult.placeId}",
            snippet: searchResult.snippet,
            title: searchResult.title,
            similarity: 0);
      }).toList(),
      local: mapResults,
    );

    final updatedResults = initialResults
      ..removeLast()
      ..add(updResultData);

    if (state.threadData.id != "") {
      updThreadData = ThreadSessionData(
          id: state.threadData.id,
          email: userEmail,
          isIncognito: state.threadData.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    } else {
      updThreadData = ThreadSessionData(
          id: threadId,
          email: userEmail,
          isIncognito: state.isIncognito,
          results: updatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    if (_cancelTaskGen) {
      //emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        threadData: updThreadData,
        uploadedImageUrl: "",
        editIndex: -1,
        editQuery: "",
        editStatus: HomeEditStatus.idle));
    event.imageDescriptionNotifier.value = "";

    if (updThreadData.results.length == 1) {
      await createSession(updThreadData, threadId);
    } else {
      await updateSession(updThreadData, state.threadData.id);
    }

    //Get User Data
    if (userEmail != "") {
      try {
        final db = FirebaseFirestore.instance;

        final querySnapshot = await db
            .collection("threads")
            .where("email", isEqualTo: userEmail)
            .orderBy("createdAt",
                descending: true) // assumes createdAt is stored
            .limit(20)
            .get();

        final userSessionData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return ThreadSessionData.fromJson(data);
        }).toList();
        emit(state.copyWith(threadHistory: userSessionData));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
      }
    }
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

  // Generate a reply from Drissea API given a query and search results.
  // Generate a reply from Vercel AI SDK API given a query and search results.
  Future<String?> vercelGenerateReply(
    String query,
    List<Map<String, String>> results,
    ValueNotifier<String> streamedText,
    Emitter<HomeState> emit,
    String imageDescription,
    List<ThreadResultData> previousResults,
    ExtractedUrlResultData? extractedUrlData,
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

You may use the following user context for additional personalization (if relevant):
${jsonEncode(userContext)}
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
    }

    // Step 5: Make the streaming API request to Vercel AI SDK Gateway
    // Correct Vercel AI Gateway URL found via search.
    final url = Uri.parse("https://ai-gateway.vercel.sh/v1/chat/completions");

    final request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
      "Authorization": "Bearer ${dotenv.get("VERCEL_AI_KEY")}",
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
                  "$query ${imageDescription == "" ? "" : "| Here's the image description: $imageDescription"}  ${extractedUrlData?.snippet == "" ? "" : "| Here's the extracted url page description: ${extractedUrlData?.snippet}"}"
                      .trim()
            },
          ]
        },

        {
          "role": "user",
          "content": jsonEncode({
            "results": formattedSources,
            "user_context": userContext,
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
          email: state.threadData.email,
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = prefs.getString("email") ?? "";

    emit(
      state.copyWith(
        status: HomePageStatus.idle,
        threadData: ThreadSessionData(
          id: "",
          isIncognito: false,
          email: "",
          results: [],
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        ),
      ),
    );
  }

  Future<void> _getUserInfo(
      HomeInitialUserData event, Emitter<HomeState> emit) async {
    initMixpanel();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userEmail = prefs.getString("email");
    String? profilePicUrl = prefs.getString("profile_pic_url");
    String? displayName = prefs.getString("displayName");
    UserProfileInfo userData = UserProfileInfo(
        email: userEmail ?? "",
        fullname: displayName ?? "",
        username: "",
        profilePicUrl: profilePicUrl ?? "");
    emit(state.copyWith(
        userData: userData, historyStatus: HomeHistoryStatus.loading));

    //Get User Data
    if (userEmail != null) {
      try {
        final db = FirebaseFirestore.instance;

        final querySnapshot = await db
            .collection("threads")
            .where("email", isEqualTo: userEmail)
            .orderBy("createdAt",
                descending: true) // assumes createdAt is stored
            .limit(20)
            .get();

        final userSessionData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return ThreadSessionData.fromJson(data);
        }).toList();
        print(userSessionData.length);

        emit(state.copyWith(
            threadHistory: userSessionData,
            historyStatus: HomeHistoryStatus.idle));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
      }
    } else {
      emit(state
          .copyWith(threadHistory: [], historyStatus: HomeHistoryStatus.idle));
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void> _handleGoogleSignIn(
      HomeAttemptGoogleSignIn event, Emitter<HomeState> emit) async {
    try {
      //navService.router.pop();
      // Sign out first to force account picker
      await _googleSignIn.signOut();
      await _googleSignIn.initialize();
      print("as");
      //_googleSignIn.
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.authenticate();
      print("");
      print(googleUser);
      print("");
      emit(state.copyWith(profileStatus: HomeProfileStatus.loading));
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          //accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign out of Firebase first
        await FirebaseAuth.instance.signOut();

        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);

        print("User Signed In: ${userCredential.user?.email}");

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('displayName', googleUser.displayName ?? "");
        await prefs.setString('email', googleUser.email);
        await prefs.setString('profile_pic_url', googleUser.photoUrl ?? "");
        await prefs.setBool('isLoggedIn', true);
        await saveUserData(googleUser);
        emit(
          state.copyWith(
            status: HomePageStatus.idle,
            profileStatus: HomeProfileStatus.idle,
            userData: UserProfileInfo(
                username: googleUser?.email.split("@").first ?? "",
                email: googleUser?.email ?? "",
                fullname: googleUser?.displayName ?? "",
                profilePicUrl: googleUser?.photoUrl ?? ""),
          ),
        );
      }

      //Get History Data
      if (googleUser?.email != "") {
        try {
          final db = FirebaseFirestore.instance;
          final querySnapshot = await db
              .collection("threads")
              .where("email", isEqualTo: googleUser?.email)
              .orderBy("createdAt",
                  descending: true) // assumes createdAt is stored
              .limit(20)
              .get();

          final userSessionData = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return ThreadSessionData.fromJson(data);
          }).toList();

          emit(state.copyWith(
              threadHistory: userSessionData,
              historyStatus: HomeHistoryStatus.idle));
        } catch (e) {
          print("❌ Error fetching sessions: $e");
        }
      } else {
        emit(state.copyWith(
            threadHistory: [], historyStatus: HomeHistoryStatus.idle));
      }
    } catch (error) {
      print("Google Sign-In Error: $error");
      emit(state.copyWith(status: HomePageStatus.idle));
    }
  }

  Future<void> saveUserData(GoogleSignInAccount googleUser) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    // Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("users")
        .where('email', isEqualTo: googleUser.email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      print("asdasd");
      // Document with the same email exists, update it
      String documentId = querySnapshot.docs.first.id;
      await db.collection("users").doc(documentId).set({
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true)).then((onValue) {
        print("aaa");
        String username = googleUser.email.split("@").first;
        mixpanel.identify(username);
        mixpanel.track("sign_in");
      }); // Merge to update only specified fields
    } else {
      // Create a new user with a first and last name
      String username = googleUser.email.split("@").first;
      final user = <String, dynamic>{
        "username": username,
        "email": googleUser.email,
        "name": googleUser.displayName ?? "",
        "image": googleUser.photoUrl ?? "",
        "createdAt": DateTime.now().toUtc().toIso8601String(),
        "updatedAt": DateTime.now().toUtc().toIso8601String(),
        "id": "",
        "userId": googleUser.id,
        "sessionToken": "",
        "userAgent": ""
      };
      // Add a new document with a generated ID
      await db.collection("users").add(user).then((onValue) {
        mixpanel.identify(username);
        mixpanel.track("sign_up");
      });
    }
  }

  Future<String?> createSession(
      ThreadSessionData sessionData, String sessionId) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      print(sessionId);
      print("aa");
      print(sessionData.toJson());
      print("aa");

      await firestore
          .collection("threads")
          .doc(sessionId)
          .set(sessionData.toJson());
      print("✅ Session created/updated in Firestore with ID: $sessionId");
      return sessionId;
    } catch (e) {
      print("❌ Firestore session creation failed: $e");
      return null;
    }
  }

  Future<String?> updateSession(
      ThreadSessionData sessionData, String sessionId) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      final docRef = firestore.collection("threads").doc(sessionId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        await docRef.update(sessionData.toJson());
        print("✅ Session updated successfully with ID: $sessionId");
      } else {
        await docRef.set(sessionData.toJson());
        print("🆕 Session created with ID: $sessionId");
      }

      return sessionId;
    } catch (e) {
      print("❌ Firestore session update failed: $e");
      return null;
    }
  }

  //Sign in
}

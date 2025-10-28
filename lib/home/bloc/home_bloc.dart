import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bavi/models/api/retrieve_answer.dart';
import 'package:bavi/models/collection.dart';
import 'package:bavi/models/question_answer.dart';
import 'package:bavi/models/session.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final http.Client httpClient;
  HomeBloc({required this.httpClient}) : super(HomeState()) {
    //Show Me
    on<HomeSwitchSearchType>(_switchSearchType);
    on<HomeSwitchPrivacyType>(_switchPrivacyType);
    on<HomeWatchSearchVideos>(_watchGoogleAnswer);
    on<HomeWatchSearchResults>(_watchGeneralGoogleAnswer);
    on<HomeCancelTaskGen>(_cancelTaskSearchQuery);
    on<HomeInitialUserData>(_getUserInfo);
    on<HomeAttemptGoogleSignIn>(_handleGoogleSignIn);
    on<HomeRetrieveSearchData>(_retrieveSearchData);
    on<HomeRefreshReply>(_refreshReply);
    on<HomeGenScreenshot>(_genScreenshot);
    //on<HomeNavToReply>(_navToReply);
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("home_view");
  }

  //Switch Search Type
  Future<void> _genScreenshot(
    HomeGenScreenshot event,
    Emitter<HomeState> emit,
  ) async {
    // emit(state.copyWith(shareStatus: HomeShareStatus.loading));
    // await Future.delayed(Duration(milliseconds: 300));
    //     try {
    //   // Get the RenderRepaintBoundary
    //   RenderRepaintBoundary boundary = event.globalKey.currentContext!
    //       .findRenderObject() as RenderRepaintBoundary;

    //   // Convert to image
    //   ui.Image image = await boundary.toImage(pixelRatio: 3.0);

    //   // Convert image to bytes
    //   ByteData? byteData =
    //       await image.toByteData(format: ui.ImageByteFormat.png);
    //   Uint8List pngBytes = byteData!.buffer.asUint8List();

    //   // Save to file
    //   final directory = await getApplicationDocumentsDirectory();
    //   final filePath = '${directory.path}/screenshot.png';
    //   final file = File(filePath);
    //   await file.writeAsBytes(pngBytes);

    //   print("✅ Screenshot saved at $filePath");

    // Build the text and url for sharing
    final url = "https://drissea.com/session/${state.sessionId}";
    final actualIsSearchMode =
        state.isSearchMode && state.generalSearchResults.isEmpty
            ? false
            : state.isSearchMode == false && state.searchResults.isEmpty
                ? true
                : state.isSearchMode;
    final text = actualIsSearchMode
        ? "I used Drissea to search '${state.searchQuery}' and go through ${state.generalSearchResults.length} webpages. Here’s what it had to say 👇"
        : "I used Drissea to search '${state.searchQuery}' and watch ${state.searchResults.length} videos without watching. Here’s what it had to say 👇";
    // Share the screenshot with the text and url
    await Share.share("$text\n$url");
    mixpanel
        .track("whatsapp_share_${actualIsSearchMode ? 'search' : 'session'}");
    // } catch (e) {
    //   print("❌ Error capturing screenshot: $e");
    // }
    // emit(state.copyWith(shareStatus: HomeShareStatus.idle));
  }

  //Switch Search Type
  Future<void> _switchSearchType(
    HomeSwitchSearchType event,
    Emitter<HomeState> emit,
  ) async {
    if (event.searchType == "general") {
      emit(state.copyWith(isSearchMode: true));
    } else {
      emit(state.copyWith(isSearchMode: false));
      print(state.isSearchMode);
    }
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
    String drisseaApiHost = dotenv.get('API_HOST');
    mixpanel.timeEvent("fetch_saved_session");
    bool isSearchMode = event.sessionData.isSearchMode;
    print("Search Mode");
    print("");
    print(isSearchMode);

    emit(
      state.copyWith(
        isSearchMode: isSearchMode,
        status: HomePageStatus.success,
        savedStatus: HomeSavedStatus.fetched,
        userQuery: event.sessionData.questions.first,
        sessionData: event.sessionData,
        sessionId: event.sessionData.id,
        totalContentDuration: event.sessionData.contentDuration,
        videosCount: event.sessionData.sourceUrls.length,
        searchQuery: event.sessionData.searchTerms.first,
        searchResults: [],
        videoResults: [],
        shortVideoResults: [],
        generalSearchResults: [],
        searchAnswer: event.sessionData.answers.first,
      ),
    );

    // --- Parallel GET requests for og-extract ---
    if (isSearchMode == false) {
      List<String> sourceUrls = event.sessionData.sourceUrls;
      List<ExtractedVideoInfo> retrievedVideoInfo = [];
      List<ExtractedVideoInfo> updRetrievedVideoInfo = [];
      List<ExtractedVideoInfo> updRetrievedShortVideoInfo = [];
      List<ExtractedVideoInfo> updRetrievedLongVideoInfo = [];
      // Initialize searchResultsInfo with empty thumbnailUrl
      for (var url in sourceUrls) {
        retrievedVideoInfo.add(
          ExtractedVideoInfo(
              searchContent: "",
              caption: "",
              userData: UserData(username: "", fullname: "", profilePicUrl: ""),
              videoData: VideoData(thumbnailUrl: "", videoUrl: url),
              videoId: "",
              platform: Uri.parse(url).host.contains("instagram")
                  ? "instagram"
                  : "youtube",
              videoDescription: "",
              audioDescription: ""),
        );
      }

      final thumbnailFutures = sourceUrls.map((url) async {
        print(url);
        String thumbnailUrl = "";
        try {
          final ogUri = Uri.parse(
              'https://$drisseaApiHost/api/og-extract?url=${Uri.encodeComponent(url)}');
          final ogResponse = await http.get(
            ogUri,
            headers: {
              'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
              'Content-Type': 'application/json',
            },
          );
          if (ogResponse.statusCode == 200) {
            final ogData = jsonDecode(ogResponse.body);
            if (ogData['success'] == true && ogData.containsKey('ogImage')) {
              thumbnailUrl = ogData['ogImage'] ?? "";
            } else {
              thumbnailUrl = "";
            }
          } else {
            thumbnailUrl = "";
          }
        } catch (e) {
          print("OG extract failed for $url: $e");
        }

        // Build the updated video info for this url
        ExtractedVideoInfo updVideoInfo = ExtractedVideoInfo(
            searchContent: "",
            caption: "",
            userData: UserData(username: "", fullname: "", profilePicUrl: ""),
            videoData: VideoData(thumbnailUrl: thumbnailUrl, videoUrl: url),
            videoId: "",
            platform: Uri.parse(url).host.contains("instagram")
                ? "instagram"
                : "youtube",
            videoDescription: "",
            audioDescription: "");

        // Find and replace in retrievedVideoInfo to preserve original order
        final idx = retrievedVideoInfo
            .indexWhere((item) => item.videoData.videoUrl == url);
        if (idx != -1) {
          retrievedVideoInfo[idx] = updVideoInfo;
        }

        // Update short/long lists based on platform and url (leave as before)
        if (updVideoInfo.platform == "instagram" ||
            (updVideoInfo.platform == "youtube" &&
                updVideoInfo.videoData.videoUrl.contains("shorts"))) {
          // Find and replace in short video list
          final shortIdx = updRetrievedShortVideoInfo
              .indexWhere((item) => item.videoData.videoUrl == url);
          if (shortIdx != -1) {
            updRetrievedShortVideoInfo[shortIdx] = updVideoInfo;
          } else {
            updRetrievedShortVideoInfo.add(updVideoInfo);
          }
        } else {
          // Find and replace in long video list
          final longIdx = updRetrievedLongVideoInfo
              .indexWhere((item) => item.videoData.videoUrl == url);
          if (longIdx != -1) {
            updRetrievedLongVideoInfo[longIdx] = updVideoInfo;
          } else {
            updRetrievedLongVideoInfo.add(updVideoInfo);
          }
        }

        // Emit the updated lists, preserving their order
        emit(
          state.copyWith(
              searchResults: List<ExtractedVideoInfo>.from(retrievedVideoInfo),
              shortVideoResults:
                  List<ExtractedVideoInfo>.from(updRetrievedShortVideoInfo),
              videoResults:
                  List<ExtractedVideoInfo>.from(updRetrievedLongVideoInfo),
              generalSearchResults: []),
        );
      }).toList();
      await Future.wait(thumbnailFutures);
      mixpanel.track("fetch_saved_session");
    } else {
      List<String> sourceUrls = event.sessionData.sourceUrls;
      List<ExtractedResultInfo> searchResultsInfo = [];
      // Initialize searchResultsInfo with empty thumbnailUrl
      for (var url in sourceUrls) {
        searchResultsInfo.add(
          ExtractedResultInfo(
              url: url,
              title: "Link ${sourceUrls.indexOf(url) + 1}",
              excerpts: "",
              thumbnailUrl: ""),
        );
      }
      final thumbnailFutures = sourceUrls.map((url) async {
        print(url);
        String thumbnailUrl = "";
        try {
          final ogUri = Uri.parse(
              'https://$drisseaApiHost/api/og-extract?url=${Uri.encodeComponent(url)}');
          final ogResponse = await http.get(
            ogUri,
            headers: {
              'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
              'Content-Type': 'application/json',
            },
          );
          if (ogResponse.statusCode == 200) {
            final ogData = jsonDecode(ogResponse.body);
            if (ogData['success'] == true && ogData.containsKey('ogImage')) {
              thumbnailUrl = ogData['ogImage'] ?? "";
            } else {
              thumbnailUrl = "";
            }
          } else {
            thumbnailUrl = "";
          }
        } catch (e) {
          print("OG extract failed for $url: $e");
        }

        // Find the corresponding item in searchResultsInfo by url and update its thumbnailUrl
        final idx = searchResultsInfo.indexWhere((item) => item.url == url);
        if (idx != -1) {
          // Create new object with updated thumbnailUrl, preserve other fields
          final old = searchResultsInfo[idx];
          searchResultsInfo[idx] = ExtractedResultInfo(
            url: old.url,
            title: old.title,
            excerpts: old.excerpts,
            thumbnailUrl: thumbnailUrl,
          );
        }

        // Emit the updated list (preserving order)
        emit(state.copyWith(
            generalSearchResults:
                List<ExtractedResultInfo>.from(searchResultsInfo),
            searchResults: [],
            videoResults: [],
            shortVideoResults: []));
      }).toList();
      await Future.wait(thumbnailFutures);
      mixpanel.track("fetch_saved_session");
    }
  }

  Future<void> _saveUserTask(
    String initialQuery,
    String searchQuery,
    List<String> sortedResults,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userEmaildId = prefs.getString("email");
    try {
      // Reference to the Firestore collection "users"
      final CollectionReference historyCollection =
          FirebaseFirestore.instance.collection('history');

      await historyCollection.add({
        'username': userEmaildId,
        'initial_query': initialQuery,
        'search_query': searchQuery,
        'final_results': sortedResults,
        'created_at': Timestamp.now(),
        'updated_at': Timestamp.now(),
      });
      print('New collections added successfully');
    } catch (e) {
      print('Error adding video collections: $e');
      // Optionally, you can rethrow the error or handle it differently
      // rethrow;
    }
  }

  Future<bool> checkBackupVidInfo(String videoId, String platform) async {
    bool isAlreadyExtracted = false;
    //Save Extracted Reel Info
    FirebaseFirestore db = FirebaseFirestore.instance;
    //Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("videos")
        .where('videoId', isEqualTo: videoId)
        .where('platform', isEqualTo: platform)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      isAlreadyExtracted = true;
      final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
      await db.collection("videos").doc(querySnapshot.docs.first.id).set({
        'total_extracts': data["total_extracts"] + 1,
        'updated_at': Timestamp.now()
      }, SetOptions(merge: true)); // Merge to update only specified fields
    }
    return isAlreadyExtracted;
  }

  Future<void> chooseAccount(
      HomeAccountSelect event, Emitter<HomeState> emit) async {
    emit(state.copyWith(account: event.accountInfo));
  }

  Future<void> selectSearch(
      HomeSelectSearch event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomePageStatus.idle));
  }

  Future<void> deselectAccount(
      HomeAccountDeselect event, Emitter<HomeState> emit) async {
    emit(state.copyWith(account: ExtractedAccountInfo.empty()));
  }

  //Refresh Reply
  Future<void> _refreshReply(
      HomeRefreshReply event, Emitter<HomeState> emit) async {
    emit(state.copyWith(replyStatus: HomeReplyStatus.loading));
    //Format watchedVideos to different json structure
    String query = state.userQuery;
    List<Map<String, String>> formattedResults = [];
    if (event.isSearchMode == false) {
      formattedResults = state.replyContext.map((video) {
        return {
          "title": "",
          "url": video.sourceUrl,
          "snippet":
              "${video.user.username} | ${video.user.fullname} | ${video.video.caption} | ${video.video.transcription} | ${video.video.framewatch} | ${DateTime.fromMillisecondsSinceEpoch(video.video.timestamp * 1000).toLocal().toString()}"
                  .trim(),
        };
      }).toList();
    } else {
      formattedResults = state.generalSearchResults.map((webpage) {
        return {
          "title": webpage.title,
          "url": webpage.url,
          "snippet": webpage.excerpts,
        };
      }).toList();
    }
    //Come up with Reply
    String? answer;
    try {
      answer = await generateReply(query, formattedResults);
      SessionData updSessionData = SessionData(
          isSearchMode: state.sessionData.isSearchMode,
          sourceUrls: state.replyContext.map((v) => v.sourceUrl).toList(),
          videos: state.replyContext.map((v) => v.video.videoUrl).toList(),
          questions: [query],
          searchTerms: [state.searchQuery],
          answers: [answer ?? ""],
          email: state.sessionData.email,
          createdAt: state.sessionData.createdAt,
          updatedAt: DateTime.now().toUtc(),
          understandDuration: state.sessionData.understandDuration,
          searchDuration: state.sessionData.searchDuration,
          fetchDuration: state.sessionData.fetchDuration,
          extractDuration: state.sessionData.extractDuration,
          contentDuration: state.sessionData.contentDuration);

      await updateSession(updSessionData, state.sessionId);
      emit(state.copyWith(
          replyStatus: HomeReplyStatus.success,
          searchAnswer: answer ?? "Couldn't come up with a reply, try again",
          followupAnswers: [answer ?? ""],
          sessionData: updSessionData,
          followupQuestions: [query]));
    } catch (err) {
      emit(state.copyWith(
          replyStatus: HomeReplyStatus.failure,
          searchAnswer: "Couldn't come up with a reply, try again",
          followupAnswers: [answer ?? ""],
          followupQuestions: [query]));
    }
    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success, searchAnswer: answer));
  }

  /// Function to search using SerpAPI Google results for Instagram Reels
  Future<void> _watchGeneralGoogleAnswer(
      HomeWatchSearchResults event, Emitter<HomeState> emit) async {
    String query = event.query;
    String searchQuery = event.query;
    String drisseaApiHost = dotenv.get('API_HOST');
    _cancelTaskGen = false;

    //Check if previous query or answer is present
    Map<String, dynamic> genSearchReqBody = {};

    if (state.userQuery != "" && state.searchAnswer != "") {
      genSearchReqBody = {
        "task": query,
        "previousQuestion": state.userQuery,
        "previousAnswer": state.searchAnswer,
        "isSearchMode": true
      };
    } else {
      genSearchReqBody = {"task": query, "isSearchMode": true};
    }

    //Understand the query
    DateTime understandStartDatetime = DateTime.now();
    emit(state.copyWith(
        status: HomePageStatus.generateQuery,
        userQuery: query,
        savedStatus: HomeSavedStatus.idle));
    if (state.isIncognito == false) {
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
    }

    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }

    DateTime understandEndDatetime = DateTime.now();
    DateTime searchStartDatetime = DateTime.now();
    // Get Search Results
    emit(state.copyWith(
        status: HomePageStatus.getSearchResults,
        userQuery: query,
        searchQuery: searchQuery,
        searchResults: [],
        searchAnswer: "",
        videoResults: [],
        shortVideoResults: [],
        generalSearchResults: []));
    try {
      final resp = await http.get(
        Uri.parse(
            "https://$drisseaApiHost/dev/api/search/source/general?query=${Uri.encodeComponent(searchQuery)}"),
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 200) {
        final Map<String, dynamic> respJson = jsonDecode(resp.body);
        if (respJson["success"] == true) {
          final List<ExtractedResultInfo> extractedResults =
              (respJson['results'] as List<dynamic>)
                  .map((e) =>
                      ExtractedResultInfo.fromJson(e as Map<String, dynamic>))
                  .toList();
          emit(state.copyWith(
              generalSearchResults: extractedResults,
              status: HomePageStatus.success));
        }
      }
    } catch (e) {
      print("Error in understanding query: $e");
    }
    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    DateTime searchEndDatetime = DateTime.now();
    emit(state.copyWith(
        status: HomePageStatus.success,
        replyStatus: HomeReplyStatus.loading,
        searchAnswer: ""));
    // Set Thumbnails incrementally as each is fetched (concurrently)
    List<ExtractedResultInfo> updSearchResults = [];
    final tasks = state.generalSearchResults.map((searchResult) async {
      String thumbnailUrl = "";
      try {
        final ogUri = Uri.parse(
            'https://$drisseaApiHost/api/og-extract?url=${Uri.encodeComponent(searchResult.url)}');
        final ogResponse = await http.get(
          ogUri,
          headers: {
            'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
            'Content-Type': 'application/json',
          },
        );
        if (ogResponse.statusCode == 200) {
          final ogData = jsonDecode(ogResponse.body);
          if (ogData['success'] == true && ogData.containsKey('ogImage')) {
            thumbnailUrl = ogData['ogImage'] ?? "";
          }
        }
      } catch (e) {
        print("OG extract failed for ${searchResult.url}: $e");
      }

      if (thumbnailUrl.startsWith("/")) {
        final baseUri = Uri.tryParse(searchResult.url);
        if (baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty) {
          thumbnailUrl = "${baseUri.scheme}://${baseUri.host}$thumbnailUrl";
        }
      }
      final searchResultInfo = ExtractedResultInfo(
          url: searchResult.url,
          thumbnailUrl: thumbnailUrl,
          title: searchResult.title,
          excerpts: searchResult.excerpts);
      updSearchResults.add(searchResultInfo);
      print(searchResultInfo);
      emit(state.copyWith(generalSearchResults: List.from(updSearchResults)));
    }).toList();
    Future.wait(tasks);

    // Get Answer (streamed, SSE parsing)
    //Format watchedVideos to different json structure
    final List<Map<String, String>> formattedResults =
        state.generalSearchResults.map((searchResult) {
      return {
        "title": searchResult.title,
        "url": searchResult.url,
        "snippet": searchResult.excerpts.trim(),
      };
    }).toList();

    String? answer = await generateReply(
        state.followupQuestions.isNotEmpty
            ? "Previous Question:${state.followupQuestions.first} | Current Question:$query | Answer the current question without mentioning it as 'current question'"
            : query,
        formattedResults);
    emit(state.copyWith(
        replyStatus: HomeReplyStatus.success,
        searchAnswer: answer,
        followupAnswers: [answer ?? ""],
        followupQuestions: [query]));

    if (answer != null) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userEmail = prefs.getString("email");
      SessionData sessionData = SessionData(
          sourceUrls: state.generalSearchResults.map((v) => v.url).toList(),
          videos: state.generalSearchResults.map((v) => v.url).toList(),
          questions: [query],
          searchTerms: [searchQuery],
          answers: [answer ?? ""],
          email: userEmail ?? "",
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          understandDuration: understandEndDatetime
              .difference(understandStartDatetime)
              .inSeconds,
          searchDuration:
              searchEndDatetime.difference(searchStartDatetime).inSeconds,
          fetchDuration: 0,
          extractDuration: 0,
          contentDuration: 0,
          isSearchMode: true);
      String? sessionId = await createSession(sessionData);
      emit(state.copyWith(sessionId: sessionId, sessionData: sessionData));
    }
    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }

    //Update search history
    String userEmail = state.isIncognito ? "" : state.userData.email;
    //Get User Data
    if (userEmail != "") {
      try {
        emit(state.copyWith(historyStatus: HomeHistoryStatus.loading));
        final db = FirebaseFirestore.instance;

        final querySnapshot = await db
            .collection("sessions")
            .where("email", isEqualTo: userEmail)
            .orderBy("createdAt",
                descending: true) // assumes createdAt is stored
            .limit(20)
            .get();

        final userSessionData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return SessionData(
            isSearchMode: true,
            sourceUrls: List<String>.from(data['sourceUrls'] ?? []),
            videos: List<String>.from(data['videos'] ?? []),
            questions: List<String>.from(data['questions'] ?? []),
            searchTerms: List<String>.from(data['searchTerms'] ?? []),
            answers: List<String>.from(data['answers'] ?? []),
            email: data['email'] ?? '',
            understandDuration: data['understandDuration'] ?? 0,
            searchDuration: data['searchDuration'] ?? 0,
            fetchDuration: data['fetchDuration'] ?? 0,
            extractDuration: data['extractDuration'] ?? 0,
            contentDuration: data['contentDuration'] ?? 0,
            createdAt: data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate().toLocal()
                : (DateTime.tryParse(data['createdAt'] ?? '')?.toLocal() ??
                    DateTime.now().toLocal()),
            updatedAt: data['updatedAt'] is Timestamp
                ? (data['updatedAt'] as Timestamp).toDate().toLocal()
                : (DateTime.tryParse(data['updatedAt'] ?? '')?.toLocal() ??
                    DateTime.now().toLocal()),
          );
        }).toList();

        emit(state.copyWith(
            sessionHistory: userSessionData,
            historyStatus: HomeHistoryStatus.idle));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
        emit(state.copyWith(historyStatus: HomeHistoryStatus.idle));
      }
    } else {
      if (state.isIncognito) {
        emit(state.copyWith(historyStatus: HomeHistoryStatus.idle));
      } else {
        emit(state.copyWith(
            sessionHistory: [], historyStatus: HomeHistoryStatus.idle));
      }
    }
  }

  /// Function to search using SerpAPI Google results for Instagram Reels
  Future<void> _watchGoogleAnswer(
      HomeWatchSearchVideos event, Emitter<HomeState> emit) async {
    //mixpanel.timeEvent("watch_answer_result");
    String query = event.query;
    String searchQuery = event.query;
    String drisseaApiHost = dotenv.get('API_HOST');
    DateTime startDatetime = DateTime.now();
    _cancelTaskGen = false;
    //Understand the query
    DateTime understandStartDatetime = DateTime.now();

    //Check if previous query or answer is present
    Map<String, String> genSearchReqBody = {};

    if (state.userQuery != "" && state.searchAnswer != "") {
      genSearchReqBody = {
        "task": query,
        "previousQuestion": state.userQuery,
        "previousAnswer": state.searchAnswer
      };
    } else {
      genSearchReqBody = {"task": query};
    }

    emit(state.copyWith(
        status: HomePageStatus.generateQuery,
        userQuery: query,
        savedStatus: HomeSavedStatus.idle));
    if (state.isIncognito == false) {
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
    }
    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    DateTime understandEndDatetime = DateTime.now();
    DateTime searchStartDatetime = DateTime.now();
    List<String> sourceLinks = [];
    if (searchQuery != "") {
      //Get Search Results
      emit(state.copyWith(
          status: HomePageStatus.getSearchResults,
          searchQuery: searchQuery,
          searchResults: [],
          searchAnswer: "",
          videoResults: [],
          shortVideoResults: [],
          generalSearchResults: []));
      final searchResultUrl = Uri.parse(
          'https://$drisseaApiHost/api/search/source?query=$searchQuery');
      final searchResultResponse = await http.get(
        searchResultUrl,
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
          'Content-Type': 'application/json',
        },
      );
      final Map<String, dynamic> searchResultData =
          jsonDecode(searchResultResponse.body);
      print(searchResultData);
      sourceLinks = (searchResultData['source_links'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
    }

    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }

    DateTime searchEndDatetime = DateTime.now();
    DateTime fetchStartDatetime = DateTime.now();
    List<ResultVideoItem> getResultVideosData = [];
    if (sourceLinks.isNotEmpty) {
      //Fetch source videos data
      emit(state.copyWith(
          status: HomePageStatus.getResultVideos,
          videosCount: sourceLinks.length));
      final getResultVideosUrl =
          Uri.parse('https://$drisseaApiHost/dev/api/fetch/source');
      final body = jsonEncode({"urls": sourceLinks});
      final getResultVideosResponse = await http.post(
        getResultVideosUrl,
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      print(getResultVideosResponse.body);
      final Map<String, dynamic> getResultVideosResponseData =
          jsonDecode(getResultVideosResponse.body);
      print(getResultVideosResponseData);
      getResultVideosData =
          (getResultVideosResponseData['data'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((e) => ResultVideoItem.fromJson(e))
                  .toList() ??
              [];

      // Remove videos longer than 1 hour
      getResultVideosData = getResultVideosData
          .where((video) => video.video.duration <= 2400)
          .toList();

      // Ensure total duration of all videos does not exceed 1 hour
      double cumulativeDuration = 0;
      List<ResultVideoItem> limitedVideos = [];
      for (final video in getResultVideosData) {
        if (cumulativeDuration + video.video.duration <= 2400) {
          limitedVideos.add(video);
          cumulativeDuration += video.video.duration;
        } else {
          continue;
        }
      }
      getResultVideosData = limitedVideos;
    }
    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }

    DateTime fetchEndDatetime = DateTime.now();
    DateTime watchStartDatetime = DateTime.now();

    List<ResultVideoItem> watchedVideos = [];
    if (getResultVideosData.isNotEmpty) {
      //Watch source videos data
      emit(state.copyWith(
          status: HomePageStatus.watchResultVideos,
          videosCount: getResultVideosData.length));
      try {
        final watchUrl =
            Uri.parse('https://$drisseaApiHost/dev/api/extract/source');
        final watchBody = jsonEncode({
          "videos": getResultVideosData.map((v) => v.toJson()).toList(),
        });
        final watchResp = await http.post(
          watchUrl,
          headers: {
            'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
            'Content-Type': 'application/json',
          },
          body: watchBody,
        );
        if (watchResp.statusCode == 200) {
          final Map<String, dynamic> watchJson = jsonDecode(watchResp.body);
          watchedVideos = (watchJson['data'] as List<dynamic>?)
                  ?.map((e) =>
                      ResultVideoItem.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          // // rerank videos according to query
          // List<String> videoSnippets = watchedVideos.map((video) {
          //   return "${video.user.username} | ${video.user.fullname} | ${video.video.caption} | ${video.video.transcription} | ${video.video.framewatch} | ${DateTime.fromMillisecondsSinceEpoch(video.video.timestamp * 1000).toLocal().toString()}"
          //       .trim();
          // }).toList();
          // List<String> rerankedSnippets =
          //     await rerankSnippets(query: query, documents: videoSnippets);
          // // Reorder watchedVideos according to rerankedSnippets order
          // watchedVideos = rerankedSnippets.map((snippet) {
          //   final idx = videoSnippets.indexOf(snippet);
          //   return watchedVideos[idx];
          // }).toList();
        } else {
          getResultVideosData.forEach(
            (element) {
              print(element.sourceUrl);
            },
          );
          print(
              "❌ Summarize API failed: ${watchResp.statusCode} - ${watchResp.body}");
        }
      } catch (e) {
        print("❌ Error calling summarize API: $e");
      }
    }

    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }

    DateTime watchEndDatetime = DateTime.now();

    int totalContentDuration = 0;
    if (watchedVideos.isNotEmpty) {
      //Convert the watched videos to ExtractedVideoInfo type
      List<ExtractedVideoInfo> videos = watchedVideos.map((result) {
        //totalContentDuration += result.video.duration.toInt();
        return ExtractedVideoInfo(
          videoId: result.video.id,
          platform: Uri.parse(result.sourceUrl).host.contains("instagram")
              ? "instagram"
              : "youtube",
          searchContent:
              "${result.user.username}, ${result.user.fullname}, ${result.video.caption}, ${result.video.transcription}",
          caption: result.video.caption,
          videoDescription: result.video.framewatch,
          audioDescription: result.video.transcription,
          userData: UserData(
            username: result.user.username,
            fullname: result.user.fullname,
            profilePicUrl: "", // Not provided in ResultVideoUser
          ),
          videoData: VideoData(
            thumbnailUrl: result.video.thumbnailUrl,
            videoUrl: result.sourceUrl,
          ),
        );
      }).toList();

      List<ExtractedVideoInfo> shortVideos = watchedVideos.where((result) {
        final url = result.sourceUrl.toLowerCase();
        return url.contains("reel") ||
            url.contains("reels") ||
            url.contains("shorts");
      }).map((result) {
        totalContentDuration += result.video.duration.toInt();
        return ExtractedVideoInfo(
          videoId: result.video.id,
          platform: Uri.parse(result.sourceUrl).host.contains("instagram")
              ? "instagram"
              : "youtube",
          searchContent:
              "${result.user.username}, ${result.user.fullname}, ${result.video.caption}, ${result.video.transcription}",
          caption: result.video.caption,
          videoDescription: result.video.framewatch,
          audioDescription: result.video.transcription,
          userData: UserData(
            username: result.user.username,
            fullname: result.user.fullname,
            profilePicUrl: "", // Not provided in ResultVideoUser
          ),
          videoData: VideoData(
            thumbnailUrl: result.video.thumbnailUrl,
            videoUrl: result.video.videoUrl,
          ),
        );
      }).toList();

      List<ExtractedVideoInfo> longVideos = watchedVideos.where((result) {
        final url = result.sourceUrl.toLowerCase();
        return url.contains("watch");
      }).map((result) {
        totalContentDuration += result.video.duration.toInt();
        print(totalContentDuration);
        return ExtractedVideoInfo(
          videoId: result.video.id,
          platform: Uri.parse(result.sourceUrl).host.contains("instagram")
              ? "instagram"
              : "youtube",
          searchContent:
              "${result.user.username}, ${result.user.fullname}, ${result.video.caption}, ${result.video.transcription}",
          caption: result.video.caption,
          videoDescription: result.video.framewatch,
          audioDescription: result.video.transcription,
          userData: UserData(
            username: result.user.username,
            fullname: result.user.fullname,
            profilePicUrl: "", // Not provided in ResultVideoUser
          ),
          videoData: VideoData(
            thumbnailUrl: result.video.thumbnailUrl,
            videoUrl: result.video.videoUrl,
          ),
        );
      }).toList();

      DateTime endDatetime = DateTime.now();

      emit(state.copyWith(
          status: HomePageStatus.success,
          replyStatus: HomeReplyStatus.loading,
          videosCount: videos.length,
          searchResults: videos,
          shortVideoResults: shortVideos,
          videoResults: longVideos,
          userQuery: query,
          searchQuery: searchQuery,
          totalContentDuration: totalContentDuration));

      //Format watchedVideos to different json structure
      final List<Map<String, String>> formattedResults =
          watchedVideos.map((video) {
        return {
          "title": "",
          "url": video.sourceUrl,
          "snippet":
              "${video.user.username} | ${video.user.fullname} | ${video.video.caption} | ${video.video.transcription} | ${video.video.framewatch} | ${DateTime.fromMillisecondsSinceEpoch(video.video.timestamp * 1000).toLocal().toString()}"
                  .trim(),
        };
      }).toList();
      //Come up with Reply
      String? answer;
      try {
        answer = await generateReply(query, formattedResults);
        emit(state.copyWith(
            replyStatus: HomeReplyStatus.success,
            replyContext: watchedVideos,
            searchAnswer: answer ?? "Couldn't come up with a reply, try again",
            followupAnswers: [answer ?? ""],
            followupQuestions: [query]));
      } catch (err) {
        emit(state.copyWith(
            replyStatus: HomeReplyStatus.failure,
            replyContext: watchedVideos,
            searchAnswer: "Couldn't come up with a reply, try again",
            followupAnswers: [answer ?? ""],
            followupQuestions: [query]));
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userEmail = prefs.getString("email");
      SessionData sessionData = SessionData(
          isSearchMode: false,
          sourceUrls: watchedVideos.map((v) => v.sourceUrl).toList(),
          videos: watchedVideos.map((v) => v.video.videoUrl).toList(),
          questions: [query],
          searchTerms: [searchQuery],
          answers: [answer ?? ""],
          email: userEmail ?? "",
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          understandDuration: understandEndDatetime
              .difference(understandStartDatetime)
              .inSeconds,
          searchDuration:
              searchEndDatetime.difference(searchStartDatetime).inSeconds,
          fetchDuration:
              fetchEndDatetime.difference(fetchStartDatetime).inSeconds,
          extractDuration:
              watchEndDatetime.difference(watchStartDatetime).inSeconds,
          contentDuration: totalContentDuration);
      String? sessionId = await createSession(sessionData);
      emit(state.copyWith(sessionId: sessionId, sessionData: sessionData));
    }

    //Update search history
    String userEmail = state.isIncognito ? "" : state.userData.email;
    //Get User Data
    if (userEmail != "") {
      try {
        emit(state.copyWith(historyStatus: HomeHistoryStatus.loading));
        final db = FirebaseFirestore.instance;

        final querySnapshot = await db
            .collection("sessions")
            .where("email", isEqualTo: userEmail)
            .orderBy("createdAt",
                descending: true) // assumes createdAt is stored
            .limit(20)
            .get();

        final userSessionData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return SessionData(
            isSearchMode: false,
            sourceUrls: List<String>.from(data['sourceUrls'] ?? []),
            videos: List<String>.from(data['videos'] ?? []),
            questions: List<String>.from(data['questions'] ?? []),
            searchTerms: List<String>.from(data['searchTerms'] ?? []),
            answers: List<String>.from(data['answers'] ?? []),
            email: data['email'] ?? '',
            understandDuration: data['understandDuration'] ?? 0,
            searchDuration: data['searchDuration'] ?? 0,
            fetchDuration: data['fetchDuration'] ?? 0,
            extractDuration: data['extractDuration'] ?? 0,
            contentDuration: data['contentDuration'] ?? 0,
            createdAt: data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate().toLocal()
                : (DateTime.tryParse(data['createdAt'] ?? '')?.toLocal() ??
                    DateTime.now().toLocal()),
            updatedAt: data['updatedAt'] is Timestamp
                ? (data['updatedAt'] as Timestamp).toDate().toLocal()
                : (DateTime.tryParse(data['updatedAt'] ?? '')?.toLocal() ??
                    DateTime.now().toLocal()),
          );
        }).toList();

        emit(state.copyWith(
            sessionHistory: userSessionData,
            historyStatus: HomeHistoryStatus.idle));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
        emit(state.copyWith(historyStatus: HomeHistoryStatus.idle));
      }
    } else {
      if (state.isIncognito) {
        emit(state.copyWith(historyStatus: HomeHistoryStatus.idle));
      } else {
        emit(state.copyWith(
            sessionHistory: [], historyStatus: HomeHistoryStatus.idle));
      }
    }

    // navService.goTo(
    //   "/reply",
    //   extra: event.searchId == ""
    //       ? {
    //           "videos": videos,
    //           'query': event.query,
    //           'isGlanceMode': false,
    //           "searchTime": endDatetime.difference(startDatetime).inMilliseconds
    //         }
    //       : {
    //           "searchId": event.searchId,
    //           "videos": videos,
    //           'query': event.query,
    //           'isGlanceMode': false,
    //           "searchTime": endDatetime.difference(startDatetime).inMilliseconds
    //         },
    // );
    // } else {
    //   print("❌ Serp API failed: ${response.body}");
    //   emit(state.copyWith(status: HomePageStatus.idle));
    // }
    //mixpanel.track("watch_answer_result");
  }

  //Rerank Snippets

  Future<List<String>> rerankSnippets({
    required String query,
    required List<String> documents,
  }) async {
    try {
      final url = Uri.parse("https://api.jina.ai/v1/rerank");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${dotenv.get("JINA_API_KEY")}",
        },
        body: jsonEncode({
          "model": "jina-reranker-v2-base-multilingual",
          "query": query,
          "top_n": 10,
          "documents": documents,
          "return_documents": false,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        final List<dynamic> results = data["results"] ?? [];

        // Sort results by index and map back to documents
        final reorderedDocs = results
            .map((r) => r as Map<String, dynamic>)
            .toList()
          ..sort((a, b) => (a["index"] as int).compareTo(b["index"] as int));

        return reorderedDocs.map((r) => documents[r["index"] as int]).toList();
      } else {
        print("❌ Failed to rerank: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Exception during rerank: $e");
      return [];
    }
  }

  Future<ExtractedVideoInfo> _enrichVideoWithOgData(
      ExtractedVideoInfo video) async {
    String caption = video.caption;
    String searchContent = video.searchContent;
    String thumbnailUrl = "";
    String videoUrl = "";

    final ogHost = dotenv.get('API_HOST');
    final ogUri = Uri.parse(
        'https://$ogHost/api/og-extract?url=${Uri.encodeComponent(video.videoData.videoUrl)}');

    try {
      final ogResponse = await http.get(
        ogUri,
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
          'Content-Type': 'application/json',
        },
      );
      if (ogResponse.statusCode == 200) {
        final ogData = jsonDecode(ogResponse.body);
        print(ogData);
        if (ogData['success'] == true) {
          thumbnailUrl = ogData['ogImage'] ?? video.videoData.thumbnailUrl;
          print(thumbnailUrl);
          videoUrl = video.videoData.videoUrl;
          caption = ogData['ogDescription'] ?? caption;
          searchContent =
              "${video.searchContent} ${ogData['ogTitle']}, ${ogData['ogDescription']}"
                  .trim();
        }
      }
    } catch (e) {
      print("OG extract failed for ${video.videoData.videoUrl}: $e");
    }

    return ExtractedVideoInfo(
      videoId: video.videoId,
      platform: video.platform,
      caption: caption,
      searchContent: searchContent,
      videoDescription: video.videoDescription,
      audioDescription: video.audioDescription,
      userData: video.userData,
      videoData: VideoData(
        thumbnailUrl: thumbnailUrl,
        videoUrl: videoUrl,
      ),
    );
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

  Future<ExtractedVideoInfo> _enrichVideoWithWatchData(
      ExtractedVideoInfo video) async {
    String caption = video.caption;
    String searchContent = video.searchContent;
    String thumbnailUrl = "";
    String videoUrl = "";
    String audioDescription = "";

    final ogHost = dotenv.get('API_HOST');
    final ogUri = Uri.parse(
        'https://$ogHost/api/instagram/extract/reel?url=${Uri.encodeComponent(video.videoData.videoUrl)}');

    try {
      final ogResponse = await http.get(
        ogUri,
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
        },
      );
      if (ogResponse.statusCode == 200) {
        final ogData = jsonDecode(ogResponse.body);
        if (ogData['success'] == true) {
          final user = ogData['data']['user'];
          final videoJson = ogData['data']['video'];
          thumbnailUrl =
              videoJson['thumbnail_url'] ?? video.videoData.thumbnailUrl;
          videoUrl = video.videoData.videoUrl;
          audioDescription = videoJson['transcription'];
          caption = videoJson['caption'] ?? caption;
          searchContent =
              "${video.searchContent} ${user['fullname']}, ${videoJson['caption']}, ${videoJson['transcription']}"
                  .trim();
        }
      }
    } catch (e) {
      print("OG extract failed for ${video.videoData.videoUrl}: $e");
    }

    return ExtractedVideoInfo(
      videoId: video.videoId,
      platform: video.platform,
      caption: caption,
      searchContent: searchContent,
      videoDescription: video.videoDescription,
      audioDescription: audioDescription,
      userData: video.userData,
      videoData: VideoData(
        thumbnailUrl: thumbnailUrl,
        videoUrl: videoUrl,
      ),
    );
  }

  Future<String?> generateMarkdownStyledAnswer({
    required List<ExtractedVideoInfo> videos,
    required String userQuery,
  }) async {
    final prompt = StringBuffer()
      ..writeln(
          "You are a helpful and concise assistant that answers user questions using a list of insights extracted from short videos.")
      ..writeln("")
      ..writeln("The user has asked:")
      ..writeln("\"$userQuery\"")
      ..writeln("")
      ..writeln(
          "You are given brief content summaries from multiple videos. Each including a caption, video description and audio description from the respective short video")
      ..writeln("")
      ..writeln(
          "Your job is to write a clean, readable answer based only on the Caption/Transcript/Video Description available. Follow these rules:")
      ..writeln("")
      ..writeln("1. ✅ Structure the response clearly")
      ..writeln(
          "2. ✅ **Bold key insights** and highlight notable places, dishes, or experiences.")
      ..writeln(
          "3. ✅ For any place, food item, or experience that was featured in a video, wrap the **main word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
      ..writeln(
          "4. ✅ Write naturally as if you're recommending or informing — never say “based on search results” or “these videos say.”")
      ..writeln(
          "5. From the Caption/Transcript/Video Description available, only use those that exactly answers the query. And the answer should be exactly according to the query")
      ..writeln(
          "6. ✅ If no strong or direct matches are found, gracefully say:  \n   _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_")
      ..writeln("6. ❌ Do not repeat the question or use generic filler lines.")
      ..writeln(
          "7. ⚡ Keep your language short, engaging, and optimized for mobile readability.")
      ..writeln("")
      ..writeln("Here’s the video content:\n");

    for (final video in videos) {
      prompt.writeln("Caption: ${video.caption}");
      prompt.writeln("Transcript: ${video.audioDescription}");
      prompt.writeln("Video Description: ${video.videoDescription}");
      prompt.writeln(
          "Video URL: https://www.instagram.com/${video.userData.username}/reel/${video.videoId}");
      prompt.writeln("---");
    }

    final response = await http.post(
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer ${dotenv.get("GROQ_API_KEY")}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "deepseek-r1-distill-llama-70b",
        "messages": [
          {
            "role": "user",
            "content": prompt.toString(),
          }
        ],
        "temperature": 0.3,
        "max_tokens": 1000,
      }),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final json = jsonDecode(decodedBody);
      return json["choices"][0]["message"]["content"];
    } else {
      print("❌ Groq API Error: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  Future<String?> newAltGenerateMarkdownStyledAnswer({
    required ExtractedVideoInfo video,
    required String userQuery,
  }) async {
    final prompt = StringBuffer()
      ..writeln(
          "You are a helpful and concise assistant that answers user questions using a list of insights extracted from short videos.")
      ..writeln("")
      ..writeln(
          "You are given brief content of a particular video. Each including a caption, video description and audio description from the respective short video")
      ..writeln("")
      ..writeln(
          "Your job is to write a clean, readable answer based only on the content available. Follow these rules:")
      ..writeln("")
      ..writeln(
          "4. ✅ Write naturally as if you're recommending or informing — never say “based on search results” or “these videos say.”")
      ..writeln(
          "5. ✅ If given content can't be used to answer the query, then tell that you wouldn't be able to answer their query and then psegue into explaining about what the video is")
      ..writeln("6. ❌ Do not repeat the question or use generic filler lines.")
      ..writeln(
          "7. ⚡ Keep your language short, engaging, and optimized for mobile readability.")
      ..writeln("6. Keep the answer in under 250 characters.")
      ..writeln("")
      ..writeln("Here’s the video content:\n");

    prompt.writeln("Caption: ${video.caption}");
    prompt.writeln("Transcript: ${video.audioDescription}");
    prompt.writeln("Video Description: ${video.videoDescription}");
    prompt.writeln(
        "Video URL: https://www.instagram.com/${video.userData.username}/reel/${video.videoId}");
    prompt.writeln("---");

    final response = await http.post(
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer ${dotenv.get("GROQ_API_KEY")}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gemma2-9b-it",
        "messages": [
          {"role": "system", "content": prompt.toString()},
          {
            "role": "user",
            "content": userQuery,
          }
        ],
        "temperature": 0,
        "max_tokens": 500,
      }),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final json = jsonDecode(decodedBody);
      return json["choices"][0]["message"]["content"];
    } else {
      print("❌ Groq API Error: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  Future<String?> altGenerateMarkdownStyledAnswer({
    required ExtractedVideoInfo video,
    required String userQuery,
  }) async {
    final prompt = StringBuffer()
      ..writeln(
          "You are a helpful and concise assistant that answers user questions using a list of insights extracted from short videos.")
      ..writeln("")
      ..writeln("The user has asked:")
      ..writeln("\"$userQuery\"")
      ..writeln("")
      ..writeln(
          "You are given brief content summaries from multiple videos. Each including a caption, video description and audio description from the respective short video")
      ..writeln("")
      ..writeln(
          "Your job is to write a clean, readable answer based only on the content available. Follow these rules:")
      ..writeln("")
      ..writeln(
          "1. ✅ Structure the response clearly using bullet points when appropriate.")
      ..writeln(
          "4. ✅ Write naturally as if you're recommending or informing — never say “based on search results” or “these videos say.”")
      ..writeln(
          "5. ✅ If given content can't be used to answer the query, gracefully say:  \n   _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_")
      ..writeln("6. ❌ Do not repeat the question or use generic filler lines.")
      ..writeln(
          "7. ⚡ Keep your language short, engaging, and optimized for mobile readability.")
      ..writeln("6. Keep the answer in under 250 characters.")
      ..writeln("")
      ..writeln("Here’s the video content:\n");

    prompt.writeln("Caption: ${video.caption}");
    prompt.writeln("Transcript: ${video.audioDescription}");
    prompt.writeln("Video Description: ${video.videoDescription}");
    prompt.writeln(
        "Video URL: https://www.instagram.com/${video.userData.username}/reel/${video.videoId}");
    prompt.writeln("---");

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer ${dotenv.get("OPENAI_API_KEY")}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "user",
            "content": prompt.toString(),
          }
        ],
        "temperature": 0.5,
        "max_tokens": 100,
      }),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final json = jsonDecode(decodedBody);
      return json["choices"][0]["message"]["content"];
    } else {
      print("❌ Error: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  Future<void> backupExtractedData(Map<String, dynamic> extractedData,
      String videoId, String platform) async {
    //Save Extracted Reel Info
    FirebaseFirestore db = FirebaseFirestore.instance;
    //Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("videos")
        .where('videoId', isEqualTo: videoId)
        .where('platform', isEqualTo: platform)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      // Document with the same id exists, update it
      String documentId = querySnapshot.docs.first.id;
      int totalExtracts = querySnapshot.docs.first.get("total_extracts") ?? 0;
      await db.collection("videos").doc(documentId).set(
          {'total_extracts': totalExtracts + 1, 'updated_at': Timestamp.now()},
          SetOptions(merge: true)); // Merge to update only specified fields
    } else {
      // Add a new document with a generated ID
      await db.collection("videos").add(extractedData);
    }
  }

  //Get relevant search query from task
  bool _cancelTaskGen = false;
  //Cancel Gen Task
  Future<void> _cancelTaskSearchQuery(
      HomeCancelTaskGen event, Emitter<HomeState> emit) async {
    _cancelTaskGen = true;
    emit(state.copyWith(status: HomePageStatus.idle));
  }

  Future<String> _getTaskSearchQuery(String task) async {
    String query = "";

    final url = Uri.https(
      "api.openai.com",
      '/v1/responses',
    );

    final headers = {
      'Authorization': "Bearer ${dotenv.get("OPENAI_API_KEY")}",
      "Content-Type": "application/json"
    };

    final body = jsonEncode({
      "model": "gpt-4o-mini", //"gpt-3.5-turbo",
      "input": [
        {
          "role": "system",
          "content":
              "You are a helpful assistant. The user will ask factual or recommendation-based questions such as:\n- Best bar in Bangalore\n- Famous momo place in Delhi\n- Best cheap perfumes for men\n\nYour job is to:\n\n1. Identify the correct answer (e.g., a place, brand, or name).\n2. Combine the answer with any relevant part of the question (like location, target audience, or category).\n3. Return only a concise, lowercase search phrase.\n\n Do NOT rephrase the question.\n Do NOT explain the answer.\n DO include the actual answer (e.g., \"tonic and toast bangalore\").\n\nReturn only the final search query — no labels, no punctuation, no formatting."
        },
        {"role": "user", "content": task}
      ],
      "temperature": 1
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      // Successfully fetched data
      final data = response.body;
      Map<String, dynamic> respData = jsonDecode(data);
      if (respData["output"].isNotEmpty) {
        List<Map<String, dynamic>> outputList =
            List<Map<String, dynamic>>.from(respData["output"]);
        List<Map<String, dynamic>> searchQueryData =
            List<Map<String, dynamic>>.from(outputList.first["content"]);
        if (searchQueryData.isNotEmpty) {
          query = searchQueryData.first["text"];
        }
      }
    } else {
      // Handle error
      print('Failed to load data: ${response.body}');
    }
    return query;
  }

  //Choose right video
  Future<List<ExtractedVideoInfo>> _chooseTaskRightVideo(
      String query, List<ExtractedVideoInfo> searchResults) async {
    List<int> taskResultVideoIds = [];
    final url = Uri.https(
      "api.openai.com",
      '/v1/responses',
    );

    final headers = {
      'Authorization': "Bearer ${dotenv.get("OPENAI_API_KEY")}",
      "Content-Type": "application/json"
    };

    //Make Request body
    List<Map<String, dynamic>> inputBodyList = [
      {
        "role": "system",
        "content":
            "You are a helpful assistant that selects the most relevant video from a list of results based on a user's query. Sort nad return the list of `id` of the best-matching items. No explanation or formatting."
      },
    ];

    List<Map<String, dynamic>> contentUserBody = [
      {"type": "input_text", "text": "Query: $query"},
    ];
    int i = 0;
    for (ExtractedVideoInfo videoInfo in searchResults) {
      Map<String, dynamic> videoInputData = {
        "id": i.toString(),
        "data": videoInfo.toJson()
      };
      Map<String, dynamic> videoInput = {
        "type": "input_text",
        "text": jsonEncode(videoInputData)
      };
      contentUserBody.add(videoInput);
      i++;
    }

    inputBodyList.add({"role": "user", "content": contentUserBody});

    final body = jsonEncode({
      "model": "gpt-4o-mini", //"gpt-3.5-turbo",
      "input": inputBodyList,
      "temperature": 0.2
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      // Successfully fetched data
      final data = response.body;
      Map<String, dynamic> respData = jsonDecode(data);
      if (respData["output"].isNotEmpty) {
        List<Map<String, dynamic>> outputList =
            List<Map<String, dynamic>>.from(respData["output"]);
        List<Map<String, dynamic>> searchQueryData =
            List<Map<String, dynamic>>.from(outputList.first["content"]);
        if (searchQueryData.isNotEmpty) {
          String taskResultVideoIdsResult = searchQueryData.first["text"];
          taskResultVideoIds =
              json.decode(taskResultVideoIdsResult).cast<int>().toList();
          taskResultVideoIds = taskResultVideoIds.length > 3
              ? taskResultVideoIds.sublist(0, 3)
              : taskResultVideoIds;
        }
      }
    } else {
      // Handle error
      print('Failed to load data: ${response.body}');
    }

    //Get Right Videos
    List<ExtractedVideoInfo> updTaskResultVideos = [];
    for (int resultId in taskResultVideoIds) {
      ExtractedVideoInfo taskResultVideoInfo = searchResults[resultId];
      updTaskResultVideos.add(taskResultVideoInfo);
    }

    return updTaskResultVideos;
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
            .collection("sessions")
            .where("email", isEqualTo: userEmail)
            .orderBy("createdAt",
                descending: true) // assumes createdAt is stored
            .limit(20)
            .get();

        final userSessionData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return SessionData(
            isSearchMode: data['isSearchMode'] ?? false,
            id: doc.id,
            sourceUrls: List<String>.from(data['sourceUrls'] ?? []),
            videos: List<String>.from(data['videos'] ?? []),
            questions: List<String>.from(data['questions'] ?? []),
            searchTerms: List<String>.from(data['searchTerms'] ?? []),
            answers: List<String>.from(data['answers'] ?? []),
            email: data['email'] ?? '',
            understandDuration: data['understandDuration'] ?? 0,
            searchDuration: data['searchDuration'] ?? 0,
            fetchDuration: data['fetchDuration'] ?? 0,
            extractDuration: data['extractDuration'] ?? 0,
            contentDuration: data['contentDuration'] ?? 0,
            createdAt: data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate().toLocal()
                : (DateTime.tryParse(data['createdAt'] ?? '')?.toLocal() ??
                    DateTime.now().toLocal()),
            updatedAt: data['updatedAt'] is Timestamp
                ? (data['updatedAt'] as Timestamp).toDate().toLocal()
                : (DateTime.tryParse(data['updatedAt'] ?? '')?.toLocal() ??
                    DateTime.now().toLocal()),
          );
        }).toList();
        print(userSessionData.length);

        emit(state.copyWith(
            sessionHistory: userSessionData,
            historyStatus: HomeHistoryStatus.idle));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
      }
    } else {
      emit(state
          .copyWith(sessionHistory: [], historyStatus: HomeHistoryStatus.idle));
    }
  }

  GoogleSignIn _googleSignIn = GoogleSignIn();
  Future<void> _handleGoogleSignIn(
      HomeAttemptGoogleSignIn event, Emitter<HomeState> emit) async {
    try {
      //navService.router.pop();
      // Sign out first to force account picker
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      emit(state.copyWith(profileStatus: HomeProfileStatus.loading));
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
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
              .collection("sessions")
              .where("email", isEqualTo: googleUser?.email)
              .orderBy("createdAt",
                  descending: true) // assumes createdAt is stored
              .limit(20)
              .get();

          final userSessionData = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return SessionData(
              isSearchMode: data['isSearchMode'] ?? false,
              sourceUrls: List<String>.from(data['sourceUrls'] ?? []),
              videos: List<String>.from(data['videos'] ?? []),
              questions: List<String>.from(data['questions'] ?? []),
              searchTerms: List<String>.from(data['searchTerms'] ?? []),
              answers: List<String>.from(data['answers'] ?? []),
              email: data['email'] ?? '',
              understandDuration: data['understandDuration'] ?? 0,
              searchDuration: data['searchDuration'] ?? 0,
              fetchDuration: data['fetchDuration'] ?? 0,
              extractDuration: data['extractDuration'] ?? 0,
              contentDuration: data['contentDuration'] ?? 0,
              createdAt: data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.tryParse(data['createdAt'] ?? '') ??
                      DateTime.now(),
              updatedAt: data['updatedAt'] is Timestamp
                  ? (data['updatedAt'] as Timestamp).toDate()
                  : DateTime.tryParse(data['updatedAt'] ?? '') ??
                      DateTime.now(),
            );
          }).toList();
          print(userSessionData.length);

          emit(state.copyWith(
              sessionHistory: userSessionData,
              historyStatus: HomeHistoryStatus.idle));
        } catch (e) {
          print("❌ Error fetching sessions: $e");
        }
      } else {
        emit(state.copyWith(
            sessionHistory: [], historyStatus: HomeHistoryStatus.idle));
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

  Future<String?> createRecall(SessionData sessionData) async {
    final apiSecret = dotenv.get("API_SECRET");
    final apiHost = dotenv.get('API_HOST');
    final url = Uri.parse("https://$apiHost/api/recall/create");

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(sessionData.toJson()),
    );
    print(response.body);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonRes = jsonDecode(response.body);
      if (jsonRes["success"] == true) {
        return jsonRes["id"] as String? ?? "";
      } else {
        return "";
      }
    } else {
      print(
          "❌ Session create failed: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  Future<String?> updateRecall(
      SessionData sessionData, String sessionId) async {
    final apiSecret = dotenv.get("API_SECRET");
    final apiHost = dotenv.get('API_HOST');
    final url = Uri.parse("https://$apiHost/api/recall/update");

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        ...sessionData.toJson(),
        "sessionId": sessionId, // ✅ force add
      }),
    );
    print(response.body);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonRes = jsonDecode(response.body);
      if (jsonRes["success"] == true) {
        return jsonRes["id"] as String? ?? "";
      } else {
        return "";
      }
    } else {
      print(
          "❌ Session update failed: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  Future<String?> createSession(SessionData sessionData) async {
    final apiSecret = dotenv.get("API_SECRET");
    final apiHost = dotenv.get('API_HOST');
    final url = Uri.parse("https://$apiHost/api/session/create");

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(sessionData.toJson()),
    );
    print(response.body);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonRes = jsonDecode(response.body);
      if (jsonRes["success"] == true) {
        return jsonRes["id"] as String? ?? "";
      } else {
        return "";
      }
    } else {
      print(
          "❌ Session create failed: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  Future<String?> updateSession(
      SessionData sessionData, String sessionId) async {
    final apiSecret = dotenv.get("API_SECRET");
    final apiHost = dotenv.get('API_HOST');
    final url = Uri.parse("https://$apiHost/api/session/update");

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        ...sessionData.toJson(),
        "sessionId": sessionId, // ✅ force add
      }),
    );
    print(response.body);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonRes = jsonDecode(response.body);
      if (jsonRes["success"] == true) {
        return jsonRes["id"] as String? ?? "";
      } else {
        return "";
      }
    } else {
      print(
          "❌ Session update failed: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  //Sign in
}

// Strongly typed model for result video user
class ResultVideoUser {
  final String username;
  final String fullname;
  final String id;
  final bool isVerified;
  final int totalMedia;
  final int totalFollowers;

  ResultVideoUser({
    required this.username,
    required this.fullname,
    required this.id,
    required this.isVerified,
    required this.totalMedia,
    required this.totalFollowers,
  });

  factory ResultVideoUser.fromJson(Map<String, dynamic> json) {
    return ResultVideoUser(
      username: json['username'] ?? '',
      fullname: json['fullname'] ?? '',
      id: json['id'] ?? '',
      isVerified: json['is_verified'] ?? false,
      totalMedia: json['total_media'] ?? 0,
      totalFollowers: json['total_followers'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'fullname': fullname,
      'id': id,
      'is_verified': isVerified,
      'total_media': totalMedia,
      'total_followers': totalFollowers,
    };
  }
}

// Strongly typed model for result video video
class ResultVideoVideo {
  final String id;
  final double duration;
  final String thumbnailUrl;
  final String videoUrl;
  final int views;
  final int plays;
  final int timestamp;
  final String caption;
  final String framewatch;
  final String transcription;

  ResultVideoVideo(
      {required this.id,
      required this.duration,
      required this.thumbnailUrl,
      required this.videoUrl,
      required this.views,
      required this.plays,
      required this.timestamp,
      required this.caption,
      required this.framewatch,
      required this.transcription});

  factory ResultVideoVideo.fromJson(Map<String, dynamic> json) {
    return ResultVideoVideo(
      id: json['id'] ?? '',
      duration: (json['duration'] is int)
          ? (json['duration'] as int).toDouble()
          : (json['duration'] is double)
              ? (json['duration'] as double)
              : 0.0,
      thumbnailUrl: json['thumbnail_url'] ?? '',
      videoUrl: json['video_url'] ?? '',
      views: json['views'] ?? 0,
      plays: json['plays'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      caption: json['caption'] ?? '',
      framewatch: json['framewatch'] ?? '',
      transcription: json['transcription'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'duration': duration,
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
      'views': views,
      'plays': plays,
      'timestamp': timestamp,
      'caption': caption,
      'framewatch': framewatch,
      'transcription': transcription,
    };
  }
}

// Strongly typed model for result video items
class ResultVideoItem {
  final String sourceUrl;
  final bool hasAudio;
  final ResultVideoUser user;
  final ResultVideoVideo video;

  ResultVideoItem({
    required this.sourceUrl,
    required this.hasAudio,
    required this.user,
    required this.video,
  });

  factory ResultVideoItem.fromJson(Map<String, dynamic> json) {
    return ResultVideoItem(
      sourceUrl: json['sourceUrl'] ?? '',
      hasAudio: json['has_audio'] ?? false,
      user: ResultVideoUser.fromJson(json['user'] ?? {}),
      video: ResultVideoVideo.fromJson(json['video'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceUrl': sourceUrl,
      'has_audio': hasAudio,
      'user': user.toJson(),
      'video': video.toJson(),
    };
  }
}

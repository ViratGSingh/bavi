import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
import 'package:uuid/uuid.dart';
import 'dart:ui' as ui;
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final http.Client httpClient;
  HomeBloc({required this.httpClient}) : super(HomeState()) {
    //Show Me
    on<HomeSwitchType>(_switchType);
    on<HomeSwitchPrivacyType>(_switchPrivacyType);
    //on<HomeWatchSearchVideos>(_watchGoogleAnswer);
    on<HomeGetAnswer>(_watchGeneralGoogleAnswer);
    on<HomeUpdateAnswer>(_updateGeneralGoogleAnswer);
    on<SelectEditInputOption>(_selectEditInputOption);

    on<HomeGetSearch>(_getSearchResults);
    on<HomeGetNewsSearch>(_getNewsSearchData);
    on<HomeGetImagesSearch>(_getImagesSearchData);
    on<HomeGetReelsSearch>(_getReelsSearchData);
    on<HomeGetVideosSearch>(_getVideosSearchData);

    on<HomeCancelTaskGen>(_cancelTaskSearchQuery);
    on<HomeStartNewThread>(_startNewThread);
    on<HomeInitialUserData>(_getUserInfo);
    on<HomeAttemptGoogleSignIn>(_handleGoogleSignIn);
    on<HomeRetrieveSearchData>(_retrieveSearchData);
    on<HomeRefreshReply>(_refreshReply);
    // on<HomeGenScreenshot>(_genScreenshot);
    //on<HomeNavToReply>(_navToReply);
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("home_view");
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
            cacheThreadData: state.threadData,
            editQuery: event.query,
            editIndex: event.index,
            isSearchMode: event.isSearchMode))
        : emit(state.copyWith(
            editStatus: HomeEditStatus.idle, editQuery: "", editIndex: -1));
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
      answer = await altGenerateReply(
          initialresultData.userQuery,
          formattedResults,
          event.streamedText,
          emit,
          state.threadData.results
              .getRange(0, state.threadData.results.length - 1)
              .toList());
      ThreadResultData updResultData = ThreadResultData(
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
          isSearchMode: initialresultData.isSearchMode);

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
    } catch (err) {
      emit(state.copyWith(
          replyStatus: HomeReplyStatus.success, loadingIndex: event.index));
    }
  }

  //Get reels data
  Future<void> _getReelsSearchData(
      HomeGetReelsSearch event, Emitter<HomeState> emit) async {
    ThreadResultData initialResultData = state.threadData.results[event.index];
    List<ShortVideoResultData> reelsResults = [];
    String drisseaApiHost = dotenv.get('API_HOST');

    //Get other types data
    //Get Data

    emit(state.copyWith(
        status: HomePageStatus.shortVideosSearch, loadingIndex: event.index));
    try {
      //Get Algolia Search and Drissea API in parallel
      final algoliaAppId = dotenv.get('ALGOLIA_APP_ID');
      final algoliaApiKey = dotenv.get('ALGOLIA_API_KEY');
      final algoliaIndexName = 'ig_reels';
      final algoliaUrl = Uri.parse(
          "https://${algoliaAppId}-dsn.algolia.net/1/indexes/${algoliaIndexName}/query");
      final drisseaUrl = Uri.parse(
          "https://$drisseaApiHost/api/search/videos/short?gl=in&location=India&query=${Uri.encodeComponent(initialResultData.userQuery)}");

      final futures = await Future.wait([
        http.post(
          algoliaUrl,
          headers: {
            'X-Algolia-Application-Id': algoliaAppId,
            'X-Algolia-API-Key': algoliaApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'params':
                'query=${Uri.encodeComponent(initialResultData.userQuery)}'
          }),
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

      // Parse Algolia Results
      if (algoliaResponse.statusCode == 200) {
        final Map<String, dynamic> algoliaJson =
            jsonDecode(algoliaResponse.body);
        final List hits = algoliaJson['hits'] ?? [];

        if (hits.isNotEmpty) {
          hits.asMap().forEach((index, entry) {
            final hit = entry as Map<String, dynamic>;
            reelsResults.add(ShortVideoResultData.fromJson({
              'title': hit['title'] ?? '',
              'link': hit['permalink'] ?? '',
              'thumbnail': hit['thumbnail_url'] ?? '',
              'clip': hit['video_url'] ?? '',
              'source': hit["username"] ?? "",
              'sourceIcon': hit["profile_pic_url"] ?? "",
              'channel': "Instagram",
              'duration': "00"
            }));
          });
        }
      } else {
        print(
            "⚠️ Algolia search failed: ${algoliaResponse.statusCode} ${algoliaResponse.body}");
      }

      // Parse Drissea API Results
      if (drisseaResponse.statusCode == 200) {
        final Map<String, dynamic> respJson = jsonDecode(drisseaResponse.body);
        if (respJson["success"] == true) {
          final drisseaResults = (respJson['data'] as List<dynamic>)
              .asMap()
              .entries
              .map((entry) => ShortVideoResultData.fromJson({
                    ...entry.value as Map<String, dynamic>,
                    'position': entry.key + 1,
                  }))
              .toList();

          reelsResults.addAll(drisseaResults);
        }
      } else {
        print(
            "⚠️ Drissea API failed: ${drisseaResponse.statusCode} ${drisseaResponse.body}");
      }
    } catch (e) {
      print("Error in understanding query: $e");
    }

    //Update result data
    ThreadResultData updResultData = ThreadResultData(
        knowledgeGraph: initialResultData.knowledgeGraph,
        answerBox: initialResultData.answerBox,
        web: initialResultData.web,
        shortVideos: reelsResults.take(24).toList(),
        videos: initialResultData.videos,
        news: initialResultData.news,
        images: initialResultData.images,
        createdAt: initialResultData.createdAt,
        updatedAt: initialResultData.updatedAt,
        userQuery: initialResultData.userQuery,
        searchQuery: initialResultData.searchQuery,
        answer: initialResultData.answer,
        influence: initialResultData.influence,
        isSearchMode: initialResultData.isSearchMode);

    final updatedResults = List<ThreadResultData>.from(state.threadData.results)
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

    emit(state.copyWith(
        threadData: updThreadData,
        status: HomePageStatus.success,
        loadingIndex: 0));

    //Update Thread Data
    updateSession(updThreadData, state.threadData.id);

    //Get User Data
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";
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

  //Get videos data
  Future<void> _getVideosSearchData(
      HomeGetVideosSearch event, Emitter<HomeState> emit) async {
    ThreadResultData initialResultData = state.threadData.results[event.index];
    List<VideoResultData> videosResults = [];
    String drisseaApiHost = dotenv.get('API_HOST');

    //Get other types data
    //Get Data

    emit(state.copyWith(
        status: HomePageStatus.videosSearch, loadingIndex: event.index));
    try {
      final resp = await http.get(
        Uri.parse(
            "https://$drisseaApiHost/api/search/videos?gl=in&location=India&query=${Uri.encodeComponent(initialResultData.userQuery)}"),
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 200) {
        final Map<String, dynamic> respJson = jsonDecode(resp.body);
        if (respJson["success"] == true) {
          videosResults = (respJson['data'] as List<dynamic>)
              .asMap()
              .entries
              .map((entry) => VideoResultData.fromJson({
                    ...entry.value as Map<String, dynamic>,
                    'position': entry.key + 1,
                  }))
              .toList();
          print(videosResults);
        }
      }
    } catch (e) {
      print("Error in understanding query: $e");
    }

    //Update result data
    ThreadResultData updResultData = ThreadResultData(
        knowledgeGraph: initialResultData.knowledgeGraph,
        answerBox: initialResultData.answerBox,
        web: initialResultData.web,
        shortVideos: initialResultData.shortVideos,
        videos: videosResults,
        news: initialResultData.news,
        images: initialResultData.images,
        createdAt: initialResultData.createdAt,
        updatedAt: initialResultData.updatedAt,
        userQuery: initialResultData.userQuery,
        searchQuery: initialResultData.searchQuery,
        answer: initialResultData.answer,
        influence: initialResultData.influence,
        isSearchMode: initialResultData.isSearchMode);

    final updatedResults = List<ThreadResultData>.from(state.threadData.results)
      ..removeAt(event.index)
      ..insert(event.index, updResultData);

    final updThreadData = ThreadSessionData(
      id: state.threadData.id,
      isIncognito: state.threadData.isIncognito,
      results: updatedResults,
      email: state.threadData.email,
      createdAt: state.threadData.createdAt,
      updatedAt: Timestamp.now(),
    );

    emit(state.copyWith(
        threadData: updThreadData,
        status: HomePageStatus.success,
        loadingIndex: 0));

    //Update Thread Data
    updateSession(updThreadData, state.threadData.id);

    //Get User Data
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";
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

  //Get images data
  Future<void> _getImagesSearchData(
      HomeGetImagesSearch event, Emitter<HomeState> emit) async {
    ThreadResultData initialResultData = state.threadData.results[event.index];
    List<ImageResultData> imagesResults = [];
    String drisseaApiHost = dotenv.get('API_HOST');

    //Get other types data
    //Get Data

    emit(state.copyWith(
        status: HomePageStatus.imagesSearch, loadingIndex: event.index));
    try {
      final resp = await http.get(
        Uri.parse(
            "https://$drisseaApiHost/api/search/images?gl=in&location=India&query=${Uri.encodeComponent(initialResultData.userQuery)}"),
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 200) {
        final Map<String, dynamic> respJson = jsonDecode(resp.body);
        if (respJson["success"] == true) {
          imagesResults = (respJson['data'] as List<dynamic>)
              .asMap()
              .entries
              .map((entry) => ImageResultData.fromJson({
                    ...entry.value as Map<String, dynamic>,
                    'position': entry.key + 1,
                  }))
              .toList();
        }
      }
    } catch (e) {
      print("Error in understanding query: $e");
    }

    //Update result data
    ThreadResultData updResultData = ThreadResultData(
        knowledgeGraph: initialResultData.knowledgeGraph,
        answerBox: initialResultData.answerBox,
        web: initialResultData.web,
        shortVideos: initialResultData.shortVideos,
        videos: initialResultData.videos,
        news: initialResultData.news,
        images: imagesResults,
        createdAt: initialResultData.createdAt,
        updatedAt: initialResultData.updatedAt,
        userQuery: initialResultData.userQuery,
        searchQuery: initialResultData.searchQuery,
        answer: initialResultData.answer,
        influence: initialResultData.influence,
        isSearchMode: initialResultData.isSearchMode);

    final updatedResults = List<ThreadResultData>.from(state.threadData.results)
      ..removeAt(event.index)
      ..insert(event.index, updResultData);

    final updThreadData = ThreadSessionData(
      id: state.threadData.id,
      isIncognito: state.threadData.isIncognito,
      results: updatedResults,
      email: state.threadData.email,
      createdAt: state.threadData.createdAt,
      updatedAt: Timestamp.now(),
    );

    emit(state.copyWith(
        threadData: updThreadData,
        status: HomePageStatus.success,
        loadingIndex: 0));

    //Update Thread Data
    updateSession(updThreadData, state.threadData.id);

    //Get User Data
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";
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

  //Get news data
  Future<void> _getNewsSearchData(
      HomeGetNewsSearch event, Emitter<HomeState> emit) async {
    ThreadResultData initialResultData = state.threadData.results[event.index];
    List<NewsResultData> newsResults = [];
    String drisseaApiHost = dotenv.get('API_HOST');

    //Get other types data
    //Get Data

    emit(state.copyWith(
        status: HomePageStatus.newsSearch, loadingIndex: event.index));
    try {
      final resp = await http.get(
        Uri.parse(
            "https://$drisseaApiHost/api/search/news?gl=in&location=India&query=${Uri.encodeComponent(initialResultData.userQuery)}"),
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 200) {
        final Map<String, dynamic> respJson = jsonDecode(resp.body);
        if (respJson["success"] == true) {
          newsResults = (respJson['data'] as List<dynamic>)
              .asMap()
              .entries
              .map((entry) => NewsResultData.fromJson({
                    ...entry.value as Map<String, dynamic>,
                    'position': entry.key + 1,
                  }))
              .toList();
          print(newsResults);
        }
      }
    } catch (e) {
      print("Error in understanding query: $e");
    }

    //Update result data
    ThreadResultData updResultData = ThreadResultData(
        knowledgeGraph: initialResultData.knowledgeGraph,
        answerBox: initialResultData.answerBox,
        web: initialResultData.web,
        shortVideos: initialResultData.shortVideos,
        videos: initialResultData.videos,
        news: newsResults,
        images: initialResultData.images,
        createdAt: initialResultData.createdAt,
        updatedAt: initialResultData.updatedAt,
        userQuery: initialResultData.userQuery,
        searchQuery: initialResultData.searchQuery,
        answer: initialResultData.answer,
        influence: initialResultData.influence,
        isSearchMode: initialResultData.isSearchMode);

    final updatedResults = List<ThreadResultData>.from(state.threadData.results)
      ..removeAt(event.index)
      ..insert(event.index, updResultData);

    final updThreadData = ThreadSessionData(
      id: state.threadData.id,
      isIncognito: state.threadData.isIncognito,
      email: state.threadData.email,
      results: updatedResults,
      createdAt: state.threadData.createdAt,
      updatedAt: Timestamp.now(),
    );

    emit(state.copyWith(
        threadData: updThreadData,
        status: HomePageStatus.success,
        loadingIndex: 0));

    //Update Thread Data
    updateSession(updThreadData, state.threadData.id);

    //Get User Data
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";
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
  Future<void> _getSearchResults(
      HomeGetSearch event, Emitter<HomeState> emit) async {
    String query = event.query;
    String type = event.type;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userEmail = state.isIncognito ? "" : prefs.getString("email") ?? "";

    String drisseaApiHost = dotenv.get('API_HOST');
    _cancelTaskGen = false;
    HomePageStatus pageSearchStatus = type == "web"
        ? HomePageStatus.webSearch
        : type == "reels"
            ? HomePageStatus.shortVideosSearch
            : type == "images"
                ? HomePageStatus.imagesSearch
                : type == "news"
                    ? HomePageStatus.newsSearch
                    : type == "videos"
                        ? HomePageStatus.videosSearch
                        : HomePageStatus.webSearch;
    String threadId = Uuid().v4().substring(0, 8);
    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
      isSearchMode: true,
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
    );
    List<WebResultData> searchResults = [];
    KnowledgeGraphData? knowledgeGraph;
    AnswerBoxData? answerBox;

    ThreadSessionData updThreadData = state.threadData;

    // Get Results
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
          isIncognito: state.isIncognito,
          email: userEmail,
          results: tempUpdatedResults,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now());
    }
    emit(
      state.copyWith(
          status: pageSearchStatus,
          threadData: updThreadData,
          loadingIndex: updThreadData.results.length - 1),
    );

    //Get Data
    // Get Algolia Search and Drissea API in parallel
    final algoliaAppId = dotenv.get('ALGOLIA_APP_ID');
    final algoliaApiKey = dotenv.get('ALGOLIA_API_KEY');
    final algoliaIndexName = 'ig_creators';
    final algoliaUrl = Uri.parse(
        "https://${algoliaAppId}-dsn.algolia.net/1/indexes/${algoliaIndexName}/query");
    final drisseaUrl = Uri.parse(
        "https://$drisseaApiHost/api/search/web?gl=in&location=India&query=${Uri.encodeComponent(query)}");
    print("1");
    try {
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
      print("2");
      final algoliaResponse = futures[0];
      final drisseaResponse = futures[1];

      // Parse Algolia Results
      if (algoliaResponse.statusCode == 200) {
        final Map<String, dynamic> algoliaJson =
            jsonDecode(algoliaResponse.body);
        final List hits = algoliaJson['hits'] ?? [];

        if (hits.isNotEmpty) {
          final firstHit = hits.first as Map<String, dynamic>;
          knowledgeGraph = KnowledgeGraphData(
            title: firstHit['title'] ?? '',
            type: firstHit['category'] ?? '',
            description: firstHit['overview'] ?? '',
            headerImages: [
              if (firstHit['profile_pic_url'] != null)
                HeaderImageData(
                  image: firstHit['profile_pic_url'] ?? '',
                  source: firstHit['profile_url'] ?? '',
                ),
            ],
            movies: [],
            moviesAndShows: [],
            tvShows: [],
            videoGames: [],
            books: [],
          );
        }
      } else {
        print("⚠️ Algolia search failed: ${algoliaResponse.statusCode}");
      }
      print("3");

      // Parse Drissea Results
      if (drisseaResponse.statusCode == 200) {
        final Map<String, dynamic> respJson = jsonDecode(drisseaResponse.body);
        if (respJson["success"] == true) {
          final drisseaResults = (respJson['data'] as List<dynamic>)
              .asMap()
              .entries
              .map((entry) => WebResultData.fromJson({
                    ...entry.value as Map<String, dynamic>,
                    'position': searchResults.length + entry.key + 1,
                  }))
              .toList();
          searchResults.addAll(drisseaResults);

          // Parse Knowledge Graph
          if (respJson['knowledge_graph'] != null && knowledgeGraph == null) {
            final kgJson = respJson['knowledge_graph'] as Map<String, dynamic>;
            knowledgeGraph = KnowledgeGraphData(
              title: kgJson['title'] ?? '',
              type: kgJson['type'] ?? '',
              description: kgJson['description'] ?? '',
              headerImages: (kgJson['header_images'] as List<dynamic>?)
                      ?.map((img) => HeaderImageData(
                            image: img['image'] ?? '',
                            source: img['source'] ?? '',
                          ))
                      .toList() ??
                  [],
              movies: (kgJson['movies'] as List<dynamic>?)
                      ?.map((m) => MediaItemData(
                            extensions: (m['extensions'] as List<dynamic>?)
                                ?.map((e) => e.toString())
                                .toList(),
                            image: m['image'] ?? '',
                          ))
                      .toList() ??
                  [],
              moviesAndShows: (kgJson['movies_and_shows'] as List<dynamic>?)
                      ?.map((m) => MediaItemData(
                            extensions: (m['extensions'] as List<dynamic>?)
                                ?.map((e) => e.toString())
                                .toList(),
                            image: m['image'] ?? '',
                          ))
                      .toList() ??
                  [],
              tvShows: (kgJson['tv_shows'] as List<dynamic>?)
                      ?.map((t) => MediaItemData(
                            extensions: (t['extensions'] as List<dynamic>?)
                                ?.map((e) => e.toString())
                                .toList(),
                            image: t['image'] ?? '',
                          ))
                      .toList() ??
                  [],
              videoGames: (kgJson['video_games'] as List<dynamic>?)
                      ?.map((v) => MediaItemData(
                            extensions: (v['extensions'] as List<dynamic>?)
                                ?.map((e) => e.toString())
                                .toList(),
                            image: v['image'] ?? '',
                          ))
                      .toList() ??
                  [],
              books: (kgJson['books'] as List<dynamic>?)
                      ?.map((b) => MediaItemData(
                            extensions: (b['extensions'] as List<dynamic>?)
                                ?.map((e) => e.toString())
                                .toList(),
                            image: b['image'] ?? '',
                          ))
                      .toList() ??
                  [],
            );
          }

          // Parse Answer Box
          if (respJson['answer_box'] != null) {
            final answerJson = respJson['answer_box'] as Map<String, dynamic>;
            answerBox = AnswerBoxData(
              title: answerJson['title'] ?? '',
              type: answerJson['type'] ?? '',
              answer: answerJson['answer'] ?? '',
              thumbnail: answerJson['thumbnail'] ?? '',
            );
          }
        }

        //Update result data
        //Add Search data to updated result data
        ThreadResultData updResultData = ThreadResultData(
          isSearchMode: true,
          web: searchResults,
          knowledgeGraph: knowledgeGraph,
          answerBox: answerBox,
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
        );

        final updatedResults =
            List<ThreadResultData>.from(state.threadData.results)
              ..removeLast()
              ..add(updResultData);

        if (state.threadData.id != "") {
          updThreadData = ThreadSessionData(
              id: state.threadData.id,
              isIncognito: state.threadData.isIncognito,
              email: userEmail,
              results: updatedResults,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now());
        } else {
          updThreadData = ThreadSessionData(
              id: threadId,
              isIncognito: state.isIncognito,
              email: userEmail,
              results: updatedResults,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now());
        }

        if (_cancelTaskGen) {
          //emit(state.copyWith(status: HomePageStatus.success));

          return;
        }
        emit(state.copyWith(
            status: HomePageStatus.success, threadData: updThreadData));
      }
    } catch (e) {
      print("Error fetching parallel search results: $e");
    }
    if (_cancelTaskGen) {
      //emit(state.copyWith(status: HomePageStatus.success));

      return;
    }

    //Update Thread Data
    if (updThreadData.results.length == 1) {
      createSession(updThreadData, threadId);
    } else {
      updateSession(updThreadData, state.threadData.id);
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
        print(userSessionData.length);

        emit(state.copyWith(threadHistory: userSessionData));
      } catch (e) {
        print("❌ Error fetching sessions: $e");
      }
    }
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
      answer: "",
      influence: [],
    );
    List<ExtractedResultInfo> extractedResults = [];

    ThreadSessionData updThreadData = state.threadData;

    //Check if previous query or answer is present
    Map<String, dynamic> genSearchReqBody = {};

    if (state.threadData.results.isNotEmpty) {
      if (state.threadData.results.last.isSearchMode == false) {
        genSearchReqBody = {
          "task": query,
          "previousQuestion": state.threadData.results.last.userQuery,
          "previousAnswer": state.threadData.results.last.answer,
        };
      }
    } else {
      genSearchReqBody = {"task": query};
    }

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
        status: HomePageStatus.generateQuery,
        threadData: updThreadData,
        loadingIndex: updThreadData.results.length - 1));
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

    String? answer = await altGenerateReply(
        query,
        formattedResults,
        event.streamedText,
        emit,
        state.threadData.results
            .getRange(0, state.threadData.results.length - 1)
            .toList());

    ThreadResultData updResultData = ThreadResultData(
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
        replyStatus: HomeReplyStatus.success, threadData: updThreadData));

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
    String threadId = Uuid().v4().substring(0, 8);
    String drisseaApiHost = dotenv.get('API_HOST');
    _cancelTaskGen = false;

    //Set Initial Result Data
    ThreadResultData resultData = ThreadResultData(
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
    );
    List<ExtractedResultInfo> extractedResults = [];

    ThreadSessionData updThreadData = state.threadData;

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

    String? answer = await altGenerateReply(
        query, formattedResults, event.streamedText, emit, initialResults);

    ThreadResultData updResultData = ThreadResultData(
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
        editStatus: HomeEditStatus.idle));

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

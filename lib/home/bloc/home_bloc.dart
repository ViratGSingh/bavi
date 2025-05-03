import 'dart:convert';
import 'dart:io';
import 'package:bavi/models/collection.dart';
import 'package:bavi/models/question_answer.dart';
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
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final http.Client httpClient;
  HomeBloc({required this.httpClient}) : super(HomeState()) {
    on<HomeNavOptionSelect>(_changeNavOption);
    on<HomeAccountSelect>(chooseAccount);
    on<HomeAccountDeselect>(deselectAccount);
    on<HomeSelectSearch>(selectSearch);
    //Show Me
    on<HomeSearchVideos>(_searchPinecone);
    on<HomeCancelTaskGen>(_cancelTaskSearchQuery);
    on<HomeInitialUserData>(_getUserInfo);
    on<HomeAttemptGoogleSignIn>(_handleGoogleSignIn);
    on<HomeNavToReply>(_navToReply);
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("home_view");
  }

  _navToReply(HomeNavToReply event, Emitter<HomeState> emit)async{
     navService.goTo(
          "/reply",
          extra: {
            'markdownText': event.conversationData.conversation.first.reply,
            'query': event.conversationData.conversation.first.query,
            'conversationId': event.conversationData.id,
            'conversation': event.conversationData,
            'account': state.account, // Can be null or ExtractedAccountInfo
          },
        );
  }

  //Save Video

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

  Future<List<ExtractedAccountInfo>> fetchInstagramAccounts(String name) async {
    final url = Uri.https(
      dotenv.get("IG_RAPID_API_HOST"),
      '/v1/search_users',
      {'search_query': name},
    );

    final headers = {
      'x-rapidapi-key': dotenv.get("RAPID_API_KEY"),
      'x-rapidapi-host': dotenv.get("IG_RAPID_API_HOST"),
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> respData = jsonDecode(response.body);
      final List<dynamic> items = respData['data']['items'];

      final List<ExtractedAccountInfo> accounts = items.map((item) {
        return ExtractedAccountInfo(
          accountId: item["id"],
          isPrivate: item["is_private"],
          isVerified: item["is_verified"],
          username: item['username'] ?? '',
          fullname: item['full_name'] ?? '',
          profilePicUrl: item['profile_pic_url'] ?? '',
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        );
      }).toList();

      return accounts;
    } else {
      print('Failed to load accounts: ${response.statusCode}');
      return [];
    }
  }

  /// Function to search Pinecone using a vector
  Future<void> _searchPinecone(
      HomeSearchVideos event, Emitter<HomeState> emit) async {

    mixpanel.timeEvent("initial_chat_reply");
    _cancelTaskGen = false;
    String pineconeApiKey = dotenv.get('PINECONE_API_KEY');
    String indexUrl = '${dotenv.get('PINECONE_HOST_URL')}/query';

    final headers = {
      'Content-Type': 'application/json',
      'Api-Key': pineconeApiKey,
    };

    emit(state.copyWith(status: HomePageStatus.generateQuery));
    final embeddingResponse = await http.post(
      Uri.parse("https://api.openai.com/v1/embeddings"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${dotenv.get("OPENAI_API_KEY")}',
      },
      body: jsonEncode({
        'model': 'text-embedding-3-small',
        'input': event.query,
      }),
    );
    if (embeddingResponse.statusCode != 200) {
      throw Exception(
          "Failed to generate embedding: ${embeddingResponse.body}");
    }
    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    final embeddingJson = jsonDecode(embeddingResponse.body);
    final List<double> vector =
        List<double>.from(embeddingJson["data"][0]["embedding"]);

    emit(state.copyWith(status: HomePageStatus.getSearchResults));
    final body = jsonEncode({
      'vector': vector,
      'topK': event.topK,
      'includeValues': false,
      'includeMetadata': true,
      if (event.userId.trim() != "") 'filter': {'collection_id': event.userId.trim()},
    });

    final response = await http.post(
      Uri.parse(indexUrl),
      headers: headers,
      body: body,
    );

    List<ExtractedVideoInfo> updSortedTaskVideos = [];
    if (response.statusCode == 200) {
      //print(response.body);
      final decoded = jsonDecode(response.body);
      updSortedTaskVideos = (decoded['matches'] as List<dynamic>).map((match) {
        final metadata = match['metadata'];
        String videoId = metadata['videoId'];
        String username = metadata["username"];
        String videoLink = "https://www.instagram.com/$username/reel/$videoId";

        return ExtractedVideoInfo(
          videoId: metadata['videoId'],
          platform: "instagram",
          searchContent:
              "${metadata["username"]}, ${metadata["fullname"]}, ${metadata["caption"]}",
          caption: metadata["caption"],
          videoDescription: metadata["video_description"] ?? "",
          audioDescription: metadata["audio_description"] ?? "",
          userData: UserData(
            username: metadata["username"],
            fullname: metadata["fullname"],
            profilePicUrl: metadata["profile_pic_url"],
          ),
          videoData: VideoData(
            thumbnailUrl: "",//metadata["thumbnail_url"],
            videoUrl: videoLink, //metadata["video_url"],
          ),
        );
      }).toList();
    } else {
      throw Exception('Pinecone search failed: ${response.body}');
    }

    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }

    //Get Answer
    emit(state.copyWith(
        status: HomePageStatus.summarize, searchResults: updSortedTaskVideos));
    String? searchAnswer = await generateMarkdownStyledAnswer(
        videos: updSortedTaskVideos, userQuery: event.query);
    if (_cancelTaskGen) {
      emit(state.copyWith(status: HomePageStatus.idle));
      return;
    }
    //Save convo data
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userEmaildId = prefs.getString("email");
    if (userEmaildId != null) {
      FirebaseFirestore db = FirebaseFirestore.instance;
      final CollectionReference usersCollection = db.collection('users');

      // Query the users collection for a document with the matching email
      final QuerySnapshot querySnapshot = await usersCollection
          .where('email', isEqualTo: userEmaildId)
          .limit(1)
          .get();

      // Check if any documents were found
      if (querySnapshot.docs.isEmpty) {
        throw Exception('User not found');
      } else {
        ConversationData conversationData = ConversationData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversation: [
            QuestionAnswerData(
              reply: searchAnswer ?? "",
              query: event.query,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            )
          ],
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        );

        final docRef = usersCollection.doc(querySnapshot.docs.first.id);
        final userDoc = await docRef.get();
        final data = userDoc.data() as Map<String, dynamic>;
        List<dynamic> currentHistory = data['search_history'] ?? [];

        currentHistory.add(conversationData.id);
        await docRef.update({'search_history': currentHistory});
        // Also save to conversations collection
        await db
            .collection("conversations")
            .doc(conversationData.id)
            .set(conversationData.toJson());
        navService.goTo(
          "/reply",
          extra: {
            'markdownText': searchAnswer ?? "",
            'query': event.query,
            'conversationId': conversationData.id,
            'account': state.account, // Can be null or ExtractedAccountInfo
          },
        );
      }
    }

    mixpanel.track("initial_chat_reply");
    emit(state.copyWith(status: HomePageStatus.idle));
    // //Collect Sort Video links
    // List<String> updSortedVideoids = updSortedTaskVideos.map((video) {
    //   return video.videoId;
    // }).toList();
    // //Save Task Info
    // _saveUserTask(event.task, taskSearchQuery, updSortedVideoids);
    //navService.goTo("/searchResult", extra: updSortedTaskVideos);
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
          "Your job is to write a clean, readable answer based only on the content available. Follow these rules:")
      ..writeln("")
      ..writeln(
          "1. ✅ **Structure the response clearly** using bullet points when appropriate.")
      ..writeln(
          "2. ✅ **Bold key insights** and highlight notable places, dishes, or experiences.")
      ..writeln(
          "3. ✅ For any place, food item, or experience that was featured in a video, wrap the **main word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
      ..writeln(
          "4. ✅ Write naturally as if you're recommending or informing — never say “based on search results” or “these videos say.”")
      ..writeln(
          "5. ✅ If no strong or direct matches are found, gracefully say:  \n   _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_")
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
        "model": "llama-3.3-70b-versatile",
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

  Future<String?> altGenerateMarkdownStyledAnswer({
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
          "Your job is to write a clean, readable answer based only on the content available. Follow these rules:")
      ..writeln("")
      ..writeln(
          "1. ✅ **Structure the response clearly** using bullet points when appropriate.")
      ..writeln(
          "2. ✅ **Bold key insights** and highlight notable places, dishes, or experiences.")
      ..writeln(
          "3. ✅ For any place, food item, or experience that was featured in a video, wrap the **main word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
      ..writeln(
          "4. ✅ Write naturally as if you're recommending or informing — never say “based on search results” or “these videos say.”")
      ..writeln(
          "5. ✅ If no strong or direct matches are found, gracefully say:  \n   _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_")
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
        "temperature": 0,
        "max_tokens": 800,
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

    try {
      FirebaseFirestore db = FirebaseFirestore.instance;
      final QuerySnapshot querySnapshot = await db
          .collection("users")
          .where("email", isEqualTo: userEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print("No user found with email: $userEmail");
        return null;
      }

      Map<String, dynamic> data =
          querySnapshot.docs.first.data() as Map<String, dynamic>;
      UserProfileInfo userData = UserProfileInfo.fromJson(data);
      List<String> conversationIdList = userData.searchHistory ?? [];

      List<ConversationData> allConversations = [];

      for (String convoId in conversationIdList) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection("conversations")
            .doc(convoId)
            .get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          if (data != null) {
            allConversations.add(ConversationData.fromJson(data));
          }
        }
      }

      emit(state.copyWith(searchHistory: allConversations, userData: userData));
    } catch (e) {
      print("Error fetching user info: $e");
      return null;
    }
  }

  Future<void> _changeNavOption(
      HomeNavOptionSelect event, Emitter<HomeState> emit) async {
    NavBarOption updatedPosition = event.page;
    if (updatedPosition == NavBarOption.profile) {
      navService.goTo("/profile");
    } else if (updatedPosition == NavBarOption.search) {
      navService.goTo("/search", extra: fetchInstagramAccounts);
    }
  }

  GoogleSignIn _googleSignIn = GoogleSignIn();
  Future<void> _handleGoogleSignIn(
      HomeAttemptGoogleSignIn event, Emitter<HomeState> emit) async {
    try {
      navService.router.pop();
      // Sign out first to force account picker
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      emit(state.copyWith(status: HomePageStatus.loading));
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

        if (prefs.getString('displayName') == "Guest") {
          await updateUserData(googleUser, state.searchHistory, emit);
        } else {
          await saveUserData(googleUser, emit);
        }
      }
      emit(state.copyWith(
        status: HomePageStatus.idle,
      ));
    } catch (error) {
      print("Google Sign-In Error: $error");
      emit(state.copyWith(status: HomePageStatus.idle));
    }
  }

  Future<void> saveUserData(
      GoogleSignInAccount googleUser, Emitter<HomeState> emit) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString('displayName', googleUser.displayName ?? "");
    await prefs.setString('email', googleUser.email);
    await prefs.setString('profile_pic_url', googleUser.photoUrl ?? "");
    await prefs.setBool('isLoggedIn', true);

    FirebaseFirestore db = FirebaseFirestore.instance;
    // Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("users")
        .where('email', isEqualTo: googleUser.email)
        .limit(1)
        .get();
    UserProfileInfo userData;
    List<ConversationData> allConversations = [];

    if (querySnapshot.docs.isNotEmpty) {
      print("asdasd");
      // Document with the same email exists, update it
      String documentId = querySnapshot.docs.first.id;
      final userDoc = await db.collection("users").doc(documentId).get();
      final mapData = userDoc.data() as Map<String, dynamic>;
      userData = UserProfileInfo.fromJson(mapData);

      await db.collection("users").doc(documentId).set({
        'updated_at': Timestamp.now(),
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
        "fullname": googleUser.displayName ?? "",
        "profile_pic_url": googleUser.photoUrl ?? "",
        "created_at": Timestamp.now(),
        "updated_at": Timestamp.now(),
        "search_history": [],
      };
      userData = UserProfileInfo.fromJson(user);
      // Add a new document with a generated ID
      await db.collection("users").add(user).then((onValue) {
        mixpanel.identify(username);
        mixpanel.track("sign_up");
        navService.goToAndPopUntil('/home');
      });
    }

    //Get Conversation Data
    for (String convoId in userData.searchHistory ?? []) {
      final docSnapshot = await FirebaseFirestore.instance
          .collection("conversations")
          .doc(convoId)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          allConversations.add(ConversationData.fromJson(data));
        }
      }
    }

    emit(state.copyWith(
        status: HomePageStatus.idle,
        userData: userData,
        searchHistory: allConversations));
  }

  Future<void> updateUserData(
      GoogleSignInAccount googleUser,
      List<ConversationData> currentConversationData,
      Emitter<HomeState> emit) async {
    UserProfileInfo? userData;
    List<ConversationData> allConversations = [];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    print("FFFF");
    FirebaseFirestore db = FirebaseFirestore.instance;
    // Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("users")
        .where('email', isEqualTo: googleUser.email)
        .limit(1)
        .get();
    print("GGGG");
    String? guestEmail = prefs.getString('email');

    print("Asdasd");
    print(guestEmail);
    QuerySnapshot guestSnapshot = await db
        .collection("users")
        .where('email', isEqualTo: guestEmail)
        .limit(1)
        .get();

    //Exists
    if (querySnapshot.docs.isNotEmpty) {
      print("asdasd");
      // Document with the same email exists, update it
      String documentId = querySnapshot.docs.first.id;
      Map<String, dynamic> userMap =
          querySnapshot.docs.first.data() as Map<String, dynamic>;
      UserProfileInfo existingUser = UserProfileInfo.fromJson(userMap);

      //Update User Data
      List<String> existingSearchHistory = existingUser.searchHistory ?? [];
      List<String> newSearchHistory =
          currentConversationData.map((e) => e.id).toList();
      List<String> updSearchHistory = [];
      updSearchHistory.addAll(existingSearchHistory);
      updSearchHistory.addAll(newSearchHistory);
      UserProfileInfo updatedUser = UserProfileInfo(
          email: existingUser.email,
          fullname: existingUser.fullname,
          username: existingUser.username,
          profilePicUrl: existingUser.profilePicUrl,
          createdAt: existingUser.createdAt,
          updatedAt: Timestamp.now(),
          searchHistory: updSearchHistory);

      await prefs.setString('displayName', googleUser.displayName ?? "");
      await prefs.setString('email', googleUser.email);
      await prefs.setString('profile_pic_url', googleUser.photoUrl ?? "");
      await prefs.setBool('isLoggedIn', true);

      await db
          .collection("users")
          .doc(documentId)
          .set(updatedUser.toJson(), SetOptions(merge: true))
          .then((onValue) {
        print("aaa");
        String username = googleUser.email.split("@").first;
        mixpanel.identify(username);
        mixpanel.track("sign_in_existing");
        userData = updatedUser;
      }); // Merge to update only specified fields

      //Delete old doc

      String guestDocumentId = guestSnapshot.docs.first.id;
      await db.collection("users").doc(guestDocumentId).delete();
    }
    //Doesn't Exist
    else {
      if (guestSnapshot.docs.isNotEmpty) {
        print("1");
        Map<String, dynamic> guestMap =
            guestSnapshot.docs.first.data() as Map<String, dynamic>;
        print("2");
        UserProfileInfo guestUser = UserProfileInfo.fromJson(guestMap);
        print("3");
        UserProfileInfo updatedGuestUser = UserProfileInfo(
            email: googleUser.email,
            fullname: googleUser.displayName ?? "",
            username: googleUser.email.split("@").first,
            profilePicUrl: googleUser.photoUrl ?? "",
            createdAt: guestUser.createdAt,
            updatedAt: Timestamp.now(),
            searchHistory: guestUser.searchHistory);
        // Update guest user to actual user document

        await prefs.setString('displayName', googleUser.displayName ?? "");
        await prefs.setString('email', googleUser.email);
        await prefs.setString('profile_pic_url', googleUser.photoUrl ?? "");
        await prefs.setBool('isLoggedIn', true);
        print("4");

        await db
            .collection("users")
            .doc(guestSnapshot.docs.first.id)
            .set(updatedGuestUser.toJson(), SetOptions(merge: true))
            .then((onValue) {
          String username = googleUser.email.split("@").first;
          mixpanel.identify(username);
          mixpanel.track("sign_in_new");
          userData = updatedGuestUser;
        });
      }
    }



    //Get Conversation Data
    for (String convoId in userData?.searchHistory ?? []) {
      final docSnapshot = await FirebaseFirestore.instance
          .collection("conversations")
          .doc(convoId)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          allConversations.add(ConversationData.fromJson(data));
        }
      }
    }

    emit(state.copyWith(
        status: HomePageStatus.idle,
        userData: userData,
        searchHistory: allConversations));
  }
}

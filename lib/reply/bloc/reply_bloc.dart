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
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
part 'reply_event.dart';
part 'reply_state.dart';

class ReplyBloc extends Bloc<ReplyEvent, ReplyState> {
  final http.Client httpClient;
  ReplyBloc({required this.httpClient}) : super(ReplyState()) {
    on<ReplyNavOptionSelect>(_changeNavOption);

    on<ReplyCancelTaskGen>(_cancelTaskSearchQuery);

    on<ReplySearchResultShare>(_shareSearchResult);

    //Next answers
    on<ReplySetInitialAnswer>(_setInitialData);
    on<ReplyRefreshAnswer>(_refreshAnswer);
    // on<ReplyNextAnswer>(_getNextAnswer);
    // on<ReplyPreviousAnswer>(_getPreviousAnswer);

    on<ReplyUpdateQuery>(_updateSearchData);
    on<ReplyUpdateThumbnails>(_updateThumbnailUrls);
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("reply_view");
  }

  Future<String?> generateMarkdownStyledAnswer(
      {required List<ExtractedVideoInfo> videos,
      required String userQuery,
      required String prevAnswer}) async {
    final prompt = StringBuffer()
      ..writeln(
          "You are a helpful and concise assistant that answers follow-up questions using past conversation context and insights from short videos.")
      ..writeln("")
      ..writeln("The user has previously asked and been given this answer:")
      ..writeln(prevAnswer)
      ..writeln("")
      ..writeln("Now they ask:")
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
          "3. ✅ For any place, item or experience that was featured in a video, wrap the **main word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
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
      ReplyCancelTaskGen event, Emitter<ReplyState> emit) async {
    _cancelTaskGen = true;
    emit(state.copyWith(status: ReplyPageStatus.idle));
  }

  Future<void> _changeNavOption(
      ReplyNavOptionSelect event, Emitter<ReplyState> emit) async {
    NavBarOption updatedPosition = event.page;
    if (updatedPosition == NavBarOption.profile) {
      navService.goTo("/profile");
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

    final request = http.Request(
      "POST",
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
    );
    request.headers.addAll({
      "Authorization": "Bearer ${dotenv.get("GROQ_API_KEY")}",
      "Content-Type": "application/json",
    });
    request.body = jsonEncode({
      "model": "deepseek-r1-distill-llama-70b",
      "messages": [
        {
          "role": "user",
          "content": prompt.toString(),
        }
      ],
      "temperature": 0.3,
      "max_tokens": 1000,
      "stream": true,
      "stop": null
    });

    final streamedResponse = await httpClient.send(request);

    if (streamedResponse.statusCode == 200) {
      final buffer = StringBuffer();
      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith("data: ")) {
          final chunk = line.substring(6).trim();
          if (chunk == "[DONE]") break;

          try {
            final jsonChunk = jsonDecode(chunk);
            final delta = jsonChunk['choices'][0]['delta'];
            if (delta != null && delta.containsKey('content')) {
              final content = delta['content'];
              buffer.write(content);
              print(content); // Or emit to UI
            }
          } catch (e) {
            print("Error decoding chunk: $e");
          }
        }
      }

      return buffer.toString();
    } else {
      print("❌ Groq API Error: ${streamedResponse.statusCode}");
      return null;
    }
  }

  Future<void> _setInitialData(
      ReplySetInitialAnswer event, Emitter<ReplyState> emit) async {
    initMixpanel();
    emit(state.copyWith(
        status: ReplyPageStatus.loading, searchQuery: event.query));
    int startPoint = 0;
    int endPoint = event.similarVideos.length;
    List<ExtractedVideoInfo> videos =
        event.similarVideos.sublist(startPoint, endPoint);
    String userQuery = event.query;

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
          "2. ✅ **Bold key insights** and highlight notable places, dishes, or experiences. Wrap the **word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
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
      ..writeln("7. ⚡ Keep it under 800 characters")
      ..writeln("")
      ..writeln("Here’s the video content:\n");

    for (final video in videos) {
      print(video.videoData.videoUrl);
      print(video.caption.length);
      print(video.audioDescription.length);
      print(video.videoDescription.length);
      prompt.writeln("Caption: ${video.caption}");
      prompt.writeln("Transcript: ${video.audioDescription}");
      prompt.writeln("Video Description: ${video.videoDescription}");
      prompt.writeln(
          "Video URL: https://www.instagram.com/${video.userData.username}/reel/${video.videoId}");
      prompt.writeln("---");
    }

    final request = http.Request(
      "POST",
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
    );
    request.headers.addAll({
      "Authorization": "Bearer ${dotenv.get("GROQ_API_KEY")}",
      "Content-Type": "application/json",
    });
    request.body = jsonEncode({
      "model": "deepseek-r1-distill-llama-70b",
      "messages": [
        {
          "role": "user",
          "content": prompt.toString(),
        }
      ],
      "temperature": 0.3,
      "max_tokens": 1000,
      "stream": true,
      "stop": null
    });

    final streamedResponse = await httpClient.send(request);

    if (streamedResponse.statusCode == 200) {
      final buffer = StringBuffer();
      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith("data: ")) {
          final chunk = line.substring(6).trim();
          if (chunk == "[DONE]") break;

          try {
            final jsonChunk = jsonDecode(chunk);
            final delta = jsonChunk['choices'][0]['delta'];
            if (delta != null && delta.containsKey('content')) {
              final content = delta['content'];
              if (content.toString().contains("<think>") == false) {
                buffer.write(content);
              }

              emit(state.copyWith(
                  status: ReplyPageStatus.thinking,
                  thinking: buffer.toString().split("</think>").first));
            }
          } catch (e) {
            print("Error decoding chunk: $e");
          }
        }
      }
      String answer = buffer.toString();
      answer = answer.split("</think>").last;
      emit(state.copyWith(status: ReplyPageStatus.idle, searchAnswer: answer));

      //Save answer data
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
          //Set search data and updated search history in user data
          SearchData searchData = SearchData(
            id: event.searchId ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            answer: answer,
            process: buffer.toString().split("</think>").first,
            sourceLinks: event.similarVideos.map((data){
                  return data.videoData.videoUrl;
                }).toList(),
            query: event.query,
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          );

          final docRef = usersCollection.doc(querySnapshot.docs.first.id);
          final userDoc = await docRef.get();
          final data = userDoc.data() as Map<String, dynamic>;
          List<dynamic> currentHistory = data['search_history'] ?? [];

          currentHistory.add(searchData.id);

          //Update to answers collection
          await db
              .collection("answers")
              .doc(searchData.id)
              .set(searchData.toJson());

          //Update answer id in user data
          if (event.searchId == null) {
            await docRef.update({'search_history': currentHistory});
          }

          emit(state.copyWith(searchId: searchData.id, answerNumber: 1));
        }
      }
      //return buffer.toString();
    } else {
      print("❌ Groq API Error: ${streamedResponse.statusCode}");
    }
  }

  Future<void> _updateSearchData(
      ReplyUpdateQuery event, Emitter<ReplyState> emit) async {
    emit(state.copyWith(
        status: ReplyPageStatus.loading, searchQuery: event.query));
    print("Started");
    print(state.status.toString());
    int startPoint = 0;
    int endPoint = 11;
    List<ExtractedVideoInfo> videos =
        event.similarVideos.sublist(startPoint, endPoint);
    String userQuery = event.query;

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
          "2. ✅ **Bold key insights** and highlight notable places, dishes, or experiences. Wrap the **word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
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
      ..writeln("7. ⚡ Keep it under 800 characters")
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

    final request = http.Request(
      "POST",
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
    );
    request.headers.addAll({
      "Authorization": "Bearer ${dotenv.get("GROQ_API_KEY")}",
      "Content-Type": "application/json",
    });
    request.body = jsonEncode({
      "model": "deepseek-r1-distill-llama-70b",
      "messages": [
        {
          "role": "user",
          "content": prompt.toString(),
        }
      ],
      "temperature": 0.3,
      "max_tokens": 1000,
      "stream": true,
      "stop": null
    });

    final streamedResponse = await httpClient.send(request);

    if (streamedResponse.statusCode == 200) {
      final buffer = StringBuffer();
      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith("data: ")) {
          final chunk = line.substring(6).trim();
          if (chunk == "[DONE]") break;

          try {
            final jsonChunk = jsonDecode(chunk);
            final delta = jsonChunk['choices'][0]['delta'];
            if (delta != null && delta.containsKey('content')) {
              final content = delta['content'];
              if (content.toString().contains("<think>") == false) {
                buffer.write(content);
              }

              emit(state.copyWith(
                  status: ReplyPageStatus.thinking,
                  thinking: buffer.toString().split("</think>").first));
            }
          } catch (e) {
            print("Error decoding chunk: $e");
          }
        }
      }
      String answer = buffer.toString();
      answer = answer.split("</think>").last;
      emit(state.copyWith(status: ReplyPageStatus.idle, searchAnswer: answer));

      //Save answer data

      FirebaseFirestore db = FirebaseFirestore.instance;
      //Set search data and updated search history in user data
      SearchData searchData = SearchData(
        id: state.searchId,
        answer: answer,
        process: buffer.toString().split("</think>").first,
        sourceLinks: event.similarVideos.map((data){
                  return data.videoData.videoUrl;
                }).toList(),
        query: event.query,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      print(searchData.id);
      //Update to answers collection
      await db
          .collection("answers")
          .doc(searchData.id)
          .set(searchData.toJson());

      emit(state.copyWith(searchId: searchData.id, answerNumber: 1));

      //return buffer.toString();
    } else {
      print("❌ Groq API Error: ${streamedResponse.statusCode}");
    }
  }

  Future<void> _shareSearchResult(
      ReplySearchResultShare event, Emitter<ReplyState> emit) async {
    mixpanel.track("share_answer_result");
    final searchResultLink = "https://drissea.com/search/${state.searchId}";
    print("Asd");
    Clipboard.setData(ClipboardData(text: searchResultLink));
  }

  Future<void> _refreshAnswer(
      ReplyRefreshAnswer event, Emitter<ReplyState> emit) async {
    emit(state.copyWith(status: ReplyPageStatus.loading));
    int startPoint = 0;
    // event.answerNumber == 1 ? 0 : 11 + 10 * (event.answerNumber - 2);
    int endPoint = event.similarVideos
        .length; //startPoint + (event.answerNumber == 1 ? 11 : 10);
    List<ExtractedVideoInfo> videos =
        event.similarVideos.sublist(startPoint, endPoint);
    String userQuery = event.query;
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
          "2. ✅ **Bold key insights** and highlight notable places, dishes, or experiences. Wrap the **word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
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
      ..writeln("7. ⚡ Keep it under 800 characters")
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

    final request = http.Request(
      "POST",
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
    );
    request.headers.addAll({
      "Authorization": "Bearer ${dotenv.get("GROQ_API_KEY")}",
      "Content-Type": "application/json",
    });
    request.body = jsonEncode({
      "model": "deepseek-r1-distill-llama-70b",
      "messages": [
        {
          "role": "user",
          "content": prompt.toString(),
        }
      ],
      "temperature": 0.3,
      "max_tokens": 1000,
      "stream": true,
      "stop": null
    });

    final streamedResponse = await httpClient.send(request);

    if (streamedResponse.statusCode == 200) {
      final buffer = StringBuffer();
      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith("data: ")) {
          final chunk = line.substring(6).trim();
          if (chunk == "[DONE]") break;

          try {
            final jsonChunk = jsonDecode(chunk);
            final delta = jsonChunk['choices'][0]['delta'];
            if (delta != null && delta.containsKey('content')) {
              final content = delta['content'];
              if (content.toString().contains("<think>") == false) {
                buffer.write(content);
              }

              emit(state.copyWith(
                  status: ReplyPageStatus.thinking,
                  thinking: buffer.toString().split("</think>").first));
            }
          } catch (e) {
            print("Error decoding chunk: $e");
          }
        }
      }
      String answer = buffer.toString();
      answer = answer.split("</think>").last;
      emit(state.copyWith(status: ReplyPageStatus.idle, searchAnswer: answer));

      //Updated answer data
      FirebaseFirestore db = FirebaseFirestore.instance;
      final CollectionReference searchCollection = db.collection('answers');

      // Query the answer collection for a document with the matching email
      final QuerySnapshot querySnapshot = await searchCollection
          .where('id', isEqualTo: state.searchId)
          .limit(1)
          .get();

      // Check if any documents were found
      if (querySnapshot.docs.isEmpty) {
        throw Exception('Search data not found');
      } else {
        //Update search data
        final docRef = searchCollection.doc(querySnapshot.docs.first.id);
        final userDoc = await docRef.get();
        final data = userDoc.data() as Map<String, dynamic>;
        SearchData currSearchData = SearchData.fromJson(data);

        //Replace current answer with new answer in answers list
        SearchData updSearchData = SearchData(
          id: currSearchData.id,
          answer: answer,
          query: event.query,
          process: buffer.toString().split("</think>").first,
          sourceLinks: event.similarVideos.map((data){
                  return data.videoData.videoUrl;
                }).toList(),
          createdAt: currSearchData.createdAt,
          updatedAt: Timestamp.now(),
        );

        //Update to answers collection
        await db
            .collection("answers")
            .doc(currSearchData.id)
            .set(updSearchData.toJson());
      }

      //return buffer.toString();
    } else {
      print("❌ Groq API Error: ${streamedResponse.statusCode}");
    }
    mixpanel.track("refresh_answer_result");
  }

  // Future<void> _getPreviousAnswer(
  //     ReplyPreviousAnswer event, Emitter<ReplyState> emit) async {
  //   emit(state.copyWith(status: ReplyPageStatus.loading));

  //   //Get previous answer data
  //   FirebaseFirestore db = FirebaseFirestore.instance;
  //   final CollectionReference searchCollection = db.collection('answers');

  //   // Query the answer collection for a document with the matching email
  //   final QuerySnapshot querySnapshot = await searchCollection
  //       .where('id', isEqualTo: state.searchId)
  //       .limit(1)
  //       .get();

  //   // Check if any documents were found
  //   if (querySnapshot.docs.isEmpty) {
  //     throw Exception('Search data not found');
  //   } else {
  //     //Update search data
  //     final docRef = searchCollection.doc(querySnapshot.docs.first.id);
  //     final userDoc = await docRef.get();
  //     final data = userDoc.data() as Map<String, dynamic>;
  //     SearchData currSearchData = SearchData.fromJson(data);

  //     //Get previous answer
  //     AnswerData prevAnswerData =
  //         currSearchData.answers[state.answerNumber - 2];
  //     emit(state.copyWith(
  //         status: ReplyPageStatus.idle,
  //         searchAnswer: prevAnswerData.reply,
  //         answerNumber: state.answerNumber - 1));
  //   }
  // }

  // Future<void> _getNextAnswer(
  //     ReplyNextAnswer event, Emitter<ReplyState> emit) async {
  //   emit(state.copyWith(status: ReplyPageStatus.loading));

  //   //Check answer data exist
  //   FirebaseFirestore db = FirebaseFirestore.instance;
  //   final CollectionReference searchCollection = db.collection('answers');

  //   // Query the answer collection for a document with the matching email
  //   final QuerySnapshot querySnapshot = await searchCollection
  //       .where('id', isEqualTo: state.searchId)
  //       .limit(1)
  //       .get();

  //   // Check if any documents were found
  //   if (querySnapshot.docs.isEmpty) {
  //     throw Exception('Search data not found');
  //   } else {
  //     //Update search data
  //     final docRef = searchCollection.doc(querySnapshot.docs.first.id);
  //     final userDoc = await docRef.get();
  //     final data = userDoc.data() as Map<String, dynamic>;
  //     SearchData currSearchData = SearchData.fromJson(data);

  //     //Get current answers
  //     List<AnswerData> currAnswerData = currSearchData.answers;

  //     //Check if answer exists
  //     if (currAnswerData.length >= event.answerNumber) {
  //       print("donee");
  //       emit(state.copyWith(
  //           status: ReplyPageStatus.idle,
  //           thinking: currAnswerData[event.answerNumber - 1].process,
  //           searchAnswer: currAnswerData[event.answerNumber - 1].reply,
  //           answerNumber: event.answerNumber));
  //     } else {
  //       //Get Answer
  //       int startPoint =
  //           event.answerNumber == 1 ? 0 : 11 + 10 * (event.answerNumber - 2);

  //       int endPoint = startPoint + (event.answerNumber == 1 ? 11 : 10);
  //       List<ExtractedVideoInfo> videos =
  //           event.similarVideos.sublist(startPoint, endPoint);
  //       String userQuery = event.query;

  //       final prompt = StringBuffer()
  //         ..writeln(
  //             "You are a helpful and concise assistant that answers user questions using a list of insights extracted from short videos.")
  //         ..writeln("")
  //         ..writeln("The user has asked:")
  //         ..writeln("\"$userQuery\"")
  //         ..writeln("")
  //         ..writeln(
  //             "You are given brief content summaries from multiple videos. Each including a caption, video description and audio description from the respective short video")
  //         ..writeln("")
  //         ..writeln(
  //             "Your job is to write a clean, readable answer based only on the Caption/Transcript/Video Description available. Follow these rules:")
  //         ..writeln("")
  //         ..writeln("1. ✅ Structure the response clearly")
  //         ..writeln(
  //             "2. ✅ **Bold key insights** and highlight notable places, dishes, or experiences. Wrap the **word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
  //         ..writeln(
  //             "3. ✅ For any place, food item, or experience that was featured in a video, wrap the **main word or phrase** (not the whole sentence) in this format:  \n   `[text to show](<reel_link>)`\n   Example: Try the **[Dum Pukht Biryani](https://instagram.com/reel/abc123)** for something royal.")
  //         ..writeln(
  //             "4. ✅ Write naturally as if you're recommending or informing — never say “based on search results” or “these videos say.”")
  //         ..writeln(
  //             "5. From the Caption/Transcript/Video Description available, only use those that exactly answers the query. And the answer should be exactly according to the query")
  //         ..writeln(
  //             "6. ✅ If no strong or direct matches are found, gracefully say:  \n   _“There isn’t a perfect match for that, but here are a few options that might still interest you.”_")
  //         ..writeln(
  //             "6. ❌ Do not repeat the question or use generic filler lines.")
  //         ..writeln(
  //             "7. ⚡ Keep your language short, engaging, and optimized for mobile readability.")
  //         ..writeln("7. ⚡ Keep it under 800 characters")
  //         ..writeln("")
  //         ..writeln("Here’s the video content:\n");

  //       for (final video in videos) {
  //         prompt.writeln("Caption: ${video.caption}");
  //         prompt.writeln("Transcript: ${video.audioDescription}");
  //         prompt.writeln("Video Description: ${video.videoDescription}");
  //         prompt.writeln(
  //             "Video URL: https://www.instagram.com/${video.userData.username}/reel/${video.videoId}");
  //         prompt.writeln("---");
  //       }

  //       final request = http.Request(
  //         "POST",
  //         Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
  //       );
  //       request.headers.addAll({
  //         "Authorization": "Bearer ${dotenv.get("GROQ_API_KEY")}",
  //         "Content-Type": "application/json",
  //       });
  //       request.body = jsonEncode({
  //         "model": "deepseek-r1-distill-llama-70b",
  //         "messages": [
  //           {
  //             "role": "user",
  //             "content": prompt.toString(),
  //           }
  //         ],
  //         "temperature": 0.3,
  //         "max_tokens": 1000,
  //         "stream": true,
  //         "stop": null
  //       });

  //       final streamedResponse = await httpClient.send(request);

  //       if (streamedResponse.statusCode == 200) {
  //         final buffer = StringBuffer();
  //         final stream = streamedResponse.stream
  //             .transform(utf8.decoder)
  //             .transform(const LineSplitter());

  //         await for (final line in stream) {
  //           if (line.startsWith("data: ")) {
  //             final chunk = line.substring(6).trim();
  //             if (chunk == "[DONE]") break;

  //             try {
  //               final jsonChunk = jsonDecode(chunk);
  //               final delta = jsonChunk['choices'][0]['delta'];
  //               if (delta != null && delta.containsKey('content')) {
  //                 final content = delta['content'];
  //                 if (content.toString().contains("<think>") == false) {
  //                   buffer.write(content);
  //                 }

  //                 emit(state.copyWith(
  //                     status: ReplyPageStatus.thinking,
  //                     thinking: buffer.toString().split("</think>").first));
  //               }
  //             } catch (e) {
  //               print("Error decoding chunk: $e");
  //             }
  //           }
  //         }
  //         String answer = buffer.toString();
  //         answer = answer.split("</think>").last;
  //         emit(state.copyWith(
  //             status: ReplyPageStatus.idle,
  //             searchAnswer: answer,
  //             answerNumber: event.answerNumber));

  //         //Updated answer data
  //         FirebaseFirestore db = FirebaseFirestore.instance;
  //         final CollectionReference searchCollection = db.collection('answers');

  //         // Query the answer collection for a document with the matching email
  //         final QuerySnapshot querySnapshot = await searchCollection
  //             .where('id', isEqualTo: state.searchId)
  //             .limit(1)
  //             .get();

  //         // Check if any documents were found
  //         if (querySnapshot.docs.isEmpty) {
  //           throw Exception('Search data not found');
  //         } else {
  //           //Update search data
  //           final docRef = searchCollection.doc(querySnapshot.docs.first.id);
  //           final userDoc = await docRef.get();
  //           final data = userDoc.data() as Map<String, dynamic>;
  //           SearchData currSearchData = SearchData.fromJson(data);

  //           //Get current answers
  //           List<AnswerData> currAnswerData = currSearchData.answers;

  //           //Add new answer data
  //           AnswerData updAnswerData = AnswerData(
  //               reply: answer,
  //               process: buffer.toString().split("</think>").first,
  //               sourceLinks: event.similarVideos.map((data){
  //                 return data.videoData.videoUrl;
  //               }).toList(),
  //               createdAt: Timestamp.now(),
  //               updatedAt: Timestamp.now());
  //           currAnswerData.add(updAnswerData);

  //           //Replace current answers with new answers list
  //           List<AnswerData> updAnswers = currAnswerData;
  //           SearchData updSearchData = SearchData(
  //             id: currSearchData.id,
  //             answers: updAnswers,
  //             query: event.query,
  //             createdAt: currSearchData.createdAt,
  //             updatedAt: Timestamp.now(),
  //           );

  //           //Update to answers collection
  //           await db
  //               .collection("answers")
  //               .doc(currSearchData.id)
  //               .set(updSearchData.toJson());
  //         }

  //         //return buffer.toString();
  //       } else {
  //         print("❌ Groq API Error: ${streamedResponse.statusCode}");
  //       }
  //     }
  //   }
  // }

  Future<void> _updateThumbnailUrls(
      ReplyUpdateThumbnails event, Emitter<ReplyState> emit) async {
    List<String> videoThumbnails = [];
    List<String> videoUrls = [];

    emit(state.copyWith(
        assetStatus: ReplyThumbnailStatus.loading,
        videoThumbnails: [],
        videoUrls: []));
    for (final video in event.similarVideos) {
      emit(state.copyWith(assetStatus: ReplyThumbnailStatus.loading));
      final ogImage = await getOgImageFromUrl(video.videoData.videoUrl);
      if (ogImage != null) {
        videoThumbnails.add(ogImage.toString());
        videoUrls.add(video.videoData.videoUrl);
      }
      emit(state.copyWith(
          assetStatus: ReplyThumbnailStatus.idle,
          videoThumbnails: videoThumbnails,
          videoUrls: videoUrls));
    }
  }

  Future<String?> getOgImageFromUrl(String url) async {
    print(url);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.82 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parse(response.body);
        print(response.body);
        final meta = document.getElementsByTagName('meta').firstWhere(
              (e) =>
                  e.attributes['property'] == 'og:image' ||
                  e.attributes['name'] == 'og:image',
            );
        print(meta?.attributes['content']);
        return meta?.attributes['content'];
      }
    } catch (e) {
      print('Error: $e');
    }
    return null;
  }
}

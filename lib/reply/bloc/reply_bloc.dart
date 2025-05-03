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
    //Show Me
    on<ReplyFollowUpSearchVideos>(_searchPinecone);
    on<ReplyCancelTaskGen>(_cancelTaskSearchQuery);
    on<ReplySetInitialConversation>(_setInitialData);
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("reply_view");
  }

  /// Function to search Pinecone using a vector
  Future<void> _searchPinecone(
      ReplyFollowUpSearchVideos event, Emitter<ReplyState> emit) async {

    mixpanel.timeEvent("chat_reply");
    _cancelTaskGen = false;
    //Get Answer
    emit(state.copyWith(status: ReplyPageStatus.summarize));

    // Get Conversation Data using the event.conversationId
    // Get the current conversation info from it
    final db = FirebaseFirestore.instance;
    final conversationSnapshot =
        await db.collection('conversations').doc(event.conversationId).get();

    List<QuestionAnswerData> currentConversations = [];

    if (conversationSnapshot.exists) {
      Map<String, dynamic>? data = conversationSnapshot.data();
      ConversationData conversationData = ConversationData.fromJson(data!);
      currentConversations = conversationData.conversation;

      // Get reply
      String? searchAnswer = await generateMarkdownStyledAnswer(
          videos: event.savedVideos,
          userQuery: event.query,
          prevAnswer: currentConversations.last.reply);
      if (_cancelTaskGen) {
        emit(state.copyWith(status: ReplyPageStatus.idle));
        return;
      }

      //Add Conversation Data
      currentConversations.add(QuestionAnswerData(
        reply: searchAnswer ?? "",
        query: event.query,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      ));

      //Update the conversation data
      ConversationData updConversationData = ConversationData(
        id: event.conversationId,
        conversation: currentConversations,
        createdAt: conversationData.createdAt,
        updatedAt: Timestamp.now(),
      );
      await db
          .collection('conversations')
          .doc(event.conversationId)
          .update(updConversationData.toJson());

      emit(
        state.copyWith(
          status: ReplyPageStatus.idle,
          conversationData: currentConversations,
        ),
      );

      await Future.delayed(Duration(milliseconds: 300));
      event.scrollController.animateTo(
        event.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }

    mixpanel.track("chat_reply");

    // //Collect Sort Video links
    // List<String> updSortedVideoids = updSortedTaskVideos.map((video) {
    //   return video.videoId;
    // }).toList();
    // //Save Task Info
    // _saveUserTask(event.task, taskSearchQuery, updSortedVideoids);
    //navService.goTo("/searchResult", extra: updSortedTaskVideos);
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

  Future<void> _setInitialData(
      ReplySetInitialConversation event, Emitter<ReplyState> emit) async {
    initMixpanel();
    emit(state.copyWith(conversationData: event.conversation?.conversation));
  }

  Future<List<ExtractedVideoInfo>> updateThumbnailUrls(
      List<ExtractedVideoInfo> videos) async {
    List<ExtractedVideoInfo> updatedVideos = [];

    for (final video in videos) {
      final ogImage = await getOgImageFromUrl(video.videoData.videoUrl);
      final updatedVideo = ExtractedVideoInfo(
        videoId: video.videoId,
        platform: video.platform,
        searchContent: video.searchContent,
        caption: video.caption,
        videoDescription: video.videoDescription,
        audioDescription: video.audioDescription,
        userData: video.userData,
        videoData: VideoData(
          thumbnailUrl: ogImage ?? video.videoData.thumbnailUrl,
          videoUrl: video.videoData.videoUrl,
        ),
      );
      updatedVideos.add(updatedVideo);
    }

    return updatedVideos;
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

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
part 'answer_event.dart';
part 'answer_state.dart';

class AnswerBloc extends Bloc<AnswerEvent, AnswerState> {
  final http.Client httpClient;
  AnswerBloc({required this.httpClient}) : super(AnswerState()) {
    on<AnswerUpdateThumbnails>(_updateThumbnailUrls);
    on<AnswerSearchResultShare>(_shareSearchResult);
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("answer_view");
  }

  Future<Map<String, dynamic>> enrichThumbnailData(String videoUrl) async {
    String thumbnailUrl = await getOgImageFromUrl(videoUrl);
    //print({"url": videoUrl, "thumbnail": thumbnailUrl});
    return {"url": videoUrl, "thumbnail": thumbnailUrl};
  }

  Future<void> _updateThumbnailUrls(
      AnswerUpdateThumbnails event, Emitter<AnswerState> emit) async {
    await initMixpanel();
    emit(state.copyWith(
      assetStatus: AnswerThumbnailStatus.loading,
      videoThumbnails: [],
      videoUrls: [],
    ));

    final videoThumbnails = <String>[];
    final videoUrls = <String>[];

    for (final url in event.sourceUrls) {
      final thumbnail = await getOgImageFromUrl(url);
      videoThumbnails.add(thumbnail.isNotEmpty ? thumbnail : "");
      videoUrls.add(url);

      emit(state.copyWith(
        videoThumbnails: List.from(videoThumbnails),
        videoUrls: List.from(videoUrls),
      ));
    }

    emit(state.copyWith(assetStatus: AnswerThumbnailStatus.idle));
  }

  Future<String> getOgImageFromUrl(String url) async {
    String thumbnailUrl = "";

    final ogHost = dotenv.get('API_HOST');
    final ogUri = Uri.parse(
        'https://$ogHost/api/og-extract?url=${Uri.encodeComponent(url)}');
    try {
      print("trying");
      print(url);
      final ogResponse = await http.get(
        ogUri,
        headers: {
          'Authorization': 'Bearer ${dotenv.get("API_SECRET")}',
        },
      );
      if (ogResponse.statusCode == 200) {
        final ogData = jsonDecode(ogResponse.body);
        if (ogData['success'] == true) {
          thumbnailUrl = ogData['ogImage'] ?? "";
          print(thumbnailUrl);
          print("");
          print(ogData['ogUrl']);
        }
      }
    } catch (e) {
      print("OG extract failed: $e");
    }
    print(thumbnailUrl);
    return thumbnailUrl;
  }

  Future<void> _shareSearchResult(
      AnswerSearchResultShare event, Emitter<AnswerState> emit) async {
    mixpanel.track("share_answer_result");
    final searchResultLink = "https://drissea.com/search/${event.searchId}";
    Clipboard.setData(ClipboardData(text: searchResultLink));
  }
}

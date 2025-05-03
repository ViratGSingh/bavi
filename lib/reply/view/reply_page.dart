import 'dart:convert';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/models/question_answer.dart';
import 'package:bavi/reply/widgets/answer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/reply/bloc/reply_bloc.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ReplyView extends StatefulWidget {
  final String markdownText;
  final ExtractedAccountInfo? account;
  final String conversationId;
  final String query;
  final ConversationData? conversation;

  const ReplyView(
      {super.key,
      required this.markdownText,
      required this.query,
      required this.conversationId,
      required this.conversation,
      this.account});

  @override
  State<ReplyView> createState() => _ReplyViewState();
}

TextEditingController taskTextController = TextEditingController();
bool isTaskValid = false;

class _ReplyViewState extends State<ReplyView> {
  final ScrollController _scrollController = ScrollController();
  List<ExtractedVideoInfo> _videoList = [];

  @override
  void initState() {
    super.initState();
    // _videoList = widget.savedVideos;
    // updateThumbnails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // void updateThumbnails() async {
  //   for (int i = 0; i < _videoList.length; i++) {
  //     final ogImage = await context
  //         .read<ReplyBloc>()
  //         .getOgImageFromUrl(_videoList[i].videoData.videoUrl);
  //     if (ogImage != null) {
  //       setState(() {
  //         _videoList[i] = ExtractedVideoInfo(
  //           videoId: _videoList[i].videoId,
  //           platform: _videoList[i].platform,
  //           searchContent: _videoList[i].searchContent,
  //           caption: _videoList[i].caption,
  //           videoDescription: _videoList[i].videoDescription,
  //           audioDescription: _videoList[i].audioDescription,
  //           userData: _videoList[i].userData,
  //           videoData: VideoData(
  //             thumbnailUrl: ogImage,
  //             videoUrl: _videoList[i].videoData.videoUrl,
  //           ),
  //         );
  //       });
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReplyBloc(httpClient: http.Client())
        ..add(ReplySetInitialConversation(widget.conversation)),
      child: BlocBuilder<ReplyBloc, ReplyState>(builder: (context, state) {
        return SafeArea(
          child: Scaffold(
            appBar: state.status == ReplyPageStatus.idle
                ? AppBar(
                    titleSpacing: 8,
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    centerTitle: true,
                    leadingWidth: 60,
                    leading: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => const HomePage(),
                          ),
                        );
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(),
                        child: Icon(Icons.arrow_back_ios, color: Colors.black),
                      ),
                    ),
                    title: Text(
                      'Drissea',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Jua',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
            bottomSheet: state.status == ReplyPageStatus.idle
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border.all(color: Colors.black54),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: taskTextController,
                                decoration: InputDecoration(
                                  hintText: 'Ask follow-up',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                                maxLines: 1, // allow multiline input
                                onChanged: (value) {
                                  if (value.length > 7) {
                                    setState(() {
                                      isTaskValid = true;
                                    });
                                  } else {
                                    setState(() {
                                      isTaskValid = false;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity(horizontal: -4),
                              onPressed: () {
                                if (isTaskValid) {
                                  //Set Conversation Data
                                  String taskText = taskTextController.text
                                      .replaceAll(RegExp(r'[^\w\s]'), '')
                                      .toLowerCase();

                                  context.read<ReplyBloc>().add(
                                        ReplyFollowUpSearchVideos(
                                            taskText,
                                            _videoList,
                                            widget.conversationId,
                                            _scrollController),
                                      );
                                  taskTextController.text = "";
                                }
                              },
                              icon: Container(
                                margin: EdgeInsets.only(left: 0, bottom: 0),
                                decoration: BoxDecoration(
                                  color: isTaskValid == true
                                      ? Color(0xFF8A2BE2)
                                      : Color(0xFFC99DF2),
                                  shape: BoxShape.circle,
                                ),
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.send,
                                  color: Color(0xFFDFFF00),
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : null,
            backgroundColor: Colors.white,
            body: state.status != ReplyPageStatus.idle
                ? Container(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Image.asset(
                                    "assets/images/logo/icon.png",
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Visibility(
                                visible: state.status ==
                                        ReplyPageStatus.generateQuery ||
                                    state.status == ReplyPageStatus.summarize,
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFDFFF00),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Text(
                            state.status == ReplyPageStatus.generateQuery
                                ? "Understanding Query"
                                : state.status == ReplyPageStatus.summarize
                                    ? "Watching Relevant Reels"
                                    : "Loading",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 25),
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red),
                                fixedSize: Size(
                                    MediaQuery.of(context).size.width / 3, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () {
                                context.read<ReplyBloc>().add(
                                      ReplyCancelTaskGen(),
                                    );
                              },
                              child: Text("Cancel"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 125),
                    child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            if (state.conversationData.isEmpty)
                              QuestionAnswerView(
                                markdownText: widget.markdownText,
                                savedVideos: _videoList,
                                account: widget.account,
                                query: widget.query,
                              ),
                            if (state.conversationData.isNotEmpty)
                              ...state.conversationData.map((data) {
                                return Column(
                                  children: [
                                    QuestionAnswerView(
                                      account: widget.account,
                                      markdownText: data.reply,
                                      savedVideos: _videoList,
                                      query: data.query,
                                    ),
                                    SizedBox(height: 16),
                                    Divider(color: Colors.grey.shade300),
                                    SizedBox(height: 16),
                                  ],
                                );
                              }),
                          ],
                        )),
                  ),
          ),
        );
      }),
    );
  }
}

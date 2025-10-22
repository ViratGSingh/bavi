import 'dart:convert';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:bavi/answer/bloc/answer_bloc.dart';
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
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class AnswerView extends StatefulWidget {
  final List<String> sourceUrls;
  final String process;
  final String query;
  final String answer;
  final String searchId;
  final int searchTime;

  const AnswerView({
    super.key,
    required this.sourceUrls,
    required this.query,
    required this.answer,
    required this.process,
    required this.searchTime,
    required this.searchId,
  });

  @override
  State<AnswerView> createState() => _AnswerViewState();
}

TextEditingController taskTextController = TextEditingController();

class _AnswerViewState extends State<AnswerView> {
  final ScrollController _scrollController = ScrollController();
  List<ExtractedVideoInfo> _videoList = [];
  OverlayEntry? _overlayEntry;

  // ... rest of your existing code

  void _showOverlay(BuildContext context, String imageUrl) {
    _overlayEntry = OverlayEntry(
      builder: (context) => SafeArea(
        child: Container(
          color: Colors.black.withOpacity(0.7),
          padding: EdgeInsets.all(20),
          child: Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void initState() {
    super.initState();
    taskTextController.text = widget.query;
    // _videoList = widget.savedVideos;
    // updateThumbnails();
  }

  bool isThoughtProcess = false;
  bool isTaskValid = true;

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
      create: (context) => AnswerBloc(httpClient: http.Client())
        ..add(AnswerUpdateThumbnails(
          widget.sourceUrls,
        )),
      child: BlocBuilder<AnswerBloc, AnswerState>(builder: (context, state) {
        return SafeArea(
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 145,
              titleSpacing: 0,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              centerTitle: true,
              automaticallyImplyLeading: false,
              leadingWidth: 60,
              // leading: InkWell(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute<void>(
              //         builder: (BuildContext context) => const HomePage(),
              //       ),
              //     );

              //     // context.read<ReplyBloc>().add(ReplySetInitialConversation(
              //     //     widget.conversation,
              //     //     widget.query,
              //     //     widget.similarVideos.sublist(0, 11)));
              //   },
              //   child: Container(
              //     width: 24,
              //     height: 24,
              //     clipBehavior: Clip.antiAlias,
              //     decoration: BoxDecoration(),
              //     child: Icon(Icons.arrow_back_ios, color: Colors.black),
              //   ),
              // ),
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => const HomePage(),
                          ),
                        );
                      },
                      child: Text(
                        'Drissea',
                        style: TextStyle(
                          color: Colors.black, // Purple text
                          fontSize: 32,

                          fontFamily: 'Jua',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: InkWell(
                        onTap: () {
                          taskTextController.text = widget.query;
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) => HomePage(
                                query: taskTextController.text,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width - 16,
                          padding: const EdgeInsets.all(12),
                          decoration: ShapeDecoration(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  width: 1, color: Color(0xFF090E1D)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            shadows: [
                              BoxShadow(
                                color: Color(0xFF080E1D),
                                blurRadius: 0,
                                offset: Offset(0, 4),
                                spreadRadius: 0,
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Iconsax.search_normal_outline,
                                      size: 20,
                                      color: Colors.black,
                                    ),
                                    SizedBox(width: 7),
                                    Container(
                                      width: 3 *
                                          MediaQuery.of(context).size.width /
                                          4,
                                      child: Text(
                                        widget.query,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 20, top: 6, right: 20, bottom: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "About ${widget.sourceUrls.length} Videos",
                            style: TextStyle(
                                color: Colors.black,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${(widget.searchTime / 1000)} seconds",
                            style: TextStyle(
                                color: Colors.black,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 6),
                    Container(
                      height: 168,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.sourceUrls.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          bool hasThumbnails = state.videoThumbnails.isNotEmpty;
                          bool hasValidThumbnail = false;
                          if(hasThumbnails){
                            if(state.videoThumbnails.length>index){
                              hasValidThumbnail = state.videoThumbnails[index]!="";
                            }
                          }
                          print(state.videoThumbnails);

                          return AnimatedSwitcher(
                            duration: Duration(milliseconds: 300),
                            child: hasThumbnails
                                ? hasValidThumbnail?GestureDetector(
                                    onTap: () async {
                                      String href = widget.sourceUrls[index];
                                      final uri = Uri.parse(href);
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    },
                                    onLongPressStart: (_) {
                                      _showOverlay(
                                          context, state.videoThumbnails[index]);
                                    },
                                    onLongPressEnd: (_) {
                                      _hideOverlay();
                                    },
                                    child: Container(
                                      key: ValueKey(state.videoThumbnails[index]),
                                      width: 90,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          state.videoThumbnails[index],
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Shimmer.fromColors(
                                              baseColor: Colors.grey.shade300,
                                              highlightColor:
                                                  Colors.grey.shade100,
                                              child: Container(
                                                width: 100,
                                                height: 200,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ):
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey.shade300,
                                    highlightColor: Colors.grey.shade100,
                                    child: Container(
                                      width: 100,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                : Shimmer.fromColors(
                                    baseColor: Colors.grey.shade300,
                                    highlightColor: Colors.grey.shade100,
                                    child: Container(
                                      width: 100,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(0, 12, 0, 12),
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Color(0xFFE6E7E8),
                          ),
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isThoughtProcess == false
                                            ? state.status ==
                                                    AnswerPageStatus.thinking
                                                ? "Thought Process"
                                                : "Answer"
                                            : "Thought Process",
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontFamily: 'Poppins',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      // SizedBox(
                                      //   width:
                                      //       MediaQuery.of(context).size.width /
                                      //               2 -
                                      //           30,
                                      //   child: Text(
                                      //     "From ${state.answerNumber}${state.answerNumber == 1 ? 'st' : state.answerNumber == 2 ? 'nd' : state.answerNumber == 3 ? 'rd' : state.answerNumber >= 4 && state.answerNumber <= 10 ? 'th' : ''} ten videos",
                                      //     style: TextStyle(
                                      //       color: Color(0xFF8E9097),
                                      //       fontFamily: 'Poppins',
                                      //       fontSize: 14,
                                      //     ),
                                      //   ),
                                      // ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: 65,
                                    child: AnimatedToggleSwitch<bool>.dual(
                                      current: isThoughtProcess,
                                      first: false,
                                      second: true,
                                      spacing: 0.0,
                                      height: 32,
                                      style: ToggleStyle(
                                        indicatorColor: Color(0xFF8A2BE2),
                                        backgroundColor: Color(0xFFDFFF00),
                                      ),
                                      onChanged: (value) => setState(
                                          () => isThoughtProcess = value),
                                      iconBuilder: (value) => value
                                          ? Icon(
                                              Iconsax.lamp_charge_bold,
                                              color: Colors.white,
                                              size: 18,
                                            )
                                          : Icon(
                                              Iconsax.magicpen_bold,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            SizedBox(height: 10),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: state.status == ReplyPageStatus.loading
                                  ? SizedBox(
                                      height: 42,
                                      width: 42,
                                      child: Image.asset(
                                          "assets/animations/typing.gif"))
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        isThoughtProcess == true
                                            ? Container(
                                                padding: EdgeInsets.all(0),
                                                child: Text(
                                                  widget.process.trim(),
                                                  style: const TextStyle(
                                                      color: Colors.black,
                                                      fontFamily: 'Poppins',
                                                      fontSize: 16,
                                                      height: 1.5),
                                                ),
                                              )
                                            : state.status !=
                                                    AnswerPageStatus.idle
                                                ? Container(
                                                    padding: EdgeInsets.all(0),
                                                    child: Text(
                                                      widget.process.trim(),
                                                      style: const TextStyle(
                                                          color: Colors.black,
                                                          fontFamily: 'Poppins',
                                                          fontSize: 16,
                                                          height: 1.5),
                                                    ),
                                                  )
                                                : MarkdownBody(
                                                    data: widget.answer,
                                                    onTapLink: (text, href,
                                                        title) async {
                                                      if (href != null) {
                                                        final uri =
                                                            Uri.parse(href);
                                                        if (await canLaunchUrl(
                                                            uri)) {
                                                          await launchUrl(uri,
                                                              mode: LaunchMode
                                                                  .externalApplication);
                                                        }
                                                      }
                                                    },
                                                    styleSheet:
                                                        MarkdownStyleSheet
                                                                .fromTheme(
                                                                    Theme.of(
                                                                        context))
                                                            .copyWith(
                                                      h1: const TextStyle(
                                                          color: Colors.black,
                                                          fontFamily: 'Poppins',
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      h2: const TextStyle(
                                                          color: Colors.black,
                                                          fontFamily: 'Poppins',
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      h3: const TextStyle(
                                                          color: Colors.black,
                                                          fontFamily: 'Poppins',
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                      p: const TextStyle(
                                                          color: Colors.black,
                                                          fontFamily: 'Poppins',
                                                          fontSize: 16,
                                                          height: 1.5),
                                                      a: const TextStyle(
                                                        fontFamily: 'Poppins',
                                                        color:
                                                            Color(0xFF8A2BE2),
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                        decorationColor:
                                                            Color(0xFF8A2BE2),
                                                      ),
                                                      listBullet:
                                                          const TextStyle(
                                                              fontSize: 16),
                                                    ),
                                                  ),
                                      ],
                                    ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        final textToCopy =
                                            isThoughtProcess == true
                                                ? widget.process.trim()
                                                : widget.answer.trim();
                                        Clipboard.setData(
                                            ClipboardData(text: textToCopy));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Color(0xFF8A2BE2), // Purple background
                                            content: Text(
                                              'Copied to clipboard',
                                              style: TextStyle(
                                                color: Color(0xFFDFFF00), // Neon green text
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      visualDensity: VisualDensity.compact,
                                      icon:
                                          Icon(Iconsax.copy_outline, size: 18),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    //Share button
                                    IconButton(
                                      //padding: EdgeInsets.all(5),
                                      color: Color(0xFF8A2BE2),
                                      onPressed: () {
                                        context
                                            .read<AnswerBloc>()
                                            .add(AnswerSearchResultShare(widget.searchId));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Color(0xFF8A2BE2), // Purple background
                                            content: Text(
                                              'Copied to clipboard',
                                              style: TextStyle(
                                                color: Color(0xFFDFFF00), // Neon green text
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(Iconsax.send_2_bold, size: 24),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                   
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

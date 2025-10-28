import 'dart:convert';

import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/widgets/video_scroll.dart';
import 'package:bavi/home/widgets/thumbnails_scroll.dart';
import 'package:bavi/models/short_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

class VideoTaskmaster extends StatefulWidget {
  final HomePageStatus status;
  final HomeReplyStatus replyStatus;
  final HomeSavedStatus savedStatus;
  final int totalVideos;
  final int totalContentDuration;
  final bool isSearchMode;
  final bool isIncognito;
  final String query;
  final String answer;
  final List<String> followUpQuestions;
  final List<String> followUpAnswers;
  final List<ExtractedVideoInfo>? videos;
  final List<ExtractedResultInfo>? searchResults;
  final List<ExtractedVideoInfo>? longVideos;
  final List<ExtractedVideoInfo>? shortVideos;
  final Function() onCancel;
  final Function() onProfile;
  final Function() onRefresh;
  final String task;
  const VideoTaskmaster({
    super.key,
    this.videos,
    this.searchResults,
    this.shortVideos,
    this.longVideos,
    required this.isIncognito,
    required this.task,
    required this.totalContentDuration,
    required this.followUpQuestions,
    required this.followUpAnswers,
    required this.status,
    required this.replyStatus,
    required this.savedStatus,
    required this.query,
    required this.answer,
    required this.isSearchMode,
    required this.totalVideos,
    required this.onCancel,
    required this.onProfile,
    required this.onRefresh,
  });

  @override
  State<VideoTaskmaster> createState() => _VideoTaskmasterState();
}

class _VideoTaskmasterState extends State<VideoTaskmaster> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String _selectedTab = "Short Videos";

  @override
  void didUpdateWidget(VideoTaskmaster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _elapsed = Duration.zero;

      // Start timer on entering search or video processing states
      if (widget.status == HomePageStatus.getSearchResults ||
          widget.status == HomePageStatus.filterSearchResults ||
          widget.status == HomePageStatus.getResultVideos ||
          widget.status == HomePageStatus.watchResultVideos ||
          widget.replyStatus == HomeReplyStatus.loading) {
        _stopTimer();
        _startTimer();
      }

      // Stop timer when going idle or success/failure states
      if (widget.status == HomePageStatus.idle ||
          widget.status == HomePageStatus.success ||
          widget.status == HomePageStatus.failure) {
        _stopTimer();
      }
    }

    // 👇 Ensure current Q/A follow updated widget props
    if (oldWidget.query != widget.query || oldWidget.answer != widget.answer) {
      setState(() {
        _currentQuestion = widget.query;
        _currentAnswer = widget.answer;
      });
    }
  }

  void _startTimer() {
    _elapsed = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = Duration(seconds: timer.tick);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  late String _currentQuestion;
  late String _currentAnswer;

  @override
  void initState() {
    super.initState();
    _currentQuestion = widget.query;
    _currentAnswer = widget.answer;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      child: widget.status == HomePageStatus.success
          ? SingleChildScrollView(
              child: Column(
                  mainAxisAlignment: widget.status == HomePageStatus.idle
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      // width: 2 * MediaQuery.of(context).size.width / 3,
                      child: Text(
                        _currentQuestion,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: 
                      widget.isSearchMode==false?[
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTab = "Short Videos";
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: _selectedTab == "Short Videos"
                                        ? Color(0xFF8A2BE2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Color(0xFF8A2BE2))),
                                child: Text(
                                  "Instagram",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: _selectedTab == "Short Videos"
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 12,
                                    color: _selectedTab == "Short Videos"
                                        ? Color(0xFFDFFF00)
                                        : Color(0xFF8A2BE2),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 5),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTab = "Long Videos";
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: _selectedTab == "Long Videos"
                                        ? Color(0xFF8A2BE2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Color(0xFF8A2BE2))),
                                child: Text(
                                  "YouTube",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: _selectedTab == "Long Videos"
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 12,
                                    color: _selectedTab == "Long Videos"
                                        ? Color(0xFFDFFF00)
                                        : Color(0xFF8A2BE2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),


                    SizedBox(height: 5),
                    _selectedTab == "Short Videos"
                        ? ShortVideoThumbnails(
                            shortVideos: widget.shortVideos,
                          )
                        : LongVideoThumbnails(
                            longVideos: widget.longVideos,
                          ),
                      ]:[
                        SearchResultThumbnails(
                            searchResults: widget.searchResults,
                          )
                      ],
                    ),
                    // Container(
                    //   height: 168,
                    //   padding: EdgeInsets.symmetric(horizontal: 0),
                    //   child: ListView.separated(
                    //     scrollDirection: Axis.horizontal,
                    //     itemCount: widget.shortVideos?.length ?? 0,
                    //     separatorBuilder: (context, index) =>
                    //         SizedBox(width: 10),
                    //     itemBuilder: (context, index) {
                    //       // bool hasValidThumbnail =
                    //       //     index < state.videoThumbnails.length &&
                    //       //         state.videoThumbnails.isNotEmpty;
                    //       bool hasValidThumbnail =
                    //           widget.shortVideos?[index].videoData.thumbnailUrl !=
                    //               "";
                    //       return AnimatedSwitcher(
                    //           duration: Duration(milliseconds: 300),
                    //           child: hasValidThumbnail
                    //               ? GestureDetector(
                    //                   onTap: () async {
                    //                     // String href = "https://instagram.com/reels/${widget.videos?[index]
                    //                     //         .videoId ??
                    //                     //     ""}";
                    //                     // final uri = Uri.parse(href);
                    //                     // await launchUrl(uri,
                    //                     //     mode:
                    //                     //         LaunchMode.externalApplication);

                    //                     // Navigator.of(context).push(
                    //                     //   MaterialPageRoute(
                    //                     //     builder: (context) =>
                    //                     //         VideoPlayerPage(
                    //                     //             videoList:
                    //                     //                 widget.videos ?? [],
                    //                     //             initialPosition: index),
                    //                     //   ),
                    //                     // );

                    //                   },
                    //                   // onLongPressStart: (_) {
                    //                   //   _showOverlay(
                    //                   //       context,
                    //                   //       widget.similarVideos[index]
                    //                   //           .videoData.thumbnailUrl);
                    //                   // },
                    //                   // onLongPressEnd: (_) {
                    //                   //   _hideOverlay();
                    //                   // },
                    //                   child: Container(
                    //                     key: ValueKey(widget.videos?[index]
                    //                         .videoData.thumbnailUrl),
                    //                     width: 90,
                    //                     height: 160,
                    //                     decoration: BoxDecoration(
                    //                       borderRadius:
                    //                           BorderRadius.circular(8),
                    //                     ),
                    //                     child: ClipRRect(
                    //                       borderRadius:
                    //                           BorderRadius.circular(8),
                    //                       child: Image.network(
                    //                         widget.videos?[index].videoData
                    //                                 .thumbnailUrl ??
                    //                             "",
                    //                         fit: BoxFit.cover,
                    //                         loadingBuilder: (context, child,
                    //                             loadingProgress) {
                    //                           if (loadingProgress == null)
                    //                             return child;
                    //                           return Shimmer.fromColors(
                    //                             baseColor: Colors.grey.shade300,
                    //                             highlightColor:
                    //                                 Colors.grey.shade100,
                    //                             child: Container(
                    //                               width: 100,
                    //                               height: 200,
                    //                               decoration: BoxDecoration(
                    //                                 color: Colors.grey,
                    //                                 borderRadius:
                    //                                     BorderRadius.circular(
                    //                                         8),
                    //                               ),
                    //                             ),
                    //                           );
                    //                         },
                    //                       ),
                    //                     ),
                    //                   ),
                    //                 )
                    //               : null);
                    //     },
                    //   ),
                    // ),
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(vertical: 5),
                    //   child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //       children: [
                    //         Text(
                    //           "${widget.isRecallMode ? 'Recalled' : 'Watched'} ${widget.totalVideos} videos",
                    //           style: TextStyle(
                    //             color: Colors.black,
                    //             fontSize: 14,
                    //             fontFamily: 'Poppins',
                    //             fontWeight: FontWeight.w600,
                    //           ),
                    //         ),
                    //         Text(
                    //           "Saved ${widget.totalContentDuration} seconds",
                    //           style: TextStyle(
                    //             color: Colors.black,
                    //             fontSize: 14,
                    //             fontFamily: 'Poppins',
                    //             fontWeight: FontWeight.w600,
                    //           ),
                    //         ),
                    //       ]),
                    // ),
                    SizedBox(height: 10),
                    widget.replyStatus == HomeReplyStatus.loading
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(40),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(40),
                                                color: Color(0xFF8A2BE2)),
                                            child: Image.asset(
                                              "assets/images/logo/icon.png",
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(40),
                                          ),
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFDFFF00),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey.shade600,
                                    highlightColor: Colors.grey.shade300,
                                    child: Text(
                                      "Thinking of a reply",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : widget.replyStatus == HomeReplyStatus.failure
                            ? InkWell(
                                onTap: () {
                                  widget.onRefresh();
                                },
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // ClipRRect(
                                              //   borderRadius:
                                              //       BorderRadius.circular(40),
                                              //   child: Container(
                                              //     width: 24,
                                              //     height: 24,
                                              //     decoration: BoxDecoration(
                                              //         borderRadius:
                                              //             BorderRadius.circular(
                                              //                 40),
                                              //         color: Color(0xFF8A2BE2)),
                                              //     child: Image.asset(
                                              //       "assets/images/logo/icon.png",
                                              //       fit: BoxFit.cover,
                                              //     ),
                                              //   ),
                                              // ),
                                              Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFF8A2BE2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            40),
                                                  ),
                                                  child: Icon(
                                                      Iconsax.refresh_outline,
                                                      color: Color(0xFFDFFF00),
                                                      size: 18)),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          "Couldn't reply, Tap to try again",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : MarkdownBody(
                                data: _currentAnswer,
                                onTapLink: (text, href, title) async {
                                  if (href != null) {
                                    final uri = Uri.parse(href);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                        Theme.of(context))
                                    .copyWith(
                                  h1: const TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'Poppins',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  h2: const TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  h3: const TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                  p: const TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      height: 1.5),
                                  a: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF8A2BE2),
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFF8A2BE2),
                                  ),
                                  listBullet: const TextStyle(fontSize: 16),
                                ),
                              ),
                    // : Align(
                    //     alignment: Alignment.centerLeft,
                    //     child: Column(
                    //       //crossAxisAlignment: CrossAxisAlignment.start,
                    //       children:
                    //           widget.followUpQuestions.map<Widget>((q) {
                    //         return GestureDetector(
                    //           onTap: () {
                    //             setState(() {
                    //               _currentQuestion = q;
                    //               _currentAnswer = widget.followUpAnswers[
                    //                   widget.followUpQuestions.indexOf(q)];
                    //               _selectedTab = "Answer";
                    //             });
                    //           },
                    //           child: Container(
                    //             margin: EdgeInsets.symmetric(vertical: 4),
                    //             width: MediaQuery.of(context).size.width,
                    //             padding: EdgeInsets.symmetric(
                    //                 horizontal: 8, vertical: 8),
                    //             decoration: BoxDecoration(
                    //               color: Colors.white,
                    //               border: Border.all(
                    //                   color: Colors.grey.shade300),
                    //               borderRadius: BorderRadius.circular(8),
                    //             ),
                    //             child: Text(
                    //               q,
                    //               style: TextStyle(
                    //                 fontFamily: 'Poppins',
                    //                 fontSize: 14,
                    //                 color: Colors.black,
                    //               ),
                    //             ),
                    //           ),
                    //         );
                    //       }).toList(),
                    //     ),
                    //   ),
                    Visibility(
                      visible: widget.savedStatus==HomeSavedStatus.fetched?false:true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  // final textToCopy =
                                  //     isThoughtProcess == true
                                  //         ? state.thinking.trim()
                                  //         : state.searchAnswer.trim();
                                  // Clipboard.setData(
                                  //     ClipboardData(text: textToCopy));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor:
                                          Color(0xFF8A2BE2), // Purple background
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
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(0,5,10,5),
                                  child: Icon(Iconsax.copy_outline, size: 18),
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  
                                    widget.onRefresh();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10,5,5,5),
                                  child: Icon(Iconsax.refresh_outline, size: 18),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              //Source button
                              InkWell(
                                //padding: EdgeInsets.all(5)
                                onTap: () {
                                  // context
                                  //     .read<HBloc>()
                                  //     .add(ReplySearchResultShare());
                                    showModalBottomSheet(
                                      context: context,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      backgroundColor: Color(0xFF8A2BE2),
                                      builder: (context) {
                                        return Container(
                                          padding: EdgeInsets.all(16),
                                          height: MediaQuery.of(context).size.height / 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    widget.isSearchMode==false?"Videos":"Sources",
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () => Navigator.pop(context),
                                                    child: Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white24,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(Icons.close, size: 18, color: Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                              Expanded(
                                                child: widget.isSearchMode==false?
                                                ListView.separated(
                                                  itemCount: widget.videos?.length ?? 0,
                                                  separatorBuilder: (_, __) => Divider(color: Colors.purple),
                                                  itemBuilder: (context, index) {
                                                    final item = widget.videos?[index];
                                                    return GestureDetector(
                                                      onTap: () async {
                                                            final uri = Uri.parse(item?.videoData.videoUrl ?? "");
                                                            if (await canLaunchUrl(uri)) {
                                                              await launchUrl(uri,
                                                                  mode: LaunchMode.externalApplication);
                                                            }
                                                          },
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            item?.platform=="instagram"?"Instagram":"Youtube",
                                                            maxLines: 1,
                                                            style: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 16,
                                                                
                                                                color: Colors.white),
                                                          ),
                                                          SizedBox(height: 4),
                                                           Text(
                                                              item?.videoData.videoUrl ?? "",
                                                              style: TextStyle(
                                                                color: Color(0xFFDFFF00),
                                                                decoration: TextDecoration.underline,
                                                              ),
                                                            ),
                                                          
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ) 
                                                :ListView.separated(
                                                  itemCount: widget.searchResults?.length ?? 0,
                                                  separatorBuilder: (_, __) => Divider(color: Colors.purple),
                                                  itemBuilder: (context, index) {
                                                    final item = widget.searchResults?[index];
                                                    return GestureDetector(
                                                      onTap: () async {
                                                            final uri = Uri.parse(item?.url ?? "");
                                                            if (await canLaunchUrl(uri)) {
                                                              await launchUrl(uri,
                                                                  mode: LaunchMode.externalApplication);
                                                            }
                                                          },
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            item?.title ?? "",
                                                            style: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 16,
                                                                color: Colors.white),
                                                          ),
                                                          SizedBox(height: 4),
                                                           Text(
                                                              item?.url ?? "",
                                                              style: TextStyle(
                                                                color: Color(0xFFDFFF00),
                                                                decoration: TextDecoration.underline,
                                                              ),
                                                            ),
                                                          
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical:5),
                                  child: Row(
                                    children: [
                                      Icon(Iconsax.link_2_outline, size: 18, color: Color(0xFF8A2BE2),),
                                      SizedBox(width: 4),
                                      Text(
                                          widget.isSearchMode?'Sources':'Videos',
                                          style: TextStyle(
                                            color: Color(0xFF8A2BE2),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 160)
                  ]),
            )
          : Column(
              mainAxisAlignment: widget.status == HomePageStatus.idle ||
                      widget.status == HomePageStatus.loading
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: widget.status == HomePageStatus.idle
                  ? [
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    color: Color(0xFF8A2BE2)),
                                child: widget.isIncognito?Icon(RemixIcons.spy_line, 
                                color: Color(0xFFDFFF00),
                                size: 40,
                                ) :Image.asset(
                                  "assets/images/logo/icon.png",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Visibility(
                              visible: widget.status ==
                                      HomePageStatus.generateQuery ||
                                  widget.status ==
                                      HomePageStatus.getSearchResults ||
                                  widget.status == HomePageStatus.summarize,
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
                      ),
                      SizedBox(height: 5),
                      Container(
                        width: 2 * MediaQuery.of(context).size.width / 3,
                        child: Center(
                          child: widget.isIncognito?
                          Text(
                            textAlign: TextAlign.center,
                           "This search won't appear in history, use or update Drissea's memory.",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          )
                          :Text(
                            textAlign: TextAlign.center,
                            widget.status == HomePageStatus.getSearchResults
                                ? "Searching for Right Posts and Reels"
                                : widget.status ==
                                        HomePageStatus.filterSearchResults
                                    ? "${widget.isSearchMode ? 'Glancing' : 'Watching'} ${widget.totalVideos} Reels"
                                    : widget.status == HomePageStatus.summarize
                                        ? "${widget.isSearchMode ? 'Glancing' : 'Watching'} ${widget.totalVideos} Reels"
                                        : "What would you like me to ${widget.task}?",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ]
                  : widget.status == HomePageStatus.loading
                      ? [
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(40),
                                        color: Color(0xFF8A2BE2)),
                                  ),
                                ),
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFDFFF00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : widget.status == HomePageStatus.success
                          ? [
                              Align(
                                alignment: Alignment.centerLeft,
                                // width: 2 * MediaQuery.of(context).size.width / 3,
                                child: Text(
                                  _currentQuestion,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 5),
                              Container(
                                height: 168,
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: widget.videos?.length ?? 0,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    // bool hasValidThumbnail =
                                    //     index < state.videoThumbnails.length &&
                                    //         state.videoThumbnails.isNotEmpty;
                                    bool hasValidThumbnail = widget
                                            .videos?[index]
                                            .videoData
                                            .thumbnailUrl !=
                                        "";
                                    return AnimatedSwitcher(
                                        duration: Duration(milliseconds: 300),
                                        child: hasValidThumbnail
                                            ? GestureDetector(
                                                onTap: () async {
                                                  String href = widget
                                                          .videos?[index]
                                                          .videoData
                                                          .videoUrl ??
                                                      "";
                                                  final uri = Uri.parse(href);
                                                  await launchUrl(uri,
                                                      mode: LaunchMode
                                                          .externalApplication);
                                                },
                                                // onLongPressStart: (_) {
                                                //   _showOverlay(
                                                //       context,
                                                //       widget.similarVideos[index]
                                                //           .videoData.thumbnailUrl);
                                                // },
                                                // onLongPressEnd: (_) {
                                                //   _hideOverlay();
                                                // },
                                                child: Container(
                                                  key: ValueKey(widget
                                                      .videos?[index]
                                                      .videoData
                                                      .thumbnailUrl),
                                                  width: 90,
                                                  height: 160,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.network(
                                                      widget
                                                              .videos?[index]
                                                              .videoData
                                                              .thumbnailUrl ??
                                                          "",
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context,
                                                          child,
                                                          loadingProgress) {
                                                        if (loadingProgress ==
                                                            null) return child;
                                                        return Shimmer
                                                            .fromColors(
                                                          baseColor: Colors
                                                              .grey.shade300,
                                                          highlightColor: Colors
                                                              .grey.shade100,
                                                          child: Container(
                                                            width: 100,
                                                            height: 200,
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.grey,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : null);
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Watched ${widget.totalVideos} videos",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        "Saved ${widget.totalContentDuration} seconds",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ]),
                              ),
                              SizedBox(height: 5),
                              widget.replyStatus == HomeReplyStatus.loading
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                          height: 42,
                                          width: 42,
                                          child: Image.asset(
                                              "assets/animations/typing.gif")),
                                    )
                                  : widget.replyStatus ==
                                          HomeReplyStatus.failure
                                      ? Container(
                                          padding: EdgeInsets.all(0),
                                          child: Text(
                                            "",
                                            style: const TextStyle(
                                                color: Colors.black,
                                                fontFamily: 'Poppins',
                                                fontSize: 16,
                                                height: 1.5),
                                          ),
                                        )
                                      : MarkdownBody(
                                          data: _currentAnswer,
                                          onTapLink: (text, href, title) async {
                                            if (href != null) {
                                              final uri = Uri.parse(href);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri,
                                                    mode: LaunchMode
                                                        .externalApplication);
                                              }
                                            }
                                          },
                                          styleSheet:
                                              MarkdownStyleSheet.fromTheme(
                                                      Theme.of(context))
                                                  .copyWith(
                                            h1: const TextStyle(
                                                color: Colors.black,
                                                fontFamily: 'Poppins',
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold),
                                            h2: const TextStyle(
                                                color: Colors.black,
                                                fontFamily: 'Poppins',
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold),
                                            h3: const TextStyle(
                                                color: Colors.black,
                                                fontFamily: 'Poppins',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600),
                                            p: const TextStyle(
                                                color: Colors.black,
                                                fontFamily: 'Poppins',
                                                fontSize: 16,
                                                height: 1.5),
                                            a: const TextStyle(
                                              fontFamily: 'Poppins',
                                              color: Color(0xFF8A2BE2),
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor:
                                                  Color(0xFF8A2BE2),
                                            ),
                                            listBullet:
                                                const TextStyle(fontSize: 16),
                                          ),
                                        ),
                              SizedBox(height: 160)
                            ]
                          : [
                              Align(
                                alignment: Alignment.centerLeft,
                                // width: 2 * MediaQuery.of(context).size.width / 3,
                                child: Text(
                                  _currentQuestion,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 5),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(40),
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            40),
                                                    color: Color(0xFF8A2BE2)),
                                                child: Image.asset(
                                                  "assets/images/logo/icon.png",
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(40),
                                              ),
                                              child: CircularProgressIndicator(
                                                color: Color(0xFFDFFF00),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Shimmer.fromColors(
                                        baseColor: Colors.grey.shade600,
                                        highlightColor: Colors.grey.shade300,
                                        child: Text(
                                          widget.status ==
                                                  HomePageStatus.generateQuery
                                              ? "Understanding the query"
                                              : widget.status ==
                                                      HomePageStatus
                                                          .getSearchResults
                                                  ? "Searching for the right videos"
                                                  : widget.status ==
                                                          HomePageStatus
                                                              .getResultVideos
                                                      ? "Fetching ${widget.totalVideos} videos (${_elapsed.inSeconds}s)"
                                                      : widget.status ==
                                                              HomePageStatus
                                                                  .watchResultVideos
                                                          ? "Watching ${widget.totalVideos} videos (${_elapsed.inSeconds}s)"
                                                          : "",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // SizedBox(height: 25),
                              // Container(
                              //   padding: EdgeInsets.symmetric(vertical: 40),
                              //   child: ElevatedButton(
                              //     style: ElevatedButton.styleFrom(
                              //       backgroundColor: Colors.white,
                              //       foregroundColor: Colors.red,
                              //       side: BorderSide(color: Colors.red),
                              //       fixedSize:
                              //           Size(MediaQuery.of(context).size.width / 3, 48),
                              //       shape: RoundedRectangleBorder(
                              //         borderRadius: BorderRadius.circular(24),
                              //       ),
                              //     ),
                              //     onPressed: () {
                              //       widget.onCancel();
                              //     },
                              //     child: Text("Cancel"),
                              //   ),
                              // ),
                            ],
            ),
    );
  }
}

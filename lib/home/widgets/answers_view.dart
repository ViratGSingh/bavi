import 'dart:convert';
import 'dart:async';

import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/home/widgets/youtube_video_card.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bavi/home/widgets/web_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ThreadAnswerView extends StatefulWidget {
  final List<YoutubeVideoData> youtubeVideos;
  final List<ShortVideoResultData> shortVideos;
  final List<InfluenceData> answerResults;
  final String query;
  final String answer;
  final bool hideRefresh;
  final HomePageStatus status;
  final HomeReplyStatus replyStatus;
  final Function() onRefresh;
  final Function() onEditSelected;
  final String sourceImageUrl;
  final Uint8List? sourceImage;
  final List<LocalResultData> local;
  final Function(String url) onLinkTap;
  final ExtractedUrlResultData? extractedUrlData;
  final String? deepDrissyReadingStatus;
  final List<Map<String, String>> condensingSources;
  final String? obsidianNoteName;
  final List<VisualBrowseResultData> visualBrowseResults;
  final String? visualBrowseAnalysisStatus;
  final List<MoodboardResultData> moodboardResults;
  final String? moodboardAnalysisStatus;
  final String? moodboardProgressText;
  /// All image URIs extracted so far (accepted + being scanned) — for scan animation
  final List<String> moodboardScanImages;
  /// Images extracted from Google Images during browse search
  final List<VisualBrowseResultData> browseImages;
  const ThreadAnswerView({
    super.key,
    required this.youtubeVideos,
    required this.shortVideos,
    required this.answerResults,
    required this.query,
    required this.answer,
    required this.status,
    required this.replyStatus,
    required this.onRefresh,
    required this.onEditSelected,
    required this.hideRefresh,
    required this.sourceImageUrl,
    required this.sourceImage,
    required this.local,
    required this.onLinkTap,
    this.extractedUrlData,
    this.deepDrissyReadingStatus,
    this.condensingSources = const [],
    this.obsidianNoteName,
    this.visualBrowseResults = const [],
    this.visualBrowseAnalysisStatus,
    this.moodboardResults = const [],
    this.moodboardAnalysisStatus,
    this.moodboardProgressText,
    this.moodboardScanImages = const [],
    this.browseImages = const [],
  });

  @override
  State<ThreadAnswerView> createState() => _ThreadAnswerViewState();
}

class _ThreadAnswerViewState extends State<ThreadAnswerView> {
  String _selectedTab = "";

  @override
  void initState() {
    super.initState();
    _initializeTab();
  }

  @override
  void didUpdateWidget(covariant ThreadAnswerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeVideos != widget.youtubeVideos ||
        oldWidget.local != widget.local) {
      _initializeTab();
    }
  }

  void _initializeTab() {
    if (widget.shortVideos.isNotEmpty) {
      _selectedTab = "Instagram";
    } else if (widget.youtubeVideos.isNotEmpty) {
      _selectedTab = "YouTube";
    } else if (widget.local.isNotEmpty) {
      _selectedTab = "Map";
    } else {
      _selectedTab = "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // //Extracted URL
        // if (widget.extractedUrlData?.title != "" ||
        //     widget.extractedUrlData?.snippet != "")
        //   Container(
        //     margin: EdgeInsets.only(right: 8, left: 8, bottom: 12),
        //     alignment: Alignment.centerRight,
        //     width: MediaQuery.of(context).size.width,
        //     height: 220,
        //     decoration: BoxDecoration(
        //       color: Colors.white,
        //       borderRadius: BorderRadius.circular(16),
        //       boxShadow: [
        //         BoxShadow(
        //           color: Colors.black.withOpacity(0.1),
        //           blurRadius: 10,
        //           offset: Offset(0, 4),
        //         ),
        //       ],
        //     ),
        //     child: Stack(
        //       children: [
        //         // Background Image
        //         ClipRRect(
        //           borderRadius: BorderRadius.circular(16),
        //           child: Image.network(
        //             widget.extractedUrlData?.thumbnail ?? "",
        //             width: double.infinity,
        //             height: double.infinity,
        //             fit: BoxFit.cover,
        //             errorBuilder: (context, error, stackTrace) {
        //               return Container(
        //                 color: Colors.grey.shade200,
        //                 child: Center(
        //                   child: Icon(
        //                     Icons.image_not_supported,
        //                     color: Colors.grey.shade400,
        //                     size: 40,
        //                   ),
        //                 ),
        //               );
        //             },
        //           ),
        //         ),
        //         // Gradient Overlay
        //         Container(
        //           decoration: BoxDecoration(
        //             borderRadius: BorderRadius.circular(16),
        //             gradient: LinearGradient(
        //               begin: Alignment.topCenter,
        //               end: Alignment.bottomCenter,
        //               colors: [
        //                 Colors.transparent,
        //                 Colors.black.withOpacity(0.7),
        //               ],
        //               stops: [0.5, 1.0],
        //             ),
        //           ),
        //         ),
        //         // Title at Bottom Left
        //         Positioned(
        //           left: 16,
        //           right: 16,
        //           bottom: 12,
        //           child: Text(
        //             (widget.extractedUrlData?.title == ""
        //                     ? widget.extractedUrlData?.snippet
        //                     : widget.extractedUrlData?.title) ??
        //                 "",
        //             style: TextStyle(
        //               color: Colors.white,
        //               fontSize: 16,
        //               fontWeight: FontWeight.bold,
        //               shadows: [
        //                 Shadow(
        //                   color: Colors.black.withOpacity(0.5),
        //                   blurRadius: 4,
        //                   offset: Offset(0, 2),
        //                 ),
        //               ],
        //             ),
        //             maxLines: 2,
        //             overflow: TextOverflow.ellipsis,
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        if (widget.obsidianNoteName != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, left: 50, top: 12, bottom: 4),
              child: Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF8A2BE2), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.obsidianNoteName!.replaceAll(RegExp(r'\.[^.]+$'), ''),
                        style: const TextStyle(
                          color: Color(0xFF3D1466),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A2BE2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (RegExp(r'\.([^.]+)$').firstMatch(widget.obsidianNoteName!)?.group(1)?.toUpperCase()) ?? 'FILE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Builder(
            builder: (context) {
              return GestureDetector(
                onLongPressStart: (details) async {
                  HapticFeedback.mediumImpact();
                  final position = details.globalPosition;
                  await showMenu(
                    context: context,
                    color: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    position: RelativeRect.fromLTRB(
                      position.dx,
                      position.dy,
                      position.dx,
                      position.dy,
                    ),
                    items: [
                      PopupMenuItem(
                        value: "copy",
                        child: SizedBox(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Copy"),
                              Icon(Icons.copy, size: 18, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                      // PopupMenuItem(
                      //   value: "edit",
                      //   child: SizedBox(
                      //     child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //       children: [
                      //         Text("Edit"),
                      //         Icon(Icons.edit,
                      //             size: 18, color: Colors.black),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                    ],
                  ).then((value) {
                    if (value == "copy") {
                      Clipboard.setData(ClipboardData(text: widget.query));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Color(0xFF8A2BE2),
                          content: Text(
                            'Copied to clipboard',
                            style: TextStyle(
                              color: Color(0xFFDFFF00),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else if (value == "edit") {
                      widget.onEditSelected();
                    }
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(right: 8, left: 50, top: 12),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Color(0xFFe6e7e8), // Light purple bubble
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(4),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    widget.query,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.sourceImageUrl.isNotEmpty || widget.sourceImage != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 50, top: 10),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.sourceImageUrl.isNotEmpty
                    ? Image.network(
                        widget.sourceImageUrl,
                        height: 120,
                      )
                    : Image.memory(
                        widget.sourceImage!,
                        height: 120,
                      )),
          ),
        SizedBox(height: 20),
        widget.status != HomePageStatus.success ||
                widget.replyStatus != HomeReplyStatus.success
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnswerLoader(
                    loaderText: widget.deepDrissyReadingStatus != null
                            ? widget.deepDrissyReadingStatus!
                            : widget.status == HomePageStatus.generateQuery
                                ? "Understanding"
                                : widget.status == HomePageStatus.getSearchResults
                                    ? "Reading"
                                    : widget.condensingSources.isNotEmpty
                                        ? "Reading sources"
                                        : "Thinking",
                  ),
                  if (widget.condensingSources.isNotEmpty) ...[
                    SizedBox(height: 16),
                    SourceCondensingList(sources: widget.condensingSources),
                  ],
                  SizedBox(
                    height: widget.condensingSources.isNotEmpty
                        ? 40
                        : MediaQuery.of(context).size.height / 3,
                  )
                ],
              )
            : (widget.moodboardResults.isNotEmpty ||
                        widget.moodboardScanImages.isNotEmpty ||
                        (widget.moodboardProgressText != null &&
                            widget.moodboardProgressText!.isNotEmpty) ||
                        widget.moodboardAnalysisStatus != null)
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                    child: _MoodboardView(
                      results: widget.moodboardResults,
                      scanImages: widget.moodboardScanImages,
                      moodboardTitle: widget.query,
                      progressText: widget.moodboardProgressText,
                      analysisStatus: widget.moodboardAnalysisStatus,
                    ),
                  )
                : widget.visualBrowseResults.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VisualBrowseAlbum(
                          results: widget.visualBrowseResults,
                          analysisStatus: widget.visualBrowseAnalysisStatus,
                        ),
                        if (widget.answer.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SelectionArea(
                            child: MarkdownBody(
                              data: widget.answer,
                              onTapLink: (text, href, title) async {
                                if (href != null) widget.onLinkTap(href);
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
                                listBullet:
                                    const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ] else if (widget.visualBrowseAnalysisStatus != null) ...[
                          // Answer not yet started but analysis is running — show loader
                          const SizedBox(height: 8),
                          AnswerLoader(loaderText: widget.visualBrowseAnalysisStatus!),
                        ] else if (widget.deepDrissyReadingStatus != null) ...[
                          const SizedBox(height: 8),
                          AnswerLoader(loaderText: widget.deepDrissyReadingStatus!),
                        ],
                      ],
                    ),
                  )
                : Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.browseImages.isNotEmpty) ...[
                      _BrowseImageStrip(images: widget.browseImages),
                    ],
                    if (widget.youtubeVideos.isNotEmpty ||
                        widget.local.isNotEmpty ||
                        widget.shortVideos.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            if (widget.shortVideos.isNotEmpty) ...[
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = "Instagram";
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == "Instagram"
                                        ? Color(0xFF8A2BE2)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Instagram",
                                    style: TextStyle(
                                      color: _selectedTab == "Instagram"
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                            ],
                            if (widget.youtubeVideos.isNotEmpty) ...[
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = "YouTube";
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == "YouTube"
                                        ? Color(0xFF8A2BE2)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "YouTube",
                                    style: TextStyle(
                                      color: _selectedTab == "YouTube"
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                            ],
                            if (widget.local.isNotEmpty) ...[
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = "Map";
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == "Map"
                                        ? Color(0xFF8A2BE2)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Map",
                                    style: TextStyle(
                                      color: _selectedTab == "Map"
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (_selectedTab == "Instagram" &&
                        widget.shortVideos.isNotEmpty) ...[
                      AspectRatio(
                        aspectRatio: 1.65,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 10),
                          child: PageView.builder(
                            padEnds: false,
                            controller: PageController(viewportFraction: 0.4),
                            itemCount: widget.shortVideos.length > 5
                                ? 5
                                : widget.shortVideos.length,
                            itemBuilder: (context, index) {
                              final video = widget.shortVideos[index];
                              return InstagramVideoCard(video: video);
                            },
                          ),
                        ),
                      ),
                    ],
                    if (_selectedTab == "YouTube" &&
                        widget.youtubeVideos.isNotEmpty) ...[
                      AspectRatio(
                        aspectRatio: 1.65,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 10),
                          child: PageView.builder(
                            padEnds: false,
                            controller: PageController(viewportFraction: 0.92),
                            itemCount: widget.youtubeVideos.length > 5
                                ? 5
                                : widget.youtubeVideos.length,
                            itemBuilder: (context, index) {
                              final video = widget.youtubeVideos[index];
                              return YoutubeVideoCard(video: video);
                            },
                          ),
                        ),
                      ),
                    ],
                    if (_selectedTab == "Map" && widget.local.isNotEmpty) ...[
                      Container(
                        height: 310,
                        padding: EdgeInsets.only(bottom: 10),
                        child: PageView.builder(
                          padEnds: false,
                          controller: PageController(viewportFraction: 0.92),
                          itemCount:
                              widget.local.length > 5 ? 5 : widget.local.length,
                          itemBuilder: (context, index) {
                            final place = widget.local[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: PlaceCard(place: place),
                            );
                          },
                        ),
                      ),
                    ],
                    SelectionArea(
                        child: MarkdownBody(
                          data: widget.answer,
                          onTapLink: (text, href, title) async {
                            if (href != null) {
                              widget.onLinkTap(href);
                            }
                          },
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context))
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
                      ),
                  ],
                ),
              ),
        Visibility(
          visible: widget.status == HomePageStatus.success &&
              widget.replyStatus == HomeReplyStatus.success,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (widget.moodboardResults.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.moodboardResults.length} photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else ...[
                  InkWell(
                    onTap: () {
                      final textToCopy = widget.answer.trim();
                      Clipboard.setData(ClipboardData(text: textToCopy));
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
                      padding: const EdgeInsets.fromLTRB(0, 5, 10, 5),
                      child: Icon(Iconsax.copy_outline, size: 18),
                    ),
                  ),
                  Visibility(
                    visible: !widget.hideRefresh,
                    child: InkWell(
                      onTap: () async {
                        widget.onRefresh();
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
                        child: Icon(Iconsax.refresh_outline, size: 18),
                      ),
                    ),
                  ),
                  // InkWell(
                  //   onTap: () async {
                  //     // context.read<HomeBloc>().add(
                  //     //       HomeStartNewThread(),
                  //     //     );
                  //     // taskTextController.clear();
                  //     // setState(() {
                  //     //   isTaskValid = false;
                  //     // });
                  //     // mixpanel.track("start_new_thread");
                  //   },
                  //   child: Container(
                  //     width: 32,
                  //     height: 32,
                  //     decoration: BoxDecoration(
                  //         // borderRadius: BorderRadius.circular(18),
                  //         // color: Color(0xFFDFFF00),
                  //         // border: Border.all()
                  //         ),
                  //     child: Center(
                  //       child: Icon(
                  //         Iconsax.send_2_outline,
                  //         color: Colors.black,
                  //         size: 20,
                  //       ),
                  //     ),
                  //   ),
                  // )
                  ],
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
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        backgroundColor: Colors.white,
                        builder: (context) {
                          final sortedResults = [
                            ...widget.answerResults
                                .where((r) => r.isVerified),
                            ...widget.answerResults
                                .where((r) => !r.isVerified),
                          ];
                          final verifiedCount =
                              sortedResults.where((r) => r.isVerified).length;

                          // Check if sources are grouped by query (Deep Drissy)
                          final hasGroups = sortedResults
                              .any((r) => r.sourceQuery.isNotEmpty);

                          // Build grouped map preserving insertion order
                          final Map<String, List<InfluenceData>>
                              groupedSources = {};
                          if (hasGroups) {
                            for (final item in sortedResults) {
                              final key = item.sourceQuery.isNotEmpty
                                  ? item.sourceQuery
                                  : 'Other';
                              groupedSources
                                  .putIfAbsent(key, () => [])
                                  .add(item);
                            }
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Handle bar
                                Center(
                                  child: Container(
                                    margin: EdgeInsets.only(top: 12),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                "Sources",
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              if (hasGroups) ...[
                                                SizedBox(width: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFE8D5FF),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.auto_awesome,
                                                        size: 12,
                                                        color: const Color(
                                                            0xFF8A2BE2),
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Deep Drissy",
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                              0xFF8A2BE2),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (verifiedCount > 0)
                                            Text(
                                              "$verifiedCount verified",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () => Navigator.pop(context),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.close,
                                              size: 18,
                                              color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12),
                                Divider(
                                    height: 1,
                                    color: Colors.grey.shade200),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        MediaQuery.of(context).size.height *
                                            0.60,
                                  ),
                                  child: hasGroups
                                      ? _buildGroupedSourcesList(
                                          context, groupedSources)
                                      : _buildFlatSourcesList(
                                          context, sortedResults),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).padding.bottom +
                                          12,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.link_2_outline,
                            size: 18,
                            color: Color(0xFF8A2BE2),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Sources',
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
      ],
    );
  }

  /// Builds the flat (non-grouped) sources list - original behavior
  Widget _buildFlatSourcesList(
      BuildContext context, List<InfluenceData> sortedResults) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedResults.length,
      itemBuilder: (context, index) {
        final item = sortedResults[index];
        final isLast = index == sortedResults.length - 1;
        return Column(
          children: [
            _buildSourceItem(context, item, index, isLast),
          ],
        );
      },
    );
  }

  /// Builds grouped sources list for Deep Drissy mode
  Widget _buildGroupedSourcesList(
      BuildContext context, Map<String, List<InfluenceData>> groupedSources) {
    final queryKeys = groupedSources.keys.toList();
    int globalIndex = 0;

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: queryKeys.asMap().entries.map((entry) {
          final queryIndex = entry.key;
          final queryText = entry.value;
          final sources = groupedSources[queryText]!;
          final isLastGroup = queryIndex == queryKeys.length - 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Query section header
              Padding(
                padding: EdgeInsets.fromLTRB(20, queryIndex == 0 ? 12 : 20, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8A2BE2),
                            const Color(0xFFAB47BC),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          "${queryIndex + 1}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        queryText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${sources.length}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sources for this query
              ...sources.asMap().entries.map((sourceEntry) {
                final localIndex = sourceEntry.key;
                final item = sourceEntry.value;
                final currentGlobal = globalIndex;
                globalIndex++;
                final isLastInGroup = localIndex == sources.length - 1;
                return Column(
                  children: [
                    _buildSourceItem(
                        context, item, currentGlobal, false),
                    if (!isLastInGroup)
                      Divider(
                        height: 1,
                        indent: 60,
                        endIndent: 20,
                        color: Colors.grey.shade100,
                      ),
                  ],
                );
              }),
              // Group separator
              if (!isLastGroup)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Builds a single source item row (shared between flat and grouped lists)
  Widget _buildSourceItem(
      BuildContext context, InfluenceData item, int index, bool isLast) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            if (item.url.isNotEmpty) {
              Navigator.pop(context);
              // Pass snippet text to highlight on the source page
              String? highlightText = item.snippet;
              if (highlightText.length > 200) {
                highlightText = highlightText.substring(0, 200);
              }
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => WebViewPage(
                  url: item.url,
                  highlightText: highlightText,
                ),
              ));
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source number badge
                Container(
                  width: 28,
                  height: 28,
                  margin: EdgeInsets.only(right: 12, top: 1),
                  decoration: BoxDecoration(
                    color: item.isVerified
                        ? Colors.green.shade50
                        : const Color(0xFF8A2BE2).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: item.isVerified
                            ? Colors.green.shade700
                            : const Color(0xFF8A2BE2),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (item.isVerified) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.green.shade300, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 11,
                                    color: Colors.green.shade600,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: Colors.green.shade600,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        item.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF8A2BE2),
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFF8A2BE2),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 60,
            endIndent: 20,
            color: Colors.grey.shade100,
          ),
      ],
    );
  }
}

class SourceCondensingList extends StatefulWidget {
  final List<Map<String, String>> sources;
  const SourceCondensingList({super.key, required this.sources});

  @override
  State<SourceCondensingList> createState() => _SourceCondensingListState();
}

class _SourceCondensingListState extends State<SourceCondensingList>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _activeIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Cycle through sources to show reading progress
    if (widget.sources.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) {
          setState(() {
            _activeIndex = (_activeIndex + 1) % widget.sources.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.sources.length, (index) {
        final source = widget.sources[index];
        final title = source["title"] ?? "";
        final url = source["url"] ?? "";
        final domain = _extractDomain(url);
        final isActive = index == _activeIndex;

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final opacity = isActive
                ? 0.6 + (_pulseController.value * 0.4)
                : 0.35;

            return AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 400),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF8A2BE2).withValues(alpha: 0.05)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF8A2BE2).withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Source number badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF8A2BE2).withValues(alpha: 0.12)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? const Color(0xFF8A2BE2)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title and domain
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.black87
                                  : Colors.grey.shade500,
                              height: 1.3,
                            ),
                          ),
                          if (domain.isNotEmpty && !url.startsWith("memory://"))
                            Text(
                              domain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Poppins',
                                color: isActive
                                    ? const Color(0xFF8A2BE2).withValues(alpha: 0.7)
                                    : Colors.grey.shade400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Reading indicator
                    if (isActive)
                      Shimmer.fromColors(
                        baseColor: const Color(0xFF8A2BE2),
                        highlightColor: const Color(0xFF8A2BE2).withValues(alpha: 0.3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8A2BE2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Reading",
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A2BE2),
                            ),
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Colors.grey.shade300,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class AnswerLoader extends StatelessWidget {
  final String loaderText;
  const AnswerLoader({super.key, required this.loaderText});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        // padding: EdgeInsets.all(8),
        // decoration: BoxDecoration(
        //   border: Border.all(color: Colors.grey.shade400),
        //   borderRadius: BorderRadius.circular(12),
        // ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // SizedBox(
            //   width: 24,
            //   height: 24,
            //   child: Stack(
            //     alignment: Alignment.center,
            //     children: [
            //       ClipRRect(
            //         borderRadius: BorderRadius.circular(40),
            //         child: Container(
            //           width: 24,
            //           height: 24,
            //           decoration: BoxDecoration(
            //               borderRadius: BorderRadius.circular(40),
            //               color: Color(0xFF8A2BE2)),
            //           child: Image.asset(
            //             "assets/images/logo/icon.png",
            //             fit: BoxFit.cover,
            //           ),
            //         ),
            //       ),
            //       Container(
            //         width: 24,
            //         height: 24,
            //         decoration: BoxDecoration(
            //           borderRadius: BorderRadius.circular(40),
            //         ),
            //         child: CircularProgressIndicator(color: Color(0xFF8A2BE2)),
            //       ),
            //     ],
            //   ),
            // ),
            // SizedBox(width: 12),
            Shimmer.fromColors(
              baseColor: Colors.grey.shade600,
              highlightColor: Colors.grey.shade300,
              child: Text(
                loaderText,
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
    );
  }
}

class PlaceCard extends StatefulWidget {
  final LocalResultData place;
  const PlaceCard({super.key, required this.place});

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  int _currentImageIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.place.images.length > 1) {
      _timer = Timer.periodic(Duration(seconds: 4), (timer) {
        if (mounted) {
          setState(() {
            _currentImageIndex =
                (_currentImageIndex + 1) % widget.place.images.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final query = Uri.encodeComponent(
            "${widget.place.title} ${widget.place.address}");
        final mapUrl =
            "https://www.google.com/maps/search/?api=1&query=$query&query_place_id=${widget.place.placeId}";
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => WebViewPage(url: mapUrl),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image Slideshow
              AnimatedSwitcher(
                duration: Duration(milliseconds: 800),
                child: widget.place.images.isNotEmpty
                    ? Image.network(
                        widget.place.images[_currentImageIndex],
                        key: ValueKey<String>(
                            widget.place.images[_currentImageIndex]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade900,
                          child: Center(
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.white54)),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade900,
                        child: Center(
                            child: Icon(Icons.place,
                                size: 40, color: Colors.white54)),
                      ),
              ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: [0.0, 0.5, 0.8, 1.0],
                  ),
                ),
              ),

              // // More button
              // Positioned(
              //   top: 0,
              //   right: 0,
              //   child: IconButton(
              //     icon: Icon(
              //       Iconsax.location_bold,
              //       color: Colors.white,
              //     ),
              //     onPressed: () {},
              //   ),
              // ),

              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.place.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF8A2BE2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${widget.place.rating}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.star, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "${widget.place.reviews} reviews",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      // if (widget.place.address.isNotEmpty) ...[
                      //   SizedBox(height: 8),
                      //   Row(
                      //     children: [
                      //       Icon(Icons.location_on,
                      //           size: 14, color: Colors.white70),
                      //       SizedBox(width: 4),
                      //       Expanded(
                      //         child: Text(
                      //           widget.place.address,
                      //           style: TextStyle(
                      //             color: Colors.white.withOpacity(0.8),
                      //             fontSize: 13,
                      //             fontFamily: 'Poppins',
                      //           ),
                      //           maxLines: 1,
                      //           overflow: TextOverflow.ellipsis,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InstagramVideoCard extends StatelessWidget {
  final ShortVideoResultData video;

  const InstagramVideoCard({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => WebViewPage(url: video.link),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            CachedNetworkImage(
              imageUrl: video.thumbnail,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF8A2BE2),
                  ),
                ),
              ),
              errorWidget: (context, error, stackTrace) => Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white54, size: 48),
                ),
              ),
            ),

            // Gradient overlays
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Play icon overlay
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8A2BE2).withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A2BE2).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            // Title at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    height: 1.3,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Browse Image Strip ───────────────────────────────────────────────────────

class _BrowseImageStrip extends StatefulWidget {
  final List<VisualBrowseResultData> images;
  const _BrowseImageStrip({required this.images});

  static const _heroPrefix = 'browse_img';

  @override
  State<_BrowseImageStrip> createState() => _BrowseImageStripState();
}

class _BrowseImageStripState extends State<_BrowseImageStrip> {
  // Number of slots shown at once (based on total image count)
  int get _slotCount {
    final n = widget.images.length;
    if (n >= 4) return 4;
    return n; // 0, 1, 2, 3
  }

  // Current image index shown in each slot
  late List<int> _slotIndices;
  // Next image index to rotate in
  int _nextIndex = 0;

  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _initSlots();
    if (widget.images.length > _slotCount) {
      _scheduleCycle();
    }
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  void _initSlots() {
    final count = _slotCount;
    _slotIndices = List.generate(count, (i) => i);
    _nextIndex = count % widget.images.length;
  }

  void _scheduleCycle() {
    _cycleTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _rotateCycle();
    });
  }

  void _rotateCycle() {
    final count = _slotIndices.length;
    for (int slot = 0; slot < count; slot++) {
      Future.delayed(Duration(milliseconds: slot * 380), () {
        if (!mounted) return;
        setState(() {
          _slotIndices[slot] = _nextIndex;
          _nextIndex = (_nextIndex + 1) % widget.images.length;
        });
      });
    }
  }

  void _openLightbox(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, animation, _) => _AnswersImageLightbox(
          results: widget.images,
          initialIndex: 0,
          heroTagPrefix: _BrowseImageStrip._heroPrefix,
        ),
        transitionsBuilder: (ctx, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  Widget _cell(int slot) {
    final item = widget.images[_slotIndices[slot]];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: _AlbumTileImage(
        key: ValueKey(item.thumbnailDataUri.hashCode),
        src: item.thumbnailDataUri,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    final count = _slotCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _openLightbox(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8A2BE2).withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: count == 1
                  ? _cell(0)
                  : count == 2
                      ? Row(children: [
                          Expanded(child: _cell(0)),
                          const SizedBox(width: 2),
                          Expanded(child: _cell(1)),
                        ])
                      : count == 3
                          ? Row(children: [
                              Expanded(flex: 55, child: _cell(0)),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: 45,
                                child: Column(children: [
                                  Expanded(child: _cell(1)),
                                  const SizedBox(height: 2),
                                  Expanded(child: _cell(2)),
                                ]),
                              ),
                            ])
                          : Column(children: [
                              Expanded(
                                child: Row(children: [
                                  Expanded(child: _cell(0)),
                                  const SizedBox(width: 2),
                                  Expanded(child: _cell(1)),
                                ]),
                              ),
                              const SizedBox(height: 2),
                              Expanded(
                                child: Row(children: [
                                  Expanded(child: _cell(2)),
                                  const SizedBox(width: 2),
                                  Expanded(child: _cell(3)),
                                ]),
                              ),
                            ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Visual Browse Album ─────────────────────────────────────────────────────

class _VisualBrowseAlbum extends StatelessWidget {
  final List<VisualBrowseResultData> results;
  final String? analysisStatus;
  const _VisualBrowseAlbum({required this.results, this.analysisStatus});

  void _openLightbox(BuildContext context, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, animation, _) => _AnswersImageLightbox(
          results: results,
          initialIndex: index,
        ),
        transitionsBuilder: (ctx, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8A2BE2), Color(0xFFAB47BC)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8A2BE2).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_rounded,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        '${results.length} image${results.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Tap to view',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          // 3-column album grid — wrapped in RepaintBoundary so token
          // stream rebuilds above don't repaint the image tiles
          RepaintBoundary(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                return GestureDetector(
                  onTap: () => _openLightbox(context, index),
                  child: Hero(
                    tag: 'answers_vb_img_${item.thumbnailDataUri.hashCode}_$index',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFFF3F4F6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8A2BE2).withValues(alpha: 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _AlbumTileImage(
                          key: ValueKey(item.thumbnailDataUri.hashCode),
                          src: item.thumbnailDataUri,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // if (analysisStatus != null) ...[
          //   const SizedBox(height: 12),
          //   _VBAnalyzingIndicator(status: analysisStatus!),
          // ],
        ],
      ),
    );
  }
}

// ─── Moodboard ────────────────────────────────────────────────────────────────

class _MoodboardView extends StatelessWidget {
  final List<MoodboardResultData> results;
  /// All image URIs seen so far (accepted + being scanned) — for scanning grid
  final List<String> scanImages;
  final String moodboardTitle;
  final String? progressText;
  final String? analysisStatus;

  const _MoodboardView({
    required this.results,
    required this.scanImages,
    required this.moodboardTitle,
    this.progressText,
    this.analysisStatus,
  });

  void _openLightbox(BuildContext context, int index) {
    HapticFeedback.mediumImpact();
    // Convert to VisualBrowseResultData to reuse the existing lightbox
    final vbResults = results
        .map((r) => VisualBrowseResultData(
              thumbnailDataUri: r.thumbnailDataUri,
              title: r.title,
              sourceLink: r.sourceLink,
            ))
        .toList();
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, animation, _) => _AnswersImageLightbox(
          results: vbResults,
          initialIndex: index,
        ),
        transitionsBuilder: (ctx, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAlbumGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.0,
        ),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          return GestureDetector(
            onTap: () => _openLightbox(context, index),
            child: Hero(
              tag: 'moodboard_album_${item.thumbnailDataUri.hashCode}_$index',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF3F0FF),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A2BE2).withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _AlbumTileImage(
                    key: ValueKey(item.thumbnailDataUri.hashCode),
                    src: item.thumbnailDataUri,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // progressText is non-empty during query generation; analysisStatus=='scanning' during scan phase
    final bool isWorking = (progressText != null && progressText!.isNotEmpty) || analysisStatus == 'scanning';
    final bool isGeneratingQueries = isWorking && scanImages.isEmpty && results.isEmpty && analysisStatus != 'scanning';
    final bool isScanning = scanImages.isNotEmpty && (analysisStatus == 'scanning' || (progressText != null && progressText!.isNotEmpty));
    final bool isDone = results.isNotEmpty && analysisStatus == null && (progressText == null || progressText!.isEmpty);

    // Set of accepted URIs for fast lookup in scanning grid
    final acceptedUris = results.map((r) => r.thumbnailDataUri).toSet();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // // ── Header ──────────────────────────────────────────────────────────
          // Padding(
          //   padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          //   child: Row(
          //     children: [
          //       Container(
          //         padding:
          //             const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          //         decoration: BoxDecoration(
          //           gradient: const LinearGradient(
          //             colors: [Color(0xFF8A2BE2), Color(0xFFAB47BC)],
          //             begin: Alignment.centerLeft,
          //             end: Alignment.centerRight,
          //           ),
          //           borderRadius: BorderRadius.circular(20),
          //           boxShadow: [
          //             BoxShadow(
          //               color: const Color(0xFF8A2BE2).withValues(alpha: 0.3),
          //               blurRadius: 10,
          //               offset: const Offset(0, 3),
          //             ),
          //           ],
          //         ),
          //         child: Row(
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             const Icon(Icons.collections_rounded,
          //                 color: Colors.white, size: 13),
          //             const SizedBox(width: 5),
          //             Text(
          //               results.isNotEmpty
          //                   ? '${results.length} images'
          //                   : 'Moodboard',
          //               style: const TextStyle(
          //                 color: Colors.white,
          //                 fontSize: 12,
          //                 fontFamily: 'Poppins',
          //                 fontWeight: FontWeight.w600,
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //       const SizedBox(width: 10),
          //       if (isDone)
          //         Text(
          //           'Tap to view',
          //           style: TextStyle(
          //             fontSize: 12,
          //             fontFamily: 'Poppins',
          //             color: Colors.grey.shade400,
          //           ),
          //         )
          //       else
          //         Expanded(
          //           child: Text(
          //             moodboardTitle,
          //             maxLines: 1,
          //             overflow: TextOverflow.ellipsis,
          //             style: const TextStyle(
          //               fontSize: 13,
          //               fontFamily: 'Poppins',
          //               fontWeight: FontWeight.w600,
          //               color: Color(0xFF1A1A1A),
          //             ),
          //           ),
          //         ),
          //     ],
          //   ),
          // ),

          // ── Phase A: generating queries — purple progress text ───────────────
          if (isGeneratingQueries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF8A2BE2).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progressText ?? analysisStatus ?? 'Planning searches...',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        color: const Color(0xFF8A2BE2).withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const _MoodboardShimmerGrid(),
          ]

          // ── Phase B: album cover — cycles through all extracted images ─────────
          else if (results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 0),
              child: _MoodboardAlbumCover(
                results: results,
                onTap: () => _openLightbox(context, 0),
              ),
            )

          else
            const _MoodboardShimmerGrid(),
        ],
      ),
    );
  }

  /// Scanning grid: 2-col, shows all extracted images.
  /// Accepted ones show green checkmark; unaccepted show scan animation.
  Widget _buildScanGrid(BuildContext context, Set<String> acceptedUris) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = (screenWidth - 44 - 8) / 2;
    const tileHeight = 160.0;

    final col1 = <int>[];
    final col2 = <int>[];
    for (int i = 0; i < scanImages.length; i++) {
      if (i.isEven) { col1.add(i); } else { col2.add(i); }
    }

    Widget buildColumn(List<int> indices) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: indices.map((i) {
        final uri = scanImages[i];
        final isAccepted = acceptedUris.contains(uri);
        // Only the last image in the list is actively being scanned
        final isActive = i == scanImages.length - 1 && !isAccepted;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MoodboardScanTile(
            key: ValueKey(uri),
            src: uri,
            width: tileWidth,
            height: tileHeight,
            isAccepted: isAccepted,
            isActive: isActive,
          ),
        );
      }).toList(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: buildColumn(col1)),
          const SizedBox(width: 8),
          Expanded(child: buildColumn(col2)),
        ],
      ),
    );
  }
}

/// Animated tile shown during image scanning phase.
/// Shows the image with a sweeping purple scan line while being evaluated,
/// and a green checkmark once accepted.
class _MoodboardScanTile extends StatefulWidget {
  final String src;
  final double width;
  final double height;
  final bool isAccepted;
  /// Only the tile currently being evaluated by AI should be true.
  /// All others render statically so GPU load stays constant.
  final bool isActive;

  const _MoodboardScanTile({
    super.key,
    required this.src,
    required this.width,
    required this.height,
    required this.isAccepted,
    required this.isActive,
  });

  @override
  State<_MoodboardScanTile> createState() => _MoodboardScanTileState();
}

class _MoodboardScanTileState extends State<_MoodboardScanTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scan;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scan = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MoodboardScanTile old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isActive && old.isActive) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF3F0FF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A2BE2).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            _AlbumTileImage(
              key: ValueKey(widget.src.hashCode),
              src: widget.src,
            ),
            // Active scan overlay: animated shimmer + scan line
            if (!widget.isAccepted && widget.isActive)
              AnimatedBuilder(
                animation: _scan,
                builder: (context, _) {
                  return LayoutBuilder(builder: (context, constraints) {
                    final top = _scan.value * constraints.maxHeight;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.purple.withValues(alpha: 0.06),
                          highlightColor: Colors.purple.withValues(alpha: 0.16),
                          child: Container(color: Colors.white),
                        ),
                        Positioned(
                          top: top - 28,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF8A2BE2).withValues(alpha: 0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF8A2BE2).withValues(alpha: 0.9),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  });
                },
              ),
            // Inactive pending: static dim overlay, no animation
            if (!widget.isAccepted && !widget.isActive)
              Container(color: const Color(0xFF8A2BE2).withValues(alpha: 0.08)),
            // AI scanning badge (top-right, while not accepted)
            if (!widget.isAccepted)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8A2BE2).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            // Green checkmark when accepted
            if (widget.isAccepted)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, size: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Album cover: stacked cards with cycling image preview ─────────────────────

class _MoodboardAlbumCover extends StatefulWidget {
  final List<MoodboardResultData> results;
  final VoidCallback onTap;

  const _MoodboardAlbumCover({required this.results, required this.onTap});

  @override
  State<_MoodboardAlbumCover> createState() => _MoodboardAlbumCoverState();
}

class _MoodboardAlbumCoverState extends State<_MoodboardAlbumCover> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.results.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) {
          setState(() =>
              _currentIndex = (_currentIndex + 1) % widget.results.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double cardW = 200;
    const double cardH = 220;
    const double pad = 24.0;
    final n = widget.results.length;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: cardW + pad * 2,
        height: cardH + pad,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Back card
            if (n >= 3)
              Transform.rotate(
                angle: 0.12,
                child: _buildCard(((_currentIndex + 2) % n)),
              ),
            // Middle card
            if (n >= 2)
              Transform.rotate(
                angle: -0.06,
                child: _buildCard((_currentIndex + 1) % n),
              ),
            // Front card — crossfades when index changes
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _buildCard(_currentIndex, key: ValueKey(_currentIndex)),
            ),
            // // Count badge
            // Positioned(
            //   bottom: 6,
            //   right: pad - 2,
            //   child: Container(
            //     padding:
            //         const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //     decoration: BoxDecoration(
            //       color: Colors.black.withValues(alpha: 0.55),
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: Text(
            //       '${widget.results.length} photos',
            //       style: const TextStyle(
            //         color: Colors.white,
            //         fontSize: 11,
            //         fontFamily: 'Poppins',
            //         fontWeight: FontWeight.w500,
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(int index, {Key? key}) {
    const double cardW = 200;
    const double cardH = 220;
    return Container(
      key: key,
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A2BE2).withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _AlbumTileImage(
          key: ValueKey(widget.results[index].thumbnailDataUri.hashCode),
          src: widget.results[index].thumbnailDataUri,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MoodboardTile extends StatelessWidget {
  final MoodboardResultData item;
  final double width;
  final double height;

  const _MoodboardTile({
    required this.item,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A2BE2).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            _AlbumTileImage(
              key: ValueKey(item.thumbnailDataUri.hashCode),
              src: item.thumbnailDataUri,
            ),
            // Bottom gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Title overlay
            if (item.title.isNotEmpty)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoodboardShimmerGrid extends StatelessWidget {
  const _MoodboardShimmerGrid();

  @override
  Widget build(BuildContext context) {
    const heights = [190.0, 245.0, 205.0, 265.0, 195.0, 220.0];

    Widget shimmerTile(double height) => Shimmer.fromColors(
          baseColor: const Color(0xFFEDE0FF),
          highlightColor: const Color(0xFFF5F0FF),
          child: Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(children: [
              shimmerTile(heights[0]),
              shimmerTile(heights[2]),
              shimmerTile(heights[4]),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(children: [
              shimmerTile(heights[1]),
              shimmerTile(heights[3]),
              shimmerTile(heights[5]),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Analyzing indicator ──────────────────────────────────────────────────────

class _VBAnalyzingIndicator extends StatefulWidget {
  final String status;
  const _VBAnalyzingIndicator({required this.status});

  @override
  State<_VBAnalyzingIndicator> createState() => _VBAnalyzingIndicatorState();
}

class _VBAnalyzingIndicatorState extends State<_VBAnalyzingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: const Color(0xFF8A2BE2), width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A2BE2).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  const Color(0xFF8A2BE2).withValues(alpha: 0.4),
                  const Color(0xFF8A2BE2),
                  _pulse.value,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2BE2)
                        .withValues(alpha: _pulse.value * 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.status,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: Color(0xFF5B21B6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: const Color(0xFF8A2BE2).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Album tile image (handles data URI + http) ───────────────────────────────

class _AlbumTileImage extends StatefulWidget {
  final String src;
  const _AlbumTileImage({required this.src, super.key});

  @override
  State<_AlbumTileImage> createState() => _AlbumTileImageState();
}

class _AlbumTileImageState extends State<_AlbumTileImage> {
  Uint8List? _bytes;
  bool _decoded = false;

  @override
  void initState() {
    super.initState();
    _decode(widget.src);
  }

  @override
  void didUpdateWidget(_AlbumTileImage old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src) _decode(widget.src);
  }

  void _decode(String src) {
    if (src.startsWith('data:image/')) {
      try {
        _bytes = base64Decode(src.split(',').last);
      } catch (_) {
        _bytes = null;
      }
    } else {
      _bytes = null;
    }
    _decoded = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_decoded) return _placeholder();
    final src = widget.src;
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (src.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFD1D5DB), size: 28),
      ),
    );
  }
}

// ─── Fullscreen lightbox ──────────────────────────────────────────────────────

class _AnswersImageLightbox extends StatefulWidget {
  final List<VisualBrowseResultData> results;
  final int initialIndex;
  final String heroTagPrefix;
  const _AnswersImageLightbox(
      {required this.results, required this.initialIndex, this.heroTagPrefix = 'answers_vb_img'});

  @override
  State<_AnswersImageLightbox> createState() => _AnswersImageLightboxState();
}

class _AnswersImageLightboxState extends State<_AnswersImageLightbox>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _fadeController.reverse();
    if (mounted) Navigator.pop(context);
  }

  String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.results[_currentIndex];
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0015),
                Color(0xFF12002A),
                Color(0xFF0D0D1F),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Ambient purple glow
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        const Color(0xFF4A148C).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // PageView
              PageView.builder(
                controller: _pageController,
                itemCount: widget.results.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (ctx, index) {
                  final it = widget.results[index];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, topPad + 72, 20, bottomPad + 130),
                    child: Hero(
                      tag: '${widget.heroTagPrefix}_${it.thumbnailDataUri.hashCode}_$index',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2)
                                  .withValues(alpha: 0.45),
                              blurRadius: 48,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _LightboxImage(src: it.thumbnailDataUri),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      EdgeInsets.fromLTRB(16, topPad + 10, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const Spacer(),
                      if (widget.results.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.results.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, bottomPad + 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dots
                      if (widget.results.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(widget.results.length, (i) {
                              final isActive = i == _currentIndex;
                              return TweenAnimationBuilder<double>(
                                key: ValueKey('dot_$i\_$isActive'),
                                tween: Tween(
                                  begin: isActive ? 0.6 : 1.05,
                                  end: 1.0,
                                ),
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutBack,
                                builder: (context, scale, _) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 300),
                                      opacity: isActive ? 1.0 : 0.45,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 380),
                                        curve: Curves.easeOutBack,
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: isActive ? 24 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          gradient: isActive
                                              ? const LinearGradient(colors: [
                                                  Color(0xFF8A2BE2),
                                                  Color(0xFFCE93D8),
                                                ])
                                              : null,
                                          color: isActive
                                              ? null
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(3),
                                          boxShadow: isActive
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFF8A2BE2)
                                                        .withValues(alpha: 0.65),
                                                    blurRadius: 10,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                      // Title
                      if (item.title.isNotEmpty)
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      if (item.title.isNotEmpty && item.sourceLink.isNotEmpty)
                        const SizedBox(height: 5),
                      // Source
                      if (item.sourceLink.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8A2BE2).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFAB47BC).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link_rounded,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 11),
                              const SizedBox(width: 4),
                              Text(
                                _domain(item.sourceLink),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Lightbox full-res image (handles data URI + http) ────────────────────────

class _LightboxImage extends StatelessWidget {
  final String src;
  const _LightboxImage({required this.src});

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(src.split(',').last);
        return Image.memory(bytes, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _placeholder());
      } catch (_) {
        return _placeholder();
      }
    } else if (src.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 200,
      height: 200,
      color: const Color(0xFF1A0830),
      child: const Icon(Icons.image_outlined, color: Color(0xFF6B7280), size: 56),
    );
  }
}


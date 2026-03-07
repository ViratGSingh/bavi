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
        //Extracted URL
        if (widget.extractedUrlData?.title != "" ||
            widget.extractedUrlData?.snippet != "")
          Container(
            margin: EdgeInsets.only(right: 8, left: 8, bottom: 12),
            alignment: Alignment.centerRight,
            width: MediaQuery.of(context).size.width,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.extractedUrlData?.thumbnail ?? "",
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade400,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: [0.5, 1.0],
                    ),
                  ),
                ),
                // Title at Bottom Left
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Text(
                    (widget.extractedUrlData?.title == ""
                            ? widget.extractedUrlData?.snippet
                            : widget.extractedUrlData?.title) ??
                        "",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Builder(
            builder: (context) {
              return GestureDetector(
                onLongPressStart: (details) async {
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
                children: [
                  AnswerLoader(
                    loaderText: widget.deepDrissyReadingStatus != null
                            ? widget.deepDrissyReadingStatus!
                            : widget.status == HomePageStatus.generateQuery
                                ? "Understanding"
                                : widget.status == HomePageStatus.getSearchResults
                                    ? "Reading"
                                    : "Thinking",
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height / 3,
                  )
                ],
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => WebViewPage(url: item.url),
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

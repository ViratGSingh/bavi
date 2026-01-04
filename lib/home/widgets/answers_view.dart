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
import 'package:url_launcher/url_launcher.dart';

class ThreadAnswerView extends StatefulWidget {
  final List<YoutubeVideoData> youtubeVideos;
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

  const ThreadAnswerView({
    super.key,
    required this.youtubeVideos,
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
    if (widget.youtubeVideos.isNotEmpty) {
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
                    loaderText: widget.status == HomePageStatus.generateQuery
                        ? "Understanding your query"
                        : widget.status == HomePageStatus.getSearchResults
                            ? "Searching the web"
                            : "Thinking of a reply",
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
                        widget.local.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
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
                    MarkdownBody(
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
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Sources",
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
                                        child: Icon(Icons.close,
                                            size: 18, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: widget.answerResults.length,
                                    separatorBuilder: (_, __) =>
                                        Divider(color: Colors.purple),
                                    itemBuilder: (context, index) {
                                      final item = widget.answerResults[index];
                                      return GestureDetector(
                                        onTap: () async {
                                          if (item.url.isNotEmpty) {
                                            Navigator.pop(context);
                                            // Open in external browser
                                            final uri = Uri.parse(item.url);
                                            if (!await launchUrl(uri,
                                                mode: LaunchMode
                                                    .externalApplication)) {
                                              launchUrl(uri);
                                            }
                                          }
                                        },
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.white),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              item.url,
                                              style: TextStyle(
                                                color: Color(0xFFDFFF00),
                                                decoration:
                                                    TextDecoration.underline,
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
}

class AnswerLoader extends StatelessWidget {
  final String loaderText;
  const AnswerLoader({super.key, required this.loaderText});

  @override
  Widget build(BuildContext context) {
    return Align(
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
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
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
                      borderRadius: BorderRadius.circular(40),
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
        final url = Uri.parse(
            "https://www.google.com/maps/search/?api=1&query=$query&query_place_id=${widget.place.placeId}");
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          // fallback to browser if external app fails (though externalApplication usually handles both)
          launchUrl(url);
        }
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

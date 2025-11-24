import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/home/widgets/web_view.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class ThreadSearchView extends StatefulWidget {
  final KnowledgeGraphData? knowledgeGraph;
  final AnswerBoxData? answerBox;
  final List<WebResultData> web;
  final List<ShortVideoResultData> shortVideos;
  final List<VideoResultData> videos;
  final List<NewsResultData> news;
  final List<ImageResultData> images;
  final String query;
  final bool isIncognito;
  final HomePageStatus status;
  final Function(String) onTabChanged;
  final Function(String) onGraphImageTap;
  const ThreadSearchView(
      {super.key,
      required this.web,
      required this.query,
      required this.shortVideos,
      required this.videos,
      required this.news,
      required this.images,
      required this.status,
      required this.isIncognito,
      required this.onTabChanged,
      required this.onGraphImageTap,
      this.knowledgeGraph,
      this.answerBox});

  @override
  State<ThreadSearchView> createState() => _ThreadSearchViewState();
}

class _ThreadSearchViewState extends State<ThreadSearchView> {
  String currentTab = 'web';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          constraints: BoxConstraints(maxHeight: 150),
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
              border: Border.all(),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(offset: Offset(0, 4), color: Colors.black)
              ]),
          padding: EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Iconsax.search_normal_1_outline,
                color: Colors.black,
                size: 20,
              ),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.query,
                  overflow: TextOverflow.clip,
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
        ),
        SizedBox(height: 10),
        if (widget.status == HomePageStatus.success)
          SearchTabs(
            initialTab: currentTab,
            onTabChanged: (tab) {
              setState(() {
                currentTab = tab;
              });
              if (tab == "news" && widget.news.isEmpty) {
                widget.onTabChanged(tab);
              } else if (tab == "videos" && widget.videos.isEmpty) {
                widget.onTabChanged(tab);
              } else if (tab == "shortVideos" && widget.shortVideos.isEmpty) {
                widget.onTabChanged(tab);
              } else if (tab == "web" && widget.web.isEmpty) {
                widget.onTabChanged(tab);
              } else if (tab == "images" && widget.images.isEmpty) {
                widget.onTabChanged(tab);
              }
            },
          ),
        if (widget.status == HomePageStatus.success) SizedBox(height: 10),
        widget.status != HomePageStatus.success
            ? Column(
                children: [
                  SearchLoader(
                    loaderText: widget.status == HomePageStatus.webSearch
                        ? "Searching the web"
                        : widget.status == HomePageStatus.imagesSearch
                            ? "Searching for images"
                            : widget.status == HomePageStatus.newsSearch
                                ? "Searching for news"
                                : widget.status == HomePageStatus.videosSearch
                                    ? "Searching for videos"
                                    : widget.status ==
                                            HomePageStatus.shortVideosSearch
                                        ? "Searching for short videos"
                                        : "",
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height / 3),
                ],
              )
            : currentTab == 'web'
                ? WebResultsView(
                    onGraphImageTap: widget.onGraphImageTap,
                    results: widget.web, isIncognito: widget.isIncognito, knowledgeGraph: widget.knowledgeGraph, answerBox: widget.answerBox,)
                : currentTab == 'images'
                    ? ImagesResultsView(
                        results: widget.images,
                        isIncognito: widget.isIncognito,
                      )
                    : currentTab == 'news'
                        ? NewsResultsView(
                            results: widget.news,
                            isIncognito: widget.isIncognito,
                          )
                        : currentTab == 'videos'
                            ? VideosResultsView(
                                results: widget.videos,
                                isIncognito: widget.isIncognito,
                              )
                            : currentTab == 'shortVideos'
                                ? ShortVideosResultsView(
                                    results: widget.shortVideos,
                                    isIncognito: widget.isIncognito,
                                  )
                                : WebResultsView(
                                    onGraphImageTap: widget.onGraphImageTap,
                                    results: widget.web,
                                    isIncognito: widget.isIncognito,
                                    knowledgeGraph: widget.knowledgeGraph,
                                    answerBox: widget.answerBox,
                                  ),
      ],
    );
  }
}

class SearchLoader extends StatelessWidget {
  final String loaderText;
  const SearchLoader({super.key, required this.loaderText});

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

class SearchTabs extends StatefulWidget {
  final Function(String)? onTabChanged;
  final String? initialTab;

  const SearchTabs({
    super.key,
    this.onTabChanged,
    this.initialTab,
  });

  @override
  State<SearchTabs> createState() => _SearchTabsState();
}

class _SearchTabsState extends State<SearchTabs> {
  String currentMode = 'web';

  final List<Map<String, String>> tabs = const [
    {'label': 'Web', 'mode': 'web'},
    {'label': 'Reels', 'mode': 'shortVideos'},
    {'label': 'Videos', 'mode': 'videos'},
    {'label': 'Images', 'mode': 'images'},
    {'label': 'News', 'mode': 'news'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      currentMode = widget.initialTab!;
    }
  }

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF8A2BE2); // purple hexcode
    const defaultColor = Colors.black54;

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((tab) {
            final isActive = currentMode == tab['mode'];
            return GestureDetector(
              onTap: () {
                if (!isActive) {
                  setState(() {
                    currentMode = tab['mode']!;
                  });
                  widget.onTabChanged?.call(currentMode);
                }
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    tabs.indexOf(tab) == 0 ? 0 : 12, 5, 12, 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab['label']!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isActive ? selectedColor : defaultColor,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 2,
                      width: 20,
                      decoration: BoxDecoration(
                        color: isActive ? selectedColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class KnowledgeGraphView extends StatelessWidget {
  final KnowledgeGraphData knowledgeGraph;
  final Function(String) onGraphImageTap;
  const KnowledgeGraphView({super.key, required this.knowledgeGraph, required this.onGraphImageTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        //border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Color(0xFF8A2BE2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (knowledgeGraph.title != "")
            Text(
              knowledgeGraph.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            if (knowledgeGraph.type != "")
            Text(
              knowledgeGraph.type,
              style:  TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: knowledgeGraph.headerImages.map((toElement) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                  child: InkWell(
                    onTap: () {
                      
                        
                        Navigator.push(
                  context,
                  MaterialPageRoute<void>(
      builder: (BuildContext context) => WebViewPage(
                      url: toElement.source,
                      title: toElement.source.split(" ").first.trim(),
                      isIncognito: false,
                    ),
    ),);
                 
                    
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        toElement.image,
                        height: 150,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if(knowledgeGraph.movies.isNotEmpty && knowledgeGraph.headerImages.isEmpty)
           SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: knowledgeGraph.movies.map((toElement) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                  child: InkWell(
                    onTap: () {
                      onGraphImageTap(toElement.extensions?.first.toString() ?? "");
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            toElement.image,
                            height: 150,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  width: 50,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                                  toElement.extensions?.last.toString() ?? "",
                                  style:  TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if(knowledgeGraph.tvShows.isNotEmpty && knowledgeGraph.headerImages.isEmpty)
           SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: knowledgeGraph.tvShows.map((toElement) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                  child: InkWell(
                    onTap: () {
                      onGraphImageTap(toElement.extensions?.first.toString() ?? "");
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            toElement.image,
                            height: 150,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  width: 50,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                                  toElement.extensions?.last.toString() ?? "",
                                  style:  TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if(knowledgeGraph.moviesAndShows.isNotEmpty && knowledgeGraph.headerImages.isEmpty)
           SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: knowledgeGraph.moviesAndShows.map((toElement) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                  child: InkWell(
                    onTap: () {
                      onGraphImageTap(toElement.extensions?.first.toString() ?? "");
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            toElement.image,
                            height: 150,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  width: 50,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                                  toElement.extensions?.last.toString() ?? "",
                                  style:  TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (knowledgeGraph.title != "") const SizedBox(height: 8),
          if (knowledgeGraph.description != "") ...[
            Builder(
              builder: (context) {
                final description = knowledgeGraph.description.trim();
                final hasWikipedia = description.endsWith("Wikipedia");
                final wikipediaLink = knowledgeGraph.title.isNotEmpty
                    ? "https://en.wikipedia.org/wiki/${Uri.encodeComponent(knowledgeGraph.title)}"
                    : null;

                if (hasWikipedia && wikipediaLink != null) {
                  final descWithoutWiki = description.replaceAll(RegExp(r'Wikipedia$'), '').trimRight();
                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "$descWithoutWiki ",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: ()  {
                              
                              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebViewPage(
                      url: wikipediaLink,
                      title: wikipediaLink.split(" ").first.trim(),
                      isIncognito: false,
                    ),
                  ),
                );
                            },
                            child: Text(
                              "Wikipedia",
                              style: const TextStyle(
                                color: Color(0xFFDFFF00), // purple
                                fontSize: 12,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if(knowledgeGraph.type=="Digital creator"){
                  return Text(
                    knowledgeGraph.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  );

                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
class AnswerBoxView extends StatelessWidget {
  final AnswerBoxData answerBox;
  const AnswerBoxView({super.key, required this.answerBox});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        //border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Color(0xFF8A2BE2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (answerBox.title != "")
                Text(
                  answerBox.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                ),
              if (answerBox.answer != "") 
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    answerBox.answer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
            ],
          ),
          if(answerBox.thumbnail != "")
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              answerBox.thumbnail,
              height: 60,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
class WebResultsView extends StatelessWidget {
  final List<WebResultData> results;
  final KnowledgeGraphData? knowledgeGraph;
  final Function(String) onGraphImageTap;
  final AnswerBoxData? answerBox;
  final bool isIncognito;
  const WebResultsView(
      {super.key, required this.results, required this.isIncognito, required this.onGraphImageTap,  this.knowledgeGraph, this.answerBox });

  @override
  Widget build(BuildContext context) {
    const purpleColor = Color(0xFF8A2BE2);
    print(knowledgeGraph);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (knowledgeGraph != null && knowledgeGraph?.title != "")
          Padding(
            padding: const EdgeInsets.fromLTRB(0,5,0,15),
            child: KnowledgeGraphView(knowledgeGraph: knowledgeGraph!, 
                    onGraphImageTap: onGraphImageTap,),
          ),
        if (answerBox != null && answerBox?.answer != "")
        Padding(
            padding: const EdgeInsets.fromLTRB(0,5,0,15),
          child: AnswerBoxView(answerBox: answerBox!),
        ),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final result = results[index];
            return GestureDetector(
              onTap: () {
                //final uri = Uri.tryParse(result.link);
                // if (uri != null) {
                //   await launchUrl(uri, mode: LaunchMode.externalApplication);
                // }
        
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebViewPage(
                      url: result.link,
                      title: result.displayedLink.split(" ").first.trim(),
                      isIncognito: isIncognito,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.displayedLink,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.title,
                    style: const TextStyle(
                      color: purpleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.snippet,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class NewsResultsView extends StatelessWidget {
  final List<NewsResultData> results;
  final bool isIncognito;
  const NewsResultsView(
      {super.key, required this.results, required this.isIncognito});

  @override
  Widget build(BuildContext context) {
    const purpleColor = Color(0xFF8A2BE2);

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final result = results[index];
        return GestureDetector(
          onTap: () async {
            // final uri = Uri.tryParse(result.link);
            // if (uri != null) {
            //   await launchUrl(uri, mode: LaunchMode.externalApplication);
            // }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WebViewPage(
                  url: result.link,
                  title: result.source,
                  isIncognito: isIncognito,
                ),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.thumbnail != "")
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    result.thumbnail ?? "",
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width / 4 + 20,
                    height: 100,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: MediaQuery.of(context).size.width / 4,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (result.thumbnail != "") const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 100,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                          result.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: purpleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        // Text(
                        //   result.snippet,
                        //   maxLines: 1,
                        //   overflow: TextOverflow.ellipsis,
                        //   style: TextStyle(
                        //     color: Colors.grey.shade800,
                        //     fontSize: 12,
                        //     fontFamily: 'Poppins',
                        //   ),
                        // ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                          result.source,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          result.date,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),

                          ],
                        )
                        
                       
                      ]),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class VideosResultsView extends StatelessWidget {
  final List<VideoResultData> results;
  final bool isIncognito;
  const VideosResultsView(
      {super.key, required this.results, required this.isIncognito});

  @override
  Widget build(BuildContext context) {
    const purpleColor = Color(0xFF8A2BE2);

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final result = results[index];
        return GestureDetector(
          onTap: () async {
            // final uri = Uri.tryParse(result.link);
            // if (uri != null) {
            //   await launchUrl(uri, mode: LaunchMode.externalApplication);
            // }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WebViewPage(
                  url: result.link,
                  title: result.displayedLink.split(" ").first.trim(),
                  isIncognito: isIncognito,
                ),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.thumbnail != "")
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      Image.network(
                        result.thumbnail!,
                        fit: BoxFit.cover,
                        height: 80,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                      if (result.duration != "")
                        Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 4),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                              color: Colors.black.withOpacity(0.6),
                            ),
                            padding: EdgeInsets.all(4),
                            child: Text(
                              result.duration,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              if (result.thumbnail != "") const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              result.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: purpleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            if (result.thumbnail == "")
                              Text(
                                result.snippet,
                                maxLines: 2,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                          ],
                        ),
                        Text(
                          result.date,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ]),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class ImagesResultsView extends StatefulWidget {
  final List<ImageResultData> results;
  final bool isIncognito;
  const ImagesResultsView({
    super.key,
    required this.results,
    required this.isIncognito,
  });

  @override
  State<ImagesResultsView> createState() => _ImagesResultsViewState();
}

class _ImagesResultsViewState extends State<ImagesResultsView> {
  String currentMode = 'Square';

  void showFullImagePopup(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87, // dim background
    builder: (context) {
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, _, __) =>
                            const Icon(Icons.broken_image, color: Colors.white, size: 80),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
                  ],
                ),
              ),
            ),
          ),
          
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    // Filter results based on selected orientation mode
    final filteredResults = widget.results.where((r) {
      if (r.originalWidth == 0 || r.originalHeight == 0) return false;
      final ratio = r.originalWidth / r.originalHeight;

      if (currentMode == 'Square') {
        return ratio > 0.8 && ratio < 1.25;
      } else if (currentMode == 'Portrait') {
        return ratio <= 0.8;
      } else if (currentMode == 'Landscape') {
        return ratio >= 1.25;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Orientation Tabs
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: ['Square', 'Portrait', 'Landscape'].map((mode) {
            final isActive = currentMode == mode;
            return GestureDetector(
              onTap: () {
                setState(() {
                  currentMode = mode;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color:
                      isActive ? const Color(0xFF8A2BE2) : Colors.transparent,
                  border: Border.all(color: const Color(0xFF8A2BE2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mode,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF8A2BE2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Image Grid
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: filteredResults.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: currentMode == 'Square'
                ? 2
                : currentMode == 'Portrait'
                    ? 3
                    : 2,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: currentMode == 'Square'
                ? 1
                : currentMode == 'Portrait'
                    ? 9 / 16
                    : 16 / 9,
          ),
          itemBuilder: (context, index) {
            final result = filteredResults[index];
            if (result.thumbnail.isEmpty) return const SizedBox.shrink();
            final imageUrl = result.original.toLowerCase().endsWith('.gif')
                ? result.original
                : result.thumbnail;
            return Stack(
                alignment: Alignment.bottomRight,
                children: [
                  // Display image or GIF
                  GestureDetector(
                    onTap: () {
                      print("Tapped image: ${result}");
                      final supportedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
                      final lower = result.original.toLowerCase();
                      final hasSupported = supportedExtensions.any((ext) => lower.endsWith(ext));
                      final chosenUrl = hasSupported ? result.original : result.thumbnail;
                      showFullImagePopup(context, chosenUrl);
                    },
                    child: SizedBox.expand(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          alignment: Alignment.center,
                          errorBuilder: (context, _, __) => Container(
                            color: Colors.grey.shade300,
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Shimmer.fromColors(
                              baseColor: Colors.grey.shade300,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Download button overlay
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          final uri = Uri.parse(result.original);
                          final response = await http.get(uri);
                          final Uint8List bytes =
                              Uint8List.fromList(response.bodyBytes);

                          final isGif =
                              imageUrl.toLowerCase().endsWith('.gif');
                          final fileName =
                              'bavi_${DateTime.now().millisecondsSinceEpoch}.${isGif ? 'gif' : 'jpg'}';

                          if (isGif) {
                            // Save GIF as a real file
                            final tempDir = await getTemporaryDirectory();
                            final filePath = '${tempDir.path}/$fileName';
                            final file = File(filePath);
                            await file.writeAsBytes(bytes);

                            final result =
                                await ImageGallerySaverPlus.saveFile(
                              filePath,
                              isReturnPathOfIOS: true,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  (result['isSuccess'] == true)
                                      ? 'GIF saved to gallery!'
                                      : 'Failed to save GIF',
                                ),
                              ),
                            );
                          } else {
                            // Save normal image
                            final result =
                                await ImageGallerySaverPlus.saveImage(
                              bytes,
                              quality: 100,
                              name: fileName,
                              isReturnImagePathOfIOS: true,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  (result['isSuccess'] == true)
                                      ? 'Image saved to gallery!'
                                      : 'Failed to save image',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Error downloading file')),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              );
          },
        ),
      ],
    );
  }
}

class ShortVideosResultsView extends StatefulWidget {
  final List<ShortVideoResultData> results;
  final bool isIncognito;
  const ShortVideosResultsView(
      {super.key, required this.results, required this.isIncognito});

  @override
  State<ShortVideosResultsView> createState() => _ShortVideosResultsViewState();
}

class _ShortVideosResultsViewState extends State<ShortVideosResultsView> {
  int? _currentlyPlayingIndex;

  void _onPreviewStarted(int index) {
    setState(() {
      _currentlyPlayingIndex = index;
    });
  }

  void _onPreviewEnded(int index) {
    // Only clear if this is still the current
    if (_currentlyPlayingIndex == index) {
      setState(() {
        _currentlyPlayingIndex = null;
      });
      _playNextAvailable(index + 1);
    }
  }

  // Keys for accessing state of each item
  late final List<GlobalKey<_ShortVideoItemState>> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(
      widget.results.length,
      (i) => GlobalKey<_ShortVideoItemState>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playNextAvailable(0);
    });
  }

  void _playNextAvailable(int startIndex) {
    for (int i = startIndex; i < widget.results.length; i++) {
      final clip = widget.results[i].clip;
      if (clip.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _itemKeys[i].currentState?.playPreview();
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: results.length,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 8,
        childAspectRatio: 9 / 16,
      ),
      itemBuilder: (context, index) {
        final result = results[index];
        return _ShortVideoItem(
          key: _itemKeys[index],
          result: result,
          index: index,
          isIncognito: widget.isIncognito,
          playing: _currentlyPlayingIndex == index,
          onPreviewStarted: _onPreviewStarted,
          onPreviewEnded: _onPreviewEnded,
        );
      },
    );
  }
}

class _ShortVideoItem extends StatefulWidget {
  final ShortVideoResultData result;
  final int index;
  final bool playing;
  final bool isIncognito;
  final void Function(int index) onPreviewStarted;
  final void Function(int index) onPreviewEnded;
  const _ShortVideoItem({
    Key? key,
    required this.result,
    required this.isIncognito,
    required this.index,
    required this.playing,
    required this.onPreviewStarted,
    required this.onPreviewEnded,
  }) : super(key: key);

  @override
  State<_ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends State<_ShortVideoItem>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> playPreview() async {
    try {
      if (_controller == null) {
        _controller = VideoPlayerController.network(widget.result.clip);
      }

      if (!_isInitialized) {
        await _controller!.initialize();
        if (!mounted) return;
        setState(() => _isInitialized = true);
      }

      await _controller!.seekTo(Duration.zero);
      await _controller!.play();
      setState(() => _isPlaying = true);
      widget.onPreviewStarted(widget.index);

      // If video is from Drissea CDN, stop after 5 seconds
      if (widget.result.clip.contains('cdn.drissea.com')) {
        Future.delayed(const Duration(seconds: 5), () {
          if (_controller != null && _controller!.value.isPlaying) {
            _controller!.pause();
            setState(() => _isPlaying = false);
            widget.onPreviewEnded(widget.index);
          }
        });
      }

      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration &&
            _isPlaying) {
          setState(() => _isPlaying = false);
          widget.onPreviewEnded(widget.index);
        }
      });
    } catch (e) {
      debugPrint("⚠️ Video preview error: $e");
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ShortVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.playing && _isPlaying) {
      _controller?.pause();
      setState(() => _isPlaying = false);
    } else if (widget.playing && !_isPlaying) {
      playPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: () async {
        // final uri = Uri.tryParse(widget.result.link);
        // if (uri != null) {
        //   await launchUrl(uri, mode: LaunchMode.externalApplication);
        // }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WebViewPage(
              url: widget.result.link,
              title: widget.result.source,
              isIncognito: widget.isIncognito,
            ),
          ),
        );
      },
      onLongPress: () {
        if (!_isPlaying) playPreview();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: (_controller != null &&
                      _controller!.value.isInitialized &&
                      _isPlaying)
                  ? VideoPlayer(_controller!)
                  : Image.network(
                      widget.result.thumbnail ?? "",
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) => Container(
                        color: Colors.grey.shade300,
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
            ),
            // if (widget.result.duration != "" && !_isPlaying)
            //   Padding(
            //     padding: const EdgeInsets.all(6),
            //     child: Container(
            //       decoration: BoxDecoration(
            //         borderRadius: BorderRadius.circular(4),
            //         color: Colors.black.withOpacity(0.6),
            //       ),
            //       padding:
            //           const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            //       child: Text(
            //         widget.result.duration,
            //         style: const TextStyle(
            //           color: Colors.white,
            //           fontSize: 12,
            //           fontWeight: FontWeight.bold,
            //         ),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

import 'dart:convert';

import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class ThreadSearchView extends StatefulWidget {
  final List<WebResultData> web;
  final List<ShortVideoResultData> shortVideos;
  final List<VideoResultData> videos;
  final List<NewsResultData> news;
  final List<ImageResultData> images;
  final String query;
  final HomePageStatus status;
  final Function(String) onTabChanged;
  const ThreadSearchView(
      {super.key,
      required this.web,
      required this.query,
      required this.shortVideos,
      required this.videos,
      required this.news,
      required this.images,
      required this.status,
      required this.onTabChanged});

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
                ? WebResultsView(results: widget.web)
                : currentTab == 'images'
                    ? ImagesResultsView(results: widget.images)
                    : currentTab == 'news'
                        ? NewsResultsView(results: widget.news)
                        : currentTab == 'videos'
                            ? VideosResultsView(results: widget.videos)
                            : currentTab == 'shortVideos'
                                ? ShortVideosResultsView(
                                    results: widget.shortVideos)
                                : WebResultsView(results: widget.web),
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

class WebResultsView extends StatelessWidget {
  final List<WebResultData> results;
  const WebResultsView({super.key, required this.results});

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
            final uri = Uri.tryParse(result.link);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
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
    );
  }
}

class NewsResultsView extends StatelessWidget {
  final List<NewsResultData> results;
  const NewsResultsView({super.key, required this.results});

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
            final uri = Uri.tryParse(result.link);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
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
                    width: MediaQuery.of(context).size.width / 4,
                    height: 80,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: MediaQuery.of(context).size.width / 4,
                          height: 80,
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
                  height: 80,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          result.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: purpleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          result.snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

class VideosResultsView extends StatelessWidget {
  final List<VideoResultData> results;
  const VideosResultsView({super.key, required this.results});

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
            final uri = Uri.tryParse(result.link);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
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

class ImagesResultsView extends StatelessWidget {
  final List<ImageResultData> results;
  const ImagesResultsView({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    // Only show image thumbnails in a responsive grid, no text.
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: results.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150, // adaptive to available width
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final result = results[index];
        if (result.thumbnail.isEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () async {
            final uri = Uri.tryParse(result.link);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              result.thumbnail,
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
        );
      },
    );
  }
}

class ShortVideosResultsView extends StatefulWidget {
  final List<ShortVideoResultData> results;
  const ShortVideosResultsView({super.key, required this.results});

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
  final void Function(int index) onPreviewStarted;
  final void Function(int index) onPreviewEnded;
  const _ShortVideoItem({
    Key? key,
    required this.result,
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
        final uri = Uri.tryParse(widget.result.link);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
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
            if (widget.result.duration != "" && !_isPlaying)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.black.withOpacity(0.6),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    widget.result.duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

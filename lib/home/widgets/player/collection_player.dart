import 'package:bavi/models/collection.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/navigation_service.dart';
import 'package:chewie/chewie.dart'; // For video controls
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:video_player/video_player.dart'; // For video playback
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // For caching videos
import 'package:cached_network_image/cached_network_image.dart'; // For caching thumbnails
import 'package:carousel_slider/carousel_slider.dart'; // For carousel functionality
import 'package:shimmer/shimmer.dart'; // Add this import
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:gal/gal.dart';

class CollectionPlayerPage extends StatefulWidget {
  final List<ExtractedVideoInfo> videoList;
  final int initialPosition;
  final Map<String, dynamic> platform;
  final List<VideoCollectionInfo>? collectionsInfo;
  const CollectionPlayerPage({
    Key? key,
    required this.videoList,
    required this.initialPosition,
    required this.platform,
    this.collectionsInfo,
  }) : super(key: key);

  @override
  _CollectionPlayerPageState createState() => _CollectionPlayerPageState();
}

class _CollectionPlayerPageState extends State<CollectionPlayerPage>
    with WidgetsBindingObserver {
  final Map<String, ChewieController?> _chewieControllers = {};
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  final Map<String, bool> _videoLoadFailed = {};
  late CarouselSliderController _carouselController;
  String _currentVideoId = '';
  int _collectionIndex = 0;
  List<ExtractedVideoInfo> sortedSavedVideoList = [];
  //Sort according to user collection list
  void _sortVideoList(VideoCollectionInfo collectionInfo) {
    for (CollectionVideoData videoData in collectionInfo.videos) {
      String platform = widget.platform[videoData.videoId] ?? "";
      if (widget.videoList.any((element) =>
          element.videoData.videoUrl.contains(videoData.videoId) &&
          element.videoData.videoUrl.contains(platform) == true)) {
        sortedSavedVideoList.add(widget.videoList.firstWhere((element) =>
            element.videoData.videoUrl.contains(videoData.videoId)));
      }
    }
  }

  String formatTimestamp(Timestamp timestamp) {
    // Convert Firestore Timestamp to DateTime
    DateTime dateTime = timestamp.toDate();

    // Get the day with the correct suffix
    String daySuffix = _getDaySuffix(dateTime.day);

    // Format the date and time
    String formattedDate =
        "${dateTime.day}$daySuffix ${_getMonthAbbreviation(dateTime.month)} ${dateTime.year}, ${_formatTime(dateTime)}";

    return formattedDate;
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime dateTime) {
    String hour = dateTime.hour > 12
        ? (dateTime.hour - 12).toString()
        : dateTime.hour == 0
            ? "12"
            : dateTime.hour < 10 && dateTime.hour > 0
                ? "0${dateTime.hour.toString()}"
                : dateTime.hour.toString();
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String period = dateTime.hour < 12 ? 'AM' : 'PM';
    return "$hour:$minute $period";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addObserver(this); // Add observer to detect app state changes
    _carouselController = CarouselSliderController();
    _currentVideoId = widget.collectionsInfo![_collectionIndex]
        .videos[widget.initialPosition].videoId;
    _sortVideoList(widget.collectionsInfo![_collectionIndex]);
    _preloadAllVideos();
  }

  @override
  void dispose() {
    // Pause all videos first
    _pauseAllVideos();

    // Dispose all Chewie controllers and their video controllers
    _chewieControllers.forEach((_, controller) {
      if (controller != null) {
        final videoController = controller.videoPlayerController;
        videoController.pause(); // Ensure video is paused
        videoController.dispose(); // Dispose video controller
        controller.dispose(); // Dispose chewie controller
      }
    });
    _chewieControllers.clear(); // Clear the controllers map

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void deactivate() {
    // Pause all videos when widget is deactivated (e.g., when navigating away)
    _pauseAllVideos();
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pause all videos when the app is paused
      _pauseAllVideos();
    } else if (state == AppLifecycleState.resumed) {
      // Resume the current video when the app is resumed
      _playCurrentVideo(_currentVideoId);
    }
  }

  // Pause all videos
  void _pauseAllVideos() {
    _chewieControllers.forEach((_, controller) {
      if (controller != null) {
        try {
          final videoController = controller.videoPlayerController;
          if (videoController.value.isPlaying) {
            videoController.pause();
          }
        } catch (e) {
          print('Error pausing video: $e');
        }
      }
    });
  }

  //Open bottomsheet to show caption
  void _showCaption(String caption) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF8A2BE2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Caption",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Iconsax.close_circle_bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              caption,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Download video
  void _downloadVideo(String videoUrl) async {
    final fileInfo = await _cacheManager.getFileFromCache(videoUrl);
    if (fileInfo != null) {
      try {
        // Save video to gallery using gal package in 'Bavi Videos' album
        await Gal.putVideo(fileInfo.file.path, album: 'Bavi Videos');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video saved to Bavi Videos album')),
        );
      } catch (e) {
        print('Error saving video: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save video')),
        );
      }
    }
  }

  // Share video
  void _shareVideo(String videoId, String platform) {
    //Generate a share link based on the platform and video id
    String shareLink = "";
    if (platform == "instagram") {
      shareLink = "https://www.instagram.com/reels/$videoId/";
    } else if (platform == "youtube") {
      shareLink = "https://www.youtube.com/shorts/$videoId";
    }
    Share.share(shareLink);
  }

  // Preload all videos at the start
  void _preloadAllVideos() async {
    for (ExtractedVideoInfo videoInfo in sortedSavedVideoList) {
      await _preloadVideo(videoInfo);
    }
  }

  // Preload a video
  Future<void> _preloadVideo(ExtractedVideoInfo videoInfo) async {
    String videoId = widget.collectionsInfo![_collectionIndex].videos
        .firstWhere((v) => videoInfo.videoData.videoUrl.contains(v.videoId))
        .videoId;

    if (!_chewieControllers.containsKey(videoId)) {
      final videoUrl = videoInfo.videoData.videoUrl;
      final fileInfo = await _cacheManager.getFileFromCache(videoUrl);

      if (fileInfo != null) {
        _initializeVideoPlayer(
            videoId, VideoPlayerController.file(fileInfo.file));
      } else {
        final videoPlayerController = VideoPlayerController.network(videoUrl);
        _initializeVideoPlayer(videoId, videoPlayerController);

        _cacheManager.downloadFile(videoUrl).then((fileInfo) {
          print('Video cached: ${fileInfo.file.path}');
        }).catchError((error) {
          print('Failed to cache video: $error');
        });
      }
    }
  }

  // Initialize the video player and Chewie controller
  void _initializeVideoPlayer(
      String videoId, VideoPlayerController videoPlayerController) {
    // Set volume to full before initialization
    videoPlayerController.setVolume(1.0);

    videoPlayerController.initialize().then((_) {
      if (!mounted) return; // Ensure the widget is still mounted
      final chewieController = ChewieController(
        videoPlayerController: videoPlayerController,
        allowFullScreen: false,
        materialProgressColors:
            ChewieProgressColors(playedColor: Color(0xFF8A2BE2)),
        cupertinoProgressColors:
            ChewieProgressColors(playedColor: Color(0xFF8A2BE2)),
        autoInitialize: false,
        zoomAndPan: true,
        showOptions: false,
        autoPlay: videoId == _currentVideoId,
        looping: true,
        showControls: true,
        showControlsOnInitialize: false,
        customControls: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Bottom gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Controls overlay
              Positioned(
                bottom: 0,
                left: 12,
                right: 8,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: videoPlayerController,
                  builder: (context, value, child) {
                    return Row(
                      children: [
                        IconButton(
                          icon: Icon(
                              value.isPlaying
                                  ? Iconsax.pause_circle_bold
                                  : Iconsax.play_circle_bold,
                              color: Colors.white),
                          onPressed: () {
                            if (value.isPlaying) {
                              videoPlayerController.pause();
                            } else {
                              videoPlayerController.play();
                            }
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              final double position = details.localPosition.dx;
                              final double width = context.size!.width;
                              final double percent = position / width;
                              final Duration newPosition = Duration(
                                  milliseconds:
                                      (percent * value.duration.inMilliseconds)
                                          .toInt());
                              videoPlayerController.seekTo(newPosition);
                            },
                            child: Container(
                              height: 4,
                              color: Colors.grey[600],
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: value.position.inMilliseconds /
                                    (value.duration.inMilliseconds == 0
                                        ? 1
                                        : value.duration.inMilliseconds),
                                child: Container(
                                  color: Color(0xFF8A2BE2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                              value.volume == 0
                                  ? Iconsax.volume_cross_bold
                                  : Iconsax.volume_high_bold,
                              color: Colors.white),
                          onPressed: () {
                            if (value.volume > 0) {
                              videoPlayerController.setVolume(0);
                            } else {
                              videoPlayerController.setVolume(1.0);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        allowMuting: true,
        startAt: Duration.zero,
      );
      print("setting state");
      setState(() {
        _chewieControllers[videoId] = chewieController;
        _videoLoadFailed[videoId] = false;
        if (videoId == _currentVideoId) {
          // Ensure volume is on and play
          chewieController.videoPlayerController.setVolume(1.0);
          chewieController.videoPlayerController.play();
        }
      });
    }).catchError((error) {
      print('Failed to initialize video: $error');
      setState(() {
        _videoLoadFailed[videoId] = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: CarouselSlider.builder(
        carouselController: _carouselController,
        itemCount: sortedSavedVideoList.length,
        options: CarouselOptions(
          initialPage: widget.initialPosition,
          viewportFraction: 1.0, // Cover the whole screen
          enableInfiniteScroll: true, // Enable looping
          scrollDirection: Axis.vertical, // Vertical scrolling
          enlargeCenterPage: true, // Center the current video
          height: MediaQuery.of(context).size.height, // Full screen height
          onPageChanged: (index, reason) {
            String newVideoId =
                widget.collectionsInfo![_collectionIndex].videos[index].videoId;
            setState(() {
              _currentVideoId = newVideoId;
            });
            _playCurrentVideo(newVideoId);
          },
        ),
        itemBuilder: (context, index, realIndex) {
          final videoInfo = sortedSavedVideoList[index];
          return GestureDetector(
            onTap: () {
              VideoPlayerController currVideoPlayerController =
                  _chewieControllers[_currentVideoId]!.videoPlayerController;
              if (currVideoPlayerController.value.isPlaying) {
                currVideoPlayerController.pause();
              } else {
                currVideoPlayerController.play();
              }
            },
            onDoubleTap: () {
              VideoPlayerController currVideoPlayerController =
                  _chewieControllers[_currentVideoId]!.videoPlayerController;
              if (currVideoPlayerController.value.volume > 0) {
                currVideoPlayerController.setVolume(0);
              } else {
                currVideoPlayerController.setVolume(1.0);
              }
            },
            child: Stack(
              children: [
                _buildVideoPlayer(videoInfo, index),
                Positioned(
                  left: 15,
                  top: 0,
                  child: Builder(builder: (BuildContext context) {
                    return GestureDetector(
                      onTapDown: (TapDownDetails details) {
                        final RenderBox button =
                            context.findRenderObject() as RenderBox;
                        final RenderBox overlay = Navigator.of(context)
                            .overlay!
                            .context
                            .findRenderObject() as RenderBox;
                        final RelativeRect position = RelativeRect.fromRect(
                          Rect.fromPoints(
                            button.localToGlobal(Offset(0, 50),
                                ancestor: overlay),
                            button.localToGlobal(
                                button.size.bottomRight(Offset(0, 50)),
                                ancestor: overlay),
                          ),
                          Offset.zero & overlay.size,
                        );

                        showMenu<int>(
                          context: context,
                          position: position,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          items: widget.collectionsInfo
                                  ?.asMap()
                                  .entries
                                  .map((entry) {
                                return PopupMenuItem<int>(
                                  value: entry.key,
                                  height: 20,
                                  child: Text(
                                    entry.value.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList() ??
                              [],
                          color: Colors.black.withOpacity(0.8),
                        ).then((int? newIndex) {
                          if (newIndex != null &&
                              newIndex != _collectionIndex) {
                            setState(() {
                              _collectionIndex = newIndex;
                              sortedSavedVideoList.clear();
                              _sortVideoList(
                                  widget.collectionsInfo![_collectionIndex]);
                              _currentVideoId = widget
                                  .collectionsInfo![_collectionIndex]
                                  .videos
                                  .first
                                  .videoId;
                            });
                            _playCurrentVideo(_currentVideoId);
                          }
                        });
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        decoration: BoxDecoration(
                          //color: Colors.black.withOpacity(0.5),
                          //borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.collectionsInfo![_collectionIndex].name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                Positioned(
                  left: 18,
                  bottom: 60,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.platform[widget
                                        .collectionsInfo![_collectionIndex]
                                        .videos
                                        .reversed
                                        .toList()[index]
                                        .videoId] ==
                                    "instagram"
                                ? Iconsax.instagram_bold
                                : Iconsax.youtube_bold,
                            color: Colors.white,
                            size: widget.platform[widget
                                        .collectionsInfo![_collectionIndex]
                                        .videos
                                        .reversed
                                        .toList()[index]
                                        .videoId] ==
                                    "instagram"
                                ? 40
                                : 48,
                          ),
                          SizedBox(width: 5),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width:
                                    2 * MediaQuery.of(context).size.width / 3,
                                child: Text(
                                  videoInfo.userData.fullname,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width:
                                    2 * MediaQuery.of(context).size.width / 3,
                                child: Text(
                                  "@${videoInfo.userData.username.replaceAll("@", "")}",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          "Saved on ${formatTimestamp(widget.collectionsInfo![_collectionIndex].videos.reversed.toList()[index].createdAt)}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 48,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => _showCaption(videoInfo.caption),
                        icon: Icon(
                          Iconsax.info_circle_bold,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(height: 10),
                      IconButton(
                        onPressed: () => _shareVideo(
                            _currentVideoId, widget.platform[_currentVideoId]),
                        icon: Icon(
                          Iconsax.send_2_bold,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(height: 10),
                      IconButton(
                        onPressed: () =>
                            _downloadVideo(videoInfo.videoData.videoUrl),
                        icon: Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // Build the video player for a single video
  Widget _buildVideoPlayer(ExtractedVideoInfo videoInfo, int index) {
    String videoId =
        widget.collectionsInfo![_collectionIndex].videos[index].videoId;
    final isVideoFailed = _videoLoadFailed[videoId] ?? false;
    print(isVideoFailed);
    print(_chewieControllers.containsKey(videoId));
    print(_chewieControllers);
    print(
        _chewieControllers[videoId]?.videoPlayerController.value.isInitialized);
    print("failed");
    print("");
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail as fallback and during loading
        if (isVideoFailed || !_chewieControllers.containsKey(videoId))
          CachedNetworkImage(
            imageUrl: videoInfo.videoData.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.black),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),

        // Video player
        if (!isVideoFailed &&
            _chewieControllers.containsKey(videoId) &&
            _chewieControllers[videoId]!
                .videoPlayerController
                .value
                .isInitialized)
          Chewie(controller: _chewieControllers[videoId]!),

        // Loading overlay
        if (isVideoFailed || !_chewieControllers.containsKey(videoId))
          Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[600]!,
            child: Container(
              color: Colors.black38,
            ),
          ),
      ],
    );
  }

  // Play the current video and pause others
  void _playCurrentVideo(String videoId) {
    _chewieControllers.forEach((key, controller) {
      if (key == videoId) {
        // Play the current video
        controller?.videoPlayerController.play();
      } else {
        // Pause all other videos
        controller?.videoPlayerController.pause();
      }
    });
  }
}

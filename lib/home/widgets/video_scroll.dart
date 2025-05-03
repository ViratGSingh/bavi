import 'package:bavi/models/short_video.dart';
import 'package:bavi/navigation_service.dart';
import 'package:chewie/chewie.dart'; // For video controls
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart'; // For video playback
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // For caching videos
import 'package:cached_network_image/cached_network_image.dart'; // For caching thumbnails
import 'package:carousel_slider/carousel_slider.dart'; // For carousel functionality

class VideoPlayerPage extends StatefulWidget {
  final List<ExtractedVideoInfo> videoList;
  final int initialPosition;

  const VideoPlayerPage({
    Key? key,
    required this.videoList,
    required this.initialPosition,
  }) : super(key: key);

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with WidgetsBindingObserver {
  final Map<int, ChewieController?> _chewieControllers = {};
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  final Map<int, bool> _videoLoadFailed = {}; // Track video load failures
  late CarouselSliderController _carouselController;
  int _currentIndex = 0; // Track the current visible video index

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer to detect app state changes
    _carouselController = CarouselSliderController();
    _currentIndex = widget.initialPosition; // Set initial index
    // Preload all videos at the start
    _preloadAllVideos();
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

  @override
  void dispose() {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pause all videos when the app is paused
      _pauseAllVideos();
    } else if (state == AppLifecycleState.resumed) {
      // Resume the current video when the app is resumed
      _playCurrentVideo(_currentIndex);
    }
  }

  // Preload all videos at the start
  void _preloadAllVideos() async {
    for (int index = 0; index < widget.videoList.length; index++) {
      await _preloadVideo(index);
    }
  }

  // Preload a video at a specific index
  Future<void> _preloadVideo(int index) async {
    if (!_chewieControllers.containsKey(index)) {
      final videoUrl = widget.videoList[index].videoData.videoUrl;

      // Check if the video is already cached
      final fileInfo = await _cacheManager.getFileFromCache(videoUrl);

      if (fileInfo != null) {
        // If cached, use the cached file
        _initializeVideoPlayer(index, VideoPlayerController.file(fileInfo.file));
      } else {
        // If not cached, play directly from the URL and cache it in the background
        final videoPlayerController = VideoPlayerController.network(videoUrl);
        _initializeVideoPlayer(index, videoPlayerController);

        // Cache the video in the background
        _cacheManager.downloadFile(videoUrl).then((fileInfo) {
          print('Video cached: ${fileInfo.file.path}');
        }).catchError((error) {
          print('Failed to cache video: $error');
        });
      }
    }
  }

  // Initialize the video player and Chewie controller
  void _initializeVideoPlayer(int index, VideoPlayerController videoPlayerController) {
    videoPlayerController.initialize().then((_) {
      if (!mounted) return; // Ensure the widget is still mounted
      final chewieController = ChewieController(
        videoPlayerController: videoPlayerController,
        allowFullScreen: false,
        materialProgressColors: ChewieProgressColors(playedColor: Color(0xFF8A2BE2)),
        cupertinoProgressColors: ChewieProgressColors(playedColor: Color(0xFF8A2BE2)),
        autoInitialize: true,
        zoomAndPan: true,
        showOptions: true,
        autoPlay: index == widget.initialPosition, // Autoplay the initial video
        looping: true, // Loop the video
        showControls: true, // Show controls
        showControlsOnInitialize: false,
        placeholder: Container(
          color: Colors.black,
        ),
      );
      setState(() {
        _chewieControllers[index] = chewieController;
        _videoLoadFailed[index] = false; // Video loaded successfully
      });
    }).catchError((error) {
      print('Failed to initialize video: $error');
      setState(() {
        _videoLoadFailed[index] = true; // Video failed to load
      });
    });
  }

  //Open bottomsheet to show caption
  void _showCaption(String caption) {
    //String decodedCaption = utf8.decode(caption.runes.toList());

    String decodedCaption = caption;
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF8A2BE2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
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
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  decodedCaption,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    //mixpanel.track("home_caption_video");
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

    //mixpanel.track("home_download_video");
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
    //mixpanel.track("home_share_video");
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            CarouselSlider.builder(
              carouselController: _carouselController,
              itemCount: widget.videoList.length,
              options: CarouselOptions(
                initialPage: widget.initialPosition,
                viewportFraction: 1.0, // Cover the whole screen
                enableInfiniteScroll: true, // Enable looping
                scrollDirection: Axis.vertical, // Vertical scrolling
                enlargeCenterPage: true, // Center the current video
                height: MediaQuery.of(context).size.height, // Full screen height
                onPageChanged: (index, reason) {
                  // Handle page change
                  setState(() {
                    _currentIndex = index;
                  });
                  // Play the current video and pause others
                  _playCurrentVideo(index);
                },
              ),
              itemBuilder: (context, index, realIndex) {
                final videoInfo = widget.videoList[index];

              // String decodedUserName =
              //     utf8.decode(videoInfo.userData.fullname.runes.toList());
              String decodedUserName = videoInfo.userData.fullname;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildVideoPlayer(videoInfo, index),
                       Positioned(
              left: 10,
              top: 10,
              child: IconButton(
                onPressed: () {
                  _pauseAllVideos(); // Pause all videos before navigating back
                  navService.goTo("/home");
                },
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                ),
              ),
            ),
              // GestureDetector(
              //       onTap: () {
              //         // VideoPlayerController currVideoPlayerController =
              //         //     _chewieControllers[index]!.videoPlayerController;
              //         // if (currVideoPlayerController.value.isPlaying) {
              //         //   currVideoPlayerController.pause();
              //         // } else {
              //         //   currVideoPlayerController.play();
              //         // }
              //         //mixpanel.track("home_play_video");
              //       },
              //       onDoubleTap: () {
              //         // VideoPlayerController currVideoPlayerController =
              //         //     _chewieControllers[index]!.videoPlayerController;
              //         // if (currVideoPlayerController.value.volume > 0) {
              //         //   currVideoPlayerController.setVolume(0);
              //         //   //mixpanel.track("home_mute_video");
              //         //   isMute = true;
              //         // } else {
              //         //   currVideoPlayerController.setVolume(1.0);
              //         //   mixpanel.track("home_unmute_video");
              //         //   isMute = false;
              //         //}
              //       },
              //       child: Container(
              //         width: MediaQuery.of(context).size.width,
              //         height: 3 * MediaQuery.of(context).size.height / 4,
              //         color: Colors.transparent,
              //       ),
              //     ),
                  // Positioned(
                  //   left: 20,
                  //   top: 0,
                  //   child: Text(
                  //     'BaviSync',
                  //     style: TextStyle(
                  //       color: Colors.white,
                  //       fontSize: 24,
                  //       fontFamily: 'Gugi',
                  //       fontWeight: FontWeight.w600,
                  //     ),
                  //   ),
                  // ),
                  Positioned(
                    left: 15,
                    bottom: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                               Iconsax.instagram_bold,
                              color: Colors.white,
                              size: 40,
                            ),
                            SizedBox(width: 5),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 2 * MediaQuery.of(context).size.width / 3,
                                  child: Text(
                                    decodedUserName,
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
                                  width: 2 * MediaQuery.of(context).size.width / 3,
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
                        //SizedBox(height: 10),
                        // Padding(
                        //   padding: EdgeInsets.only(left: 4),
                        //   child: Text(
                        //     "Saved on ${formatTimestamp(widget.collectionInfo!.videos.reversed.toList()[index].createdAt)}",
                        //     style: TextStyle(
                        //       color: Colors.white,
                        //       fontSize: 12,
                        //       fontFamily: 'Poppins',
                        //       fontWeight: FontWeight.w400,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 72,
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
                              videoInfo.videoId ,
                            "instagram"),
                          icon: Icon(
                            Iconsax.send_2_bold,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        // SizedBox(height: 10),
                        // IconButton(
                        //   onPressed: () =>
                        //       _downloadVideo(videoInfo.videoData.videoUrl),
                        //   icon: Icon(
                        //     Icons.download,
                        //     color: Colors.white,
                        //     size: 24,
                        //   ),
                        // ),
                      ],
                    ),
                  )
                  ],
                );
              },
            ),
         
          ],
        ),
      ),
    );
  }

  // Build the video player for a single video
  Widget _buildVideoPlayer(ExtractedVideoInfo videoInfo, int index) {
    final isVideoFailed = _videoLoadFailed[index] ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail as a fallback (if video fails to load)
        if (isVideoFailed || !_chewieControllers.containsKey(index))
          CachedNetworkImage(
            imageUrl: videoInfo.videoData.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[300]),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
        // Video player (if initialized and not failed)
        if (!isVideoFailed && _chewieControllers.containsKey(index) &&
            _chewieControllers[index]!.videoPlayerController.value.isInitialized)
          Chewie(controller: _chewieControllers[index]!),
      ],
    );
  }

  // Play the current video and pause others
  void _playCurrentVideo(int index) {
    _chewieControllers.forEach((key, controller) {
      if (key == index) {
        // Play the current video
        controller?.videoPlayerController.play();
      } else {
        // Pause all other videos
        controller?.videoPlayerController.pause();
      }
    });
  }
}
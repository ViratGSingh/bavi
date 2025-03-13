import 'package:bavi/models/short_video.dart';
import 'package:bavi/navigation_service.dart';
import 'package:chewie/chewie.dart'; // For video controls
import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    // Dispose all Chewie controllers
    _chewieControllers.forEach((_, controller) {
      controller?.dispose();
    });
    WidgetsBinding.instance.removeObserver(this); // Remove observer
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

  // Pause all videos
  void _pauseAllVideos() {
    _chewieControllers.forEach((_, controller) {
      controller?.videoPlayerController.pause();
    });
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
        showOptions: false,
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
                return _buildVideoPlayer(videoInfo, index);
              },
            ),
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
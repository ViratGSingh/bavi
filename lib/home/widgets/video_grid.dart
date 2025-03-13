import 'package:bavi/home/widgets/video_set_player.dart';
import 'package:bavi/models/collection.dart';
import 'package:bavi/models/short_video.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoGridScreen extends StatefulWidget {
  final List<ExtractedVideoInfo> savedVideos;
  final bool isLoading;
  final Map<String, dynamic> platformData;
  final VideoCollectionInfo collection;

  const VideoGridScreen(
      {Key? key, required this.savedVideos, required this.isLoading, required this.platformData, required this.collection})
      : super(key: key);

  @override
  _VideoGridScreenState createState() => _VideoGridScreenState();
}

class _VideoGridScreenState extends State<VideoGridScreen> {
  // Map to track which video is being played
  final Map<int, CachedVideoPlayerPlusController> _videoControllers = {};

  @override
  void dispose() {
    // Dispose all video controllers
    _videoControllers.forEach((_, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isLoading
        ? _buildShimmerGrid() // Show shimmer loading when list is empty
        : _buildVideoGrid(); // Show video grid when list is not empty
  }

  // Build the shimmer loading grid
  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 9 / 16, // 9:16 aspect ratio
      ),
      itemCount: 9, // Show 9 shimmer items (3x3 grid)
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // Background color for shimmer
              borderRadius: BorderRadius.circular(12.0), // Rounded corners
            ),
          ),
        );
      },
    );
  }

  // Build the video grid
  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 9 / 16, // 9:16 aspect ratio
      ),
      itemCount: widget.savedVideos.length,
      itemBuilder: (context, index) {
        final videoInfo = widget.savedVideos[index];
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          VideoSetPlayer(
                                        videoList: widget.savedVideos,
                                        initialPosition: index,
                                        platform: widget.platformData,
                                        collectionInfo: widget.collection,
                                      ),
                                    ),
                                  );
          },
          onLongPress: () {
            // Play video on long press
            _playVideo(index, videoInfo.videoData.videoUrl);
          },
          onLongPressEnd: (_) {
            // Stop video and show thumbnail when long-press ends
            _stopVideo(index);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0), // Rounded corners
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail with caching
                CachedNetworkImage(
                  imageUrl: videoInfo.videoData.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300], // Placeholder color while loading
                  ),
                  errorWidget: (context, url, error) =>
                      Icon(Icons.error), // Error widget
                ),
                // Video player (if playing)
                if (_videoControllers.containsKey(index) &&
                    _videoControllers[index]!.value.isInitialized)
                  CachedVideoPlayerPlus(_videoControllers[index]!),
              ],
            ),
          ),
        );
      },
    );
  }

  void _playVideo(int index, String videoUrl) {
    if (!_videoControllers.containsKey(index)) {
      // Initialize video controller
      final controller = CachedVideoPlayerPlusController.network(videoUrl);

      controller.initialize().then((_) {
        if (!mounted) return; // Ensure the widget is still mounted
        setState(() {
          _videoControllers[index] = controller;
        });
        controller.play(); // Play the video after initialization
      }).catchError((error) {
        // Handle initialization errors
        print('Failed to initialize video: $error');
      });

      // Add the controller to the map immediately
      _videoControllers[index] = controller;
    } else {
      // Toggle play/pause
      final controller = _videoControllers[index]!;
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    }
  }

  void _stopVideo(int index) {
    if (_videoControllers.containsKey(index)) {
      final controller = _videoControllers[index]!;
      if (controller.value.isPlaying) {
        controller.pause(); // Pause the video
        controller.seekTo(Duration.zero); // Seek to the beginning
      }
      setState(() {
        // Remove the controller to show the thumbnail again
        _videoControllers.remove(index);
      });
    }
  }
}

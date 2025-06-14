import 'package:bavi/models/collection.dart';
import 'package:bavi/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class HomeVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  //final String videoId;
  //final Function() onBack;
  //final bool isOnboarding;
  //final Function(List<VideoCollectionInfo> updCollections) onSave;
  //final List<VideoCollectionInfo> collections;

  const HomeVideoPlayerWidget(
      {Key? key,
      //required this.videoId,
      required this.videoUrl,
      //required this.onBack,
      // required this.onSave,
      // required this.collections
      })
      : super(key: key);

  @override
  _HomeVideoPlayerWidgetState createState() => _HomeVideoPlayerWidgetState();
}

class _HomeVideoPlayerWidgetState extends State<HomeVideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  List<VideoCollectionInfo> userCollections = [];

  @override
  void initState() {
    super.initState();
    // Initialize the video player controller
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
    
    // Initialize the video player asynchronously
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      // Initialize the video player
      await _videoPlayerController.initialize();

      // Initialize the Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        allowFullScreen: false,
        autoPlay: true, // Automatically play the video once it's ready
        looping: true,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        materialProgressColors:
            ChewieProgressColors(playedColor: Color(0xFF8A2BE2)),
        cupertinoProgressColors:
            ChewieProgressColors(playedColor: Color(0xFF8A2BE2)),
        placeholder: Container(
          color: Colors.black,
        ),
        autoInitialize: true,
        zoomAndPan: true,
        showControls: true,
        showOptions: false,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      // Update the state to indicate that loading is complete
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      print('Error initializing video player: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        navService.goToAndPopUntil('/home');
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Video Player or Loading Indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
            else
              Center(
                child: Chewie(
                  controller: _chewieController!,
                ),
              ),

            // Close Button
            Positioned(
                top: 20,
                left: 10,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed:(){
                    navService.goToAndPopUntil('/home');
                  },// widget.onBack,
                ),
              ),
            

            // Save Button
            Positioned(
              bottom: 70,
              right: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  // showCollections(context, userCollections, widget.videoId,
                  //     widget.onSave, widget.isOnboarding);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

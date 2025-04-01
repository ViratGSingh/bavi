import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

class TutorialCarousel extends StatefulWidget {
  const TutorialCarousel({super.key, required this.tutorialLinks});
  final List<String> tutorialLinks;

  @override
  State<TutorialCarousel> createState() => _TutorialCarouselState();
}

class _TutorialCarouselState extends State<TutorialCarousel> {
  late List<VideoPlayerController?> _controllers;
  late List<bool> _isInitialized;
  int _currentIndex = 0;
  late CarouselSliderController _carouselController;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.tutorialLinks.length, (_) => null);
    _isInitialized = List.generate(widget.tutorialLinks.length, (_) => false);
    _carouselController = CarouselSliderController();
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    for (int i = 0; i < widget.tutorialLinks.length; i++) {
      await _initializeController(i);
    }
  }

  Future<void> _initializeController(int index) async {
    final String videoUrl = widget.tutorialLinks[index];
    VideoPlayerController controller;

    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(videoUrl);
      if (fileInfo != null) {
        controller = VideoPlayerController.file(fileInfo.file);
      } else {
        final file = await DefaultCacheManager().getSingleFile(videoUrl);
        controller = VideoPlayerController.file(file);
      }

      await controller.initialize();
      controller.setLooping(true); // Enable looping
      
      // Add listener for video completion
      controller.addListener(() {
        if (controller.value.position >= controller.value.duration) {
          if (_currentIndex < widget.tutorialLinks.length - 1) {
            _carouselController.nextPage();
          } else {
            // If we're at the last video, go back to the first one
            _carouselController.animateToPage(0);
          }
        }
      });

      if (index == _currentIndex) {
        controller.play();
      }

      if (mounted) {
        setState(() {
          _controllers[index] = controller;
          _isInitialized[index] = true;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2*MediaQuery.of(context).size.height/3,
      decoration: BoxDecoration(
        color: Colors.white,
      ),    
      child: CarouselSlider.builder(
        carouselController: _carouselController,
        itemCount: widget.tutorialLinks.length,
        options: CarouselOptions(
          height: 2*MediaQuery.of(context).size.height/3,
          viewportFraction: 1.0,
          enableInfiniteScroll: false,
          padEnds: false,
          onPageChanged: (index, reason) {
            // setState(() {
            //   _currentIndex = index;
            //   // Pause previous video
            //   if (_controllers[_currentIndex == 0 ? 1 : 0]?.value.isPlaying ?? false) {
            //     //_controllers[_currentIndex == 0 ? 1 : 0]?.pause();
            //     _controllers[index]?.seekTo(Duration(seconds: 0));
            //     _controllers[index]?.play();
            //   }
            //   // Play current video
            //   if (_controllers[index]?.value.isInitialized ?? false) {
            //     _controllers[index]?.seekTo(Duration(seconds: 0));
            //     _controllers[index]?.play();
            //   }
            // });
          },
        ),
        itemBuilder: (context, index, realIndex) {
          if (!_isInitialized[index] || _controllers[index] == null) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                height: 2*MediaQuery.of(context).size.height/3,
                margin: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }

          return 
          
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 2*MediaQuery.of(context).size.height/3,
              decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            child: AspectRatio(
              aspectRatio: _controllers[index]!.value.aspectRatio,
              child: VideoPlayer(_controllers[index]!),
            ),
            ),);
        },
      ),
    );
  }
}

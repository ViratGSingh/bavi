// import 'dart:convert';

// import 'package:bavi/home/widgets/video_activity.dart';
// import 'package:bavi/models/collection.dart';
// import 'package:bavi/models/short_video.dart';
// import 'package:bavi/models/user.dart';
// import 'package:bavi/widgets/profile_icon.dart';
// import 'package:cached_video_player_plus/cached_video_player_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:icons_plus/icons_plus.dart';
// import 'package:shimmer/shimmer.dart';
// import 'package:cached_network_image/cached_network_image.dart';

// class SearchResultsGridScreen extends StatefulWidget {
//   final List<ExtractedVideoInfo> savedVideos;
//   final ExtractedAccountInfo? account;
//   final String query;
//   final Function() onSelectSearch;

//   const SearchResultsGridScreen(
//       {super.key,
//       required this.savedVideos,
//       required this.query,
//       required this.onSelectSearch,
//       this.account});

//   @override
//   _SearchResultsGridScreenState createState() =>
//       _SearchResultsGridScreenState();
// }

// class _SearchResultsGridScreenState extends State<SearchResultsGridScreen> {
//   // Map to track which video is being played
//   final Map<int, CachedVideoPlayerPlusController> _videoControllers = {};

//   @override
//   void dispose() {
//     // Dispose all video controllers
//     _videoControllers.forEach((_, controller) {
//       controller.dispose();
//     });
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _buildVideoGrid(); // Show video grid when list is not empty
//   }

//   // Build the shimmer loading grid
//   Widget _buildShimmerGrid() {
//     return GridView.builder(
//       padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 3, // 3 columns
//         crossAxisSpacing: 8.0,
//         mainAxisSpacing: 8.0,
//         childAspectRatio: 9 / 16, // 9:16 aspect ratio
//       ),
//       itemCount: 9, // Show 9 shimmer items (3x3 grid)
//       itemBuilder: (context, index) {
//         return Shimmer.fromColors(
//           baseColor: Colors.grey[300]!,
//           highlightColor: Colors.grey[100]!,
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white, // Background color for shimmer
//               borderRadius: BorderRadius.circular(12.0), // Rounded corners
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // Build the video grid
//   Widget _buildVideoGrid() {
//     final savedVideos = widget.savedVideos;

//     return Column(
//       children: [
//         InkWell(
//           onTap: (){
//             widget.onSelectSearch();
//           },
//           child: Container(
//             width: MediaQuery.of(context).size.width - 16,
//             height: 105,
//             padding: const EdgeInsets.all(12),
//             decoration: ShapeDecoration(
//               color: Colors.white,
//               shape: RoundedRectangleBorder(
//                 side: BorderSide(width: 1, color: Color(0xFF090E1D)),
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               shadows: [
//                 BoxShadow(
//                   color: Color(0xFF080E1D),
//                   blurRadius: 0,
//                   offset: Offset(0, 4),
//                   spreadRadius: 0,
//                 )
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     CircularAvatarWithShimmer(
//                         imageUrl: widget.account?.profilePicUrl ?? ""),
//                     const SizedBox(width: 10),
//                     Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Container(
//                           width: 2 * MediaQuery.of(context).size.width / 3,
//                           child: Text(
//                             widget.account?.fullname != null
//                                 ? utf8.decode(
//                                     widget.account!.fullname.runes.toList())
//                                 : "Explore",
//                             style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.black,
//                                 fontSize: 16),
//                           ),
//                         ),
//                         Container(
//                           width: 2 * MediaQuery.of(context).size.width / 3 ,
//                           child: Text(
//                             widget.account?.username != null
//                                 ? utf8.decode(
//                                     widget.account!.username.runes.toList())
//                                 : "@drissea",
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(color: Colors.black, fontSize: 14),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 10),
//                 Padding(
//                   padding: const EdgeInsets.only(left: 5),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Icon(
//                         Iconsax.search_normal_outline,
//                         size: 20,
//                         color: Colors.black,
//                       ),
//                       SizedBox(width: 7),
//                       Container(
//                         width: 3*MediaQuery.of(context).size.width/4,
//                         child: Text(
//                           widget.query,
//                           overflow: TextOverflow.ellipsis,
//                           style: TextStyle(
//                             color: Colors.black,
//                             fontSize: 14,
//                             fontFamily: 'Poppins',
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 )
//               ],
//             ),
//           ),
//         ),
//         SizedBox(height: 8),
//         Container(
//           height: MediaQuery.of(context).size.height 
//           - MediaQuery.of(context).padding.bottom
//           - MediaQuery.of(context).padding.top
//           - 70
//           - 140,
//           child: CustomScrollView(
//             slivers: [
//               Visibility(
//                 visible: savedVideos.length >= 5,
//                 child: SliverPadding(
//                   padding: const EdgeInsets.all(8.0),
//                   sliver: SliverToBoxAdapter(
//                     child: Container(
//                       padding: EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(12),
//                         color: Color(0xFF8A2BE2),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Top Results",
//                             textAlign: TextAlign.center,
//                             style: TextStyle(
//                               color: Color(0xFFDFFF00),
//                               fontSize: 22,
//                               fontFamily: 'Poppins',
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           SizedBox(height: 10),
//                           LayoutBuilder(
//                             builder: (context, constraints) {
//                               final totalWidth = constraints.maxWidth;
//                               final leftWidth = totalWidth * 0.484;
//                               final rightWidth = totalWidth -
//                                   leftWidth -
//                                   8; // Subtract spacing

//                               return Row(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   SizedBox(
//                                     width: leftWidth,
//                                     child: AspectRatio(
//                                       aspectRatio: 9 / 16,
//                                       child: _buildVideoTile(0),
//                                     ),
//                                   ),
//                                   SizedBox(width: 8),
//                                   SizedBox(
//                                     width: rightWidth,
//                                     child: Column(
//                                       children: [
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: AspectRatio(
//                                                 aspectRatio: 9 / 16,
//                                                 child: _buildVideoTile(1),
//                                               ),
//                                             ),
//                                             SizedBox(width: 8),
//                                             Expanded(
//                                               child: AspectRatio(
//                                                 aspectRatio: 9 / 16,
//                                                 child: _buildVideoTile(2),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         SizedBox(height: 8),
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: AspectRatio(
//                                                 aspectRatio: 9 / 16,
//                                                 child: _buildVideoTile(3),
//                                               ),
//                                             ),
//                                             SizedBox(width: 8),
//                                             Expanded(
//                                               child: AspectRatio(
//                                                 aspectRatio: 9 / 16,
//                                                 child: _buildVideoTile(4),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               SliverPadding(
//                 padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 sliver: SliverGrid(
//                   delegate: SliverChildBuilderDelegate(
//                     (context, index) => _buildVideoTile(
//                         savedVideos.length > 5 ? (index + 5) : index),
//                     childCount: savedVideos.length > 5
//                         ? (savedVideos.length - 5)
//                         : savedVideos.length,
//                   ),
//                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: 3,
//                     crossAxisSpacing: 8,
//                     mainAxisSpacing: 8,
//                     childAspectRatio: 9 / 16,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildVideoTile(int index) {
//     final videoInfo = widget.savedVideos[index];
//     return GestureDetector(
//       onTap: () {
//         FocusScope.of(context).unfocus();
//         Navigator.push(context,
//     MaterialPageRoute<void>(
//       builder: (BuildContext context) => VideoSearchFeed(videoList: widget.savedVideos,initialPosition: index),
//     ),);
//       },
//       onLongPress: () {
//         _playVideo(index, videoInfo.videoData.videoUrl);
//       },
//       onLongPressEnd: (_) {
//         _stopVideo(index);
//       },
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(12.0),
//         child: Stack(
//           fit: StackFit.expand,
//           children: [
//             CachedNetworkImage(
//               imageUrl: videoInfo.videoData.thumbnailUrl,
//               fit: BoxFit.cover,
//               placeholder: (context, url) => Container(color: Colors.grey[300]),
//               errorWidget: (context, url, error) => Icon(Icons.error),
//             ),
//             if (_videoControllers.containsKey(index) &&
//                 _videoControllers[index]!.value.isInitialized)
//               CachedVideoPlayerPlus.player(controller: _videoControllers[index]!),
//           ],
//         ),
//       ),
//     );
//   }

//   void _playVideo(int index, String videoUrl) {
//     if (!_videoControllers.containsKey(index)) {
//       // Initialize video controller
//       final controller = CachedVideoPlayerPlusController.network(videoUrl);

//       controller.initialize().then((_) {
//         if (!mounted) return; // Ensure the widget is still mounted
//         setState(() {
//           _videoControllers[index] = controller;
//         });
//         controller.setVolume(0);
//         controller.play(); // Play the video after initialization
//       }).catchError((error) {
//         // Handle initialization errors
//         print('Failed to initialize video: $error');
//       });

//       // Add the controller to the map immediately
//       _videoControllers[index] = controller;
//     } else {
//       // Toggle play/pause
//       final controller = _videoControllers[index]!;
//       if (controller.value.isPlaying) {
//         controller.pause();
//       } else {
//         controller.setVolume(0);
//         controller.play();
//       }
//     }
//   }

//   void _stopVideo(int index) {
//     if (_videoControllers.containsKey(index)) {
//       final controller = _videoControllers[index]!;
//       if (controller.value.isPlaying) {
//         controller.pause(); // Pause the video
//         controller.seekTo(Duration.zero); // Seek to the beginning
//       }
//       setState(() {
//         // Remove the controller to show the thumbnail again
//         _videoControllers.remove(index);
//       });
//     }
//   }
// }

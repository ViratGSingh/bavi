import 'package:bavi/home/widgets/video_grid.dart';
import 'package:bavi/models/collection.dart';
import 'package:bavi/models/short_video.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart'; 

class VideoSearch extends StatefulWidget {
  const VideoSearch({super.key, required this.videos, required this.isLoading, required this.platformData, required this.collection, required this.onSearch});
  final List<ExtractedVideoInfo> videos;
  final bool isLoading;
  final Map<String, dynamic> platformData;
  final VideoCollectionInfo collection;
  final Function(String) onSearch;

  @override
  State<VideoSearch> createState() => _VideoSearchState();
}

class _VideoSearchState extends State<VideoSearch> {
  @override
  Widget build(BuildContext context) {
    return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                //Search Bar
                                Container(
                                  width: MediaQuery.of(context).size.width,
                                  height: 48,
                                  padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  decoration: ShapeDecoration(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                          width: 1, color: Color(0xFF090E1D)),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Iconsax.search_normal_1_outline,
                                          color: Colors.black),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Focus(
                                          child: TextField(
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Search',
                                              hintStyle: TextStyle(
                                                color: Color(0xFF5A5E68),
                                                fontSize: 16,
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            onChanged: (value) {
                                              if (value.length >= 3) {
                                                widget.onSearch(value);
                                              }else if(value.isEmpty){
                                                widget.onSearch("");
                                              }
                                            },
                                          ),
                                          onFocusChange: (hasFocus) {
                                            setState(() {
                                              // You can add state handling for focus if needed
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),
                                Expanded(
                                  //height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.bottom - MediaQuery.of(context).padding.top - 190,
                                  // Wrap VideoGridScreen with Expanded
                                  child: VideoGridScreen(
                                      savedVideos: widget.videos,
                                      isLoading:widget.isLoading,
                                      platformData: widget.platformData,
                                      collection: widget.collection),
                                ),
                              ],
                            ),
                          ),
                        );
  }
}
import 'package:bavi/home/widgets/video_grid.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/collection.dart';
import 'package:flutter/material.dart';

class CollectionVideosPage extends StatelessWidget {
  const CollectionVideosPage(
      {super.key, required this.videos, required this.collection});
  final List<ExtractedVideoInfo> videos;
  final VideoCollectionInfo collection;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black,
        leadingWidth: 80,
        leading: InkWell(
          onTap: () {
            Navigator.pop(context, 1);
          },
          child: Container(
            width: 24,
            height: 24,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(),
            child: Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
        ),
        title: Text(
          collection.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF090E1D),
            fontSize: 18,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        //automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(20),
        child: VideoGridScreen(savedVideos: videos, isLoading: false, platformData: {}, collection: collection),
      ),
    );
  }
}

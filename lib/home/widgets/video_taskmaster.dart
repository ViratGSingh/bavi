import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class VideoTaskmaster extends StatefulWidget {
  final HomePageStatus status;
  final int totalVideos;
  final Function() onCancel;
  final Function() onProfile;
  const VideoTaskmaster(
      {super.key,
      required this.status,
      required this.totalVideos,
      required this.onCancel,
      required this.onProfile});

  @override
  State<VideoTaskmaster> createState() => _VideoTaskmasterState();
}

class _VideoTaskmasterState extends State<VideoTaskmaster> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.status == HomePageStatus.idle
              ? [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(

                            borderRadius: BorderRadius.circular(40),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Image.asset(
                            "assets/images/logo/icon.png",
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Visibility(
                        visible: widget.status ==
                                HomePageStatus.generateQuery ||
                            widget.status == HomePageStatus.getSearchResults ||
                            widget.status == HomePageStatus.summarize,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: CircularProgressIndicator(
                            color: Color(0xFFDFFF00),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    widget.status == HomePageStatus.generateQuery
                        ? "Understanding Query"
                        : widget.status == HomePageStatus.getSearchResults
                            ? "Searching for Right Reels"
                            : widget.status == HomePageStatus.summarize
                                ? "Watching ${widget.totalVideos} Reels"
                                : "What are you looking for?",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]
              : widget.status == HomePageStatus.loading
                  ? [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                           ClipRRect(

                            borderRadius: BorderRadius.circular(40),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Image.asset(
                            "assets/images/logo/icon.png",
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: CircularProgressIndicator(
                              color: Color(0xFFDFFF00),
                            ),
                          ),
                        ],
                      ),
                    ]
                  : [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(

                            borderRadius: BorderRadius.circular(40),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Image.asset(
                            "assets/images/logo/icon.png",
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                          Visibility(
                            visible:
                                widget.status == HomePageStatus.generateQuery ||
                                    widget.status ==
                                        HomePageStatus.getSearchResults ||
                                    widget.status == HomePageStatus.summarize,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: CircularProgressIndicator(
                                color: Color(0xFFDFFF00),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Text(
                        widget.status == HomePageStatus.generateQuery
                            ? "Understanding Query"
                            : widget.status == HomePageStatus.getSearchResults
                                ? "Searching for Right Reels"
                                : widget.status == HomePageStatus.summarize
                                    ? "Watching ${widget.totalVideos} Reels"
                                    : "What are you looking for?",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 25),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            fixedSize:
                                Size(MediaQuery.of(context).size.width / 3, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () {
                            widget.onCancel();
                          },
                          child: Text("Cancel"),
                        ),
                      ),
                    ],
        ),
      ),
    );
  }
}

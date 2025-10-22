import 'dart:convert';

import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class AnswersView extends StatefulWidget {
  final List<ExtractedVideoInfo> videos;
  const AnswersView({super.key, required this.videos});

  @override
  State<AnswersView> createState() => _AnswersViewState();
}

class _AnswersViewState extends State<AnswersView> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar:  AppBar(
                      titleSpacing: 8,
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.white,
                      centerTitle: true,
                      leadingWidth: 60,
                      leading: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) => const HomePage(),
                            ),
                          );
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
                        'Drissea',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontFamily: 'Jua',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.fromLTRB(20,10,20,10),
            child: Column(
              children: widget.videos.map((video) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                          color: Color(0xFFE6E7E8),
                        ),
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height/4
                    ),
                    child: Column(
                      children: [
                        Container(
                          //margin: const EdgeInsets.only(bottom: 12),
                          
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                child: Row(
                                  children: [
                                    CircularAvatarWithShimmer(
                                        imageUrl: video.userData.profilePicUrl),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 2 *
                                                  MediaQuery.of(context).size.width /
                                                  3 -
                                              40,
                                          child: Text(
                                            video.userData?.username != null
                                                ? utf8.decode(video
                                                    .userData.fullname.runes
                                                    .toList())
                                                : "NA",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                                fontSize: 16),
                                          ),
                                        ),
                                        Container(
                                          width: 2 *
                                                  MediaQuery.of(context).size.width /
                                                  3 -
                                              40,
                                          child: Text(
                                            video.userData.fullname != ""
                                                ? utf8.decode(video
                                                    .userData.username.runes
                                                    .toList())
                                                : "NA",
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Colors.black, fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                           video.searchContent,
                           //maxLines: 5,
                          style:  TextStyle(
                                color: Colors.black,
                                fontFamily: 'Poppins',
                                fontSize: 14
                                ),
                        ),
                      
                    ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

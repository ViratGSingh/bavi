import 'dart:convert';

import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchResultView extends StatefulWidget {
  final String markdownText;
  final ExtractedAccountInfo? account;
  final String query;
  final List<ExtractedVideoInfo> savedVideos;
  final Function() onSelectSearch;

  const SearchResultView(
      {super.key,
      required this.markdownText,
      required this.savedVideos,
      required this.query,
      required this.onSelectSearch,
      this.account});

  @override
  State<SearchResultView> createState() => _SearchResultViewState();
}

class _SearchResultViewState extends State<SearchResultView> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              widget.onSelectSearch();
            },
            child: Container(
              width: MediaQuery.of(context).size.width - 16,
              height: 105,
              padding: const EdgeInsets.all(12),
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1, color: Color(0xFF090E1D)),
                  borderRadius: BorderRadius.circular(16),
                ),
                shadows: [
                  BoxShadow(
                    color: Color(0xFF080E1D),
                    blurRadius: 0,
                    offset: Offset(0, 4),
                    spreadRadius: 0,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircularAvatarWithShimmer(
                          imageUrl: widget.account?.profilePicUrl ?? ""),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 2 * MediaQuery.of(context).size.width / 3,
                            child: Text(
                              widget.account?.fullname != null
                                  ? utf8.decode(
                                      widget.account!.fullname.runes.toList())
                                  : "Explore",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontSize: 16),
                            ),
                          ),
                          Container(
                            width: 2 * MediaQuery.of(context).size.width / 3,
                            child: Text(
                              widget.account?.username != null
                                  ? utf8.decode(
                                      widget.account!.username.runes.toList())
                                  : "@drissea",
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: Colors.black, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Iconsax.search_normal_outline,
                          size: 20,
                          color: Colors.black,
                        ),
                        SizedBox(width: 7),
                        Container(
                          width: 3 * MediaQuery.of(context).size.width / 4,
                          child: Text(
                            widget.query,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      indicatorColor: Color(0xFF8A2BE2),
                      labelColor: Color(0xFF8A2BE2),
                      unselectedLabelColor: Colors.black,
                      indicatorWeight: 2,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: TextStyle(
                        color: Color(0xFF090E1D),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelStyle: TextStyle(
                        color: Color(0xFF090E1D),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(
                          text: 'Answer',
                        ),
                        Tab(
                          text: 'Source',
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(children: [
                        //Answer
                        Container(
                          padding: EdgeInsets.only(top: 12),
                          height: MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.bottom -
                              MediaQuery.of(context).padding.top -
                              70 -
                              160,
                          child: SingleChildScrollView(
                            child: MarkdownBody(
                              data: widget.markdownText,
                              onTapLink: (text, href, title) async {
                                if (href != null) {
                                  final uri = Uri.parse(href);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  }
                                }
                              },
                              styleSheet: MarkdownStyleSheet.fromTheme(
                                      Theme.of(context))
                                  .copyWith(
                                h1: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                                h2: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                                h3: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                                p: const TextStyle(fontSize: 16, height: 1.5),
                                a: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                listBullet: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        //Sources
                        Text("Sources")
                      ]),
                    )
                  ],
                )),
          ),
          //initialIndex: initialIndex,
        ],
      ),
    );
  }
}

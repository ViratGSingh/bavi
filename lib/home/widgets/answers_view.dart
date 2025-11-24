import 'dart:convert';

import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/home/widgets/web_view.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ThreadAnswerView extends StatefulWidget {
  final List<InfluenceData> answerResults;
  final String query;
  final String answer;
  final bool hideRefresh;
  final HomePageStatus status;
  final HomeReplyStatus replyStatus;
  final Function() onRefresh;
  final Function() onEditSelected;
  const ThreadAnswerView(
      {super.key,
      required this.answerResults,
      required this.query,
      required this.answer,
      required this.status,
      required this.replyStatus,
      required this.onRefresh,
      required this.onEditSelected,
      required this.hideRefresh
      });

  @override
  State<ThreadAnswerView> createState() => _ThreadAnswerViewState();
}

class _ThreadAnswerViewState extends State<ThreadAnswerView> {
  bool _menuOpen = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          //constraints: BoxConstraints(maxHeight: 150),
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
              border: Border.all(),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(offset: Offset(0, 4), color: Colors.black)
              ]),
          padding: EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                    Iconsax.magicpen_outline,
                    color: Colors.black,
                    size: 20,
                  ),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.query,
                  // overflow: TextOverflow.ellipsis,
                  // maxLines: 2,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              SizedBox(width: 5),

            Builder(
              builder: (iconContext) {
                return InkWell(
                  onTap: () async {
                    setState(() {
                      _menuOpen = true;
                    });
                    final renderBox = iconContext.findRenderObject() as RenderBox;
                    final position = renderBox.localToGlobal(Offset(-50, 10));
                    final size = renderBox.size;

                    await showMenu(
                      context: iconContext,
                      color: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      position: RelativeRect.fromLTRB(
                        position.dx,
                        position.dy + size.height,
                        position.dx + size.width,
                        position.dy,
                      ),
                      items: [
                        PopupMenuItem(
                          value: "copy",
                          child: SizedBox(
                            //width: 100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                
                                Text("Copy"),
                                Icon(Icons.copy, size: 18, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: "edit",
                          child: SizedBox(
                            //width: ,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Edit"),
                                Icon(Icons.edit, size: 18, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).then((value) {
                      setState(() {
                        _menuOpen = false;
                      });
                      if (value == "copy") {
                        Clipboard.setData(ClipboardData(text: widget.query));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor:
                                Color(0xFF8A2BE2), // Purple background
                            content: Text(
                              'Copied to clipboard',
                              style: TextStyle(
                                color: Color(0xFFDFFF00), // Neon green text
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else if (value == "edit") {
                        // Add edit logic here
                        widget.onEditSelected();
                      }
                    });
                  },
                  child: Icon(
                    Icons.more_vert_outlined,
                    color: _menuOpen ? Colors.grey.shade300 : Colors.black,
                    size: 20,
                  ),
                );
              },
            ),
            ],
          ),
        ),
        
        SizedBox(height: 10),
        widget.status != HomePageStatus.success ||
                widget.replyStatus != HomeReplyStatus.success
            ? Column(
                children: [
                  AnswerLoader(
                    loaderText: widget.status == HomePageStatus.generateQuery
                        ? "Understanding your query"
                        : widget.status == HomePageStatus.getSearchResults
                            ? "Searching the web"
                            : "Thinking of a reply",
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height / 3,
                  )
                ],
              )
            : MarkdownBody(
                data: widget.answer,
                onTapLink: (text, href, title) async {
                  if (href != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            WebViewPage(url: href),
                      ),
                    );
                  }
                },
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  h1: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  h2: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  h3: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  p: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      height: 1.5),
                  a: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF8A2BE2),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF8A2BE2),
                  ),
                  listBullet: const TextStyle(fontSize: 16),
                ),
              ),
        Visibility(
          visible: widget.status == HomePageStatus.success &&
              widget.replyStatus == HomeReplyStatus.success,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      final textToCopy = widget.answer.trim();
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor:
                              Color(0xFF8A2BE2), // Purple background
                          content: Text(
                            'Copied to clipboard',
                            style: TextStyle(
                              color: Color(0xFFDFFF00), // Neon green text
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 5, 10, 5),
                      child: Icon(Iconsax.copy_outline, size: 18),
                    ),
                  ),
                  Visibility(
                    visible: !widget.hideRefresh,
                    child: InkWell(
                      onTap: () async {
                        widget.onRefresh();
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
                        child: Icon(Iconsax.refresh_outline, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  //Source button
                  InkWell(
                    //padding: EdgeInsets.all(5)
                    onTap: () {
                      // context
                      //     .read<HBloc>()
                      //     .add(ReplySearchResultShare());
                      showModalBottomSheet(
                        context: context,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        backgroundColor: Color(0xFF8A2BE2),
                        builder: (context) {
                          return Container(
                            padding: EdgeInsets.all(16),
                            height: MediaQuery.of(context).size.height / 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Sources",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.close,
                                            size: 18, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount:
                                        widget.answerResults?.length ?? 0,
                                    separatorBuilder: (_, __) =>
                                        Divider(color: Colors.purple),
                                    itemBuilder: (context, index) {
                                      final item = widget.answerResults?[index];
                                      return GestureDetector(
                                        onTap: () async {
                                          if (item?.url != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder:
                                                    (BuildContext context) =>
                                                        WebViewPage(
                                                            url: item?.url ??
                                                                ""),
                                              ),
                                            );
                                          }
                                        },
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item?.title ?? "",
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.white),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              item?.url ?? "",
                                              style: TextStyle(
                                                color: Color(0xFFDFFF00),
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.link_2_outline,
                            size: 18,
                            color: Color(0xFF8A2BE2),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Sources',
                            style: TextStyle(
                              color: Color(0xFF8A2BE2),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AnswerLoader extends StatelessWidget {
  final String loaderText;
  const AnswerLoader({super.key, required this.loaderText});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: Color(0xFF8A2BE2)),
                      child: Image.asset(
                        "assets/images/logo/icon.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: CircularProgressIndicator(
                      color: Color(0xFFDFFF00),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Shimmer.fromColors(
              baseColor: Colors.grey.shade600,
              highlightColor: Colors.grey.shade300,
              child: Text(
                loaderText,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

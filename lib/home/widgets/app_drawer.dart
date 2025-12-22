import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/models/question_answer.dart';
import 'package:bavi/models/session.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class ChatAppDrawer extends StatefulWidget {
  final List<ThreadSessionData> sessions;
  final Function(ThreadSessionData session) onSessionTap;
  final HomeHistoryStatus historyStatus;

  const ChatAppDrawer({
    super.key,
    required this.sessions,
    required this.historyStatus,
    required this.onSessionTap,
  });

  @override
  State<ChatAppDrawer> createState() => _ChatAppDrawerState();
}

class _ChatAppDrawerState extends State<ChatAppDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width - 60,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width / 2,
                        child: Text(
                          "History",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: widget.historyStatus == HomeHistoryStatus.loading
                    ? ListView.builder(
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                                child: Shimmer.fromColors(
                                  baseColor: Colors.grey.shade300,
                                  highlightColor: Colors.grey.shade100,
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Container(
                                          width: 120,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 60,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
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
                                ),
                              ),
                              if (index != 5)
                                Divider(height: 1, color: Colors.grey.shade100),
                            ],
                          );
                        },
                      )
                    : widget.sessions.isEmpty
                        ? Center(
                            child: Text(
                              "No history yet",
                              style: TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          )
                        : ListView(
                            children: [
                              ...widget.sessions.map((data) {
                                return InkWell(
                                  onTap: () => widget.onSessionTap(data),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            0, 5, 0, 5),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data.results.isNotEmpty
                                                    ? data
                                                        .results.first.userQuery
                                                    : "New Thread",
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black,
                                                  fontFamily: 'Poppins',
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 10),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                            Iconsax
                                                                .clock_outline,
                                                            size: 14,
                                                            color: Colors.grey),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          DateFormat(
                                                                  "MMM d'' yy h:mm a")
                                                              .format(data
                                                                  .createdAt
                                                                  .toDate()),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                            fontFamily:
                                                                'Poppins',
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                            Iconsax
                                                                .link_2_outline,
                                                            size: 14,
                                                            color: Colors.grey),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          "${data.results.length}",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                            fontFamily:
                                                                'Poppins',
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (data != widget.sessions.last)
                                        Divider(
                                            height: 1,
                                            color: Colors.grey.shade100),
                                    ],
                                  ),
                                );
                              })
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

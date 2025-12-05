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
  final String profilePicUrl;
  final String fullname;
  final String email;
  final HomeHistoryStatus historyStatus;
  final Function() onLogin;

  const ChatAppDrawer(
      {Key? key,
      required this.sessions,
      required this.historyStatus,
      required this.onSessionTap,
      required this.profilePicUrl,
      required this.email,
      required this.fullname,
      required this.onLogin})
      : super(key: key);

  @override
  State<ChatAppDrawer> createState() => _ChatAppDrawerState();
}

class _ChatAppDrawerState extends State<ChatAppDrawer> {
  int selectedTab = 0;

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
                  // CircularAvatarWithShimmer(imageUrl: widget.profilePicUrl),
                  // SizedBox(width: 10),
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
                      // Container(
                      //   width: MediaQuery.of(context).size.width / 2,
                      //   child: Text(
                      //     widget.email != "" ? widget.email : "Hi There!",
                      //     overflow: TextOverflow.ellipsis,
                      //     maxLines: 1,
                      //     style: TextStyle(
                      //       color: Colors.black,
                      //       fontSize: 12,
                      //       fontFamily: 'Poppins',
                      //       fontWeight: FontWeight.w500,
                      //     ),
                      //   ),
                      // ),
                    ],
                  )
                ],
              ),
              SizedBox(height: 14),
              // Container(
              //   decoration: BoxDecoration(
              //     color: Color(0xFFf3eafc),
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: Row(
              //     children: [
              //       Expanded(
              //         child: InkWell(
              //           onTap: () {
              //             setState(() {
              //               selectedTab = 0;
              //             });
              //           },
              //           borderRadius: BorderRadius.circular(20),
              //           child: Container(
              //             decoration: BoxDecoration(
              //               color: selectedTab == 0
              //                   ? Color(0xFF8A2BE2)
              //                   : Colors.transparent,
              //               borderRadius: BorderRadius.circular(20),
              //               //border: Border.all(color: Color(0xFF8A2BE2))
              //             ),
              //             padding: const EdgeInsets.symmetric(
              //                 vertical: 8, horizontal: 8),
              //             child: Row(
              //               mainAxisAlignment: MainAxisAlignment.center,
              //               children: [
              //                 Icon(
              //                   Icons.help_outline,
              //                   color: selectedTab == 0
              //                       ? Color(0xFFDFFF00)
              //                       : Color(0xFF8A2BE2),
              //                 ),
              //                 SizedBox(width: 8),
              //                 Text(
              //                   'Watch',
              //                   style: TextStyle(
              //                     color: selectedTab == 0
              //                         ? Color(0xFFDFFF00)
              //                         : Color(0xFF8A2BE2),
              //                     fontWeight: FontWeight.w600,
              //                     fontFamily: 'Poppins',
              //                   ),
              //                 ),
              //               ],
              //             ),
              //           ),
              //         ),
              //       ),
              //       Expanded(
              //         child: InkWell(
              //           onTap: () {
              //             setState(() {
              //               selectedTab = 1;
              //             });
              //           },
              //           borderRadius: BorderRadius.circular(20),
              //           child: Container(
              //             decoration: BoxDecoration(
              //               color: selectedTab == 1
              //                   ? Color(0xFF8A2BE2)
              //                   : Colors.transparent,
              //               borderRadius: BorderRadius.circular(20),
              //               //border: Border.all(color: Color(0xFF8A2BE2))
              //             ),
              //             padding: const EdgeInsets.symmetric(
              //                 vertical: 8, horizontal: 8),
              //             child: Row(
              //               mainAxisAlignment: MainAxisAlignment.center,
              //               children: [
              //                 Icon(
              //                   Iconsax.message_text_outline,
              //                   color: selectedTab == 1
              //                       ? Color(0xFFDFFF00)
              //                       : Color(0xFF8A2BE2),
              //                 ),
              //                 SizedBox(width: 8),
              //                 Text(
              //                   'Threads',
              //                   style: TextStyle(
              //                     color: selectedTab == 1
              //                         ? Color(0xFFDFFF00)
              //                         : Color(0xFF8A2BE2),
              //                     fontWeight: FontWeight.w600,
              //                     fontFamily: 'Poppins',
              //                   ),
              //                 ),
              //               ],
              //             ),
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              //SizedBox(height: 5),
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
                    : ListView(
                        children: [
                          ...widget.sessions.map((data) {
                            return InkWell(
                              onTap: () => widget.onSessionTap(data),
                              child: Column(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(0, 5, 0, 5),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      //width: MediaQuery.of(context).size.width / 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data.results.first.userQuery,
                                            maxLines: 2,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black,
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          // Text(
                                          //   "searchTerm",
                                          //   maxLines: 1,
                                          //   style: const TextStyle(
                                          //     fontSize: 14,
                                          //     color: Colors.grey,
                                          //     fontFamily: 'Poppins',
                                          //     fontWeight: FontWeight.w500,
                                          //   ),
                                          // ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 10),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Iconsax.clock_outline,
                                                        size: 14,
                                                        color: Colors.grey),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      DateFormat(
                                                              "MMM d'' yy h:mm a")
                                                          .format(data.createdAt
                                                              .toDate()),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                        fontFamily: 'Poppins',
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(Iconsax.link_2_outline,
                                                        size: 14,
                                                        color: Colors.grey),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      "${data.results.length}",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                        fontFamily: 'Poppins',
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
                                        height: 1, color: Colors.grey.shade100),
                                ],
                              ),
                            );
                          })
                        ],
                      ),
              ),
              //const SizedBox(height: 14),
              // InkWell(
              //   onTap: widget.onLogin,
              //   child: widget.fullname == "Guest"
              //       ? Row(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             Icon(Iconsax.login_1_bold,
              //                 color: Colors.black, size: 24),
              //             SizedBox(width: 15),
              //             Column(
              //               crossAxisAlignment: CrossAxisAlignment.start,
              //               children: [
              //                 Text(
              //                   "Login",
              //                   style: TextStyle(
              //                     color: Colors.black,
              //                     fontSize: 16,
              //                     fontFamily: 'Poppins',
              //                     fontWeight: FontWeight.w500,
              //                   ),
              //                 ),
              //                 SizedBox(height: 5),
              //                 Container(
              //                   width: MediaQuery.of(context).size.width / 2,
              //                   child: Text(
              //                     "Login to your account to access your search history",
              //                     style: TextStyle(
              //                       color: Colors.black,
              //                       fontSize: 12,
              //                       fontFamily: 'Poppins',
              //                       fontWeight: FontWeight.w400,
              //                     ),
              //                   ),
              //                 ),
              //               ],
              //             )
              //           ],
              //         )
              //       : Row(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             Icon(Iconsax.login_1_bold,
              //                 color: Colors.black, size: 24),
              //             SizedBox(width: 15),
              //             Column(
              //               crossAxisAlignment: CrossAxisAlignment.start,
              //               children: [
              //                 Text(
              //                   "Logout",
              //                   style: TextStyle(
              //                     color: Colors.black,
              //                     fontSize: 16,
              //                     fontFamily: 'Poppins',
              //                     fontWeight: FontWeight.w500,
              //                   ),
              //                 ),
              //                 SizedBox(height: 5),
              //                 Container(
              //                   width: MediaQuery.of(context).size.width / 2,
              //                   child: Text(
              //                     "Logout to create or login to another account of yours",
              //                     style: TextStyle(
              //                       color: Colors.black,
              //                       fontSize: 12,
              //                       fontFamily: 'Poppins',
              //                       fontWeight: FontWeight.w400,
              //                     ),
              //                   ),
              //                 ),
              //               ],
              //             )
              //           ],
              //         ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:bavi/dialogs/information.dart';
import 'package:bavi/dialogs/warning.dart';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/widgets/app_drawer.dart';
import 'package:bavi/home/widgets/reply.dart';
import 'package:bavi/home/widgets/search/video_search.dart';
import 'package:bavi/home/widgets/video_grid.dart';
import 'package:bavi/home/widgets/video_taskmaster.dart';
import 'package:bavi/models/question_answer.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:http/http.dart' as http;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ModalRoute.of(context)?.addScopedWillPopCallback(_handlePop);
  }

  Future<bool> _handlePop() async {
    // when user tries to pop this page itself
    return true;
  }

  @override
  void dispose() {
    ModalRoute.of(context)?.removeScopedWillPopCallback(_handlePop);
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initMixpanel();
  }

  late Mixpanel mixpanel;
  TextEditingController taskTextController = TextEditingController();
  bool isTaskValid = false;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
    mixpanel.track("home_view");
  }

  int levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<List<int>> matrix = List.generate(
      s.length + 1,
      (_) => List<int>.filled(t.length + 1, 0),
    );

    for (int i = 0; i <= s.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= t.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s.length; i++) {
      for (int j = 1; j <= t.length; j++) {
        int cost = s[i - 1] == t[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s.length][t.length];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>(
      create: (context) =>
          HomeBloc(httpClient: http.Client())..add(HomeInitialUserData()),
      child: BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
        return PopScope(
          canPop: false,
          child: SafeArea(
            child: Scaffold(
              drawer: state.status == HomePageStatus.idle
                  ? ChatAppDrawer(
                      conversations: state.searchHistory.reversed.toList(),
                      onConversationTap: (ConversationData conversation) {
                        if (state.userData.fullname == "Guest") {
                          mixpanel.track("guest_tap_chat");
                          showDialog(
                              context: context,
                              builder: (popupContext) => InfoPopup(
                                    title: "Information",
                                    message:
                                        "You can't access your chat history until you're logged in. Please login to continue.",
                                    action: "Okay",
                                    popupColor: Color(0xFF8A2BE2),
                                    isInfo: true,
                                    popupIcon: Icons.info,
                                    actionFunc: () {
                                      popupContext.pop();
                                      mixpanel.track("popup_login_attempt");
                                      context.read<HomeBloc>().add(
                                            HomeAttemptGoogleSignIn(),
                                          );
                                      
                                    },
                                    cancelText: "No",
                                  ));
                        } else {
                          mixpanel.track("user_tap_chat");
                          context.read<HomeBloc>().add(
                                HomeNavToReply(conversation),
                              );
                        }
                      },
                      profilePicUrl: state.userData.profilePicUrl,
                      username: state.userData.username,
                      fullname: state.userData.fullname,
                      onLogin: () => context.read<HomeBloc>().add(
                            HomeAttemptGoogleSignIn(),
                          ),
                    )
                  : null,
              backgroundColor: Colors.white,

              // bottomNavigationBar: BottomAppBar(
              //   // shape: CircularNotchedRectangle(),
              //   // notchMargin: 8.0,
              //   height: 60,
              //   padding: EdgeInsets.zero,
              //   color: Colors.white,
              //   child: Container(
              //     decoration: BoxDecoration(
              //       border: Border(
              //         top: BorderSide(
              //           color: Colors.grey.shade300,
              //           width: 1.0,
              //         ),
              //       ),
              //     ),
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.spaceAround,
              //       children: <Widget>[
              //         IconButton(
              //           icon: Column(
              //             mainAxisSize: MainAxisSize.min,
              //             children: [
              //               Icon(
              //                   state.page == NavBarOption.home
              //                       ? Iconsax.home_1_bold
              //                       : Iconsax.home_1_outline,
              //                   color: Colors.black),
              //               Text(
              //                 'Home',
              //                 style: TextStyle(
              //                     color: Colors.black,
              //                     fontSize: 12,
              //                     fontWeight:  state.page == NavBarOption.home
              //                         ?FontWeight.bold:FontWeight.normal),
              //               ),
              //             ],
              //           ),
              //           onPressed: () {
              //             context.read<HomeBloc>().add(
              //                   HomeNavOptionSelect(NavBarOption.home),
              //                 );
              //             mixpanel.track("home_view");
              //           },
              //         ),
              //         IconButton(
              //           icon: Column(
              //             mainAxisSize: MainAxisSize.min,
              //             children: [
              //               Icon(
              //                   state.page == NavBarOption.search
              //                       ? Iconsax.search_normal_bold
              //                       : Iconsax.search_normal_outline,
              //                   color: Colors.black),
              //               Text(
              //                 'Search',
              //                 style: TextStyle(
              //                     color:Colors.black,
              //                     fontSize: 12,
              //                     fontWeight:  state.page == NavBarOption.search
              //                         ? FontWeight.bold:FontWeight.normal),
              //               ),
              //             ],
              //           ),
              //           onPressed: () {
              //             context.read<HomeBloc>().add(
              //                   HomeNavOptionSelect(NavBarOption.search),
              //                 );
              //             mixpanel.track("search_view");
              //           },
              //         ),
              //         IconButton(
              //           icon: Column(
              //             mainAxisSize: MainAxisSize.min,
              //             children: [
              //               Container(
              //                 decoration: BoxDecoration(
              //                     color: Color(0xFF8A2BE2),
              //                     borderRadius: BorderRadius.circular(4)),
              //                 padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
              //                 child: Icon(
              //                   Iconsax.archive_add_bold,
              //                   size: 16,
              //                   color: Color(0xFFDFFF00),
              //                 ),
              //               ),
              //               Text(
              //                 'Add Video',
              //                 style: TextStyle(
              //                     color:Colors.black,
              //                     fontSize: 12,
              //                     fontWeight:  FontWeight.normal),
              //               ),
              //             ],
              //           ),
              //           onPressed: () {
              //             navService.goTo("/addVideo");
              //             // Navigator.push(
              //             //   context,
              //             //   MaterialPageRoute<void>(
              //             //     builder: (BuildContext context) => AddVideoPage(),
              //             //   ),
              //             // );
              //           },
              //         ),
              //         IconButton(
              //           icon: Column(
              //             mainAxisSize: MainAxisSize.min,
              //             children: [
              //               Icon(
              //                 state.page == NavBarOption.player
              //                     ? Iconsax.video_play_bold
              //                     : Iconsax.video_play_outline,
              //                 color: Colors.black,
              //               ),
              //               Text(
              //                 'Plsyer',
              //                 style: TextStyle(
              //                     color:  Colors.black,
              //                     fontSize: 12,
              //                     fontWeight: state.page == NavBarOption.player
              //                         ?FontWeight.bold:FontWeight.normal),
              //               ),
              //             ],
              //           ),
              //           onPressed: () {
              //             context.read<HomeBloc>().add(
              //                   HomeNavOptionSelect(NavBarOption.player),
              //                 );
              //             mixpanel.track("player_view");
              //           },
              //         ),
              //         IconButton(
              //           icon: Column(
              //             mainAxisSize: MainAxisSize.min,
              //             children: [
              //               Icon(
              //                   state.page == NavBarOption.profile
              //                       ? Iconsax.frame_bold
              //                       : Iconsax.frame_1_outline,
              //                   color: Colors.black),
              //               Text(
              //                 'Profile',
              //                 style: TextStyle(
              //                     color: Colors.black,
              //                     fontSize: 12,
              //                     fontWeight: state.page == NavBarOption.profile
              //                         ? FontWeight.bold:FontWeight.normal),
              //               ),
              //             ],
              //           ),
              //           onPressed: () {
              //             context.read<HomeBloc>().add(
              //                   HomeNavOptionSelect(NavBarOption.profile),
              //                 );
              //             mixpanel.track("profile_view");
              //           },
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              // floatingActionButton: FloatingActionButton(
              //   shape: CircleBorder(),
              //   onPressed: () {
              //     // Add your onPressed code here!
              //   },
              //   child: Icon(Icons.bookmark_add, color: Color(0xFFDFFF00)),
              //   backgroundColor: Color(0xFF8A2BE2),
              // ),
              // floatingActionButtonLocation:
              //     FloatingActionButtonLocation.centerDocked,
              appBar: state.status == HomePageStatus.idle ||
                      state.status == HomePageStatus.success
                  ? AppBar(
                      titleSpacing: 8,
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.white,
                      leadingWidth: 35,
                      title: Text(
                        'Drissea',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontFamily: 'Jua',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () async {
                              final url = Uri.encodeComponent(
                                  "https://play.google.com/store/apps/details?id=com.wooshir.bavi");
                              final text = Uri.encodeComponent(
                                  "Found this super helpful for planning weekends and exploring Bengaluru’s food scene — all from the best local Instagram creators. Try it out to discover where to eat next!");
                              final shareLink =
                                  "https://wa.me/?text=$text%20$url";

                              await launchUrl(Uri.parse(shareLink),
                                  mode: LaunchMode.externalApplication);
                              mixpanel.track("whatsapp_share_app");
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all()),
                              child: Center(
                                child: Icon(
                                  Iconsax.share_bold,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : null,
              bottomSheet: state.status == HomePageStatus.idle
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        border: Border.all(color: Colors.black54),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          state.account.username != ""
                              ? Container(
                                  //margin: const EdgeInsets.only(bottom: 12),
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 12, 0, 12),
                                  //height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Color(0xFF8A2BE2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        child: Row(
                                          children: [
                                            CircularAvatarWithShimmer(
                                                imageUrl: state.account
                                                        ?.profilePicUrl ??
                                                    ""),
                                            const SizedBox(width: 10),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 2 *
                                                          MediaQuery.of(context)
                                                              .size
                                                              .width /
                                                          3 -
                                                      40,
                                                  child: Text(
                                                    state.account?.username !=
                                                            null
                                                        ? utf8.decode(state
                                                            .account!
                                                            .fullname
                                                            .runes
                                                            .toList())
                                                        : "NA",
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        fontSize: 16),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  width: 2 *
                                                          MediaQuery.of(context)
                                                              .size
                                                              .width /
                                                          3 -
                                                      40,
                                                  child: Text(
                                                    state.account?.fullname !=
                                                            null
                                                        ? utf8.decode(state
                                                            .account!
                                                            .username
                                                            .runes
                                                            .toList())
                                                        : "NA",
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                          onPressed: () {
                                            mixpanel.track("change_collection");
                                            showDialog(
                                                context: context,
                                                builder: (context) => InfoPopup(
                                                      title: "Information",
                                                      message:
                                                          "We'll be adding more topics very soon! Until then, we'd love your feedback and help in spreading the word about this app",
                                                      action: "Okay",
                                                      popupColor:
                                                          Color(0xFF8A2BE2),
                                                      isInfo: true,
                                                      popupIcon: Icons.info,
                                                      actionFunc: () {
                                                        Navigator.pop(context);
                                                        mixpanel
                                                            .track("explored");
                                                      },
                                                      cancelText: "No",
                                                    ));
                                          },
                                          icon: Icon(
                                            Iconsax.edit_outline,
                                            size: 24,
                                            color: Colors.white,
                                          ))
                                    ],
                                  ),
                                )
                              : InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => AccountSearch(
                                          onSearch: context
                                              .read<HomeBloc>()
                                              .fetchInstagramAccounts,
                                          onConfirm: (ExtractedAccountInfo
                                              accountInfo) {
                                            Navigator.pop(context);
                                            context.read<HomeBloc>().add(
                                                  HomeAccountSelect(
                                                      accountInfo),
                                                );
                                          }),
                                    );
                                  },
                                  child: Container(
                                      width: MediaQuery.of(context).size.width,
                                      padding:
                                          EdgeInsets.fromLTRB(20, 20, 20, 20),
                                      decoration: BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                          border: Border.all(
                                              color: Colors.grey.shade300)),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Iconsax.add_circle_outline,
                                            size: 32,
                                            color: Colors.grey.shade500,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            "Add Creator Account",
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )),
                                ),
                          SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: taskTextController,
                                  decoration: InputDecoration(
                                    hintText: 'Ask me...',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                  ),
                                  maxLines: 3, // allow multiline input
                                  onChanged: (value) {
                                    if (value.length > 7) {
                                      setState(() {
                                        isTaskValid = true;
                                      });
                                    } else {
                                      setState(() {
                                        isTaskValid = false;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity(horizontal: -4),
                                onPressed: () {
                                  if (isTaskValid) {
                                    String taskText = taskTextController.text
                                        .replaceAll(RegExp(r'[^\w\s]'), '')
                                        .toLowerCase();

                                    context.read<HomeBloc>().add(
                                          HomeSearchVideos(taskText, 8,
                                              state.account.accountId),
                                        );
                                  }
                                },
                                icon: Container(
                                  margin: EdgeInsets.only(left: 0, bottom: 0),
                                  decoration: BoxDecoration(
                                    color: isTaskValid == true
                                        ? Color(0xFF8A2BE2)
                                        : Color(0xFFC99DF2),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.send,
                                    color: Color(0xFFDFFF00),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : null,
              extendBodyBehindAppBar: true,
              body: RefreshIndicator(
                onRefresh: () async {
                  context.read<HomeBloc>().add(HomeInitialUserData());
                },
                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(), // ensures pull works even if content is short
                  child: Container(
                    height: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                    child: VideoTaskmaster(
                      status: state.status,
                      totalVideos: state.searchResults.length,
                      onCancel: () {
                        context.read<HomeBloc>().add(
                              HomeCancelTaskGen(),
                            );
                        mixpanel.track("cancel_search");
                      },
                      onProfile: () {
                        context.read<HomeBloc>().add(
                              HomeNavOptionSelect(NavBarOption.profile),
                            );
                        mixpanel.track("profile_view");
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

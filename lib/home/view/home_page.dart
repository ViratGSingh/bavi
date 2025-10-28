import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:upgrader/upgrader.dart';
import 'package:bavi/dialogs/information.dart';
import 'package:bavi/dialogs/warning.dart';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/widgets/app_drawer.dart';
import 'package:bavi/home/widgets/reply.dart';
import 'package:bavi/home/widgets/search/video_search.dart';
import 'package:bavi/home/widgets/video_grid.dart';
import 'package:bavi/home/widgets/video_taskmaster.dart';
import 'package:bavi/models/question_answer.dart';
import 'package:bavi/models/session.dart';
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
import 'package:share_plus/share_plus.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:remixicon/remixicon.dart';
import 'dart:ui' as ui;

class HomePage extends StatefulWidget {
  final String? query;
  const HomePage({super.key, this.query});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // GlobalKey to identify the widget
  final GlobalKey _screnshotGlobalKey = GlobalKey();
  Future<void> _captureScreen(HomeState state) async {
    try {
      // Get the RenderRepaintBoundary
      RenderRepaintBoundary boundary = _screnshotGlobalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // Convert to image
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      // Convert image to bytes
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/screenshot.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      print("✅ Screenshot saved at $filePath");

      // Build the text and url for sharing
      final url = "https://drissea.com/session/${state.sessionId}";
      final actualIsSearchMode =
          state.isSearchMode && state.generalSearchResults.isEmpty
              ? false
              : state.isSearchMode == false && state.searchResults.isEmpty
                  ? true
                  : state.isSearchMode;
      final text = actualIsSearchMode
          ? "I used Drissea to search '${state.searchQuery}' and go through ${state.generalSearchResults.length} webpages. Here’s what it had to say 👇"
          : "I used Drissea to search '${state.searchQuery}' and watch ${state.searchResults.length} videos without watching. Here’s what it had to say 👇";
      // Share the screenshot with the text and url
      await Share.shareXFiles([XFile(filePath)], text: "$text\n$url");
      mixpanel
          .track("whatsapp_share_${actualIsSearchMode ? 'search' : 'session'}");
    } catch (e) {
      print("❌ Error capturing screenshot: $e");
    }
  }

  bool isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  String guestUsername = "";

  final FocusNode taskTextFieldFocusNode = FocusNode();
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initMixpanel();
    guestUsername = getRandomUsername();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    taskTextController.text = widget.query ?? "";
    if (taskTextController.text.length >= 3) {
      isTaskValid = true;
    }
    isExpanded = true;
    _animationController.forward(); // Expand Glance initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isAndroid) {
        InAppUpdate.checkForUpdate();
      }
      //FocusScope.of(context).requestFocus(taskTextFieldFocusNode);
    });
  }

  void _switchToGlance() {
    context.read<HomeBloc>().add(
          HomeSwitchSearchType("general"),
        );
    _animationController.reset();
    _animationController.forward();
  }

  void _switchToWatch() {
    context.read<HomeBloc>().add(
          HomeSwitchSearchType("social"),
        );
    _animationController.reset();
    _animationController.forward();
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

  String getRandomUsername() {
    const adjectives = ["Cool", "Fast", "Smart", "Happy", "Brave"];
    const nouns = ["Lion", "Tiger", "Eagle", "Shark", "Panda"];
    final random = DateTime.now().millisecondsSinceEpoch;
    final adj = adjectives[random % adjectives.length];
    final noun = nouns[random % nouns.length];
    return "$adj$noun".toLowerCase();
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
          canPop: true,
          child: SafeArea(
            child: UpgradeAlert(
              showPrompt: Platform.isAndroid ? false : true,
              child: Scaffold(
                drawer: ChatAppDrawer(
                  sessions: state.sessionHistory,
                  historyStatus: state.historyStatus,
                  onSessionTap: (SessionData session) {
                    mixpanel.track("user_tap_search");
                    Navigator.pop(context);
                    context.read<HomeBloc>().add(
                          HomeRetrieveSearchData(session),
                        );
                    //}
                  },
                  profilePicUrl: state.userData.profilePicUrl,
                  email: state.userData.email != "" ? state.userData.email : "",
                  fullname: state.userData.fullname != ""
                      ? state.userData.fullname
                      : 'Guest',
                  onLogin: () {
                    mixpanel.track("user_tap_login");
                    Navigator.pop(context);
                    context.read<HomeBloc>().add(
                          HomeAttemptGoogleSignIn(),
                        );
                  },
                ),
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
                appBar: AppBar(
                  titleSpacing: 0,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  leadingWidth: 40,
                  centerTitle: state.status==HomePageStatus.idle?true:false,
                  leading: Builder(
                      builder: (context) => Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: InkWell(
                              onTap: () => Scaffold.of(context).openDrawer(),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: Color(0xFFDFFF00),
                                    shape: BoxShape.circle,
                                    border: Border.all()),
                                padding: EdgeInsets.fromLTRB(1, 0, 2, 0),
                                child: Center(
                                  child: Icon(
                                    Icons.history,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          )),
                          
                  title: Padding(
                    padding:  EdgeInsets.only(left: state.status==HomePageStatus.idle?0:10),
                    child: InkWell(
                      onTap: () async {
                        // context.read<HomeBloc>().add(
                        //       HomeCancelTaskGen(),
                        //     );
                        // taskTextController.clear();
                        // setState(() {
                        //   isTaskValid = false;
                        // });
                        // mixpanel.track("close_search");
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Drissea',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontFamily: 'Jua',
                              fontWeight: FontWeight.w500,
                            ),
                            textHeightBehavior: TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                          ),
                          Visibility(
                            visible: state.isIncognito &&state.status!=HomePageStatus.idle,
                            child: Text(
                              'Incognito Search',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                              textHeightBehavior: TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                            ),
                          ),
                          Visibility(
                            visible:
                                false, // state.status != HomePageStatus.idle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                width: 28,
                                height: 28,
                                child: Center(
                                  child: Icon(
                                    Iconsax.edit_outline,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // InkWell(
                  //   onTap: () async {

                  //                   context.read<HomeBloc>().add(
                  //                         HomeAttemptGoogleSignIn(),
                  //                       );
                  //                   mixpanel.track("sign_in");
                  //     // context.read<HomeBloc>().add(
                  //     //       HomeCancelTaskGen(),
                  //     //     );
                  //     // mixpanel.track("close_search");
                  //   },
                  //   child: Row(
                  //     mainAxisSize: MainAxisSize.min,
                  //     children: [
                  //       state.replyStatus == HomeReplyStatus.loading
                  //           ? SizedBox(
                  //               width: 32,
                  //               height: 32,
                  //               child: Stack(
                  //                 alignment: Alignment.center,
                  //                 children: [
                  //                   ClipRRect(
                  //                     borderRadius: BorderRadius.circular(40),
                  //                     child: Container(
                  //                       width: 32,
                  //                       height: 32,
                  //                       decoration: BoxDecoration(
                  //                           borderRadius:
                  //                               BorderRadius.circular(40),
                  //                           color: Color(0xFF8A2BE2)),
                  //                       child: Image.asset(
                  //                         "assets/images/logo/icon.png",
                  //                         fit: BoxFit.cover,
                  //                       ),
                  //                     ),
                  //                   ),
                  //                   Container(
                  //                     width: 32,
                  //                     height: 32,
                  //                     decoration: BoxDecoration(
                  //                       borderRadius: BorderRadius.circular(40),
                  //                     ),
                  //                     child: CircularProgressIndicator(
                  //                       color: Color(0xFFDFFF00),
                  //                     ),
                  //                   ),
                  //                 ],
                  //               ),
                  //             )
                  //           : Padding(
                  //               padding: const EdgeInsets.only(right: 5),
                  //               child: InkWell(
                  //                 onTap: () {
                  //                   context.read<HomeBloc>().add(
                  //                         HomeAttemptGoogleSignIn(),
                  //                       );
                  //                   mixpanel.track("sign_in");
                  //                 },
                  //                 child: CircularAvatarWithShimmer(
                  //                     imageUrl: state.userData.profilePicUrl),
                  //               ),
                  //             ),

                  //       // Column(
                  //       //   crossAxisAlignment: CrossAxisAlignment.start,
                  //       //   children: [
                  //       //     Text(
                  //       //       state.userData.fullname!=""?state.userData.fullname:'Guest',
                  //       //       style: TextStyle(
                  //       //         color: Colors.black,
                  //       //         fontSize: 14,
                  //       //         fontFamily: 'Poppins',
                  //       //         fontWeight: FontWeight.w600,
                  //       //       ),
                  //       //     ),
                  //       //     Text(
                  //       //       state.userData.username != "" ? state.userData.email.split("@").first : state.userData.email.split("@").first,
                  //       //       style: TextStyle(
                  //       //         color: Colors.black,
                  //       //         fontSize: 12,
                  //       //         fontFamily: 'Poppins',
                  //       //         fontWeight: FontWeight.w400,
                  //       //       ),
                  //       //     ),
                  //       //     // Text(
                  //       //     //   'Drissea',
                  //       //     //   style: TextStyle(
                  //       //     //     color: Colors.black,
                  //       //     //     fontSize: 32,
                  //       //     //     fontFamily: 'Jua',
                  //       //     //     fontWeight: FontWeight.w500,
                  //       //     //   ),
                  //       //     // ),
                  //       //   ],
                  //       // ),
                  //       // Visibility(
                  //       //   visible: false,//state.status != HomePageStatus.idle,
                  //       //   child: Padding(
                  //       //     padding: const EdgeInsets.only(left: 6),
                  //       //     child: Container(
                  //       //       width: 28,
                  //       //       height: 28,
                  //       //       child: Center(
                  //       //         child: Icon(
                  //       //           Iconsax.edit_outline,
                  //       //           color: Colors.black,
                  //       //           size: 20,
                  //       //         ),
                  //       //       ),
                  //       //     ),
                  //       //   ),
                  //       // ),
                  //     ],
                  //   ),
                  // ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: state.status==HomePageStatus.idle?InkWell(
                        onTap: () async {
                          context.read<HomeBloc>().add(
                                HomeSwitchPrivacyType(
                                    state.isIncognito == true ? false : true),
                              );
                          mixpanel.track(state.isIncognito == true
                              ? "set_incognito_mode"
                              : "set_normal_mode");
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Color(0xFFDFFF00),
                              border: Border.all()),
                          child: Center(
                            child: state.isIncognito == false
                                ? Icon(
                                    RemixIcons.eye_line,
                                    color: Colors.black,
                                    size: 20,
                                  )
                                : Icon(
                                    RemixIcons.eye_close_line,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ):
                      InkWell(
                        onTap: () async {
                        context.read<HomeBloc>().add(
                              HomeCancelTaskGen(),
                            );
                        taskTextController.clear();
                        setState(() {
                          isTaskValid = false;
                        });
                        mixpanel.track("edit_search");
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Color(0xFFDFFF00),
                              border: Border.all()),
                          child: Center(
                            child: Icon(
                                    Iconsax.edit_outline,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                          ),
                        ),
                      )
                      ,
                    ),
                  ],
                ),
                bottomSheet: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    border: Border.all(color: Color(0xFFB3B4B9)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: taskTextController,
                              focusNode: taskTextFieldFocusNode,
                              decoration: InputDecoration(
                                hintText:
                                    state.status == HomePageStatus.success
                                        ? "Ask follow-up"
                                        :
                                    'Ask anything',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              maxLines: 3, // allow multiline input
                              autofocus: false,
                              onTap: () {
                                FocusScope.of(context).unfocus();
                              },
                              onChanged: (value) {
                                if (value.length >= 3) {
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (state.isSearchMode) {
                                        context.read<HomeBloc>().add(
                                              HomeSwitchSearchType("social"),
                                            );
                                        _animationController.reset();
                                        _animationController.forward();
                                      }
                                    },
                                    child: AnimatedSize(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            minWidth:
                                                35), // ensures a minimum width
                                        child: Container(
                                          height: 36,
                                          padding: EdgeInsets.symmetric(
                                            horizontal:
                                                !state.isSearchMode ? 10 : 0,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !state.isSearchMode
                                                ? const Color(0xFFF4EBFF)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(40),
                                            border: Border.all(
                                                color: Colors.purple),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize
                                                .min, // <-- shrink-wrap tightly around content
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                  RemixIcons.search_eye_line,
                                                  color: Colors.purple,
                                                  size: 16),
                                              if (!state.isSearchMode)
                                                SizeTransition(
                                                  sizeFactor: _animation,
                                                  axis: Axis.horizontal,
                                                  axisAlignment: -1,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 3),
                                                    child: Text(
                                                      'Social',
                                                      overflow:
                                                          TextOverflow.clip,
                                                      style: const TextStyle(
                                                        color: Colors.purple,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      if (!state.isSearchMode) {
                                        context.read<HomeBloc>().add(
                                              HomeSwitchSearchType("general"),
                                            );
                                        _animationController.reset();
                                        _animationController.forward();
                                      }
                                    },
                                    child: AnimatedSize(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(minWidth: 35),
                                        child: Container(
                                          height: 36,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: state.isSearchMode ? 10 : 0,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: state.isSearchMode ? const Color(0xFFF4EBFF) : Colors.white,
                                            borderRadius: BorderRadius.circular(28),
                                            border: Border.all(color: Colors.purple),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Iconsax.global_search_outline,
                                                  color: Colors.purple, size: 16),
                                              if (state.isSearchMode)
                                                SizeTransition(
                                                  sizeFactor: _animation,
                                                  axis: Axis.horizontal,
                                                  axisAlignment: -1,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 3),
                                                    child: Text(
                                                      'Web',
                                                      overflow: TextOverflow.clip,
                                                      style: const TextStyle(
                                                        color: Colors.purple,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          Row(
                            children: [
                              state.status != HomePageStatus.success
                                  ? Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: InkWell(
                                        onTap: () async {
                                          final url = Uri.encodeComponent(Platform
                                                  .isIOS
                                              ? "https://apps.apple.com/us/app/drissea/id6743215602"
                                              : "https://play.google.com/store/apps/details?id=com.wooshir.bavi");
                                          final text = Uri.encodeComponent(
                                              "Found this super helpful app called Drissea for learning what people online think about anything. Try it out!");
                                          final shareLink =
                                              "https://wa.me/?text=$text%20$url";

                                          await launchUrl(Uri.parse(shareLink),
                                              mode: LaunchMode
                                                  .externalApplication);
                                          mixpanel.track("whatsapp_share_app");
                                        },
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            color: Colors.green,
                                            //border: Border.all()
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Iconsax.whatsapp_outline,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ))
                                  : Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: InkWell(
                                        onTap: () async {
                                          context.read<HomeBloc>().add(
                                                HomeGenScreenshot(
                                                    _screnshotGlobalKey),
                                              );
                                        },
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              color: Color(0xFFDFFF00),
                                              border: Border.all()),
                                          child: Center(
                                            child: Icon(
                                              Iconsax.send_2_bold,
                                              color: Colors.black,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              state.status == HomePageStatus.idle ||
                                      state.status == HomePageStatus.success
                                  ? IconButton(
                                      padding: EdgeInsets.zero,
                                      visualDensity:
                                          VisualDensity(horizontal: -4),
                                      onPressed: () {
                                        FocusScope.of(context).unfocus();
                                        if (isTaskValid) {
                                          String taskText =
                                              taskTextController.text;
                                          // .replaceAll(RegExp(r'[^\w\s]'), '')
                                          // .toLowerCase();
                                          if (state.isSearchMode == true) {
                                            // if (state.status ==
                                            //     HomePageStatus.success) {
                                            //   taskTextController.text = "";
                                            //   context.read<HomeBloc>().add(
                                            //         HomeFollowUpRecallVideos(
                                            //             taskText),
                                            //       );
                                            // } else {
                                            taskTextController.text = "";
                                            context.read<HomeBloc>().add(
                                                  HomeWatchSearchResults(
                                                      taskText),
                                                );
                                            //}
                                          } else {
                                            // if (state.status ==
                                            //     HomePageStatus.success) {
                                            //   taskTextController.text = "";
                                            //   context.read<HomeBloc>().add(
                                            //         HomeFollowUpSearchVideos(
                                            //             taskText),
                                            //       );
                                            // } else {
                                            taskTextController.text = "";
                                            context.read<HomeBloc>().add(
                                                  HomeWatchSearchVideos(
                                                      taskText, ""),
                                                );
                                            //}
                                          }
                                        }
                                      },
                                      icon: Container(
                                        margin:
                                            EdgeInsets.only(left: 0, bottom: 0),
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
                                    )
                                  : IconButton(
                                      padding: EdgeInsets.zero,
                                      visualDensity:
                                          VisualDensity(horizontal: -4),
                                      onPressed: () {
                                        FocusScope.of(context).unfocus();
                                        context.read<HomeBloc>().add(
                                              HomeCancelTaskGen(),
                                            );
                                        mixpanel.track("cancel_search");
                                      },
                                      icon: Container(
                                        margin:
                                            EdgeInsets.only(left: 0, bottom: 0),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF8A2BE2),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: EdgeInsets.all(10),
                                        child: Icon(
                                          Icons.stop,
                                          color: Color(0xFFDFFF00),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                extendBodyBehindAppBar:
                    state.status == HomePageStatus.idle ? true : false,
                body: RefreshIndicator(
                  onRefresh: () async {
                    //context.read<HomeBloc>().add(HomeInitialUserData());
                    if (state.isSearchMode == false) {
                      context.read<HomeBloc>().add(
                            HomeWatchSearchVideos(state.userQuery, ""),
                          );
                    } else {
                      context.read<HomeBloc>().add(
                            HomeWatchSearchResults(state.userQuery),
                          );
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                    },
                    child: RepaintBoundary(
                      key: _screnshotGlobalKey,
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.white,
                            height: MediaQuery.of(context).size.height -
                                MediaQuery.of(context).padding.top -
                                MediaQuery.of(context).padding.bottom,
                            child: VideoTaskmaster(
                              query: state.userQuery,
                              isIncognito: state.isIncognito,
                              savedStatus: state.savedStatus,
                              followUpAnswers: state.followupAnswers,
                              followUpQuestions: state.followupQuestions,
                              status: state.status,
                              replyStatus: state.replyStatus,
                              task: state.isSearchMode ? "search" : "watch",
                              isSearchMode:
                                  //Tapped to retrieve search data
                                  state.isSearchMode &&
                                          state.generalSearchResults.isEmpty &&
                                          state.searchResults.isEmpty
                                      ? true
                                      : state.isSearchMode == false &&
                                              state.generalSearchResults
                                                  .isEmpty &&
                                              state.searchResults.isEmpty
                                          ? false
                                          :
                                          //Tapped to general mode but hasn't done yet
                                          state.isSearchMode &&
                                                  state.generalSearchResults
                                                      .isEmpty
                                              ? false
                                              :

                                              //Tapped to social mode but hasn't done yet
                                              state.isSearchMode == false &&
                                                      state
                                                          .searchResults.isEmpty
                                                  ? true
                                                  : state.isSearchMode,
                              totalVideos: state.videosCount,
                              videos: state.searchResults,
                              searchResults: state.generalSearchResults,
                              shortVideos: state.shortVideoResults,
                              longVideos: state.videoResults,
                              totalContentDuration: state.totalContentDuration,
                              answer: state.searchAnswer,
                              onRefresh: () {
                                context.read<HomeBloc>().add(
                                      HomeRefreshReply(
                                          //Tapped to retrieve search data
                                          state.isSearchMode &&
                                                  state.generalSearchResults
                                                      .isEmpty &&
                                                  state.searchResults.isEmpty
                                              ? true
                                              : state.isSearchMode == false &&
                                                      state.generalSearchResults
                                                          .isEmpty &&
                                                      state
                                                          .searchResults.isEmpty
                                                  ? false
                                                  :
                                                  //Tapped to general mode but hasn't done yet
                                                  state.isSearchMode &&
                                                          state
                                                              .generalSearchResults
                                                              .isEmpty
                                                      ? false
                                                      :

                                                      //Tapped to social mode but hasn't done yet
                                                      state.isSearchMode ==
                                                                  false &&
                                                              state
                                                                  .searchResults
                                                                  .isEmpty
                                                          ? true
                                                          : state.isSearchMode),
                                    );
                                mixpanel.track("refresh_reply");
                              },
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
                        ],
                      ),
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

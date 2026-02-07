import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:app_links/app_links.dart';
import 'package:bavi/answer/view/answer_page.dart';
import 'package:bavi/chat/view/chat_page.dart';
import 'package:bavi/home/widgets/answers_view.dart';
import 'package:bavi/home/widgets/search_view.dart';
import 'package:bavi/home/widgets/sources_bottom_sheet.dart';
import 'package:bavi/home/widgets/offline_chat_bottom_sheet.dart';
import 'package:bavi/home/widgets/download_overlay.dart';
import 'package:bavi/home/widgets/location_permission_sheet.dart';
import 'package:bavi/home/widgets/tabs_view.dart';
import 'package:bavi/home/widgets/web_view.dart';
import 'package:bavi/memory/bloc/memory_bloc.dart';
import 'package:bavi/memory/view/memory_page.dart';
import 'package:bavi/models/thread.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  StreamSubscription<Uri>? _linkSubscription;
  final ValueNotifier<String> streamedText = ValueNotifier("");

  Future<void> initDeepLinks() async {
    // Handle links
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      print("");
      print('Got appLink: $uri');
      print("");
      openAppLink(uri);
    });
  }

  void openAppLink(Uri uri) {
    //_navigatorKey.currentState?.pushNamed(uri.fragment);
  }
  // GlobalKey to identify the widget
  final GlobalKey _screnshotGlobalKey = GlobalKey();
  // Future<void> _captureScreen(HomeState state) async {
  //   try {
  //     // Get the RenderRepaintBoundary
  //     RenderRepaintBoundary boundary = _screnshotGlobalKey.currentContext!
  //         .findRenderObject() as RenderRepaintBoundary;

  //     // Convert to image
  //     ui.Image image = await boundary.toImage(pixelRatio: 3.0);

  //     // Convert image to bytes
  //     ByteData? byteData =
  //         await image.toByteData(format: ui.ImageByteFormat.png);
  //     Uint8List pngBytes = byteData!.buffer.asUint8List();

  //     // Save to file
  //     final directory = await getApplicationDocumentsDirectory();
  //     final filePath = '${directory.path}/screenshot.png';
  //     final file = File(filePath);
  //     await file.writeAsBytes(pngBytes);

  //     print("✅ Screenshot saved at $filePath");

  //     // Build the text and url for sharing
  //     final url = "https://drissea.com/session/${state.sessionId}";
  //     final actualIsSearchMode =
  //         state.isSearchMode && state.generalSearchResults.isEmpty
  //             ? false
  //             : state.isSearchMode == false && state.searchResults.isEmpty
  //                 ? true
  //                 : state.isSearchMode;
  //     final text = actualIsSearchMode
  //         ? "I used Drissea to search '${state.searchQuery}' and go through ${state.generalSearchResults.length} webpages. Here’s what it had to say 👇"
  //         : "I used Drissea to search '${state.searchQuery}' and watch ${state.searchResults.length} videos without watching. Here’s what it had to say 👇";
  //     // Share the screenshot with the text and url
  //     await Share.shareXFiles([XFile(filePath)], text: "$text\n$url");
  //     mixpanel
  //         .track("whatsapp_share_${actualIsSearchMode ? 'search' : 'session'}");
  //   } catch (e) {
  //     print("❌ Error capturing screenshot: $e");
  //   }
  // }

  bool isExpanded = false;
  bool isChatModeActive = false; // Tracks if chat mode button is toggled
  late AnimationController _animationController;
  late Animation<double> _animation;
  String guestUsername = "";
  ValueNotifier<String> imageDescriptionNotifier = ValueNotifier<String>("");

  ValueNotifier<String> extractedUrlDescription = ValueNotifier<String>("");
  ValueNotifier<String> extractedUrlTitle = ValueNotifier<String>("");
  ValueNotifier<String> extractedUrl = ValueNotifier<String>("");
  ValueNotifier<String> extractedImageUrl = ValueNotifier<String>("");

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
    _linkSubscription?.cancel();
    streamedText.removeListener(_scrollToBottom);
    streamedText.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
    initDeepLinks();
    // Add listener to auto-scroll when streaming text updates
    streamedText.addListener(_scrollToBottom);
  }

  final ScrollController _scrollController = ScrollController();

  late Mixpanel mixpanel;
  TextEditingController taskTextController = TextEditingController();
  bool isTaskValid = false;
  bool isUrl = false;
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
      child: BlocListener<HomeBloc, HomeState>(
        listenWhen: (previous, current) =>
            previous.showLocationRationale != current.showLocationRationale &&
            current.showLocationRationale == true,
        listener: (context, state) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (bottomSheetContext) => BlocProvider.value(
              value: context.read<HomeBloc>(),
              child: const LocationPermissionSheet(),
            ),
          );
        },
        child: BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
          return PopScope(
            canPop: true,
            child: SafeArea(
              child: Stack(
                children: [
                  UpgradeAlert(
                    showPrompt: Platform.isAndroid ? false : true,
                    child: Scaffold(
                      backgroundColor: Colors.white,
                      drawerEdgeDragWidth:
                          MediaQuery.of(context).size.width * 0.25,
                      drawer: Drawer(
                        width: MediaQuery.of(context).size.width * 0.85,
                        backgroundColor: Colors.white,
                        child: HistoryPage(
                          sessions: state.threadHistory,
                          historyStatus: state.historyStatus,
                          onNewThread: () {
                            mixpanel.track("start_new_thread");
                            context.read<HomeBloc>().add(
                                  HomeStartNewThread(),
                                );
                            taskTextController.clear();
                            setState(() {
                              isTaskValid = false;
                            });
                            Navigator.pop(context);
                          },
                          onSessionTap: (ThreadSessionData session) {
                            mixpanel.track("user_tap_thread");
                            Navigator.pop(context);
                            context.read<HomeBloc>().add(
                                  HomeRetrieveSearchData(session),
                                );
                            Future.delayed(const Duration(milliseconds: 300))
                                .then((onValue) {
                              _scrollController.animateTo(
                                  _scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut);
                            });
                          },
                        ),
                      ),

                      appBar: AppBar(
                        titleSpacing: 0,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        leadingWidth: 40,
                        elevation: state.status == HomePageStatus.idle ? 0 : 4,
                        shadowColor: state.status == HomePageStatus.idle
                            ? Colors.transparent
                            : Colors.black.withOpacity(0.2),
                        centerTitle: false,
                        //state.status == HomePageStatus.idle ? true : false,
                        leading: Padding(
                          padding: const EdgeInsets.only(left: 0),
                          child: InkWell(
                            onTap: () async {
                              // Unfocus any text field and close keyboard completely
                              FocusManager.instance.primaryFocus?.unfocus();

                              // Wait a short moment to ensure keyboard is dismissed
                              await Future.delayed(
                                  const Duration(milliseconds: 100));

                              // Navigate to History page with slide from left transition
                              final homeBloc = context.read<HomeBloc>();
                              Navigator.push(
                                context,
                                SlideFromLeftRoute(
                                  page: BlocProvider.value(
                                    value: homeBloc,
                                    child: BlocBuilder<HomeBloc, HomeState>(
                                      builder: (context, state) {
                                        return HistoryPage(
                                          sessions: state.threadHistory,
                                          historyStatus: state.historyStatus,
                                          onNewThread: () {
                                            mixpanel.track("start_new_thread");
                                            context.read<HomeBloc>().add(
                                                  HomeStartNewThread(),
                                                );
                                            taskTextController.clear();
                                            setState(() {
                                              isTaskValid = false;
                                            });
                                          },
                                          onSessionTap:
                                              (ThreadSessionData session) {
                                            mixpanel.track("user_tap_thread");
                                            Navigator.pop(context);
                                            context.read<HomeBloc>().add(
                                                  HomeRetrieveSearchData(
                                                      session),
                                                );
                                            Future.delayed(const Duration(
                                                    milliseconds: 300))
                                                .then((onValue) {
                                              _scrollController.animateTo(
                                                  _scrollController
                                                      .position.maxScrollExtent,
                                                  duration: const Duration(
                                                      milliseconds: 300),
                                                  curve: Curves.easeOut);
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.fromLTRB(1, 0, 2, 0),
                              child: const Center(
                                child: Icon(
                                  Iconsax.menu_1_outline,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Padding(
                          padding: EdgeInsets.only(
                              left:
                                  state.status == HomePageStatus.idle ? 0 : 5),
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                state.status == HomePageStatus.idle
                                    ? Text(
                                        '',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 24,
                                          fontFamily: 'BagelFatOne',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    : Text(
                                        'Thread',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textHeightBehavior: TextHeightBehavior(
                                          applyHeightToFirstAscent: false,
                                          applyHeightToLastDescent: false,
                                        ),
                                      ),
                                Visibility(
                                  visible: state.isIncognito &&
                                      state.status != HomePageStatus.idle,
                                  child: Text(
                                    'Incognito Mode',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
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
                              padding: const EdgeInsets.only(right: 6),
                              child: state.status != HomePageStatus.idle
                                  ? InkWell(
                                      onTap: () async {
                                        context.read<HomeBloc>().add(
                                              HomeStartNewThread(),
                                            );
                                        taskTextController.clear();
                                        setState(() {
                                          isTaskValid = false;
                                        });
                                        mixpanel.track("start_new_thread");
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                            // borderRadius: BorderRadius.circular(18),
                                            // color: Color(0xFFDFFF00),
                                            // border: Border.all()
                                            ),
                                        child: Center(
                                          child: Icon(
                                            Iconsax.edit_outline,
                                            color: Colors.black,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    )
                                  : InkWell(
                                      onTap: () async {
                                        Navigator.push(
                                          context,
                                          SlideFromRightRoute(
                                            page: BlocProvider(
                                              create: (context) => MemoryBloc(),
                                              child: const MemoryPage(),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                            // borderRadius: BorderRadius.circular(18),
                                            // color: Color(0xFFDFFF00),
                                            // border: Border.all()
                                            ),
                                        child: Center(
                                          child: Icon(
                                            Iconsax.note_2_outline,
                                            color: Colors.black,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    )),
                          Visibility(
                            visible: state.status != HomePageStatus.idle,
                            child: Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () async {
                                    final String url =
                                        "https://drissea.com/thread/${state.threadData.id}";
                                    await Clipboard.setData(
                                        ClipboardData(text: url));
                                    if (context.mounted) {
                                      // _showSnackBar(
                                      //     context, "Link copied to clipboard");
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor: Color(
                                              0xFF8A2BE2), // Purple background
                                          content: Text(
                                            'Copied to clipboard',
                                            style: TextStyle(
                                              color: Color(
                                                  0xFFDFFF00), // Neon green text
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                    mixpanel.track("share_thread");
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                        // borderRadius: BorderRadius.circular(18),
                                        // color: Color(0xFFDFFF00),
                                        // border: Border.all()
                                        ),
                                    child: Center(
                                      child: Icon(
                                        Iconsax.send_2_outline,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                )),
                          ),
                        ],
                      ),
                      // bottomSheet: Container(
                      //   padding:
                      //       const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      //   decoration: BoxDecoration(
                      //     color: Colors.white,
                      //     borderRadius: BorderRadius.vertical(
                      //       top: Radius.circular(16),
                      //     ),
                      //     border: Border.all(color: Color(0xFFB3B4B9)),
                      //   ),
                      //   child: Column(
                      //     mainAxisSize: MainAxisSize.min,
                      //     children: [
                      //       Row(
                      //         crossAxisAlignment: CrossAxisAlignment.start,
                      //         children: [
                      //           Expanded(
                      //             child: TextField(
                      //               controller: taskTextController,
                      //               focusNode: taskTextFieldFocusNode,
                      //               style: TextStyle(
                      //                 color: isUrl ? Colors.purple : Colors.black,
                      //               ),
                      //               decoration: InputDecoration(
                      //                 hintText: state.isSearchMode
                      //                     ? "Search or type url"
                      //                     : 'Ask or type url',
                      //                 hintStyle: TextStyle(color: Colors.grey),
                      //                 border: InputBorder.none,
                      //               ),
                      //               maxLines: 3, // allow multiline input
                      //               autofocus: false,
                      //               onTap: () {
                      //                 FocusScope.of(context).unfocus();
                      //               },
                      //               onChanged: (value) {
                      //                 bool valueIsUrl = false;
                      //                 //Check if text entered is url or not
                      //                 List<String> values = value.trim().split(" ");
                      //                 String formattedValue = values.first;
                      //                 if(
                      //                   (values.length==1 && formattedValue.contains(".") && formattedValue.length>=4)||
                      //                   (values.length==1 && formattedValue.contains("http") && formattedValue.contains("://"))
                      //                 ){
                      //                   if(formattedValue.contains("https")==false&&formattedValue.contains("http")==false){
                      //                     formattedValue = "https://${formattedValue}";
                      //                   }
                      //                   valueIsUrl = true;
                      //                 }

                      //                 //Check if text valide or not
                      //                 if (value.length >= 3) {
                      //                   setState(() {
                      //                     isTaskValid = true;
                      //                     isUrl = valueIsUrl;
                      //                   });
                      //                 } else {
                      //                   setState(() {
                      //                     isTaskValid = false;
                      //                     isUrl = valueIsUrl;
                      //                   });
                      //                 }
                      //               },
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //       Row(
                      //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //         children: [
                      //           AnimatedBuilder(
                      //             animation: _animation,
                      //             builder: (context, child) {
                      //               return Row(
                      //                 children: [
                      //                   GestureDetector(
                      //                     onTap: () {
                      //                       if (!state.isSearchMode) {
                      //                         context.read<HomeBloc>().add(
                      //                               HomeSwitchType(false),
                      //                             );
                      //                         _animationController.reset();
                      //                         _animationController.forward();
                      //                       }
                      //                     },
                      //                     child: AnimatedSize(
                      //                       duration:
                      //                           const Duration(milliseconds: 300),
                      //                       curve: Curves.easeInOut,
                      //                       child: ConstrainedBox(
                      //                         constraints: const BoxConstraints(
                      //                             minWidth:
                      //                                 35), // ensures a minimum width
                      //                         child: Container(
                      //                           height: 36,
                      //                           padding: EdgeInsets.symmetric(
                      //                             horizontal:
                      //                                 state.isSearchMode ? 10 : 0,
                      //                             vertical: 8,
                      //                           ),
                      //                           decoration: BoxDecoration(
                      //                             color: state.isSearchMode
                      //                                 ? const Color(0xFFF4EBFF)
                      //                                 : Colors.white,
                      //                             borderRadius:
                      //                                 BorderRadius.circular(40),
                      //                             border: Border.all(
                      //                                 color: Colors.purple),
                      //                           ),
                      //                           child: Row(
                      //                             mainAxisSize: MainAxisSize
                      //                                 .min, // <-- shrink-wrap tightly around content
                      //                             mainAxisAlignment:
                      //                                 MainAxisAlignment.center,
                      //                             children: [
                      //                               const Icon(
                      //                                   Iconsax
                      //                                       .search_normal_1_outline,
                      //                                   color: Colors.purple,
                      //                                   size: 16),
                      //                               if (state.isSearchMode)
                      //                                 SizeTransition(
                      //                                   sizeFactor: _animation,
                      //                                   axis: Axis.horizontal,
                      //                                   axisAlignment: -1,
                      //                                   child: Padding(
                      //                                     padding:
                      //                                         const EdgeInsets.only(
                      //                                             left: 3),
                      //                                     child: Text(
                      //                                       'Search',
                      //                                       overflow:
                      //                                           TextOverflow.clip,
                      //                                       style: const TextStyle(
                      //                                         color: Colors.purple,
                      //                                         fontWeight:
                      //                                             FontWeight.bold,
                      //                                       ),
                      //                                     ),
                      //                                   ),
                      //                                 ),
                      //                             ],
                      //                           ),
                      //                         ),
                      //                       ),
                      //                     ),
                      //                   ),
                      //                   SizedBox(width: 12),
                      //                   GestureDetector(
                      //                     onTap: () {
                      //                       if (state.isSearchMode) {
                      //                         context.read<HomeBloc>().add(
                      //                               HomeSwitchType(true),
                      //                             );
                      //                         _animationController.reset();
                      //                         _animationController.forward();
                      //                       }
                      //                     },
                      //                     child: AnimatedSize(
                      //                       duration:
                      //                           const Duration(milliseconds: 300),
                      //                       curve: Curves.easeInOut,
                      //                       child: ConstrainedBox(
                      //                         constraints:
                      //                             const BoxConstraints(minWidth: 35),
                      //                         child: Container(
                      //                           height: 36,
                      //                           padding: EdgeInsets.symmetric(
                      //                             horizontal:
                      //                                 !state.isSearchMode ? 10 : 0,
                      //                             vertical: 8,
                      //                           ),
                      //                           decoration: BoxDecoration(
                      //                             color: !state.isSearchMode
                      //                                 ? const Color(0xFFF4EBFF)
                      //                                 : Colors.white,
                      //                             borderRadius:
                      //                                 BorderRadius.circular(28),
                      //                             border: Border.all(
                      //                                 color: Colors.purple),
                      //                           ),
                      //                           child: Row(
                      //                             mainAxisSize: MainAxisSize.min,
                      //                             mainAxisAlignment:
                      //                                 MainAxisAlignment.center,
                      //                             children: [
                      //                               const Icon(
                      //                                   Iconsax.magicpen_outline,
                      //                                   color: Colors.purple,
                      //                                   size: 16),
                      //                               if (!state.isSearchMode)
                      //                                 SizeTransition(
                      //                                   sizeFactor: _animation,
                      //                                   axis: Axis.horizontal,
                      //                                   axisAlignment: -1,
                      //                                   child: Padding(
                      //                                     padding:
                      //                                         const EdgeInsets.only(
                      //                                             left: 3),
                      //                                     child: Text(
                      //                                       'Answer',
                      //                                       overflow:
                      //                                           TextOverflow.clip,
                      //                                       style: const TextStyle(
                      //                                         color: Colors.purple,
                      //                                         fontWeight:
                      //                                             FontWeight.bold,
                      //                                       ),
                      //                                     ),
                      //                                   ),
                      //                                 ),
                      //                             ],
                      //                           ),
                      //                         ),
                      //                       ),
                      //                     ),
                      //                   ),
                      //                 ],
                      //               );
                      //             },
                      //           ),
                      //           Row(
                      //             children: [
                      //               Padding(
                      //                   padding: const EdgeInsets.only(right: 12),
                      //                   child: InkWell(
                      //                     onTap: () async {
                      //                       Navigator.push(
                      //                         context,
                      //                         MaterialPageRoute<void>(
                      //                           builder: (BuildContext context) =>
                      //                               TabsViewPage(),
                      //                         ),
                      //                       );
                      //                       // final url = Uri.encodeComponent(Platform
                      //                       //         .isIOS
                      //                       //     ? "https://apps.apple.com/us/app/drissea/id6743215602"
                      //                       //     : "https://play.google.com/store/apps/details?id=com.wooshir.bavi");
                      //                       // final text = Uri.encodeComponent(
                      //                       //     "Found this super helpful app called Drissea for learning what people online think about anything. Try it out!");
                      //                       // final shareLink =
                      //                       //     "https://wa.me/?text=$text%20$url";

                      //                       // await launchUrl(Uri.parse(shareLink),
                      //                       //     mode: LaunchMode
                      //                       //         .externalApplication);
                      //                       // mixpanel.track("whatsapp_share_app");
                      //                     },
                      //                     child: Container(
                      //                       width: 36,
                      //                       height: 36,
                      //                       decoration: BoxDecoration(
                      //                         borderRadius: BorderRadius.circular(18),
                      //                         color: Color(
                      //                             0xFF8A2BE2), //Color(0xFFDFFF00),
                      //                         //border: Border.all()
                      //                       ),
                      //                       child: Center(
                      //                         child: Icon(
                      //                           Iconsax.note_2_bold,
                      //                           color: Color(0xFFDFFF00),
                      //                           size: 20,
                      //                         ),
                      //                       ),
                      //                     ),
                      //                   )),
                      //               // state.status != HomePageStatus.success
                      //               //     ? Padding(
                      //               //         padding: const EdgeInsets.only(right: 12),
                      //               //         child: InkWell(
                      //               //           onTap: () async {
                      //               //             final url = Uri.encodeComponent(Platform
                      //               //                     .isIOS
                      //               //                 ? "https://apps.apple.com/us/app/drissea/id6743215602"
                      //               //                 : "https://play.google.com/store/apps/details?id=com.wooshir.bavi");
                      //               //             final text = Uri.encodeComponent(
                      //               //                 "Found this super helpful app called Drissea for learning what people online think about anything. Try it out!");
                      //               //             final shareLink =
                      //               //                 "https://wa.me/?text=$text%20$url";

                      //               //             await launchUrl(Uri.parse(shareLink),
                      //               //                 mode: LaunchMode
                      //               //                     .externalApplication);
                      //               //             mixpanel.track("whatsapp_share_app");
                      //               //           },
                      //               //           child: Container(
                      //               //             width: 36,
                      //               //             height: 36,
                      //               //             decoration: BoxDecoration(
                      //               //               borderRadius:
                      //               //                   BorderRadius.circular(18),
                      //               //               color: Colors.green,
                      //               //               //border: Border.all()
                      //               //             ),
                      //               //             child: Center(
                      //               //               child: Icon(
                      //               //                 Iconsax.whatsapp_outline,
                      //               //                 color: Colors.white,
                      //               //                 size: 20,
                      //               //               ),
                      //               //             ),
                      //               //           ),
                      //               //         ))
                      //               //     : Padding(
                      //               //         padding: const EdgeInsets.only(right: 12),
                      //               //         child: InkWell(
                      //               //           onTap: () async {
                      //               //             context.read<HomeBloc>().add(
                      //               //                   HomeGenScreenshot(
                      //               //                       _screnshotGlobalKey),
                      //               //                 );
                      //               //           },
                      //               //           child: Container(
                      //               //             width: 36,
                      //               //             height: 36,
                      //               //             decoration: BoxDecoration(
                      //               //                 borderRadius:
                      //               //                     BorderRadius.circular(18),
                      //               //                 color: Color(0xFFDFFF00),
                      //               //                 border: Border.all()),
                      //               //             child: Center(
                      //               //               child: Icon(
                      //               //                 Iconsax.send_2_bold,
                      //               //                 color: Colors.black,
                      //               //                 size: 20,
                      //               //               ),
                      //               //             ),
                      //               //           ),
                      //               //         ),
                      //               //       ),
                      //               state.status == HomePageStatus.idle ||
                      //                       state.status == HomePageStatus.success
                      //                   ? IconButton(
                      //                       padding: EdgeInsets.zero,
                      //                       visualDensity:
                      //                           VisualDensity(horizontal: -4),
                      //                       onPressed: () {
                      //                         FocusScope.of(context).unfocus();

                      //                         String taskText =
                      //                             taskTextController.text;

                      //                         if (isTaskValid) {
                      //                           if (isUrl == true) {

                      //                             if(!taskText.startsWith("http")){
                      //                               taskText = "https://${taskText}";
                      //                             }
                      //                             Navigator.push(
                      //                               context,
                      //                               MaterialPageRoute<void>(
                      //                                 builder: (BuildContext
                      //                                         context) =>
                      //                                     WebViewPage(url: taskText),
                      //                               ),
                      //                             );
                      //                             taskTextController.text = "";
                      //                           } else {
                      //                             // .replaceAll(RegExp(r'[^\w\s]'), '')
                      //                             // .toLowerCase();
                      //                             if (state.isSearchMode == true) {
                      //                               // if (state.status ==
                      //                               //     HomePageStatus.success) {
                      //                               //   taskTextController.text = "";
                      //                               //   context.read<HomeBloc>().add(
                      //                               //         HomeFollowUpRecallVideos(
                      //                               //             taskText),
                      //                               //       );
                      //                               // } else {
                      //                               taskTextController.text = "";
                      //                               context.read<HomeBloc>().add(
                      //                                     HomeGetSearch(
                      //                                         taskText, "web"),
                      //                                   );
                      //                               //}
                      //                             } else {
                      //                               // if (state.status ==
                      //                               //     HomePageStatus.success) {
                      //                               //   taskTextController.text = "";
                      //                               //   context.read<HomeBloc>().add(
                      //                               //         HomeFollowUpSearchVideos(
                      //                               //             taskText),
                      //                               //       );
                      //                               // } else {
                      //                               taskTextController.text = "";
                      //                               context.read<HomeBloc>().add(
                      //                                     HomeGetAnswer(taskText),
                      //                                   );
                      //                               //}
                      //                             }
                      //                             setState(() {
                      //                     isTaskValid = false;
                      //                   });
                      //                             Future.delayed(Duration(milliseconds: 500)).then((onValue){
                      //                               _scrollController.animateTo(
                      //                                 _scrollController
                      //                                     .position.maxScrollExtent,
                      //                                 duration:
                      //                                     Duration(milliseconds: 300),
                      //                                 curve: Curves.easeOut);
                      //                             });
                      //                           }
                      //                         }
                      //                       },
                      //                       icon: Container(
                      //                         margin:
                      //                             EdgeInsets.only(left: 0, bottom: 0),
                      //                         decoration: BoxDecoration(
                      //                           color: isTaskValid == true
                      //                               ? Color(0xFF8A2BE2)
                      //                               : Color(0xFFC99DF2),
                      //                           shape: BoxShape.circle,
                      //                         ),
                      //                         padding: EdgeInsets.all(10),
                      //                         child: Icon(
                      //                           Icons.send,
                      //                           color: Color(0xFFDFFF00),
                      //                           size: 16,
                      //                         ),
                      //                       ),
                      //                     )
                      //                   : IconButton(
                      //                       padding: EdgeInsets.zero,
                      //                       visualDensity:
                      //                           VisualDensity(horizontal: -4),
                      //                       onPressed: () {
                      //                         FocusScope.of(context).unfocus();
                      //                         context.read<HomeBloc>().add(
                      //                               HomeCancelTaskGen(),
                      //                             );
                      //                         mixpanel.track("cancel_search");
                      //                       },
                      //                       icon: Container(
                      //                         margin:
                      //                             EdgeInsets.only(left: 0, bottom: 0),
                      //                         decoration: BoxDecoration(
                      //                           color: Color(0xFF8A2BE2),
                      //                           shape: BoxShape.circle,
                      //                         ),
                      //                         padding: EdgeInsets.all(10),
                      //                         child: Icon(
                      //                           Icons.stop,
                      //                           color: Color(0xFFDFFF00),
                      //                           size: 16,
                      //                         ),
                      //                       ),
                      //                     ),
                      //             ],
                      //           ),
                      //         ],
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      bottomSheet: Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              16,
                            ),
                            //border: Border.all(color: Color(0xFFB3B4B9)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset:
                                    Offset(0, 3), // changes position of shadow
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Visibility(
                                visible:
                                    state.editStatus == HomeEditStatus.selected,
                                child: InkWell(
                                  onTap: () {
                                    context.read<HomeBloc>().add(
                                          SelectEditInputOption("", false, -1,
                                              state.isSearchMode, ""),
                                        );
                                    taskTextController.text = "";
                                    isTaskValid = false;
                                  },
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minWidth: 35),
                                    child: Container(
                                      height: 36,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF8A2BE2),
                                        borderRadius: BorderRadius.circular(28),
                                        // border: Border.all(
                                        //     color: Colors.purple),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Iconsax.edit_2_outline,
                                              color: Color(0xFFDFFF00),
                                              size: 16),
                                          SizedBox(width: 3),
                                          Text(
                                            'Edit',
                                            overflow: TextOverflow.clip,
                                            style: const TextStyle(
                                              color: Color(0xFFDFFF00),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Iconsax.close_circle_bold,
                                              color: Color(0xFFDFFF00),
                                              size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Image Preview with Close Button
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: state.imageStatus ==
                                            HomeImageStatus.selected &&
                                        state.selectedImage != null
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Image Container
                                            Container(
                                              height: 120,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.08),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                    spreadRadius: 0,
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.purple
                                                        .withOpacity(0.05),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                    spreadRadius: -4,
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Image.file(
                                                  File(state
                                                      .selectedImage!.path),
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            // Close Button
                                            Positioned(
                                              top: -8,
                                              right: -8,
                                              child: GestureDetector(
                                                onTap: () {
                                                  context.read<HomeBloc>().add(
                                                        HomeImageUnselected(
                                                            imageDescriptionNotifier),
                                                      );
                                                },
                                                child: Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.15),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      size: 18,
                                                      color: Color(0xFF8A2BE2),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: taskTextController,
                                      focusNode: taskTextFieldFocusNode,
                                      style: TextStyle(
                                        color: isUrl
                                            ? Colors.purple
                                            : Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Ask anything',
                                        hintStyle:
                                            TextStyle(color: Colors.grey),
                                        border: InputBorder.none,
                                      ),
                                      //maxLines: 1, // allow multiline input
                                      autofocus: false,
                                      minLines: 1,
                                      maxLines: 6,
                                      onTap: () {
                                        //FocusScope.of(context).unfocus();
                                      },
                                      onChanged: (value) {
                                        bool valueIsUrl = false;
                                        //Check if text entered is url or not
                                        List<String> values =
                                            value.trim().split(" ");
                                        String formattedValue = values.first;
                                        if ((values.length == 1 &&
                                                formattedValue.contains(".") &&
                                                formattedValue.length >= 4) ||
                                            (values.length == 1 &&
                                                formattedValue
                                                    .contains("http") &&
                                                formattedValue
                                                    .contains("://"))) {
                                          if (formattedValue
                                                      .contains("https") ==
                                                  false &&
                                              formattedValue.contains("http") ==
                                                  false) {
                                            formattedValue =
                                                "https://${formattedValue}";
                                          }
                                          valueIsUrl = true;
                                        }

                                        //Check if text valide or not
                                        if (value.length >= 3) {
                                          setState(() {
                                            isTaskValid = true;
                                            isUrl = valueIsUrl;
                                          });
                                        } else {
                                          setState(() {
                                            isTaskValid = false;
                                            isUrl = valueIsUrl;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          final homeBloc =
                                              context.read<HomeBloc>();
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            isScrollControlled: true,
                                            builder: (_) => BlocProvider.value(
                                              value: homeBloc,
                                              child: BlocBuilder<HomeBloc,
                                                  HomeState>(
                                                builder: (context, state) {
                                                  return SourcesBottomSheet(
                                                    onImageSelected: (image) {
                                                      print(
                                                          "DEBUG: Callback received image (bottom): ${image.path}");
                                                      homeBloc.add(
                                                          HomeImageSelected(
                                                              image,
                                                              imageDescriptionNotifier));
                                                    },
                                                    onToggleMap: () {
                                                      homeBloc.add(
                                                          HomeToggleMapStatus());
                                                    },
                                                    onToggleYoutube: () {
                                                      homeBloc.add(
                                                          HomeToggleYoutubeStatus());
                                                    },
                                                    onToggleInstagram: () {
                                                      homeBloc.add(
                                                          HomeToggleInstagramStatus());
                                                    },
                                                    isInstagramEnabled:
                                                        state.instagramStatus ==
                                                            HomeInstagramStatus
                                                                .enabled,
                                                    isYoutubeEnabled:
                                                        state.youtubeStatus ==
                                                            HomeYoutubeStatus
                                                                .enabled,
                                                    isMapEnabled: state
                                                            .mapStatus ==
                                                        HomeMapStatus.enabled,
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              26,
                                            ),
                                            //border: Border.all(color: Color(0xFFB3B4B9)),
                                          ),
                                          child: Icon(
                                            Icons.add,
                                            color: Colors.black,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () {
                                          final homeBloc =
                                              context.read<HomeBloc>();
                                          homeBloc.add(HomeToggleChatMode());
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          height: 32,
                                          padding: EdgeInsets.symmetric(
                                            horizontal:
                                                state.isChatModeActive == false
                                                    ? 12
                                                    : 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: state.isChatModeActive ==
                                                    false
                                                ? const Color(
                                                    0xFFE8D5FF) // Light purple
                                                : Colors.grey.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(26),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Iconsax.search_normal_outline,
                                                color: state.isChatModeActive ==
                                                        false
                                                    ? const Color(
                                                        0xFF8A2BE2) // Purple
                                                    : Colors.black,
                                                size: 16,
                                              ),
                                              AnimatedSize(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                curve: Curves.easeInOut,
                                                child: state.isChatModeActive ==
                                                        false
                                                    ? Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(left: 6),
                                                        child: Text(
                                                          "Search",
                                                          style: TextStyle(
                                                            color: const Color(
                                                                0xFF8A2BE2),
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      // Padding(
                                      //     padding: const EdgeInsets.only(right: 12),
                                      //     child: InkWell(
                                      //       onTap: () async {
                                      //         Navigator.push(
                                      //           context,
                                      //           MaterialPageRoute<void>(
                                      //             builder: (BuildContext context) =>
                                      //                 TabsViewPage(),
                                      //           ),
                                      //         );
                                      //       },
                                      //       child: Container(
                                      //         width: 36,
                                      //         height: 36,
                                      //         decoration: BoxDecoration(
                                      //           borderRadius:
                                      //               BorderRadius.circular(18),
                                      //           color: Color(
                                      //               0xFF8A2BE2), //Color(0xFFDFFF00),
                                      //         ),
                                      //         child: Center(
                                      //           child: Icon(
                                      //             Iconsax.note_2_bold,
                                      //             color: Color(0xFFDFFF00),
                                      //             size: 20,
                                      //           ),
                                      //         ),
                                      //       ),
                                      //     )),
                                      state.status == HomePageStatus.idle ||
                                              (state.status ==
                                                      HomePageStatus.success &&
                                                  state.replyStatus !=
                                                      HomeReplyStatus.loading)
                                          ? IconButton(
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity(horizontal: -4),
                                              onPressed: () {
                                                FocusScope.of(context)
                                                    .unfocus();

                                                String taskText =
                                                    taskTextController.text;

                                                if (isTaskValid) {
                                                  // if (state.isChatModeActive ==
                                                  //     true) {
                                                  //   Navigator.push(
                                                  //     context,
                                                  //     MaterialPageRoute<void>(
                                                  //       builder: (BuildContext
                                                  //               context) =>
                                                  //           ChatPage(
                                                  //               initialMessage:
                                                  //                   taskText),
                                                  //     ),
                                                  //   );
                                                  //   taskTextController.text = "";
                                                  //   return;
                                                  // }
                                                  if (isUrl == true) {
                                                    if (!taskText
                                                        .startsWith("http")) {
                                                      taskText =
                                                          "https://${taskText}";
                                                    }
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute<void>(
                                                        builder: (BuildContext
                                                                context) =>
                                                            WebViewPage(
                                                                url: taskText),
                                                      ),
                                                    );
                                                    taskTextController.text =
                                                        "";
                                                  } else {
                                                    if (state.isSearchMode ==
                                                        true) {
                                                      taskTextController.text =
                                                          "";
                                                      context
                                                          .read<HomeBloc>()
                                                          .add(
                                                            HomeGetSearch(
                                                                taskText,
                                                                "web"),
                                                          );
                                                    } else if (state
                                                            .editStatus ==
                                                        HomeEditStatus
                                                            .selected) {
                                                      print(
                                                          "Updating edited answer");
                                                      taskTextController.text =
                                                          "";
                                                      context
                                                          .read<HomeBloc>()
                                                          .add(
                                                            HomeUpdateAnswer(
                                                              taskText,
                                                              state
                                                                  .loadingIndex,
                                                              streamedText,
                                                              imageDescriptionNotifier
                                                                  .value,
                                                              imageDescriptionNotifier,
                                                              extractedUrlDescription,
                                                              extractedUrlTitle,
                                                              extractedUrl,
                                                              extractedImageUrl,
                                                            ),
                                                          );
                                                    } else {
                                                      taskTextController.text =
                                                          "";
                                                      context
                                                          .read<HomeBloc>()
                                                          .add(
                                                            HomeGetAnswer(
                                                              taskText,
                                                              streamedText,
                                                              extractedUrlDescription,
                                                              extractedUrlTitle,
                                                              extractedUrl,
                                                              extractedImageUrl,
                                                              imageDescriptionNotifier
                                                                  .value,
                                                              imageDescriptionNotifier,
                                                            ),
                                                          );
                                                    }
                                                    setState(() {
                                                      isTaskValid = false;
                                                    });
                                                    Future.delayed(Duration(
                                                            milliseconds: 200))
                                                        .then((onValue) {
                                                      _scrollController.animateTo(
                                                          _scrollController
                                                              .position
                                                              .maxScrollExtent,
                                                          duration: Duration(
                                                              milliseconds:
                                                                  300),
                                                          curve:
                                                              Curves.easeOut);
                                                    });

                                                    mixpanel
                                                        .track("Send Message");
                                                  }
                                                }
                                              },
                                              icon: Container(
                                                margin: EdgeInsets.only(
                                                    left: 0, bottom: 0),
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
                                                FocusScope.of(context)
                                                    .unfocus();
                                                context.read<HomeBloc>().add(
                                                      HomeCancelTaskGen(),
                                                    );
                                                mixpanel.track("cancel_search");
                                                isTaskValid = false;
                                              },
                                              icon: Container(
                                                margin: EdgeInsets.only(
                                                    left: 0, bottom: 0),
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
                      ),
                      extendBodyBehindAppBar:
                          state.status == HomePageStatus.idle ? true : false,
                      body: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                        },
                        child: state.status == HomePageStatus.idle
                            ? Container(
                                color: Colors.white,
                                height: MediaQuery.of(context).size.height -
                                    MediaQuery.of(context).padding.bottom -
                                    MediaQuery.of(context).padding.top,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        context.read<HomeBloc>().add(
                                              HomeSwitchPrivacyType(
                                                  state.isIncognito == true
                                                      ? false
                                                      : true),
                                            );
                                        mixpanel.track(state.isIncognito == true
                                            ? "set_incognito_mode"
                                            : "set_normal_mode");
                                      },
                                      child: Center(
                                        child: state.isIncognito
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 80,
                                                    height: 80,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              40),
                                                      color: Color(0xFF8A2BE2),
                                                    ),
                                                    child: Icon(
                                                      RemixIcons.spy_line,
                                                      color: Color(0xFFDFFF00),
                                                      size: 40,
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    "Incognito Mode",
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 20,
                                                      fontFamily: 'Poppins',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // D with chat icon inside
                                                  Stack(
                                                    clipBehavior: Clip.none,
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Text(
                                                        'D',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFF8A2BE2),
                                                          fontSize: 56,
                                                          fontFamily:
                                                              'BagelFatOne',
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          height: 1,
                                                        ),
                                                      ),
                                                      Container(
                                                        color:
                                                            Color(0xFF8A2BE2),
                                                        width: 20,
                                                        height: 30,
                                                        child:
                                                            SizedBox.shrink(),
                                                      ),
                                                      // Yellow chat bubble icon positioned inside D's counter
                                                      Positioned(
                                                        top: 24,
                                                        left: 14,
                                                        child: CustomPaint(
                                                          size: Size(10, 18),
                                                          painter:
                                                              ChatBubblePainter(
                                                            color: Color(
                                                                0xFFDFFF00),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  // rissy text
                                                  Text(
                                                    'rissy',
                                                    style: TextStyle(
                                                      color: Color(0xFF8A2BE2),
                                                      fontSize: 56,
                                                      fontFamily: 'BagelFatOne',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                color: Colors.white,
                                height: MediaQuery.of(context).size.height -
                                    MediaQuery.of(context).padding.top -
                                    MediaQuery.of(context).padding.bottom,
                                padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 160),
                                    child: Column(
                                      children: List.generate(
                                        state.threadData.results.length,
                                        (index) {
                                          final result =
                                              state.threadData.results[index];
                                          return Column(
                                            children: [
                                              result.isSearchMode == true
                                                  ? ThreadSearchView(
                                                      isIncognito: state
                                                          .threadData
                                                          .isIncognito,
                                                      onGraphImageTap:
                                                          (String query) {
                                                        context
                                                            .read<HomeBloc>()
                                                            .add(
                                                              HomeGetSearch(
                                                                  query, "web"),
                                                            );
                                                      },
                                                      onTabChanged:
                                                          (String type) {
                                                        if (type == "news") {
                                                          context
                                                              .read<HomeBloc>()
                                                              .add(
                                                                HomeGetNewsSearch(
                                                                    index),
                                                              );
                                                        } else if (type ==
                                                            "videos") {
                                                          context
                                                              .read<HomeBloc>()
                                                              .add(
                                                                HomeGetVideosSearch(
                                                                    index),
                                                              );
                                                        } else if (type ==
                                                            "shortVideos") {
                                                          context
                                                              .read<HomeBloc>()
                                                              .add(
                                                                HomeGetReelsSearch(
                                                                    index),
                                                              );
                                                        } else if (type ==
                                                            "images") {
                                                          context
                                                              .read<HomeBloc>()
                                                              .add(
                                                                HomeGetImagesSearch(
                                                                    index),
                                                              );
                                                        }
                                                      },
                                                      knowledgeGraph:
                                                          result.knowledgeGraph,
                                                      answerBox:
                                                          result.answerBox,
                                                      web: result.web,
                                                      query: result.userQuery,
                                                      shortVideos:
                                                          result.shortVideos,
                                                      videos: result.videos,
                                                      news: result.news,
                                                      images: result.images,
                                                      status:
                                                          state.loadingIndex ==
                                                                  index
                                                              ? state.status
                                                              : HomePageStatus
                                                                  .success)
                                                  : ValueListenableBuilder(
                                                      valueListenable:
                                                          streamedText,
                                                      builder:
                                                          (context, value, _) {
                                                        return ThreadAnswerView(
                                                          youtubeVideos: result
                                                              .youtubeVideos,
                                                          shortVideos: result
                                                              .shortVideos,
                                                          sourceImageUrl: result
                                                              .sourceImageLink,
                                                          sourceImage: result
                                                              .sourceImage,
                                                          local: result.local,
                                                          onLinkTap:
                                                              (url) async {
                                                            if (url
                                                                .isNotEmpty) {
                                                              // Open in external browser
                                                              final uri =
                                                                  Uri.parse(
                                                                      url);
                                                              if (!await launchUrl(
                                                                  uri,
                                                                  mode: LaunchMode
                                                                      .externalApplication)) {
                                                                launchUrl(uri);
                                                              }
                                                            }
                                                          },
                                                          answerResults:
                                                              result.influence,
                                                          query:
                                                              result.userQuery,
                                                          answer:
                                                              state.loadingIndex ==
                                                                      index
                                                                  ? value
                                                                  : result
                                                                      .answer,
                                                          hideRefresh: index !=
                                                                  state
                                                                          .threadData
                                                                          .results
                                                                          .length -
                                                                      1
                                                              ? true
                                                              : false,
                                                          onEditSelected: () {
                                                            context
                                                                .read<
                                                                    HomeBloc>()
                                                                .add(
                                                                  SelectEditInputOption(
                                                                      result
                                                                          .userQuery,
                                                                      true,
                                                                      state
                                                                          .threadData
                                                                          .results
                                                                          .indexOf(
                                                                              result),
                                                                      result
                                                                          .isSearchMode,
                                                                      result
                                                                          .sourceImageLink),
                                                                );
                                                            taskTextController
                                                                    .text =
                                                                result
                                                                    .userQuery;
                                                            isTaskValid = true;
                                                            //FocusManager.instance.primaryFocus?.unfocus();
                                                          },
                                                          onRefresh: () {
                                                            context
                                                                .read<
                                                                    HomeBloc>()
                                                                .add(
                                                                  HomeRefreshReply(
                                                                      index,
                                                                      streamedText),
                                                                );
                                                          },
                                                          status:
                                                              state.loadingIndex ==
                                                                      index
                                                                  ? state.status
                                                                  : HomePageStatus
                                                                      .success,
                                                          replyStatus: state
                                                                      .loadingIndex ==
                                                                  index
                                                              ? state
                                                                  .replyStatus
                                                              : HomeReplyStatus
                                                                  .success,
                                                          extractedUrlData: result
                                                              .extractedUrlData,
                                                        );
                                                      }),
                                              if (index <
                                                  state.threadData.results
                                                          .length -
                                                      1)
                                                Divider(
                                                  color: Colors.white,
                                                  thickness: 0.5,
                                                  height: 25,
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                )),
                      ),
                    ), // Close Scaffold
                  ), // Close UpgradeAlert
                  // Full-screen download overlay (premium)
                  const DownloadOverlay(),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Custom painter for the chat bubble icon inside the D letter
class ChatBubblePainter extends CustomPainter {
  final Color color;

  ChatBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Scale factors to convert SVG viewBox (12x21) to actual size
    final scaleX = size.width / 12;
    final scaleY = size.height / 21;

    // Tall rounded chat bubble icon with smooth curved tail
    // Original SVG path: M3 2h6c1.7 0 3 1.3 3 3v9c0 1.7-1.3 3-3 3H5 Q3 17 1 20 Q0 21 0 19 L0 15 Q0 14 0 14 L0 5c0-1.7 1.3-3 3-3z
    path.moveTo(3 * scaleX, 2 * scaleY);
    path.lineTo(9 * scaleX, 2 * scaleY);
    path.cubicTo(10.7 * scaleX, 2 * scaleY, 12 * scaleX, 3.3 * scaleY,
        12 * scaleX, 5 * scaleY);
    path.lineTo(12 * scaleX, 14 * scaleY);
    path.cubicTo(12 * scaleX, 15.7 * scaleY, 10.7 * scaleX, 17 * scaleY,
        9 * scaleX, 17 * scaleY);
    path.lineTo(5 * scaleX, 17 * scaleY);
    path.quadraticBezierTo(3 * scaleX, 17 * scaleY, 1 * scaleX, 20 * scaleY);
    path.quadraticBezierTo(0, 21 * scaleY, 0, 19 * scaleY);
    path.lineTo(0, 15 * scaleY);
    path.quadraticBezierTo(0, 14 * scaleY, 0, 14 * scaleY);
    path.lineTo(0, 5 * scaleY);
    path.cubicTo(
        0, 3.3 * scaleY, 1.3 * scaleX, 2 * scaleY, 3 * scaleX, 2 * scaleY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

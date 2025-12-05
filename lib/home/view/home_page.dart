import 'dart:async';

import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:aws_client/memory_db_2021_01_01.dart';

import 'package:bavi/home/widgets/answers_view.dart';
import 'package:bavi/home/widgets/search_view.dart';
import 'package:bavi/home/widgets/tabs_view.dart';
import 'package:bavi/home/widgets/web_view.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/rendering.dart';

import 'package:upgrader/upgrader.dart';

import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/widgets/app_drawer.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:icons_plus/icons_plus.dart';
import 'package:http/http.dart' as http;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

import 'package:in_app_update/in_app_update.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shimmer/shimmer.dart';

import 'package:bavi/home/widgets/sources_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  final String? query;
  const HomePage({super.key, this.query});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<Uri>? _linkSubscription;
  final ValueNotifier<String> streamedText = ValueNotifier("");
  final ValueNotifier<String> imageDescription = ValueNotifier("");
  final ValueNotifier<String> extractedUrlDescription = ValueNotifier("");
  final ValueNotifier<String> extractedUrlTitle = ValueNotifier("");
  final ValueNotifier<String> extractedUrl = ValueNotifier("");
  final ValueNotifier<String> extractedImageUrl = ValueNotifier("");

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
  double _scaleFactor = 1.0;

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

    _linkSubscription?.cancel();

    streamedText.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initMixpanel();
    guestUsername = getRandomUsername();

    taskTextController.text = widget.query ?? "";
    if (taskTextController.text.length >= 3) {
      isTaskValid = true;
    }
    isExpanded = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isAndroid) {
        InAppUpdate.checkForUpdate();
      }
      //FocusScope.of(context).requestFocus(taskTextFieldFocusNode);
    });
    initDeepLinks();
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

  void _showTopSnackBar(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF8A2BE2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
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
          child: AnimatedScale(
            scale: _scaleFactor,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: SafeArea(
              child: UpgradeAlert(
                showPrompt: Platform.isAndroid ? false : true,
                child: Scaffold(
                  drawer: ChatAppDrawer(
                    sessions: state.threadHistory,
                    historyStatus: state.historyStatus,
                    onSessionTap: (ThreadSessionData session) {
                      mixpanel.track("user_tap_thread");
                      Navigator.pop(context);
                      context.read<HomeBloc>().add(
                            HomeRetrieveSearchData(session),
                          );
                      Future.delayed(Duration(milliseconds: 300))
                          .then((onValue) {
                        _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeOut);
                      }); //}
                    },
                    profilePicUrl: state.userData.profilePicUrl,
                    email:
                        state.userData.email != "" ? state.userData.email : "",
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

                  appBar: AppBar(
                    titleSpacing: 0,
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    leadingWidth: 40,
                    elevation: state.status == HomePageStatus.idle ? 0 : 4,
                    shadowColor: state.status == HomePageStatus.idle
                        ? Colors.transparent
                        : Colors.black.withOpacity(0.2),
                    centerTitle: true,
                    //state.status == HomePageStatus.idle ? true : false,
                    leading: Builder(
                        builder: (context) => Padding(
                              padding: const EdgeInsets.only(left: 0),
                              child: InkWell(
                                onTap: () async {
                                  // Unfocus any text field and close keyboard completely
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  // Wait a short moment to ensure keyboard is dismissed
                                  await Future.delayed(
                                      const Duration(milliseconds: 100));

                                  // Then open the drawer
                                  Scaffold.of(context).openDrawer();
                                },
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    //color: Color(0xFFDFFF00),
                                    shape: BoxShape.circle,
                                    //border: Border.all()
                                  ),
                                  padding: EdgeInsets.fromLTRB(6, 0, 2, 0),
                                  child: Center(
                                    child: Icon(
                                      Icons.history_outlined,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            )),

                    title: Padding(
                      padding: EdgeInsets.only(
                          left: state.status == HomePageStatus.idle ? 0 : 5),
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
                          padding: EdgeInsets.only(
                              right:
                                  state.status != HomePageStatus.idle ? 6 : 12),
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
                                  onTap: () {
                                    mixpanel.track("user_tap_login");
                                    //Navigator.pop(context);
                                    context.read<HomeBloc>().add(
                                          HomeAttemptGoogleSignIn(),
                                        );
                                  },
                                  child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                          // borderRadius: BorderRadius.circular(18),
                                          // color: Color(0xFFDFFF00),
                                          // border: Border.all()
                                          ),
                                      child: CircularAvatarWithShimmer(
                                          imageUrl:
                                              state.userData.profilePicUrl)),
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
                                  _showTopSnackBar(
                                      context, "Link copied to clipboard");
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        //Show the extracted og image and title here
                        ValueListenableBuilder<String>(
                          valueListenable: extractedImageUrl,
                          builder: (context, imageUrl, _) {
                            return ValueListenableBuilder<String>(
                              valueListenable: extractedUrlTitle,
                              builder: (context, title, _) {
                                // Show shimmer during loading
                                if (state.extractUrlStatus ==
                                    HomeExtractUrlStatus.loading) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        margin: EdgeInsets.only(
                                            right: 12, bottom: 12),
                                        width:
                                            MediaQuery.of(context).size.width -
                                                88,
                                        color: Colors.white,
                                        child: Shimmer.fromColors(
                                          baseColor: Colors.grey.shade300,
                                          highlightColor: Colors.grey.shade100,
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width -
                                                24,
                                            height: 180,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // Show extracted data if available
                                if (extractedUrl.value.isNotEmpty) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        margin: EdgeInsets.only(
                                            right: 12, bottom: 12),
                                        alignment: Alignment.centerRight,
                                        width:
                                            MediaQuery.of(context).size.width -
                                                88,
                                        height: 180,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            // Background Image
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Image.network(
                                                imageUrl,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    color: Colors.grey.shade200,
                                                    child: Center(
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        color: Colors
                                                            .grey.shade400,
                                                        size: 40,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            // Gradient Overlay
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black
                                                        .withOpacity(0.7),
                                                  ],
                                                  stops: [0.5, 1.0],
                                                ),
                                              ),
                                            ),
                                            // Title at Bottom Left
                                            Positioned(
                                              left: 16,
                                              right: 16,
                                              bottom: 12,
                                              child: Text(
                                                title == ""
                                                    ? extractedUrlDescription
                                                        .value
                                                    : title,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black
                                                          .withOpacity(0.5),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // // Close button at top right
                                            // Positioned(
                                            //   top: 8,
                                            //   right: 8,
                                            //   child: InkWell(
                                            //     onTap: () {
                                            //       extractedImageUrl.value = "";
                                            //       extractedUrlTitle.value = "";
                                            //       extractedUrlDescription
                                            //           .value = "";
                                            //       extractedUrl.value = "";
                                            //     },
                                            //     child: Container(
                                            //       padding: EdgeInsets.all(6),
                                            //       decoration: BoxDecoration(
                                            //         color: Colors.black
                                            //             .withOpacity(0.5),
                                            //         shape: BoxShape.circle,
                                            //       ),
                                            //       child: Icon(
                                            //         Icons.close,
                                            //         color: Colors.white,
                                            //         size: 16,
                                            //       ),
                                            //     ),
                                            //   ),
                                            // ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return SizedBox.shrink();
                              },
                            );
                          },
                        ),
                        Container(
                          color: Colors.white,
                          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (_) => SourcesBottomSheet(
                                      onImageSelected: (image) {
                                        print(
                                            "DEBUG: Callback received image (bottom): ${image.path}");
                                        context.read<HomeBloc>().add(
                                            HomeImageSelected(
                                                image, imageDescription));
                                      },
                                      onSearchTypeSelected: (searchType) {
                                        context.read<HomeBloc>().add(
                                            HomeSearchTypeSelected(searchType));
                                      },
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      26,
                                    ),
                                    //border: Border.all(color: Color(0xFFB3B4B9)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        spreadRadius: 2,
                                        blurRadius: 5,
                                        offset: Offset(
                                            0, 3), // changes position of shadow
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Container(
                                width: MediaQuery.of(context).size.width - 88,
                                constraints: BoxConstraints(
                                    minHeight: 52, maxHeight: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    26,
                                  ),
                                  //border: Border.all(color: Color(0xFFB3B4B9)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.2),
                                      spreadRadius: 2,
                                      blurRadius: 5,
                                      offset: Offset(
                                          0, 3), // changes position of shadow
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: state.editStatus ==
                                                      HomeEditStatus.selected ||
                                                  state.imageStatus ==
                                                      HomeImageStatus
                                                          .selected ||
                                                  state.searchType !=
                                                      HomeSearchType.general
                                              ? 10
                                              : 0),
                                      child: Row(
                                        children: [
                                          //Selected image
                                          AnimatedSize(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.easeInOut,
                                            child: state.imageStatus ==
                                                    HomeImageStatus.selected
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 8),
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        Container(
                                                          width: 48,
                                                          height: 48,
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                              color: const Color(
                                                                      0xFFDFFF00)
                                                                  .withOpacity(
                                                                      0.5),
                                                              width: 1,
                                                            ),
                                                            image:
                                                                DecorationImage(
                                                              image: state.selectedImage
                                                                          ?.path !=
                                                                      null
                                                                  ? FileImage(
                                                                      File(state
                                                                          .selectedImage!
                                                                          .path),
                                                                    )
                                                                  : NetworkImage(
                                                                      state.uploadedImageUrl ??
                                                                          ""),
                                                              fit: BoxFit.cover,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        0.2),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (state
                                                            .isAnalyzingImage)
                                                          Positioned.fill(
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        0.5),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child:
                                                                  const Center(
                                                                child: SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    valueColor: AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Colors
                                                                            .white),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        Positioned(
                                                          top: -6,
                                                          right: -6,
                                                          child: InkWell(
                                                            onTap: () {
                                                              context
                                                                  .read<
                                                                      HomeBloc>()
                                                                  .add(HomeImageUnselected(
                                                                      imageDescription));
                                                            },
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .black,
                                                                shape: BoxShape
                                                                    .circle,
                                                                border:
                                                                    Border.all(
                                                                  color: const Color(
                                                                      0xFFDFFF00),
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: const Icon(
                                                                Icons.close,
                                                                size: 12,
                                                                color: Color(
                                                                    0xFFDFFF00),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                          Visibility(
                                            visible: state.editStatus ==
                                                HomeEditStatus.selected,
                                            child: InkWell(
                                              onTap: () {
                                                imageDescription.value = "";
                                                context.read<HomeBloc>().add(
                                                      SelectEditInputOption(
                                                          "",
                                                          false,
                                                          -1,
                                                          state.isSearchMode,
                                                          ""),
                                                    );
                                                taskTextController.text = "";
                                                isTaskValid = false;
                                              },
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 35),
                                                child: Container(
                                                  height: 36,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFF8A2BE2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            28),
                                                    // border: Border.all(
                                                    //     color: Colors.purple),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(Iconsax.edit_2_bold,
                                                          color:
                                                              Color(0xFFDFFF00),
                                                          size: 16),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'Edit',
                                                        overflow:
                                                            TextOverflow.clip,
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFFDFFF00),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Icon(
                                                          Iconsax
                                                              .close_circle_bold,
                                                          color:
                                                              Color(0xFFDFFF00),
                                                          size: 16),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Visibility(
                                            visible: state.searchType !=
                                                HomeSearchType.general,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                  left: state.editStatus ==
                                                          HomeEditStatus
                                                              .selected
                                                      ? 5
                                                      : 0),
                                              child: InkWell(
                                                onTap: () {
                                                  context.read<HomeBloc>().add(
                                                        HomeSearchTypeSelected(
                                                            HomeSearchType
                                                                .general),
                                                      );
                                                },
                                                child: ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 35),
                                                  child: Container(
                                                    height: 36,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFF8A2BE2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              28),
                                                      // border: Border.all(
                                                      //     color: Colors.purple),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                            state.searchType ==
                                                                    HomeSearchType
                                                                        .nsfw
                                                                ? Iconsax
                                                                    .huobi_token_ht_bold
                                                                : state.searchType ==
                                                                        HomeSearchType
                                                                            .map
                                                                    ? Iconsax
                                                                        .map_1_bold
                                                                    : state.searchType ==
                                                                            HomeSearchType
                                                                                .shopping
                                                                        ? Iconsax
                                                                            .shopping_cart_bold
                                                                        : Iconsax
                                                                            .huobi_token_ht_bold,
                                                            color: Color(
                                                                0xFFDFFF00),
                                                            size: 16),
                                                        SizedBox(width: 3),
                                                        Text(
                                                          state.searchType ==
                                                                  HomeSearchType
                                                                      .nsfw
                                                              ? 'NSFW'
                                                              : state.searchType ==
                                                                      HomeSearchType
                                                                          .map
                                                                  ? 'Map'
                                                                  : state.searchType ==
                                                                          HomeSearchType
                                                                              .shopping
                                                                      ? 'Shopping'
                                                                      : state.searchType ==
                                                                              HomeSearchType.portal
                                                                          ? "Portal"
                                                                          : "General",
                                                          overflow:
                                                              TextOverflow.clip,
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xFFDFFF00),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Icon(
                                                            Iconsax
                                                                .close_circle_bold,
                                                            color: Color(
                                                                0xFFDFFF00),
                                                            size: 16),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: taskTextController,
                                            focusNode: taskTextFieldFocusNode,
                                            style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 14),
                                            decoration: InputDecoration(
                                              hintText: state.isSearchMode
                                                  ? "Search or type url"
                                                  : 'Ask Drissea',
                                              hintStyle: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 14),
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
                                              //Check for url and execute it
                                              String? extractedUrlFromText;
                                              print(state.actionType);

                                              bool valueIsUrl = false;

                                              // Try to find a URL in the text using regex
                                              // Pattern matches:
                                              // 1. URLs with protocol (http:// or https://)
                                              // 2. Domain-like patterns (word.word with optional path)
                                              final urlPattern = RegExp(
                                                r'(?:https?://)?(?:www\.)?[\w-]+\.[\w.-]+(?:/[\w./?%&=~#-]*)?',
                                                caseSensitive: false,
                                              );
                                              for (int i = 0;
                                                  i < value.split(" ").length;
                                                  i++) {
                                                if (value
                                                    .split(" ")[i]
                                                    .trim()
                                                    .contains("https://")) {
                                                  final match = urlPattern
                                                      .firstMatch(value
                                                          .split(" ")[i]
                                                          .trim());

                                                  if (match != null) {
                                                    String potentialUrl =
                                                        match.group(0)!;

                                                    extractedUrlFromText =
                                                        potentialUrl;
                                                    valueIsUrl = true;
                                                    if (extractedUrlFromText !=
                                                        extractedUrl.value) {
                                                      print("");
                                                      print(
                                                          extractedUrlFromText);
                                                      print("");
                                                      print(extractedUrl.value);

                                                      print("");
                                                      print("done");
                                                      //Execute url extraction
                                                      context
                                                          .read<HomeBloc>()
                                                          .add(
                                                            HomeExtractUrlData(
                                                              extractedUrlFromText,
                                                              extractedUrlDescription,
                                                              extractedUrlTitle,
                                                              extractedUrl,
                                                              extractedImageUrl,
                                                            ),
                                                          );
                                                    }
                                                  }
                                                }
                                              }

                                              context.read<HomeBloc>().add(
                                                    HomeSwitchActionType(value),
                                                  );

                                              //Check if text valid or not
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
                                        Row(
                                          children: [
                                            // Padding(
                                            //     padding:
                                            //         const EdgeInsets.only(right: 12),
                                            //     child: InkWell(
                                            //       onTap: () async {
                                            //         Navigator.push(
                                            //           context,
                                            //           MaterialPageRoute<void>(
                                            //             builder:
                                            //                 (BuildContext context) =>
                                            //                     TabsViewPage(),
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
                                            //             size: 16,
                                            //           ),
                                            //         ),
                                            //       ),
                                            //     )),
                                            state.status ==
                                                        HomePageStatus.idle ||
                                                    (state.status ==
                                                            HomePageStatus
                                                                .success &&
                                                        state.replyStatus !=
                                                            HomeReplyStatus
                                                                .loading)
                                                ? IconButton(
                                                    padding: EdgeInsets.zero,
                                                    visualDensity:
                                                        VisualDensity(
                                                            horizontal: -4),
                                                    onPressed: () {
                                                      print(
                                                          state.selectedModel);
                                                      FocusScope.of(context)
                                                          .unfocus();

                                                      String taskText =
                                                          taskTextController
                                                              .text;

                                                      if (isTaskValid) {
                                                        if (state
                                                                .isSearchMode ==
                                                            true) {
                                                          taskTextController
                                                              .text = "";
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
                                                          taskTextController
                                                              .text = "";
                                                          context
                                                              .read<HomeBloc>()
                                                              .add(
                                                                state.searchType ==
                                                                        HomeSearchType
                                                                            .map
                                                                    ? HomeUpdateMapAnswer(
                                                                        taskText,
                                                                        state
                                                                            .loadingIndex,
                                                                        streamedText,
                                                                        imageDescription
                                                                            .value,
                                                                        imageDescription,
                                                                        extractedUrlDescription,
                                                                        extractedUrlTitle,
                                                                        extractedUrl,
                                                                        extractedImageUrl)
                                                                    : HomeUpdateAnswer(
                                                                        taskText,
                                                                        state
                                                                            .loadingIndex,
                                                                        streamedText,
                                                                        imageDescription
                                                                            .value,
                                                                        imageDescription,
                                                                        extractedUrlDescription,
                                                                        extractedUrlTitle,
                                                                        extractedUrl,
                                                                        extractedImageUrl),
                                                              );
                                                        } else {
                                                          taskTextController
                                                              .text = "";

                                                          context
                                                              .read<HomeBloc>()
                                                              .add(
                                                                state.searchType ==
                                                                        HomeSearchType
                                                                            .portal
                                                                    ? HomePortalSearch(
                                                                        taskText)
                                                                    : state.searchType ==
                                                                            HomeSearchType
                                                                                .map
                                                                        ? HomeGetMapAnswer(
                                                                            taskText,
                                                                            streamedText,
                                                                            imageDescription.value,
                                                                            imageDescription,
                                                                            extractedUrlDescription,
                                                                            extractedUrlTitle,
                                                                            extractedUrl,
                                                                            extractedImageUrl)
                                                                        : HomeGetAnswer(
                                                                            taskText,
                                                                            streamedText,
                                                                            extractedUrlDescription,
                                                                            extractedUrlTitle,
                                                                            extractedUrl,
                                                                            extractedImageUrl,
                                                                            imageDescription.value,
                                                                            imageDescription,
                                                                          ),
                                                              );
                                                        }
                                                        setState(() {
                                                          isTaskValid = false;
                                                        });
                                                        Future.delayed(Duration(
                                                                milliseconds:
                                                                    500))
                                                            .then((onValue) {
                                                          _scrollController.animateTo(
                                                              _scrollController
                                                                  .position
                                                                  .maxScrollExtent,
                                                              duration: Duration(
                                                                  milliseconds:
                                                                      300),
                                                              curve: Curves
                                                                  .easeOut);
                                                        });
                                                      }
                                                    },
                                                    icon: Container(
                                                      margin: EdgeInsets.only(
                                                          left: 0, bottom: 0),
                                                      decoration: BoxDecoration(
                                                        color: isTaskValid ==
                                                                true
                                                            ? Color(0xFF8A2BE2)
                                                            : Color(0xFFC99DF2),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding:
                                                          EdgeInsets.all(10),
                                                      child: Icon(
                                                        Iconsax.send_1_bold,
                                                        color:
                                                            Color(0xFFDFFF00),
                                                        size: 16,
                                                      ),
                                                    ))
                                                : IconButton(
                                                    padding: EdgeInsets.zero,
                                                    visualDensity:
                                                        VisualDensity(
                                                            horizontal: -4),
                                                    onPressed: () {
                                                      FocusScope.of(context)
                                                          .unfocus();
                                                      context
                                                          .read<HomeBloc>()
                                                          .add(
                                                            HomeCancelTaskGen(),
                                                          );
                                                      mixpanel.track(
                                                          "cancel_search");
                                                      isTaskValid = false;
                                                    },
                                                    icon: Container(
                                                      margin: EdgeInsets.only(
                                                          left: 0, bottom: 0),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Color(0xFF8A2BE2),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding:
                                                          EdgeInsets.all(10),
                                                      child: Icon(
                                                        Icons.stop,
                                                        color:
                                                            Color(0xFFDFFF00),
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
                            ],
                          ),
                        ),
                      ],
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
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(40),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(40),
                                            color: Color(0xFF8A2BE2)),
                                        child: state.isIncognito
                                            ? Icon(
                                                RemixIcons.spy_line,
                                                color: Color(0xFFDFFF00),
                                                size: 40,
                                              )
                                            : Image.asset(
                                                "assets/images/logo/icon.png",
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 5),
                                Container(
                                  width: MediaQuery.of(context).size.width - 40,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      state.isIncognito
                                          ? Text(
                                              textAlign: TextAlign.center,
                                              "Incognito Mode",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 20,
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            )
                                          : Text(
                                              "How may I help you?",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 20,
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ],
                                  ),
                                )
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
                                                      .threadData.isIncognito,
                                                  onGraphImageTap:
                                                      (String query) {
                                                    context
                                                        .read<HomeBloc>()
                                                        .add(
                                                          HomeGetSearch(
                                                              query, "web"),
                                                        );
                                                  },
                                                  onTabChanged: (String type) {
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
                                                  answerBox: result.answerBox,
                                                  web: result.web,
                                                  query: result.userQuery,
                                                  shortVideos:
                                                      result.shortVideos,
                                                  videos: result.videos,
                                                  news: result.news,
                                                  images: result.images,
                                                  status: state.loadingIndex ==
                                                          index
                                                      ? state.status
                                                      : HomePageStatus.success)
                                              : ValueListenableBuilder(
                                                  valueListenable: streamedText,
                                                  builder: (context, value, _) {
                                                    return ThreadAnswerView(
                                                      extractedUrlData: result
                                                          .extractedUrlData,
                                                      local: result.local,
                                                      sourceImageUrl: result
                                                          .sourceImageLink,
                                                      answerResults:
                                                          result.influence,
                                                      query: result.userQuery,
                                                      answer:
                                                          state.loadingIndex ==
                                                                  index
                                                              ? value
                                                              : result.answer,
                                                      hideRefresh: index !=
                                                              state
                                                                      .threadData
                                                                      .results
                                                                      .length -
                                                                  1
                                                          ? true
                                                          : false,
                                                      onLinkTap: (url) {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) {
                                                              return WebViewPage(
                                                                url: url,
                                                              );
                                                            },
                                                          ),
                                                        );
                                                      },
                                                      onEditSelected: () {
                                                        imageDescription.value =
                                                            result
                                                                .sourceImageDescription;
                                                        context
                                                            .read<HomeBloc>()
                                                            .add(
                                                              SelectEditInputOption(
                                                                result
                                                                    .userQuery,
                                                                true,
                                                                state.threadData
                                                                    .results
                                                                    .indexOf(
                                                                        result),
                                                                result
                                                                    .isSearchMode,
                                                                result
                                                                    .sourceImageLink,
                                                              ),
                                                            );
                                                        taskTextController
                                                                .text =
                                                            result.userQuery;
                                                        isTaskValid = true;
                                                        //FocusManager.instance.primaryFocus?.unfocus();
                                                      },
                                                      onRefresh: () {
                                                        context
                                                            .read<HomeBloc>()
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
                                                      replyStatus:
                                                          state.loadingIndex ==
                                                                  index
                                                              ? state
                                                                  .replyStatus
                                                              : HomeReplyStatus
                                                                  .success,
                                                    );
                                                  }),
                                          if (index <
                                              state.threadData.results.length -
                                                  1)
                                            Divider(
                                              color: Colors.grey.shade300,
                                              thickness: 0.5,
                                              height: 40,
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            )),
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

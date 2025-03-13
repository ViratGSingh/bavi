import 'dart:async';
import 'package:bavi/addVideo/bloc/add_video_bloc.dart';
import 'package:bavi/addVideo/bloc/add_video_state.dart';
import 'package:bavi/addVideo/widgets/video_screen.dart';
import 'package:bavi/models/collection.dart';
import 'package:bavi/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:bavi/addVideo/widgets/tutorial_carousel.dart';
import 'package:bavi/dialogs/warning.dart';

class AddVideoPage extends StatefulWidget {
  const AddVideoPage({super.key});

  @override
  State<AddVideoPage> createState() => _AddVideoPageState();
}

class _AddVideoPageState extends State<AddVideoPage> {
  FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  TextEditingController _textController = TextEditingController();

  Future<void> copyClipboard() async {
    await Clipboard.getData(Clipboard.kTextPlain).then((clipboardData) {
      if (clipboardData != null && clipboardData.text != _textController.text) {
        _textController.text = clipboardData.text ?? "";
        print("Copied text: ${_textController.text}");
        setState(() {});
        context.read<AddVideoBloc>().add(
              AddVideoCheckLink(_textController.text),
            );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<AddVideoBloc>().add(
          AddVideoReset(),
        );
    context.read<AddVideoBloc>().add(
          AddVideoFetchCollections(),
        );
    _focusNode.addListener(_onFocusChange);
    copyClipboard();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _clearText() {
    setState(() {
      _textController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddVideoBloc, AddVideoState>(builder: (context, state) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          Clipboard.setData(ClipboardData(text: ""));
          navService.goTo('/home');
        },
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: state.status == AddVideoStatus.success
                ? null
                : AppBar(
                    elevation: 1,
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    shadowColor: Colors.black,
                    leadingWidth: 70,
                    leading: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: ""));
                        navService.goTo('/home');
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
                      'Add Video',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF090E1D),
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    //automaticallyImplyLeading: false,
                    centerTitle: true,
                  ),
            body: state.status == AddVideoStatus.success
                ? VideoPlayerWidget(
                    videoId: state.videoId!,
                    collections: state.collectionsInfo ?? [],
                    videoUrl:
                        state.extractedVideoInfo?.videoData.videoUrl ?? "",
                    onSave: (List<VideoCollectionInfo> updCollections) {
                      context.read<AddVideoBloc>().add(
                            AddVideoUpdateCollections(
                                updCollections,
                                state.extractedVideoInfo!,
                                state.videoId!,
                                state.platform!),
                          );
                    },
                    onBack: () {
                      context.read<AddVideoBloc>().add(
                            AddVideoReset(),
                          );
                    })
                : state.status == AddVideoStatus.loading
                    ? Center(
                        child: Container(
                          width: 42,
                          height: 42,
                          child: CircularProgressIndicator(
                            color: Color(0xFF8A2BE2),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width,
                              height: 56,
                              padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                              decoration: ShapeDecoration(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                      width: 1, color: Color(0xFF090E1D)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                shadows: _isFocused
                                    ? [
                                        BoxShadow(
                                          color: Color(0xFF080E1D),
                                          blurRadius: 0,
                                          offset: Offset(0, 4),
                                          spreadRadius: 0,
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      focusNode: _focusNode,
                                      controller: _textController,
                                      onChanged: (value) {
                                        setState(() {});
                                        context.read<AddVideoBloc>().add(
                                              AddVideoCheckLink(value),
                                            );
                                      },
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Enter link',
                                      ),
                                    ),
                                  ),
                                  if (_textController.text.isNotEmpty)
                                    IconButton(
                                      icon: Icon(Icons.close, size: 20),
                                      onPressed: _clearText,
                                    ),
                                ],
                              ),
                            ),
                            TutorialCarousel(tutorialLinks: [
                              context
                                  .read<AddVideoBloc>()
                                  .instagramTutorialVideoUrl,
                              context
                                  .read<AddVideoBloc>()
                                  .youtubeTutorialVideoUrl,
                            ]),
                            ElevatedButton(
                              onPressed: _textController.text == ""
                                  ? null
                                  : () {
                                      if (state.isValidLink == false) {
                                        showDialog(
                                            context: context,
                                            builder: (context) => WarningPopup(
                                                  title: "Error",
                                                  message:
                                                      "Please enter a valid Instagram Reel or YouTube Short link to continue",
                                                  action: "Okay",
                                                  popupColor: Color(0xFF8A2BE2),
                                                  isInfo: true,
                                                  popupIcon: Icons.info,
                                                  actionFunc: () {
                                                    Navigator.pop(context);
                                                  },
                                                  cancelText: "Cancel",
                                                ));
                                      } else {
                                        context.read<AddVideoBloc>().add(
                                              AddVideoExtract(
                                                  _textController.text),
                                            );
                                      }
                                    },
                              style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(
                                    _textController.text == ""
                                        ? Color(0xFFF3EAFC)
                                        : Color(0xFF8A2BE2),
                                  ),
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      side: BorderSide(
                                          width: 1, color: Colors.white),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  fixedSize: WidgetStatePropertyAll(
                                    Size(MediaQuery.of(context).size.width, 56),
                                  )),
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  color: _textController.text == ""
                                      ? Color(0xFFC99DF2)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
      );
    });
  }
}

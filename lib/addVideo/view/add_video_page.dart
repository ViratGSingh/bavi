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
  final bool isOnboarding;
  const AddVideoPage({super.key, this.isOnboarding = false});

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
          AddVideoInitiateMixpanel(),
        );
    if (widget.isOnboarding) {
      _textController.text = "https://www.instagram.com/reels/DE2XfdvS5ld";
      context.read<AddVideoBloc>().add(
            AddVideoExtract(_textController.text, widget.isOnboarding),
          );
    } else {
      context.read<AddVideoBloc>().add(
            AddVideoReset(),
          );
      context.read<AddVideoBloc>().add(
            AddVideoFetchCollections(),
          );
    }

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
          if (widget.isOnboarding == false) {
            Clipboard.setData(ClipboardData(text: ""));
            navService.goTo('/home');
          }
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
                        if (state.status == AddVideoStatus.success) {
                          context.read<AddVideoBloc>().add(
                                AddVideoReset(),
                              );
                        } else {
                          //Clipboard.setData(ClipboardData(text: ""));
                          navService.goTo('/home');
                        }
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
                    isOnboarding: widget.isOnboarding,
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
                    ? ValueListenableBuilder(
                        valueListenable:
                            context.read<AddVideoBloc>().videoProgress,
                        builder: (context, value, _) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                state.extractedVideoInfo == null
                                    ? Container(
                                        width: 42,
                                        height: 42,
                                        child: CircularProgressIndicator(
                                          value: null,
                                          color: Color(0xFF8A2BE2),
                                        ),
                                      )
                                    : context
                                                .read<AddVideoBloc>()
                                                .videoProgress
                                                .value !=
                                            1
                                        ?
                                        //Show video progress

                                        ValueListenableBuilder(
                                            valueListenable: context
                                                .read<AddVideoBloc>()
                                                .videoProgress,
                                            builder: (context, value, _) {
                                              return Container(
                                                width: 42,
                                                height: 42,
                                                child:
                                                    CircularProgressIndicator(
                                                  value: context
                                                      .read<AddVideoBloc>()
                                                      .videoProgress
                                                      .value,
                                                  backgroundColor: Colors.grey[
                                                      300], // light grey track
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Color(0xFF8A2BE2)),
                                                ),
                                              );
                                            })
                                        :
                                        //Show image progress

                                        ValueListenableBuilder(
                                            valueListenable: context
                                                .read<AddVideoBloc>()
                                                .imageProgress,
                                            builder: (context, value, _) {
                                              return Container(
                                                width: 42,
                                                height: 42,
                                                child:
                                                    CircularProgressIndicator(
                                                  value: context
                                                      .read<AddVideoBloc>()
                                                      .imageProgress
                                                      .value,
                                                   backgroundColor: Colors.grey[
                                                      300], // light grey track
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Color(0xFF8A2BE2)),
                                                ),
                                              );
                                            }),
                                SizedBox(height: 15),
                                Text(
                                  state.extractedVideoInfo == null
                                      ? "Extracting video from ${_textController.text.contains("instagram") ? "Instagram" : "YouTube"}"
                                      : context
                                                  .read<AddVideoBloc>()
                                                  .videoProgress
                                                  .value !=
                                              1
                                          ?
                                          //Show video progress
                                          "Saving Video"
                                          :
                                          //Show image progress
                                          "Saving Thumbnail",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                  ),
                                )
                              ],
                            ),
                          );
                        })
                    : SingleChildScrollView(
                        child: Container(
                          height: MediaQuery.of(context).size.height -
                              50 -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom,
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
                                // context
                                //     .read<AddVideoBloc>()
                                //     .youtubeTutorialVideoUrl,
                              ]),
                              ElevatedButton(
                                onPressed: _textController.text == ""
                                    ? null
                                    : () {
                                        if (state.isValidLink == false) {
                                          showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  WarningPopup(
                                                    title: "Error",
                                                    message:
                                                        "Please enter a valid short video link to continue",
                                                    action: "Okay",
                                                    popupColor:
                                                        Color(0xFF8A2BE2),
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
                                                    _textController.text,
                                                    false),
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
                                      Size(MediaQuery.of(context).size.width,
                                          56),
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
        ),
      );
    });
  }
}

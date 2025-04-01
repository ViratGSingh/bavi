import 'package:bavi/models/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

List<VideoCollectionInfo> sortedCollections(
    List<VideoCollectionInfo> collections, Map<int, bool> selectedStates) {
  // Separate the "All" collection
  VideoCollectionInfo? allCollection = collections.firstWhere(
    (collection) => collection.collectionId == -1,
    orElse: () => null!,
  );

  // Separate selected and unselected collections
  List<VideoCollectionInfo> selectedCollections = collections
      .where((collection) =>
          selectedStates[collection.collectionId] == true &&
          collection.collectionId != -1)
      .toList();

  List<VideoCollectionInfo> unselectedCollections = collections
      .where((collection) =>
          selectedStates[collection.collectionId] == false ||
          collection.collectionId == -1)
      .toList();

  // Combine the lists: "All" collection first, then selected collections, then unselected collections
  List<VideoCollectionInfo> sortedList = [];
  if (allCollection != null) {
    sortedList.add(allCollection);
  }
  sortedList.addAll(selectedCollections);
  sortedList.addAll(unselectedCollections);

  return sortedList;
}

void showCollections(
    BuildContext context,
    List<VideoCollectionInfo> collections,
    String videoId,
    final Function(List<VideoCollectionInfo> updCollections) onSave,
    bool isOnboarding
    ) {
  // Maintain a map to keep track of selected states
  Map<int, bool> selectedStates = {};

  // Initialize selected states for existing collections
  for (var collection in collections) {
    selectedStates[collection.collectionId] = collection.videos.contains(videoId);
  }

   // Create a ScrollController
  final ScrollController _scrollController = ScrollController();

  // Function to sort collections
  List<VideoCollectionInfo> sortedCollections(List<VideoCollectionInfo> collections, Map<int, bool> selectedStates) {
    // Separate the "All" collection
    VideoCollectionInfo? allCollection = collections.firstWhere(
      (collection) => collection.collectionId == -1,
      orElse: () => null!,
    );

    // Separate selected and unselected collections
    List<VideoCollectionInfo> selectedCollections = collections
        .where((collection) => selectedStates[collection.collectionId] == true && collection.collectionId != -1)
        .toList();

    List<VideoCollectionInfo> unselectedCollections = collections
        .where((collection) => selectedStates[collection.collectionId] == false || collection.collectionId == -1)
        .toList();

    // Combine the lists: "All" collection first, then selected collections, then unselected collections
    List<VideoCollectionInfo> sortedList = [];
    if (allCollection != null) {
      sortedList.add(allCollection);
    }
    sortedList.addAll(selectedCollections);
    sortedList.addAll(unselectedCollections);

    return sortedList;
  }

  void saveInfo() {
    VideoCollectionInfo allCollectionInfo = VideoCollectionInfo(
      collectionId: -1,
      name: "All",
      type: CollectionStatus.public,
      videos: [CollectionVideoData(videoId: videoId, createdAt: Timestamp.now(), updatedAt: Timestamp.now())],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    List<VideoCollectionInfo> updCollectionsInfo = [];

    if (collections.isNotEmpty) {
      // If custom collections are present
      for (VideoCollectionInfo collection in collections) {
        List<String> videoIdList = collection.videos.map((video) => video.videoId).toList();
        CollectionVideoData newcollectionVideoData = CollectionVideoData(videoId: videoId, createdAt: Timestamp.now(), updatedAt: Timestamp.now());

        if (collection.collectionId == -1) {
          // Add new video
          if (videoIdList.contains(videoId) == false) {
            collection.videos.add(newcollectionVideoData);
            collection.updatedAt = Timestamp.now();
          }
          updCollectionsInfo.add(collection);
        } else {
          // Add extracted video in selected collections
          if (selectedStates[collection.collectionId] == true) {
            if (videoIdList.contains(videoId) == false) {
              collection.videos.add(newcollectionVideoData);
              collection.updatedAt = Timestamp.now();
            }
          } else {
            if (videoIdList.contains(videoId) == true) {
              collection.videos.remove(newcollectionVideoData);
            }
          }
          updCollectionsInfo.add(collection);
        }
      }
    } else {
      updCollectionsInfo.add(allCollectionInfo);
    }
    Navigator.pop(context);
    onSave(updCollectionsInfo);
  }

  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20.0), // Rounded top edges
    ),
    ),
    backgroundColor: Color(0xFF8A2BE2),
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.5,
    ),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          // Sort collections to show selected ones first
          List<VideoCollectionInfo> sortedList = collections.isEmpty?[]:sortedCollections(collections, selectedStates);

          return Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title and "New Collection" button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Collections',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Visibility(
                      visible: !isOnboarding,
                      child: TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return Dialog(
                                backgroundColor: Colors.transparent, // Transparent dialog background
                                insetPadding: EdgeInsets.all(0), // Padding around the dialog
                                child: NewCollectionScreen(
                                  onCreate: (newCollection) {
                                    setState(() {
                                      collections.add(newCollection);
                                      selectedStates[newCollection.collectionId] = true; // Automatically select the new collection
                                      // Scroll to the top after adding a new collection
                                      _scrollController.animateTo(
                                        0,
                                        duration: Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    });
                                  },
                                  newCollectionId: collections.isEmpty ? 0 : collections.length,
                                ),
                              );
                            },
                          );
                        },
                        style: ButtonStyle(
                          padding: WidgetStatePropertyAll(EdgeInsets.zero),
                        ),
                        child: Text(
                          'New Collection',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Color(0xFFDFFF00),
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Checklist
                Container(
                  child: sortedList.isEmpty
                      ? CollectionTypeTile(defaultSelected: true)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              height: MediaQuery.of(context).size.height / 4,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  children: [
                                    CollectionTypeTile(defaultSelected: true),
                                    ListView(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      children: sortedList.map((info) {
                                        return info.collectionId == -1
                                            ? SizedBox.shrink()
                                            : CollectionTypeTile(
                                                info: info,
                                                isSelected: selectedStates[info.collectionId] ?? false,
                                                onSelected: (bool selected) {
                                                  setState(() {
                                                    selectedStates[info.collectionId] = selected;
                                                  });
                                                },
                                              );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, // Full width
                  child: ElevatedButton(
                    onPressed: () {
                      saveInfo();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, // Button color
                      disabledBackgroundColor: Color(0xFFE6E7E8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Rounded corners
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16), // Button padding
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        color: Color.fromRGBO(9, 14, 29, 1),
                        fontSize: 16,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  )
  ;
}

class NewCollectionScreen extends StatefulWidget {
  const NewCollectionScreen(
      {super.key, required this.onCreate, required this.newCollectionId});
  final Function(VideoCollectionInfo newCollection) onCreate;
  final int newCollectionId;

  @override
  State<NewCollectionScreen> createState() => _NewCollectionScreenState();
}

class _NewCollectionScreenState extends State<NewCollectionScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    // Focus on the TextField when the screen is opened
    _focusNode.requestFocus();

    // Listen to changes in the TextField
    _textController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Update the button state based on text input
  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _textController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Bottom Sheet Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(15, 20, 15, 20), // Overall padding
              decoration: BoxDecoration(
                color: Color(0xFF8A2BE2), // Background color of the container
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ), // Rounded corners only at the top
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Collection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon:
                              Icon(Icons.cancel_outlined, color: Colors.white),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the screen
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10), // Spacing between title and text field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: TextField(
                      controller: _textController, // Controller for text input
                      focusNode: _focusNode, // Focus node for auto-focus
                      cursorColor: Colors.white,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter collection name',
                        hintStyle: TextStyle(
                          color: Color(0xFFe6e7e8),
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none, // No underline or borders
                        contentPadding:
                            EdgeInsets.zero, // Remove default padding
                      ),
                    ),
                  ),
                  SizedBox(height: 20), // Spacing between text field and button
                  // Rounded Rectangle Button
                  Padding(
                    padding: const EdgeInsets.only(left: 5, right: 10),
                    child: SizedBox(
                      width: double.infinity, // Full width
                      child: ElevatedButton(
                        onPressed: _isButtonEnabled
                            ? () {
                                widget.onCreate(VideoCollectionInfo(
                                    collectionId: widget.newCollectionId,
                                    name: _textController.text,
                                    type: CollectionStatus.public,
                                    videos: [],
                                    createdAt: Timestamp.now(),
                                    updatedAt: Timestamp.now()));
                                Navigator.of(context).pop();
                              }
                            : null, // Disable button if text is empty
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // Button color
                          disabledBackgroundColor: Color(0xFFE6E7E8),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12), // Rounded corners
                          ),
                          padding: EdgeInsets.symmetric(
                              vertical: 16), // Button padding
                        ),
                        child: Text(
                          'Create',
                          style: TextStyle(
                            color: _isButtonEnabled
                                ? Color(0xFF090E1D)
                                : Color(0xFF8E9097),
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CollectionTypeTile extends StatefulWidget {
  final bool defaultSelected;
  final bool isSelected;
  final VideoCollectionInfo? info;
  final Function(bool)? onSelected;

  const CollectionTypeTile({
    super.key,
    this.info,
    this.isSelected = false,
    this.defaultSelected = false,
    this.onSelected,
  });

  @override
  State<CollectionTypeTile> createState() => _CollectionTypeTileState();
}

class _CollectionTypeTileState extends State<CollectionTypeTile> {
  late bool isSelected;

  @override
  void initState() {
    super.initState();
    if (widget.defaultSelected == false) {
      isSelected = widget.isSelected;
    } else {
      isSelected = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero, // Remove default padding
      onTap: () {
        if (widget.defaultSelected == false) {
          setState(() {
            isSelected = !isSelected;
          });
          widget.onSelected?.call(isSelected);
        }
      },
      trailing: isSelected == false
          ? Icon(
              Icons.circle,
              color: Colors.white,
              size: 24,
            )
          : CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 24,
              ),
            ),
      title: widget.defaultSelected == true
          ? Text(
              "All",
              style: TextStyle(
                color: Color(0xFFF3EAFC),
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
              ),
            )
          : Text(
              widget.info?.name ?? "",
              style: TextStyle(
                color: Color(0xFFF3EAFC),
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
              ),
            ),
    );
  }
}

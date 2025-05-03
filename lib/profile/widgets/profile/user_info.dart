import 'package:bavi/models/collection.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/profile/widgets/profile/collection_videos.dart';
import 'package:bavi/profile/widgets/video_grid.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:icons_plus/icons_plus.dart';

class UserInfoView extends StatefulWidget {
  const UserInfoView(
      {super.key,
      required this.userData,
      required this.userAllVideos,
      required this.collectionsVideos,
      required this.collections,
      required this.onSignOut,
      this.initialIndex = 0,
      required this.platformData});

  final Map<String, dynamic> platformData;
  final UserProfileInfo userData;
  final List<ExtractedVideoInfo> userAllVideos;
  final List<List<ExtractedVideoInfo>> collectionsVideos;
  final List<VideoCollectionInfo> collections;
  final int initialIndex;
  final Function() onSignOut;
  @override
  State<UserInfoView> createState() => _UserInfoViewState();
}

class _UserInfoViewState extends State<UserInfoView> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initMixpanel();
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      child: Column(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            padding: EdgeInsets.fromLTRB(20, 20, 10, 20),
            color: Color(0xFF8A2BE2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircularAvatarWithShimmer(
                        imageUrl: widget.userData.profilePicUrl),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width:
                              (2 * MediaQuery.of(context).size.width / 3) - 40,
                          child: Text(
                            widget.userData.fullname,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width:
                              (2 * MediaQuery.of(context).size.width / 3) - 40,
                          child: Text(
                            "@${widget.userData.username}",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                // IconButton(
                //   onPressed: () {
                //     navService.goTo("/settings");
                //   },
                //   icon: Icon(Iconsax.setting_2_bold,
                //       color: Color(0xFFDFFF00), size: 24),
                // )
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              initialIndex: widget.initialIndex,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: Color(0xFF8A2BE2),
                    labelColor: Color(0xFF8A2BE2),
                    unselectedLabelColor: Colors.black,
                    indicatorWeight: 2,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: TextStyle(
                      color: Color(0xFF090E1D),
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                    unselectedLabelStyle: TextStyle(
                      color: Color(0xFF090E1D),
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(
                        text: 'Videos',
                      ),
                      Tab(
                        text: 'Collections',
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Videos tab content
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: VideoGridScreen(
                              savedVideos: widget.userAllVideos,
                              isLoading: false,
                              platformData: widget.platformData,
                              collection: widget.collections.isEmpty?null:widget.collections.first),
                        ),

                        // Collections tab content
                        Container(
                          padding: EdgeInsets.all(20),
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: widget.collections.length,
                            itemBuilder: (context, index) {
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CollectionVideosPage(
                                        videos: widget.collectionsVideos[index],
                                        collection: widget.collections[index],
                                      ),
                                    ),
                                  );
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Video thumbnail
                                    widget.collectionsVideos[index].isNotEmpty
                                        ? Container(
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              shadows: [
                                                BoxShadow(
                                                  color: Color(0x3F000000),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 4),
                                                  spreadRadius: 0,
                                                )
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  CachedNetworkImage(
                                                    imageUrl: widget
                                                        .collectionsVideos[
                                                            index]
                                                        .first
                                                        .videoData
                                                        .thumbnailUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Shimmer.fromColors(
                                                      baseColor:
                                                          Colors.grey[300]!,
                                                      highlightColor:
                                                          Colors.grey[100]!,
                                                      child: Container(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Icon(
                                                      Iconsax.save_2_outline,
                                                      color: Colors.black,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey[300],
                                          ),

                                    // Collection name
                                    Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Padding(
                                        padding: EdgeInsets.all(10.0),
                                        child: Text(
                                          widget.collections[index].name,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

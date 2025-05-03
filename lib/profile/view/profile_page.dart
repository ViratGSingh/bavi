import 'package:bavi/navigation_service.dart';
import 'package:bavi/profile/bloc/profile_bloc.dart';
import 'package:bavi/profile/widgets/profile/collection_videos.dart';
import 'package:bavi/profile/widgets/profile/user_info.dart';
import 'package:bavi/profile/widgets/video_grid.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:http/http.dart' as http;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shimmer/shimmer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
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
    mixpanel.track("profile_view");
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProfileBloc(httpClient: http.Client())..add(ProfileFetchAllVideos()),
      child: BlocBuilder<ProfileBloc, ProfileState>(builder: (context, state) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              elevation: 1,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shadowColor: Colors.black,
              leadingWidth: 80,
              leading: InkWell(
                onTap: () {
                  Navigator.pop(context, 1);
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
                "Profile",
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
            body: Container(
              height: MediaQuery.of(context).size.height,
              child: Column(
                children: [
                  state.status == ProfilePageStatus.loading
                      ? CircularProgressIndicator()
                      : Container(
                          width: MediaQuery.of(context).size.width,
                          padding: EdgeInsets.fromLTRB(20, 20, 10, 20),
                          color: Colors.white,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircularAvatarWithShimmer(
                                      imageUrl: state.userData.profilePicUrl),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: (2 *
                                                MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                3) -
                                            40,
                                        child: Text(
                                          state.userData.fullname,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 20,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: (2 *
                                                MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                3) -
                                            40,
                                        child: Text(
                                          "@${state.userData.username}",
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.black,
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
                              IconButton(
                                onPressed: () {
                                  navService.goTo("/settings");
                                },
                                icon: Icon(Iconsax.setting_2_bold,
                                    color: Colors.black, size: 24),
                              )
                            ],
                          ),
                        ),
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      //initialIndex: initialIndex,
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
                                      savedVideos: state.videos,
                                      isLoading: false,
                                      platformData: state.allVideoPlatformData,
                                      collection: state.collections.isEmpty
                                          ? null
                                          : state.collections.first),
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
                                    itemCount: state.collections.length,
                                    itemBuilder: (context, index) {
                                      return InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CollectionVideosPage(
                                                videos: state
                                                    .collectionsVideos[index],
                                                collection:
                                                    state.collections[index],
                                              ),
                                            ),
                                          );
                                        },
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // Video thumbnail
                                            state.collectionsVideos[index]
                                                    .isNotEmpty
                                                ? Container(
                                                    decoration: ShapeDecoration(
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      shadows: [
                                                        BoxShadow(
                                                          color:
                                                              Color(0x3F000000),
                                                          blurRadius: 4,
                                                          offset: Offset(0, 4),
                                                          spreadRadius: 0,
                                                        )
                                                      ],
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      child: Stack(
                                                        fit: StackFit.expand,
                                                        children: [
                                                          CachedNetworkImage(
                                                            imageUrl: state
                                                                .collectionsVideos[
                                                                    index]
                                                                .first
                                                                .videoData
                                                                .thumbnailUrl,
                                                            fit: BoxFit.cover,
                                                            placeholder: (context,
                                                                    url) =>
                                                                Shimmer
                                                                    .fromColors(
                                                              baseColor: Colors
                                                                  .grey[300]!,
                                                              highlightColor:
                                                                  Colors.grey[
                                                                      100]!,
                                                              child: Container(
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                            errorWidget:
                                                                (context, url,
                                                                        error) =>
                                                                    Icon(
                                                              Iconsax
                                                                  .save_2_outline,
                                                              color:
                                                                  Colors.black,
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
                                                  state.collections[index].name,
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
            ),
          ),
        );
      }),
    );
  }
}

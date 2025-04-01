import 'package:bavi/addVideo/view/add_video_page.dart';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/widgets/home/video_activity.dart';
import 'package:bavi/home/widgets/player/collection_player.dart';
import 'package:bavi/home/widgets/profile/profile_page.dart';
import 'package:bavi/home/widgets/search/video_search.dart';
import 'package:bavi/home/widgets/video_grid.dart';
import 'package:bavi/login/view/login_page.dart';
import 'package:bavi/models/collection.dart';
import 'package:bavi/navigation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initMixpanel();
    context.read<HomeBloc>().add(
          HomeDetectExtractVideoLink(),
        );
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          HomeBloc(httpClient: http.Client())..add(HomeFetchAllVideos()),
      child: BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            bottomNavigationBar: BottomAppBar(
              // shape: CircularNotchedRectangle(),
              // notchMargin: 8.0,
              height: 60,
              padding: EdgeInsets.zero,
              color: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              state.page == NavBarOption.home
                                  ? Iconsax.home_1_bold
                                  : Iconsax.home_1_outline,
                              color: Colors.black),
                          Text(
                            'Home',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight:  state.page == NavBarOption.home
                                    ?FontWeight.bold:FontWeight.normal),
                          ),
                        ],
                      ),
                      onPressed: () {
                        context.read<HomeBloc>().add(
                              HomeNavOptionSelect(NavBarOption.home),
                            );
                        mixpanel.track("home_view");
                      },
                    ),
                    IconButton(
                      icon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              state.page == NavBarOption.search
                                  ? Iconsax.search_normal_bold
                                  : Iconsax.search_normal_outline,
                              color: Colors.black),
                          Text(
                            'Search',
                            style: TextStyle(
                                color:Colors.black,
                                fontSize: 12,
                                fontWeight:  state.page == NavBarOption.search
                                    ? FontWeight.bold:FontWeight.normal),
                          ),
                        ],
                      ),
                      onPressed: () {
                        context.read<HomeBloc>().add(
                              HomeNavOptionSelect(NavBarOption.search),
                            );
                        mixpanel.track("search_view");
                      },
                    ),
                    IconButton(
                      icon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                color: Color(0xFF8A2BE2),
                                borderRadius: BorderRadius.circular(4)),
                            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                            child: Icon(
                              Iconsax.archive_add_bold,
                              size: 16,
                              color: Color(0xFFDFFF00),
                            ),
                          ),
                          Text(
                            'Add Video',
                            style: TextStyle(
                                color:Colors.black,
                                fontSize: 12,
                                fontWeight:  FontWeight.normal),
                          ),
                        ],
                      ),
                      onPressed: () {
                        navService.goTo("/addVideo");
                        mixpanel.track("add_video_view");
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute<void>(
                        //     builder: (BuildContext context) => AddVideoPage(),
                        //   ),
                        // );
                      },
                    ),
                    IconButton(
                      icon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            state.page == NavBarOption.player
                                ? Iconsax.video_play_bold
                                : Iconsax.video_play_outline,
                            color: Colors.black,
                          ),
                          Text(
                            'Plsyer',
                            style: TextStyle(
                                color:  Colors.black,
                                fontSize: 12,
                                fontWeight: state.page == NavBarOption.player
                                    ?FontWeight.bold:FontWeight.normal),
                          ),
                        ],
                      ),
                      onPressed: () {
                        context.read<HomeBloc>().add(
                              HomeNavOptionSelect(NavBarOption.player),
                            );
                        mixpanel.track("player_view");
                      },
                    ),
                    IconButton(
                      icon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              state.page == NavBarOption.profile
                                  ? Iconsax.frame_bold
                                  : Iconsax.frame_1_outline,
                              color: Colors.black),
                          Text(
                            'Profile',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: state.page == NavBarOption.profile
                                    ? FontWeight.bold:FontWeight.normal),
                          ),
                        ],
                      ),
                      onPressed: () {
                        context.read<HomeBloc>().add(
                              HomeNavOptionSelect(NavBarOption.profile),
                            );
                        mixpanel.track("profile_view");
                      },
                    ),
                  ],
                ),
              ),
            ),
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
            body: state.page == NavBarOption.profile
                ? ProfilePage(
                    userData: state.userData,
                    userAllVideos: state.videos,
                    collectionsVideos: state.collectionsVideos,
                    collections: state.collections,
                    platformData: state.allVideoPlatformData,
                    onSignOut: () {
                      context.read<HomeBloc>().add(
                            HomeAttemptGoogleSignOut(),
                          );
                    },
                  )
                : state.page == NavBarOption.search
                    ? VideoSearch(
                        videos: state.searchResults.isEmpty
                            ? state.videos
                            : state.searchResults,
                        isLoading: state.status == HomePageStatus.loading,
                        platformData: state.allVideoPlatformData,
                        collection: state.collections.isEmpty
                            ? VideoCollectionInfo(
                                collectionId: 0,
                                name: '',
                                type: CollectionStatus.public,
                                videos: [],
                                createdAt: Timestamp.now(),
                                updatedAt: Timestamp.now(),
                              )
                            : state.collections.first,
                        onSearch: (query) => context.read<HomeBloc>().add(
                              HomeSearchVideos(query),
                            ),
                      )
                    : state.page == NavBarOption.player
                        ? CollectionPlayerPage(
                            videoList: state.videos,
                            initialPosition: 0,
                            platform: state.allVideoPlatformData,
                            collectionsInfo: state.collections)
                        : state.page == NavBarOption.home &&
                                state.videos.isNotEmpty &&
                                state.status != HomePageStatus.loading
                            ? VideoActivityFeed(
                                videoList: state.videos,
                                initialPosition: 0,
                                platform: state.allVideoPlatformData,
                                collectionInfo: state.collections.isEmpty
                                    ? null
                                    : state.collections[0])
                            : Shimmer.fromColors(
                                baseColor: Colors.black,
                                highlightColor: Colors.black54,
                                child: Container(
                                  color: Colors.black,
                                ),
                              ),
          ),
        );
      }),
    );
  }
}

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
import 'package:icons_plus/icons_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

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
    context.read<HomeBloc>().add(
          HomeDetectExtractVideoLink(),
        );
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
              height: 50,
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
                          // Text(
                          //   'Home',
                          //   style: TextStyle(
                          //       color: state.page == NavBarOption.home
                          //           ? Colors.white: Color(0xFFe6e7e8),
                          //       fontSize: 12,
                          //       fontWeight: FontWeight.bold),
                          // ),
                        ],
                      ),
                      onPressed: () => context.read<HomeBloc>().add(
                            HomeNavOptionSelect(NavBarOption.home),
                          ),
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
                          // Text(
                          //   'Search',
                          //   style: TextStyle(
                          //       color: state.page == NavBarOption.search
                          //           ? Colors.white: Color(0xFFe6e7e8),
                          //       fontSize: 12,
                          //       fontWeight: FontWeight.bold),
                          // ),
                        ],
                      ),
                      onPressed: () => context.read<HomeBloc>().add(
                            HomeNavOptionSelect(NavBarOption.search),
                          ),
                    ),
                    IconButton(
                      icon: Container(
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
                      onPressed: () {
                        navService.goTo("/addVideo");
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
                          // Text(
                          //   'Saved',
                          //   style: TextStyle(
                          //       color: state.page == NavBarOption.saved
                          //           ? Colors.white:Color(0xFFe6e7e8),
                          //       fontSize: 12,
                          //       fontWeight: FontWeight.bold),
                          // ),
                        ],
                      ),
                      onPressed: () => context.read<HomeBloc>().add(
                            HomeNavOptionSelect(NavBarOption.player),
                          ),
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
                          // Text(
                          //   'Profile',
                          //   style: TextStyle(
                          //       color:state.page == NavBarOption.profile
                          //           ? Colors.white:Color(0xFFe6e7e8),
                          //       fontSize: 12,
                          //       fontWeight: FontWeight.bold),
                          // ),
                        ],
                      ),
                      onPressed: () => context.read<HomeBloc>().add(
                            HomeNavOptionSelect(NavBarOption.profile),
                          ),
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

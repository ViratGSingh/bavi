import 'package:bavi/addVideo/view/add_video_page.dart';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:bavi/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: BottomAppBar(
            // shape: CircularNotchedRectangle(),
            // notchMargin: 8.0,
            height: 50,
            padding: EdgeInsets.zero,
            color: Color(0xFF8A2BE2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          state.page == NavBarOption.home
                              ? Icons.home
                              : Icons.home_outlined,
                          color: Colors.white),
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
                              ? Icons.search
                              : Icons.search_outlined,
                          color: Colors.white),
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
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_box_outlined,
                        color: Colors.white,
                      ),
                      // Text(
                      //   'Add',
                      //   style: TextStyle(
                      //       color: Color(0xFFe6e7e8),
                      //       fontSize: 12,
                      //       fontWeight: FontWeight.bold),
                      // ),
                    ],
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
                        state.page == NavBarOption.saved
                            ? Icons.bookmarks
                            : Icons.bookmarks_outlined,
                        color: Colors.white,
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
                        HomeNavOptionSelect(NavBarOption.saved),
                      ),
                ),
                IconButton(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          state.page == NavBarOption.profile
                              ? Icons.person
                              : Icons.person_outline,
                          color: Colors.white),
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
          body: Padding(
            padding: const EdgeInsets.fromLTRB(0, 40, 0, 0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Bavi",
                    style: TextStyle(
                      color: Color(0xFF8A2BE2),
                      fontSize: 54,
                      height: 0.8,
                      fontFamily: 'Gugi',
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

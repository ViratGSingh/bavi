import 'package:bavi/home/widgets/account_grid.dart';
import 'package:bavi/models/user.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class AccountSearch extends StatefulWidget {
  const AccountSearch({
    super.key,
    required this.onSearch,
    required this.onConfirm,
  });

  final Future<List<ExtractedAccountInfo>> Function(String) onSearch;
  final Function(ExtractedAccountInfo) onConfirm;

  @override
  State<AccountSearch> createState() => _AccountSearchState();
}

class _AccountSearchState extends State<AccountSearch> {
  List<ExtractedAccountInfo> _accounts = [];
  bool _isSearching = false;

  void _handleSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    final results = await widget.onSearch(query);

    setState(() {
      _accounts = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.8;
    List<ExtractedAccountInfo> customVideoData = [
      ExtractedAccountInfo(
          accountId: "bengaluru_food_scene",
          username: "Let us put one full scene together",
          fullname: "Bengaluru Food Scene",
          profilePicUrl:
              "https://bavi.s3.ap-south-1.amazonaws.com/profiles/bengaluru_food_scene.png",
          isVerified: false,
          isPrivate: false),
      ExtractedAccountInfo(
          accountId: "bengaluru_food_scene",
          username: "Let us put one full scene together",
          fullname: "Bengaluru Food Scene",
          profilePicUrl:
              "https://bavi.s3.ap-south-1.amazonaws.com/profiles/bengaluru_food_scene.png",
          isVerified: false,
          isPrivate: false),
      ExtractedAccountInfo(
          accountId: "bengaluru_food_scene",
          username: "Let us put one full scene together",
          fullname: "Bengaluru Food Scene",
          profilePicUrl:
              "https://bavi.s3.ap-south-1.amazonaws.com/profiles/bengaluru_food_scene.png",
          isVerified: false,
          isPrivate: false),
    ];

    return Container(
      height: maxHeight,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            //margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
            //height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Color(0xFF8A2BE2),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    child: Row(
                      children: [
                        CircularAvatarWithShimmer(imageUrl: ""),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 2 * MediaQuery.of(context).size.width / 3 -
                                  40,
                              child: Text(
                                "",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 2 * MediaQuery.of(context).size.width / 3 -
                                  40,
                              child: Text(
                                "",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]),
          ),

          // // Handle bar
          // Container(
          //   width: 40,
          //   height: 4,
          //   decoration: BoxDecoration(
          //     color: Colors.grey.shade400,
          //     borderRadius: BorderRadius.circular(10),
          //   ),
          // ),
          // const SizedBox(height: 16),
          // // Search bar
          // Container(
          //   height: 48,
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   decoration: BoxDecoration(
          //     color: Colors.white,
          //     border: Border.all(color: const Color(0xFF090E1D)),
          //     borderRadius: BorderRadius.circular(16),
          //   ),
          //   child: Row(
          //     children: [
          //       const Icon(Iconsax.search_normal_1_outline, color: Colors.black),
          //       const SizedBox(width: 8),
          //       Expanded(
          //         child: TextField(
          //           decoration: const InputDecoration(
          //             border: InputBorder.none,
          //             hintText: 'Accounts',
          //             hintStyle: TextStyle(
          //               color: Color(0xFF5A5E68),
          //               fontSize: 16,
          //               fontFamily: 'Poppins',
          //               fontWeight: FontWeight.w400,
          //             ),
          //           ),
          //           onSubmitted: (value) {
          //             if (value.length >= 3) {
          //               _handleSearch(value);
          //             } else if (value.isEmpty) {
          //               setState(() {
          //                 _accounts = [];
          //               });
          //             }
          //           },
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 16),
          // Expanded(
          //   child: AccountGridScreen(
          //     accounts: _accounts,
          //     isLoading: _isSearching,
          //     onConfirm: widget.onConfirm,
          //   ),
          // ),
        ],
      ),
    );
  }
}

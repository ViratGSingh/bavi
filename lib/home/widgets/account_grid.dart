import 'dart:convert';

import 'package:bavi/models/user.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AccountGridScreen extends StatelessWidget {
  final List<ExtractedAccountInfo> accounts;
  final bool isLoading;
  final Function(ExtractedAccountInfo) onConfirm;

  const AccountGridScreen({
    Key? key,
    required this.accounts,
    required this.isLoading,
    required this.onConfirm
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isLoading ? _buildShimmerList() : _buildAccountList();
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];

        String decodedUserName = utf8.decode(account.username.runes.toList());
        String decodedFullName = utf8.decode(account.fullname.runes.toList());
        return InkWell(
          onTap: (){
            onConfirm(account);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: CachedNetworkImageProvider(account.profilePicUrl),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 2*MediaQuery.of(context).size.width/3,
                        child: Text(
                          decodedUserName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 2*MediaQuery.of(context).size.width/3,
                        child: Text(
                          decodedFullName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
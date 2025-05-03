import 'package:bavi/models/question_answer.dart';
import 'package:bavi/widgets/profile_icon.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class ChatAppDrawer extends StatelessWidget {
  final List<ConversationData> conversations;
  final Function(ConversationData conversation) onConversationTap;
  final String profilePicUrl;
  final String fullname;
  final String username;
  final Function() onLogin;

  const ChatAppDrawer(
      {Key? key,
      required this.conversations,
      required this.onConversationTap,
      required this.profilePicUrl,
      required this.username,
      required this.fullname,
      required this.onLogin})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                                children: [
                                  CircularAvatarWithShimmer(
                                      imageUrl: profilePicUrl),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                2,
                                        child: Text(
                                          fullname,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 18,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                2,
                                        child: Text(
                                          "@$username",
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              SizedBox(height: 24),
              const Text(
                'Chats',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ...conversations.map((conversationData) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        child: InkWell(
                          onTap:
                              () => onConversationTap(conversationData),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            width: MediaQuery.of(context).size.width / 3,
                            child: Text(
                              conversationData.conversation.first.query,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      );
                    })
                  ],
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: onLogin,
                child: fullname == "Guest"
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Iconsax.login_1_bold,
                              color: Colors.black, size: 24),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 5),
                              Container(
                                width: MediaQuery.of(context).size.width / 2,
                                child: Text(
                                  "Login to your account to access your search history",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Iconsax.login_1_bold,
                              color: Colors.black, size: 24),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Logout",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 5),
                              Container(
                                width: MediaQuery.of(context).size.width/2,
                                child: Text(
                                  "Logout to create or login to another account of yours",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _displayName = '';
  String _email = '';
  String _profilePicUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _displayName = prefs.getString('displayName') ?? '';
      _email = prefs.getString('email') ?? '';
      _profilePicUrl = prefs.getString('profile_pic_url') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(httpClient: http.Client()),
      child: BlocListener<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state.status == LoginStatus.initial) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.black, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Account',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  // Avatar
                  _buildAvatar(),
                  const SizedBox(height: 16),
                  // Display name
                  Text(
                    _displayName.isNotEmpty ? _displayName : 'User',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    _email,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Divider
                  const Divider(color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 8),
                  // Sign out tile
                  BlocBuilder<LoginBloc, LoginState>(
                    builder: (context, state) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Sign out',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 15,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: state.status == LoginStatus.loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.redAccent,
                                ),
                              )
                            : const Icon(Icons.chevron_right,
                                color: Color(0xFFD1D5DB)),
                        onTap: state.status == LoginStatus.loading
                            ? null
                            : () => context
                                .read<LoginBloc>()
                                .add(LoginSignOut()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_profilePicUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: const Color(0xFFF3F4F6),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: _profilePicUrl,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            placeholder: (_, __) => _initialsAvatar(radius: 48),
            errorWidget: (_, __, ___) => _initialsAvatar(radius: 48),
          ),
        ),
      );
    }
    return _initialsAvatar(radius: 48);
  }

  Widget _initialsAvatar({required double radius}) {
    final initials = _displayName.isNotEmpty
        ? _displayName.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF8A2BE2),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.55,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

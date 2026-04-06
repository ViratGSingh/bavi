import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/home/widgets/mode_bottom_sheet.dart';
import 'package:bavi/home/widgets/likes_dislikes_bottom_sheet.dart';
import 'package:bavi/home/widgets/personalization_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsBottomSheet extends StatefulWidget {
  final VoidCallback? onDeleteHistory;

  const SettingsBottomSheet({
    super.key,
    this.onDeleteHistory,
  });

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  bool _showKeyboardOnLaunch = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showKeyboardOnLaunch = prefs.getBool('show_keyboard_on_launch') ?? false;
    });
  }

  Future<void> _setShowKeyboardOnLaunch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_keyboard_on_launch', value);
    setState(() {
      _showKeyboardOnLaunch = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * (3 / 4),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

            // App section
            _sectionLabel('App'),
            const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // _settingsTile(
                //   icon: Iconsax.cpu_bold,
                //   label: 'Manage models',
                //   onTap: () {
                //     Navigator.pop(context);
                //     final state = context.read<HomeBloc>().state;
                //     showModalBottomSheet(
                //       context: context,
                //       shape: const RoundedRectangleBorder(
                //         borderRadius:
                //             BorderRadius.vertical(top: Radius.circular(20)),
                //       ),
                //       builder: (_) => ModeBottomSheet(
                //         selectedModel: state.selectedModel,
                //         localAIStatus: state.localAIStatus,
                //         localAIDownloadProgress:
                //             state.localAIDownloadProgress,
                //         onModelSelected: (model) {
                //           HapticFeedback.selectionClick();
                //           context
                //               .read<HomeBloc>()
                //               .add(HomeModelSelect(model));
                //         },
                //       ),
                //     );
                //   },
                // ),
                // _divider(),
                // _settingsTile(
                //   icon: Iconsax.user_edit_outline,
                //   label: 'Personalization',
                //   onTap: () {
                //     // TODO: Navigate to personalization
                //   },
                // ),
                // _divider(),
                _settingsToggleTile(
                  icon: Iconsax.keyboard_outline,
                  label: 'Show keyboard on launch',
                  value: _showKeyboardOnLaunch,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    _setShowKeyboardOnLaunch(val);
                  },
                ),
                _divider(),

                _settingsTile(
                  icon: Iconsax.designtools_outline,
                  label: 'Personalization',
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const PersonalizationBottomSheet(),
                    );
                  },
                ),
                _divider(),
                _settingsTile(
                  icon: Iconsax.heart_outline,
                  label: 'Likes & Dislikes',
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const LikesDislikesBottomSheet(),
                    );
                  },
                ),
                _divider(),
                _settingsTile(
                  icon: Iconsax.trash_outline,
                  label: 'Delete conversation history',
                  labelColor: const Color(0xFFEF4444),
                  iconColor: const Color(0xFFEF4444),
                  showChevron: false,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showDeleteConfirmation(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About section
          _sectionLabel('About'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _settingsTile(
                  icon: Iconsax.document_text_outline,
                  label: 'Terms & Conditions',
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://drissea.com/terms'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                _divider(),
                _settingsTile(
                  icon: Iconsax.lock_outline,
                  label: 'Privacy Policy',
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://drissea.com/privacy'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                _divider(),
                // _settingsTile(
                //   icon: Iconsax.document_code_outline,
                //   label: 'Licenses',
                //   onTap: () {
                //     showLicensePage(
                //       context: context,
                //       applicationName: 'Bavi',
                //       applicationVersion: '1.7.1',
                //     );
                //   },
                // ),
                // _divider(),
                _settingsTile(
                  icon: Iconsax.info_circle_outline,
                  label: 'Version $_appVersion',
                  showChevron: false,
                  onTap: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // More section
          _sectionLabel('More'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _settingsTile(
                  icon: Iconsax.share_outline,
                  label: 'Share the app (support us 🚀)',
                  onTap: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: """
Check out Drissy! It's a local assistant for your phone that chats, sees images and searches the web. Since it's all on-device, your data stays yours. Really fast and handy \nDownload link: https://apps.apple.com/in/app/drissea/id6743215602
""",
                      ),
                    );
                  },
                ),
                _divider(),
                _settingsTile(
                  icon: RemixIcons.twitter_x_line,
                  label: 'Follow us on X',
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://x.com/viratgsingh'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Thank you for using Drissy! \nMade with ❤️ from 🇮🇳',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
            ),
          ),
                  const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        color: Color(0xFF8A2BE2),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? labelColor,
    Color? iconColor,
    bool showChevron = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? const Color(0xFF374151),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? const Color(0xFF111827),
                ),
              ),
            ),
            if (showChevron && onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  Widget _settingsToggleTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF374151),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF8A2BE2),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade300,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Colors.grey.shade300,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext parentContext) {
    showDialog<void>(
      context: parentContext,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Container(
                //   width: 56,
                //   height: 56,
                //   decoration: BoxDecoration(
                //     color: const Color(0xFFFEE2E2),
                //     borderRadius: BorderRadius.circular(16),
                //   ),
                //   child: const Icon(
                //     Iconsax.trash_bold,
                //     color: Color(0xFFEF4444),
                //     size: 28,
                //   ),
                // ),
                // const SizedBox(height: 20),
                const Text(
                  'Delete History',
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to delete all your conversation history? This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(parentContext).pop();
                          widget.onDeleteHistory?.call();
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

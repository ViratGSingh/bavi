import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

import 'package:image_picker/image_picker.dart';

class SourcesBottomSheet extends StatefulWidget {
  final void Function(XFile) onImageSelected;
  final void Function(HomeSearchType) onSearchTypeSelected;
  const SourcesBottomSheet({
    super.key,
    required this.onImageSelected,
    required this.onSearchTypeSelected,
  });

  @override
  State<SourcesBottomSheet> createState() => _SourcesBottomSheetState();
}

class _SourcesBottomSheetState extends State<SourcesBottomSheet> {
  bool isWebEnabled = false;
  bool isSocialEnabled = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        print("DEBUG: Image picked: ${image.path}");

        if (mounted) {
          print("DEBUG: SourcesBottomSheet is mounted, popping with image");
          Navigator.pop(context, image);
          widget.onImageSelected(image);
        } else {
          print("DEBUG: SourcesBottomSheet is NOT mounted, cannot pop");
        }
      } else {
        print("DEBUG: Image picking cancelled or failed");
      }
    } catch (e) {
      print("DEBUG: Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sources',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () async {
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSourceCard(
                  icon: Iconsax.gallery_outline,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSourceCard(
                  icon: Iconsax.camera_outline,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTypeRow(
            icon: const Icon(Iconsax.huobi_token_ht_outline, size: 24),
            label: 'Spicy',
            sublabel: 'Helps give more uncensored answers',
            value: HomeSearchType.nsfw,
            onChanged: (value) async {
              await Future.delayed(const Duration(milliseconds: 200));
              if (context.mounted) {
                Navigator.pop(context);
              }
              widget.onSearchTypeSelected(HomeSearchType.nsfw);
            },
          ),
          const SizedBox(height: 16),
          _buildTypeRow(
            icon: const Icon(Iconsax.map_outline, size: 24),
            label: 'Map',
            sublabel: 'Helps you decide best places or services to visit',
            value: HomeSearchType.map,
            onChanged: (value) async {
              await Future.delayed(const Duration(milliseconds: 200));
              if (context.mounted) {
                Navigator.pop(context);
              }
              widget.onSearchTypeSelected(HomeSearchType.map);
            },
          ),
          const SizedBox(height: 16),
          _buildTypeRow(
            icon: Image.asset(
              "assets/images/home/portal_icon.png",
              fit: BoxFit.contain,
              width: 24,
              color: Colors.black,
            ),
            label: 'Portal',
            sublabel: 'Helps you visit any webpage using keywords',
            value: HomeSearchType.portal,
            onChanged: (value) async {
              await Future.delayed(const Duration(milliseconds: 200));
              if (context.mounted) {
                Navigator.pop(context);
              }
              widget.onSearchTypeSelected(HomeSearchType.portal);
            },
          ),
          // const SizedBox(height: 16),
          // _buildTypeRow(
          //   icon: Iconsax.image_outline,
          //   label: 'Backstory',
          //   sublabel: "Helps you understand the story behind an image",
          //   value: HomeSearchType.story,
          //   onChanged: (value) async {
          //     await Future.delayed(const Duration(milliseconds: 200));
          //     if (context.mounted) {
          //       Navigator.pop(context);
          //     }
          //     widget.onSearchTypeSelected(HomeSearchType.map);
          //   },
          // ),
          // const SizedBox(height: 16),
          // _buildTypeRow(
          //   icon: Iconsax.shopping_cart_outline,
          //   label: 'Shopping',
          //   sublabel: 'Helps you decide best things to buy',
          //   value: HomeSearchType.shopping,
          //   onChanged: (value) async {
          //     await Future.delayed(const Duration(milliseconds: 200));
          //     if (context.mounted) {
          //       Navigator.pop(context);
          //     }
          //     widget.onSearchTypeSelected(HomeSearchType.shopping);
          //   },
          // ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSourceCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeRow({
    required Widget icon,
    required String label,
    required String sublabel,
    required HomeSearchType value,
    required ValueChanged<HomeSearchType> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Switch(
          //   value: value,
          //   onChanged: onChanged,
          //   activeColor: Colors.white,
          //   activeTrackColor: Colors.grey,
          //   inactiveThumbColor: Colors.white,
          //   inactiveTrackColor: Colors.grey.shade300,
          // ),
        ],
      ),
    );
  }
}

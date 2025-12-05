import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class ModeBottomSheet extends StatelessWidget {
  final Function(HomeModel) onModelSelected;
  final HomeModel selectedModel;

  const ModeBottomSheet({
    super.key,
    required this.onModelSelected,
    required this.selectedModel,
  });

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
                'Choose A Model',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () async {
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildModeCard(
            context: context,
            title: 'Deepseek',
            subtitle: 'Advanced reasoning and coding',
            icon: Iconsax.code_1_outline,
            isSelected: selectedModel == HomeModel.deepseek,
            onTap: () {
              onModelSelected(HomeModel.deepseek);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          _buildModeCard(
            context: context,
            title: 'Gemini',
            subtitle: 'Google\'s most capable model',
            icon: Iconsax.magic_star_outline,
            isSelected: selectedModel == HomeModel.gemini,
            onTap: () {
              onModelSelected(HomeModel.gemini);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          _buildModeCard(
            context: context,
            title: 'Claude',
            subtitle: 'Anthropic\'s intelligent assistant',
            icon: Iconsax.message_2_outline,
            isSelected: selectedModel == HomeModel.claude,
            onTap: () {
              onModelSelected(HomeModel.claude);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          _buildModeCard(
            context: context,
            title: 'Open AI',
            subtitle: 'GPT-4o for complex tasks',
            icon: Iconsax.cpu_outline,
            isSelected: selectedModel == HomeModel.openAI,
            onTap: () {
              onModelSelected(HomeModel.openAI);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF3E5F5)
              : const Color(
                  0xFFF5F5F5), // Light purple if selected, grey if not
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: const Color(0xFF8A2BE2), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF8A2BE2) : Colors.black,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color:
                          isSelected ? const Color(0xFF8A2BE2) : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF8A2BE2).withOpacity(0.7)
                          : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF8A2BE2),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

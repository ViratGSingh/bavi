import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kBrowseConsentKey = 'browse_consent_accepted';

Future<bool> isBrowseConsentAccepted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kBrowseConsentKey) ?? false;
}

Future<void> _saveBrowseConsent() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kBrowseConsentKey, true);
}

/// Shows the Browse data disclosure sheet if the user hasn't accepted yet.
/// Returns true if the user accepted (or had already accepted), false if dismissed.
Future<bool> ensureBrowseConsent(BuildContext context) async {
  if (await isBrowseConsentAccepted()) return true;

  if (!context.mounted) return false;

  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const BrowseConsentSheet(),
  );

  return accepted == true;
}

class BrowseConsentSheet extends StatelessWidget {
  const BrowseConsentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 20),
              const Text(
                'Before you browse',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
              _InfoRow(
                icon: Iconsax.send_2_outline,
                text: 'Your query is sent to our server to generate search terms or summarise webpages.',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Iconsax.cpu_outline,
                text: 'Results are processed by DeepSeek via Vercel AI Gateway (3rd party).',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Iconsax.trash_outline,
                text: 'Nothing is stored. Your conversation stays on-device only.',
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://drissea.com/privacy'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text(
                      'Privacy Policy →',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A2BE2),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF8A2BE2),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _saveBrowseConsent();
                        if (context.mounted) Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A2BE2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: const Text(
                        'Got it, continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8A2BE2)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

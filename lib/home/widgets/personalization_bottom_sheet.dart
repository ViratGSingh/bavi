import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPersonalizationEnabled = 'personalization_enabled';
const String _kPersonalizationText = 'personalization_text';
const int _kMaxChars = 512;

class PersonalizationBottomSheet extends StatefulWidget {
  const PersonalizationBottomSheet({super.key});

  @override
  State<PersonalizationBottomSheet> createState() =>
      _PersonalizationBottomSheetState();
}

class _PersonalizationBottomSheetState
    extends State<PersonalizationBottomSheet> {
  bool _enabled = false;
  bool _savedEnabled = false;
  String _savedText = '';
  late final TextEditingController _controller;

  bool get _canSave {
    final text = _controller.text.trim();
    if (!_enabled) return false;
    if (text.isEmpty) return false;
    return _enabled != _savedEnabled || text != _savedText;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadPreferences();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedText = prefs.getString(_kPersonalizationText) ?? '';
    final savedEnabled = prefs.getBool(_kPersonalizationEnabled) ?? false;
    setState(() {
      _enabled = savedEnabled;
      _savedEnabled = savedEnabled;
      _controller.text = savedText;
      _savedText = savedText;
    });
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPersonalizationEnabled, _enabled);
    await prefs.setString(
        _kPersonalizationText, _controller.text.trim());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPadding),
      height: MediaQuery.of(context).size.height * 0.6,
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
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              SizedBox(width: 24),
              const Expanded(
                child: Text(
                  'Personalization',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _canSave ? _save : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _canSave
                        ? const Color(0xFF8A2BE2)
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: _canSave ? Colors.white : const Color(0xFFB0B7C3),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Enable customization toggle
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Enable customization',
                    style: TextStyle(
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
                    value: _enabled,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _enabled = val);
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF8A2BE2),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFD1D5DB),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Custom Instructions label
          const Text(
            'Custom Instructions',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A2BE2),
            ),
          ),
          const SizedBox(height: 8),

          // Text field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _controller,
                  maxLines: 6,
                  minLines: 6,
                  maxLength: _kMaxChars,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF111827),
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Tell the AI about yourself…',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9CA3AF),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_controller.text.length}/$_kMaxChars',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

import 'package:bavi/services/drissy_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLikesKey = 'likes_dislikes_likes';
const String _kDislikesKey = 'likes_dislikes_dislikes';

class LikesDislikesBottomSheet extends StatefulWidget {
  const LikesDislikesBottomSheet({super.key});

  @override
  State<LikesDislikesBottomSheet> createState() =>
      _LikesDislikesBottomSheetState();
}

class _LikesDislikesBottomSheetState extends State<LikesDislikesBottomSheet> {
  late final TextEditingController _likesController;
  late final TextEditingController _dislikesController;
  String _savedLikes = '';
  String _savedDislikes = '';
  bool _isSaving = false;

  bool get _canSave {
    if (_isSaving) return false;
    final likes = _likesController.text.trim();
    final dislikes = _dislikesController.text.trim();
    if (likes.isEmpty && dislikes.isEmpty) return false;
    return likes != _savedLikes || dislikes != _savedDislikes;
  }

  @override
  void initState() {
    super.initState();
    _likesController = TextEditingController();
    _dislikesController = TextEditingController();
    _loadPreferences();
  }

  @override
  void dispose() {
    _likesController.dispose();
    _dislikesController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final likes = prefs.getString(_kLikesKey) ?? '';
    final dislikes = prefs.getString(_kDislikesKey) ?? '';
    setState(() {
      _likesController.text = likes;
      _dislikesController.text = dislikes;
      _savedLikes = likes;
      _savedDislikes = dislikes;
    });
  }

  List<String> _split(String text) => text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final likes = _likesController.text.trim();
    final dislikes = _dislikesController.text.trim();
    await prefs.setString(_kLikesKey, likes);
    await prefs.setString(_kDislikesKey, dislikes);
    await DrissyEngine().savePreferences(
      likes: _split(likes),
      dislikes: _split(dislikes),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    // Shrink the sheet height when the keyboard appears so it stays on screen.
    // The outer Padding pushes the sheet up above the keyboard.
    final sheetHeight = (screenHeight * 0.65 - keyboardHeight)
        .clamp(screenHeight * 0.35, screenHeight * 0.65);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                        const SizedBox(width: 24),
                        const Expanded(
                          child: Text(
                            'Likes & Dislikes',
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
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
                                color: _canSave
                                    ? Colors.white
                                    : const Color(0xFFB0B7C3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // "I like" section
                    const Text(
                      'I like',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A2BE2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: TextField(
                        controller: _likesController,
                        maxLines: 4,
                        minLines: 4,
                        style: const TextStyle(
                          fontSize: 15,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'India Today, Sekiro, Korean food, beaches…',
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
                    ),
                    const SizedBox(height: 20),

                    // "I don't like" section
                    const Text(
                      "I don't like",
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A2BE2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: TextField(
                        controller: _dislikesController,
                        maxLines: 4,
                        minLines: 4,
                        style: const TextStyle(
                          fontSize: 15,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF111827),
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Republic TV, horror movies…',
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

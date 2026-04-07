import 'dart:convert';
import 'dart:io';

import 'package:bavi/app_database.dart';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/models/thread.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
const String _kBackedUpIdsKey = 'chat_backup_backed_up_ids';

class ChatBackupBottomSheet extends StatefulWidget {
  const ChatBackupBottomSheet({super.key});

  @override
  State<ChatBackupBottomSheet> createState() => _ChatBackupBottomSheetState();
}

class _ChatBackupBottomSheetState extends State<ChatBackupBottomSheet> {
  Set<String> _backedUpIds = {};
  List<Thread> _allThreads = [];
  bool _isLoading = true;
  bool _isBackingUp = false;
  bool _isSharing = false;
  bool _isRestoring = false;
  String? _lastError;
  String? _successMessage;

  int get _pendingCount => _allThreads.where((t) {
        final session = _parseSession(t);
        if (session == null || session.isIncognito) return false;
        return !_backedUpIds.contains(t.id);
      }).length;

  int get _backedUpCount => _allThreads.where((t) {
        final session = _parseSession(t);
        if (session == null || session.isIncognito) return false;
        return _backedUpIds.contains(t.id);
      }).length;

  ThreadSessionData? _parseSession(Thread t) {
    try {
      return ThreadSessionData.fromJson(
          jsonDecode(t.sessionData) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadPrefs();
    await _loadThreads();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idsJson = prefs.getString(_kBackedUpIdsKey);
    Set<String> ids = {};
    if (idsJson != null) {
      try {
        ids = Set<String>.from(jsonDecode(idsJson) as List<dynamic>);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _backedUpIds = ids);
    }
  }

  Future<void> _loadThreads() async {
    final threads = await AppDatabase().getAllThreads();
    if (mounted) {
      setState(() {
        _allThreads = threads;
        _isLoading = false;
      });
    }
  }

  Future<Directory> _getBackupDir() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final backupDir =
        Directory(p.join(appDocsDir.path, 'Drissy Chat Backup'));
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }
    return backupDir;
  }

  // ─── Backup ──────────────────────────────────────────────────────────────

  Future<void> _runBackup() async {
    if (_pendingCount == 0) {
      setState(() => _successMessage = 'All chats are already backed up.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isBackingUp = true;
      _lastError = null;
      _successMessage = null;
    });

    final Directory backupDir;
    try {
      backupDir = await _getBackupDir();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _lastError = 'Could not create backup folder: $e';
        });
      }
      return;
    }

    int newCount = 0;
    final prefs = await SharedPreferences.getInstance();

    for (final thread in _allThreads) {
      final session = _parseSession(thread);
      if (session == null || session.isIncognito) continue;
      if (_backedUpIds.contains(thread.id)) continue;

      final displayTitle = _displayTitle(session);
      final filename = _sanitizeFilename(displayTitle, thread.id);
      final content =
          await _buildMarkdown(thread, session, displayTitle, backupDir);

      try {
        final file = File(p.join(backupDir.path, filename));
        await file.writeAsString(content, flush: true);
        _backedUpIds.add(thread.id);
        await prefs.setString(
            _kBackedUpIdsKey, jsonEncode(_backedUpIds.toList()));
        newCount++;
      } catch (e) {
        if (mounted) {
          setState(() {
            _isBackingUp = false;
            _lastError = 'Failed to write "$filename": $e';
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isBackingUp = false;
        _successMessage = newCount > 0
            ? 'Backed up $newCount new chat${newCount == 1 ? '' : 's'}.'
            : 'All chats are already backed up.';
      });
    }
  }

  // ─── Share ───────────────────────────────────────────────────────────────

  Future<void> _shareToObsidian() async {
    setState(() {
      _isSharing = true;
      _lastError = null;
    });

    try {
      final backupDir = await _getBackupDir();
      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.md') ||
              f.path.endsWith('.jpg') ||
              f.path.endsWith('.png'))
          .toList();

      if (files.isEmpty) {
        setState(() {
          _isSharing = false;
          _lastError = 'No backup files found. Run Sync first.';
        });
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: files.map((f) => XFile(f.path)).toList(),
          subject: 'Drissy Chat Backup',
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _lastError = 'Share failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ─── Restore ─────────────────────────────────────────────────────────────

  Future<void> _restoreFromFiles() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isRestoring = true;
      _lastError = null;
      _successMessage = null;
    });

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Drissy backup .md files',
        type: FileType.custom,
        allowedExtensions: ['md'],
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _lastError = 'Could not open file picker: $e';
        });
      }
      return;
    }

    if (result == null || result.files.isEmpty) {
      if (mounted) setState(() => _isRestoring = false);
      return;
    }

    // Load existing thread IDs to avoid duplicates
    final existingThreads = await AppDatabase().getAllThreads();
    final existingIds = existingThreads.map((t) => t.id).toSet();

    int restored = 0;
    int skipped = 0;
    final prefs = await SharedPreferences.getInstance();

    for (final picked in result.files) {
      final path = picked.path;
      if (path == null) continue;

      try {
        final content = await File(path).readAsString();
        final parsed = _parseMarkdownFile(content);
        if (parsed == null) {
          skipped++;
          continue;
        }

        final threadId = parsed['drissy_id'] as String;

        // Skip if already in DB
        if (existingIds.contains(threadId)) {
          skipped++;
          // Still mark as backed up so Sync won't re-export it
          _backedUpIds.add(threadId);
          continue;
        }

        final session = parsed['session'] as ThreadSessionData;
        final createdAt = session.createdAt.toDate();

        final companion = ThreadsCompanion.insert(
          id: drift.Value(threadId),
          sessionData: jsonEncode(session.toJson()),
          createdAt: drift.Value(createdAt),
          updatedAt: drift.Value(session.updatedAt.toDate()),
        );

        await AppDatabase().insertThread(companion);
        existingIds.add(threadId);
        _backedUpIds.add(threadId);
        restored++;
      } catch (e) {
        skipped++;
      }
    }

    // Persist updated backedUpIds
    await prefs.setString(
        _kBackedUpIdsKey, jsonEncode(_backedUpIds.toList()));

    // Reload thread list to reflect restored chats
    await _loadThreads();

    if (mounted) {
      setState(() {
        _isRestoring = false;
        if (restored > 0) {
          _successMessage =
              'Restored $restored chat${restored == 1 ? '' : 's'}.'
              '${skipped > 0 ? ' $skipped already existed.' : ''}';
        } else {
          _successMessage = skipped > 0
              ? 'All selected chats already exist in Drissy.'
              : 'No valid Drissy backup files found in selection.';
        }
      });
    }
  }

  /// Parses a Drissy backup .md file.
  /// Returns `{'drissy_id': String, 'session': ThreadSessionData}` or null.
  Map<String, dynamic>? _parseMarkdownFile(String content) {
    // Split frontmatter
    final parts = content.split('---');
    if (parts.length < 3) return null;

    final frontmatter = parts[1];
    final body = parts.sublist(2).join('---');

    // Parse frontmatter key-value pairs
    final fm = <String, String>{};
    for (final line in frontmatter.split('\n')) {
      final idx = line.indexOf(':');
      if (idx == -1) continue;
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      fm[key] = value;
    }

    final threadId = fm['drissy_id'];
    if (threadId == null || threadId.isEmpty) return null;

    // Must have the drissy tag to be a valid backup file
    final tags = fm['tags'] ?? '';
    if (!tags.contains('drissy')) return null;

    final title = fm['title'] ?? '';
    final summary = fm['summary'] ?? '';
    DateTime date;
    try {
      date = DateTime.parse(fm['date'] ?? '');
    } catch (_) {
      date = DateTime.now();
    }
    final ts = Timestamp.fromDate(date);

    // Parse conversation turns: each turn is separated by "\n---\n"
    // Format per turn:
    //   **You:** {query}
    //   (blank line)
    //   {answer}
    final turns = body.split(RegExp(r'\n---\n'));
    final results = <ThreadResultData>[];

    for (final turn in turns) {
      final trimmed = turn.trim();
      if (trimmed.isEmpty) continue;

      // Skip the header block "*Backed up from Drissy · date*"
      if (trimmed.startsWith('*Backed up')) continue;

      // Find "**You:**"
      final youMarker = '**You:**';
      final youIdx = trimmed.indexOf(youMarker);
      if (youIdx == -1) continue;

      final afterYou = trimmed.substring(youIdx + youMarker.length).trim();
      final newlineIdx = afterYou.indexOf('\n');
      final String userQuery;
      String answer = '';
      String sourceImageLink = '';
      String sourceImageDesc = '';

      if (newlineIdx == -1) {
        userQuery = afterYou;
      } else {
        userQuery = afterYou.substring(0, newlineIdx).trim();
        final remaining = afterYou.substring(newlineIdx + 1).trim();
        final lines = remaining.split('\n');

        int i = 0;
        // Collect image references before the answer
        while (i < lines.length) {
          final line = lines[i].trim();
          if (line.isEmpty) {
            i++;
            continue;
          }
          if (line.startsWith('![')) {
            final imgMatch =
                RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').firstMatch(line);
            if (imgMatch != null) {
              sourceImageDesc = imgMatch.group(1) ?? '';
              // Only restore remote URLs; local file paths aren't accessible
              final url = imgMatch.group(2) ?? '';
              if (url.startsWith('http')) sourceImageLink = url;
            }
            i++;
          } else {
            break;
          }
        }

        // Rest is the answer, strip **Drissy:** prefix if present
        final rest = lines.sublist(i).join('\n').trim();
        const drissyMarker = '**Drissy:**';
        answer =
            rest.startsWith(drissyMarker) ? rest.substring(drissyMarker.length).trim() : rest;
      }

      if (userQuery.isEmpty) continue;

      results.add(ThreadResultData(
        searchType: HomeSearchType.general,
        web: const [],
        shortVideos: const [],
        videos: const [],
        news: const [],
        images: const [],
        local: const [],
        youtubeVideos: const [],
        influence: const [],
        createdAt: ts,
        updatedAt: ts,
        userQuery: userQuery,
        searchQuery: userQuery,
        answer: answer,
        isSearchMode: false,
        sourceImageDescription: sourceImageDesc,
        sourceImageLink: sourceImageLink,
      ));
    }

    final session = ThreadSessionData(
      id: threadId,
      isIncognito: false,
      results: results,
      createdAt: ts,
      updatedAt: ts,
      title: title,
      summary: summary,
    );

    return {'drissy_id': threadId, 'session': session};
  }

  // ─── Markdown builder ────────────────────────────────────────────────────

  String _displayTitle(ThreadSessionData session) {
    if (session.title.isNotEmpty) return session.title;
    if (session.results.isNotEmpty &&
        session.results.first.userQuery.isNotEmpty) {
      return session.results.first.userQuery;
    }
    return 'Untitled';
  }

  String _sanitizeFilename(String title, String id) {
    final sanitized = title
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final truncated =
        sanitized.length > 50 ? sanitized.substring(0, 50) : sanitized;
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    return '${truncated}_$shortId.md';
  }

  String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  Future<String> _buildMarkdown(Thread thread, ThreadSessionData session,
      String displayTitle, Directory backupDir) async {
    final dateStr = _formatDate(thread.createdAt);
    final shortId =
        thread.id.length >= 8 ? thread.id.substring(0, 8) : thread.id;
    final sb = StringBuffer();

    sb.writeln('---');
    sb.writeln('title: ${displayTitle.replaceAll('\n', ' ')}');
    sb.writeln('date: $dateStr');
    sb.writeln('drissy_id: ${thread.id}'); // ← used for restore
    if (session.summary.isNotEmpty) {
      sb.writeln('summary: ${session.summary.replaceAll('\n', ' ')}');
    }
    sb.writeln('tags: [drissy, chat-backup]');
    sb.writeln('---');
    sb.writeln();

    sb.writeln('# ${displayTitle.replaceAll('\n', ' ')}');
    sb.writeln();
    sb.writeln('*Backed up from Drissy · $dateStr*');
    sb.writeln();

    for (int i = 0; i < session.results.length; i++) {
      final result = session.results[i];
      sb.writeln('---');
      sb.writeln();
      sb.writeln('**You:** ${result.userQuery}');

      // Attach image if present
      if (result.sourceImageLink.isNotEmpty) {
        // Remote URL — embed directly
        sb.writeln();
        sb.writeln(
            '![${result.sourceImageDescription}](${result.sourceImageLink})');
      } else if (result.sourceImage != null &&
          result.sourceImage!.isNotEmpty) {
        // Local device image — save as file and reference by name
        final imgFilename = 'img_${shortId}_$i.jpg';
        final imgFile = File(p.join(backupDir.path, imgFilename));
        try {
          await imgFile.writeAsBytes(result.sourceImage!, flush: true);
          sb.writeln();
          sb.writeln('![${result.sourceImageDescription}]($imgFilename)');
        } catch (_) {
          // Skip image if write fails; don't abort the whole backup
        }
      }

      sb.writeln();
      if (result.answer.isNotEmpty) {
        sb.writeln('**Drissy:** ${result.answer}');
      }
      sb.writeln();
    }

    return sb.toString();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  bool get _busy => _isBackingUp || _isSharing || _isRestoring;
  bool get _canSync => !_busy && _pendingCount > 0;

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Header
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
                  'Chat Backup',
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
                onTap: _canSync ? _runBackup : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _canSync
                        ? const Color(0xFF8A2BE2)
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isBackingUp
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Sync',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: _canSync
                                ? Colors.white
                                : const Color(0xFFB0B7C3),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF8A2BE2)))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A2BE2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _statusRow(
                                icon: Iconsax.tick_circle_outline,
                                iconColor: const Color(0xFF10B981),
                                label: 'Already backed up',
                                value: '$_backedUpCount',
                              ),
                              const SizedBox(height: 12),
                              _statusRow(
                                icon: Iconsax.clock_outline,
                                iconColor: const Color(0xFFF59E0B),
                                label: 'Pending',
                                value: '$_pendingCount',
                              ),
                            ],
                          ),
                        ),

                        // Messages
                        if (_lastError != null) ...[
                          const SizedBox(height: 16),
                          _messageCard(
                            icon: Icons.error_outline,
                            iconColor: const Color(0xFFEF4444),
                            bgColor: const Color(0xFFFEE2E2),
                            textColor: const Color(0xFFEF4444),
                            text: _lastError!,
                          ),
                        ],
                        if (_successMessage != null) ...[
                          const SizedBox(height: 16),
                          _messageCard(
                            icon: Icons.check_circle_outline,
                            iconColor: const Color(0xFF10B981),
                            bgColor: const Color(0xFFD1FAE5),
                            textColor: const Color(0xFF065F46),
                            text: _successMessage!,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Export
                        const Text(
                          'Export',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A2BE2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Send all backed-up chats to Obsidian or any app via the share sheet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF6B7280),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _actionButton(
                                icon: Icons.ios_share_rounded,
                                label: 'Share to Obsidian',
                                loading: _isSharing,
                                disabled: _busy,
                                onTap: _shareToObsidian,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Restore
                        const Text(
                          'Restore',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A2BE2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pick your Drissy backup .md files from Files or Obsidian to restore chats. Already existing chats are skipped.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF6B7280),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _actionButton(
                                icon: Iconsax.import_outline,
                                label: 'Restore from Files',
                                loading: _isRestoring,
                                disabled: _busy,
                                onTap: _restoreFromFiles,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'Backups are stored in Files → On My iPhone → Bavi → Drissy Chat Backup.\n\nIncognito chats are never backed up.',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade500,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _messageCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color textColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required bool loading,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color:
              const Color(0xFF8A2BE2).withValues(alpha: disabled ? 0.04 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF8A2BE2)
                .withValues(alpha: disabled ? 0.15 : 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8A2BE2),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: disabled
                        ? const Color(0xFFB0B7C3)
                        : const Color(0xFF8A2BE2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: disabled
                          ? const Color(0xFFB0B7C3)
                          : const Color(0xFF8A2BE2),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

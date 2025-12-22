import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bavi/objectbox.g.dart';

/// Singleton manager for ObjectBox store used for answer-memory vector storage.
/// Initializes lazily and handles errors gracefully to avoid crashing the app.
class ObjectBoxStore {
  static ObjectBoxStore? _instance;
  static bool _initializationFailed = false;
  Store? _store;

  ObjectBoxStore._internal();

  /// Get the store instance. Returns null if not initialized or initialization failed.
  Store? get store => _store;

  /// Check if ObjectBox is available and initialized
  static bool get isAvailable => _instance != null && _instance!._store != null;

  /// Try to get the instance, returns null if not available
  static ObjectBoxStore? get instanceOrNull => _instance;

  /// Get instance - throws if not initialized. Prefer instanceOrNull for safer access.
  static ObjectBoxStore get instance {
    if (_instance == null || _instance!._store == null) {
      throw StateError(
          'ObjectBoxStore not initialized. Call ObjectBoxStore.initialize() first.');
    }
    return _instance!;
  }

  /// Initialize the ObjectBox store lazily. Safe to call multiple times.
  /// Returns null if initialization fails (won't crash the app).
  static Future<ObjectBoxStore?> initialize() async {
    // Already initialized successfully
    if (_instance != null && _instance!._store != null) {
      return _instance!;
    }

    // Already tried and failed - don't retry to avoid repeated crashes
    if (_initializationFailed) {
      debugPrint('⚠️ ObjectBox initialization previously failed, skipping');
      return null;
    }

    try {
      final objectBox = ObjectBoxStore._internal();
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/objectbox_answer_memory';

      // Create directory if it doesn't exist
      final dbDir = Directory(dbPath);
      if (!dbDir.existsSync()) {
        dbDir.createSync(recursive: true);
      }

      objectBox._store = await openStore(directory: dbPath);
      debugPrint('✅ ObjectBox store initialized at: $dbPath');

      _instance = objectBox;
      return objectBox;
    } catch (e) {
      debugPrint('❌ ObjectBox initialization failed: $e');
      _initializationFailed = true;
      return null;
    }
  }

  /// Close the store when done (typically on app shutdown)
  void close() {
    _store?.close();
    _store = null;
    _instance = null;
  }
}

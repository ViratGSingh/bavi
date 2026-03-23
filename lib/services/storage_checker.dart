import 'package:flutter/services.dart';

class StorageChecker {
  static const _channel = MethodChannel('com.example.bavi/storage');

  /// Returns available storage in bytes, or null if unable to determine.
  static Future<int?> getAvailableBytes() async {
    try {
      final bytes = await _channel.invokeMethod<int>('getAvailableBytes');
      return bytes;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

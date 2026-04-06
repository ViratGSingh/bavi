// ignore_for_file: public_member_api_docs
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llamadart/llamadart.dart';

class PeaService {
  static final PeaService _instance = PeaService._internal();
  factory PeaService() => _instance;
  PeaService._internal();

  final PeaAdapter _adapter = PeaAdapter();
  bool get isLoaded => _adapter.isLoaded;

  Pointer<PeaAdapterOpaque> get nativeHandle => _adapter.handle;

  static Future<String> get _peaPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/user_taste.pea';
  }

  Future<bool> load() async {
    final path = await _peaPath;
    final file = File(path);

    if (!file.existsSync()) {
      try {
        final bytes = await rootBundle.load('assets/user_taste.pea');
        await file.writeAsBytes(bytes.buffer.asUint8List());
      } catch (e) {
        return false;
      }
    }

    return loadFromPath(path);
  }

  bool loadFromPath(String path) {
    final loaded = _adapter.load(path);
    return loaded;
  }

  Future<void> saveFromBytes(List<int> bytes) async {
    final path = await _peaPath;
    await File(path).writeAsBytes(bytes);
  }

  void dispose() => _adapter.dispose();
}

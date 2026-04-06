import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class PeaBuilder {
  static const int _peaMagic = 0x50454100;
  static const int _hiddenDim = 64;
  static const double _likeBias = 0.8;
  static const double _dislikeBias = -0.8;

  static int _fnv1a(List<int> bytes) {
    int h = -3750763034362895579; // 14695981039346656037 as signed 64-bit
    for (final b in bytes) {
      h ^= b;
      h = (h * 1099511628211) & 0xFFFFFFFFFFFFFFFF;
    }
    return h;
  }
  
  static Future<String> buildFromTokens({
    required List<List<int>> likeTokens,
    required List<List<int>> dislikeTokens,
    required List<String> likeLabels,
    required List<String> dislikeLabels,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/user_taste.pea';
    final entries = <_PeaEntry>[];

    // Likes — single tokens only
    for (int i = 0; i < likeTokens.length; i++) {
      final tokens = likeTokens[i];
      final label = i < likeLabels.length ? likeLabels[i] : '';
      for (final tok in tokens) {
        final key = '$tok';
        final hash = _fnv1a(key.codeUnits);
        entries.add(_PeaEntry(
          hash: hash,
          label: label,
          vector: _makeVector(_likeBias),
        ));
      }
    }

    // Dislikes — single tokens only
    for (int i = 0; i < dislikeTokens.length; i++) {
      final tokens = dislikeTokens[i];
      final label = i < dislikeLabels.length ? dislikeLabels[i] : '';
      for (final tok in tokens) {
        final key = '$tok';
        final hash = _fnv1a(key.codeUnits);
        entries.add(_PeaEntry(
          hash: hash,
          label: label,
          vector: _makeVector(_dislikeBias),
        ));
      }
    }

    // Write binary .pea file
    final buffer = BytesBuilder();
    final header = ByteData(16);
    header.setUint32(0,  _peaMagic,      Endian.little);
    header.setUint32(4,  1,              Endian.little);
    header.setUint32(8,  entries.length, Endian.little);
    header.setUint32(12, _hiddenDim,     Endian.little);
    buffer.add(header.buffer.asUint8List());

    for (final entry in entries) {
      final hashBytes = ByteData(8);
      hashBytes.setUint64(0, entry.hash & 0xFFFFFFFFFFFFFFFF, Endian.little);
      buffer.add(hashBytes.buffer.asUint8List());
      final labelBytes = entry.label.codeUnits;
      final labelLen = ByteData(2);
      labelLen.setUint16(0, labelBytes.length, Endian.little);
      buffer.add(labelLen.buffer.asUint8List());
      buffer.add(labelBytes);
      final vecBytes = ByteData(_hiddenDim * 4);
      for (int i = 0; i < _hiddenDim; i++) {
        vecBytes.setFloat32(i * 4, entry.vector[i], Endian.little);
      }
      buffer.add(vecBytes.buffer.asUint8List());
    }

    await File(path).writeAsBytes(buffer.toBytes());
    print('PeaBuilder: wrote $path '
          '(${entries.length} entries, ${buffer.length} bytes)');
    return path;
  }

  static List<double> _makeVector(double bias) {
    final rng = Random();
    final vec = List<double>.generate(
      _hiddenDim,
      (_) => bias + (rng.nextDouble() - 0.5) * 0.1,
    );
    // Normalize
    final norm = sqrt(vec.fold(0.0, (s, v) => s + v * v));
    return vec.map((v) => v / norm).toList();
  }

  static Future<String> build({
    required List<String> likes,
    required List<String> dislikes,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/user_taste.pea';

    final entries = <_PeaEntry>[];

    for (final concept in likes) {
      final words = concept.trim().toLowerCase().split(' ');
      for (final word in words) {
        if (word.isEmpty) continue;
        final key = word.codeUnits;
        final hash = _fnv1a(key);
        final vec = _makeVector(_likeBias);
        entries.add(_PeaEntry(
          hash: hash,
          label: concept.trim(),
          vector: vec,
        ));
      }
    }

    for (final concept in dislikes) {
      final words = concept.trim().toLowerCase().split(' ');
      for (final word in words) {
        if (word.isEmpty) continue;
        final key = word.codeUnits;
        final hash = _fnv1a(key);
        final vec = _makeVector(_dislikeBias);
        entries.add(_PeaEntry(
          hash: hash,
          label: concept.trim(),
          vector: vec,
        ));
      }
    }

    // Write binary .pea file
    final buffer = BytesBuilder();

    // Header: magic, version, n_entries, hidden_dim
    final header = ByteData(16);
    header.setUint32(0,  _peaMagic,  Endian.little);
    header.setUint32(4,  1,          Endian.little);
    header.setUint32(8,  entries.length, Endian.little);
    header.setUint32(12, _hiddenDim, Endian.little);
    buffer.add(header.buffer.asUint8List());

    for (final entry in entries) {
      // hash (8 bytes)
      final hashBytes = ByteData(8);
      hashBytes.setUint64(0, entry.hash & 0xFFFFFFFFFFFFFFFF, Endian.little);
      buffer.add(hashBytes.buffer.asUint8List());

      // label length + label
      final labelBytes = entry.label.codeUnits;
      final labelLen = ByteData(2);
      labelLen.setUint16(0, labelBytes.length, Endian.little);
      buffer.add(labelLen.buffer.asUint8List());
      buffer.add(labelBytes);

      // vector (64 floats × 4 bytes)
      final vecBytes = ByteData(_hiddenDim * 4);
      for (int i = 0; i < _hiddenDim; i++) {
        vecBytes.setFloat32(i * 4, entry.vector[i], Endian.little);
      }
      buffer.add(vecBytes.buffer.asUint8List());
    }

    await File(path).writeAsBytes(buffer.toBytes());
    print('PeaBuilder: wrote $path '
          '(${entries.length} entries, ${buffer.length} bytes)');
    return path;
  }
}

class _PeaEntry {
  final int hash;
  final String label;
  final List<double> vector;
  _PeaEntry({required this.hash, required this.label, required this.vector});
}
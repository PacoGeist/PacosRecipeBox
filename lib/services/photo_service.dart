import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';

/// Stores the user's photos on the device.
///
/// Recipes reference photos either as `asset:<path>` (built-in library) or by
/// a bare file name. On Android/iOS the file lives in the app's private
/// documents folder; in the web app (PWA) the bytes live in the browser's
/// on-device database and are kept in memory for fast display.
class PhotoService {
  static Directory? _dir;
  static final Map<String, Uint8List> _web = {};

  static Future<void> init() async {
    if (kIsWeb) {
      _web.addAll(await RecipeDb.instance.loadPhotos());
    } else {
      await dir();
    }
  }

  static Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(docs.path, 'photos'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return _dir = d;
  }

  /// Synchronous file path lookup (mobile only); valid after [init].
  static String? filePath(String? ref) {
    if (kIsWeb || ref == null || ref.startsWith('asset:') || _dir == null) return null;
    return p.join(_dir!.path, ref);
  }

  /// Synchronous in-memory bytes (web only); valid after [init].
  static Uint8List? memoryBytes(String? ref) => (kIsWeb && ref != null) ? _web[ref] : null;

  static bool isAsset(String? ref) => ref != null && ref.startsWith('asset:');
  static String assetPath(String ref) => ref.substring(6);

  static Future<String?> pick({required bool camera}) async {
    final x = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (x == null) return null;
    final ext = p.extension(x.name).isEmpty ? '.jpg' : p.extension(x.name);
    return saveBytes(await x.readAsBytes(), ext: ext);
  }

  static Future<String> saveBytes(Uint8List bytes, {String ext = '.jpg'}) async {
    final name = '${const Uuid().v4()}$ext';
    await saveAs(name, bytes);
    return name;
  }

  /// Saves bytes under an exact file name (used when importing backups).
  static Future<void> saveAs(String name, List<int> bytes) async {
    final n = p.basename(name);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (kIsWeb) {
      _web[n] = data;
      await RecipeDb.instance.putPhoto(n, data);
    } else {
      final d = await dir();
      await File(p.join(d.path, n)).writeAsBytes(data);
    }
  }

  /// Reads a user photo's bytes (not built-in assets).
  static Future<Uint8List?> readBytes(String? ref) async {
    if (ref == null || isAsset(ref)) return null;
    if (kIsWeb) return _web[ref];
    final path = filePath(ref);
    if (path != null && File(path).existsSync()) return File(path).readAsBytes();
    return null;
  }

  static Future<void> delete(String? ref) async {
    if (ref == null || isAsset(ref)) return;
    if (kIsWeb) {
      _web.remove(ref);
      await RecipeDb.instance.deletePhoto(ref);
      return;
    }
    final path = filePath(ref);
    if (path != null) {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    }
  }
}

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import 'planner_store.dart';
import 'recipe_store.dart';
import 'share_service.dart';

/// Full backup / restore of everything the user has added or changed.
class BackupService {
  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  static Future<Uint8List> _build(RecipeStore store, PlannerStore planner) async {
    final mine = store.all.where((r) => !r.builtIn).toList();
    final favs = store.all.where((r) => r.builtIn && r.favorite).map((r) => r.id).toList();
    final notes = {
      for (final r in store.all.where((r) => r.builtIn && r.myNotes.isNotEmpty)) r.id: r.myNotes,
    };
    return ShareService.packRecipes(mine, extra: {
      'backup': true,
      'favoriteLibraryIds': favs,
      'libraryNotes': notes,
      'planner': planner.toJson(),
    });
  }

  /// Saves a backup file wherever the user chooses (Downloads, Google Drive, …).
  static Future<void> saveBackup(BuildContext context) async {
    final store = context.read<RecipeStore>();
    final planner = context.read<PlannerStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _build(store, planner);
      final uri = await FilePicker.saveFile(
        fileName: 'RecipeBox_backup_${_stamp()}.zip',
        bytes: bytes,
        mimeType: 'application/zip',
        dialogTitle: 'Save $appTitle backup',
      );
      if (uri != null) messenger.showSnackBar(const SnackBar(content: Text('Backup saved.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  /// Sends the backup through the share sheet (email it to yourself, Drive, etc.).
  static Future<void> shareBackup(BuildContext context) async {
    final store = context.read<RecipeStore>();
    final planner = context.read<PlannerStore>();
    final bytes = await _build(store, planner);
    final name = 'RecipeBox_backup_${_stamp()}.zip';
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: 'application/zip')],
      fileNameOverrides: [name],
      subject: '$appTitle backup ${_stamp()}',
    ));
  }

  static Future<void> restore(BuildContext context) async {
    final store = context.read<RecipeStore>();
    final planner = context.read<PlannerStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      final (recipes, manifest) = await ShareService.unpackRecipes(bytes, asFriend: false, keepIds: true);
      await store.saveMany(recipes);
      final favs = ((manifest['favoriteLibraryIds'] as List?) ?? []).cast<String>();
      for (final id in favs) {
        final r = store.byId(id);
        if (r != null && !r.favorite) await store.toggleFavorite(r);
      }
      final notes = Map<String, dynamic>.from(manifest['libraryNotes'] ?? {});
      for (final e in notes.entries) {
        final r = store.byId(e.key);
        if (r != null && r.myNotes.isEmpty) await store.setMyNotes(r, e.value.toString());
      }
      if (manifest['planner'] is Map) {
        await planner.mergeFrom(Map<String, dynamic>.from(manifest['planner']));
      }
      messenger.showSnackBar(SnackBar(content: Text('Restored ${recipes.length} recipes.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }
}

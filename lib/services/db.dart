import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/recipe.dart';

/// Thin SQLite layer. Each recipe is stored as a JSON document so the schema
/// can evolve without migrations; searching happens in memory.
class RecipeDb {
  RecipeDb._();
  static final RecipeDb instance = RecipeDb._();
  factory RecipeDb() => instance;

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    // In the web app (PWA) SQLite runs as WebAssembly and saves to the browser's on-device storage.
    final factory = kIsWeb ? databaseFactoryFfiWebNoWebWorker : databaseFactory;
    final path = kIsWeb ? 'recipes.db' : p.join(await getDatabasesPath(), 'recipes.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (d, v) async {
          await d.execute('CREATE TABLE recipes (id TEXT PRIMARY KEY, json TEXT NOT NULL, updated INTEGER)');
          await d.execute('CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT)');
          await d.execute('CREATE TABLE photos (name TEXT PRIMARY KEY, data BLOB NOT NULL)');
        },
        onUpgrade: (d, from, to) async {
          if (from < 2) await d.execute('CREATE TABLE IF NOT EXISTS photos (name TEXT PRIMARY KEY, data BLOB NOT NULL)');
        },
      ),
    );
  }

  Future<List<Recipe>> loadAll() async {
    final rows = await (await db).query('recipes');
    return rows.map((r) => Recipe.fromJson(jsonDecode(r['json'] as String))).toList();
  }

  Future<void> upsert(Recipe r) async {
    await (await db).insert(
      'recipes',
      {'id': r.id, 'json': jsonEncode(r.toJson()), 'updated': r.updatedAt},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMany(Iterable<Recipe> list) async {
    final d = await db;
    await d.transaction((txn) async {
      final b = txn.batch();
      for (final r in list) {
        b.insert('recipes', {'id': r.id, 'json': jsonEncode(r.toJson()), 'updated': r.updatedAt},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await b.commit(noResult: true);
    });
  }

  Future<void> delete(String id) async => (await db).delete('recipes', where: 'id = ?', whereArgs: [id]);

  Future<String?> getMeta(String k) async {
    final r = await (await db).query('meta', where: 'k = ?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  Future<void> setMeta(String k, String v) async =>
      (await db).insert('meta', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  // Photos are stored in the database only in the web app.
  Future<Map<String, Uint8List>> loadPhotos() async {
    final rows = await (await db).query('photos');
    return {for (final r in rows) r['name'] as String: r['data'] as Uint8List};
  }

  Future<void> putPhoto(String name, Uint8List data) async =>
      (await db).insert('photos', {'name': name, 'data': data}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deletePhoto(String name) async => (await db).delete('photos', where: 'name = ?', whereArgs: [name]);
}

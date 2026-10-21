import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/recipe.dart';
import 'db.dart';
import 'photo_service.dart';
import 'startup_log.dart';

enum SearchField { everything, name, ingredient, author, keyword }

extension SearchFieldLabel on SearchField {
  String get label => switch (this) {
        SearchField.everything => 'Everything',
        SearchField.name => 'Name',
        SearchField.ingredient => 'Ingredient',
        SearchField.author => 'Author',
        SearchField.keyword => 'Keyword',
      };
}

/// Filters applied to the recipe list. Empty values mean "any".
class RecipeFilter {
  final String text;
  final SearchField field;
  final String? collection;
  final String? cuisine;
  final String? mealType;
  final String? season;
  final String? holiday;
  final bool favoritesOnly;
  final int? maxMinutes;

  const RecipeFilter({
    this.text = '',
    this.field = SearchField.everything,
    this.collection,
    this.cuisine,
    this.mealType,
    this.season,
    this.holiday,
    this.favoritesOnly = false,
    this.maxMinutes,
  });

  RecipeFilter copyWith({
    String? text,
    SearchField? field,
    Object? collection = _keep,
    Object? cuisine = _keep,
    Object? mealType = _keep,
    Object? season = _keep,
    Object? holiday = _keep,
    bool? favoritesOnly,
    Object? maxMinutes = _keep,
  }) =>
      RecipeFilter(
        text: text ?? this.text,
        field: field ?? this.field,
        collection: collection == _keep ? this.collection : collection as String?,
        cuisine: cuisine == _keep ? this.cuisine : cuisine as String?,
        mealType: mealType == _keep ? this.mealType : mealType as String?,
        season: season == _keep ? this.season : season as String?,
        holiday: holiday == _keep ? this.holiday : holiday as String?,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        maxMinutes: maxMinutes == _keep ? this.maxMinutes : maxMinutes as int?,
      );

  static const _keep = Object();
}

class RecipeStore extends ChangeNotifier {
  final RecipeDb _db = RecipeDb();
  final Map<String, Recipe> _recipes = {};
  bool loaded = false;
  int libraryVersion = 0;

  List<Recipe> get all => _recipes.values.toList();
  Recipe? byId(String id) => _recipes[id];
  int get count => _recipes.length;

  /// Loads recipes directly (used by screenshot tests).
  @visibleForTesting
  void debugLoad(List<Recipe> list) {
    for (final r in list) {
      _recipes[r.id] = r;
    }
    libraryVersion = 1;
    loaded = true;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      await PhotoService.init();
    } catch (e, s) {
      StartupLog.add('photos', e, s);
    }
    try {
      for (final r in await _db.loadAll()) {
        _recipes[r.id] = r;
      }
    } catch (e, s) {
      StartupLog.add('database', e, s);
    }
    try {
      await _seedLibrary();
    } catch (e, s) {
      StartupLog.add('library', e, s);
    }
    loaded = true;
    notifyListeners();
  }

  /// Loads the built-in recipe library from assets. New library versions
  /// (shipped with app updates) add new recipes and refresh untouched ones,
  /// but never overwrite recipes the user has edited or resurrect ones they deleted.
  Future<void> _seedLibrary() async {
    final raw = await rootBundle.loadString('assets/seed/recipes.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final version = (data['version'] as num).toInt();
    libraryVersion = version;
    final have = int.tryParse(await _db.getMeta('seedVersion') ?? '0') ?? 0;
    if (have >= version) return;
    final deleted = ((jsonDecode(await _db.getMeta('deletedSeedIds') ?? '[]')) as List).toSet();
    final toWrite = <Recipe>[];
    for (final j in (data['recipes'] as List)) {
      final r = Recipe.fromJson(j as Map<String, dynamic>)
        ..builtIn = true
        ..collection = 'internet';
      if (deleted.contains(r.id)) continue;
      final existing = _recipes[r.id];
      if (existing != null && !existing.builtIn) continue; // user edited it
      if (existing != null) r.favorite = existing.favorite;
      _recipes[r.id] = r;
      toWrite.add(r);
    }
    await _db.upsertMany(toWrite);
    await _db.setMeta('seedVersion', '$version');
  }

  Future<void> save(Recipe r, {bool userEdit = true}) async {
    if (userEdit) {
      r.builtIn = false; // an edited library recipe becomes the user's own copy
      r.updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
    r.invalidateSearch();
    _recipes[r.id] = r;
    await _db.upsert(r);
    notifyListeners();
  }

  Future<void> saveMany(List<Recipe> list) async {
    for (final r in list) {
      r.invalidateSearch();
      _recipes[r.id] = r;
    }
    await _db.upsertMany(list);
    notifyListeners();
  }

  Future<void> toggleFavorite(Recipe r) async {
    r.favorite = !r.favorite;
    await _db.upsert(r);
    notifyListeners();
  }

  Future<void> delete(Recipe r) async {
    _recipes.remove(r.id);
    await _db.delete(r.id);
    if (r.id.startsWith('lib-')) {
      final deleted = ((jsonDecode(await _db.getMeta('deletedSeedIds') ?? '[]')) as List).toSet()..add(r.id);
      await _db.setMeta('deletedSeedIds', jsonEncode(deleted.toList()));
    }
    // Remove photos that no other recipe uses.
    final inUse = _recipes.values.expand((x) => x.allPhotos).toSet();
    for (final ph in r.allPhotos) {
      if (!inUse.contains(ph)) await PhotoService.delete(ph);
    }
    notifyListeners();
  }

  /// Distinct author names, for author browsing/autocomplete.
  List<String> get authors {
    final s = <String>{};
    for (final r in _recipes.values) {
      if (r.author.trim().isNotEmpty) s.add(r.author.trim());
    }
    return s.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  int countWhere(bool Function(Recipe) test) => _recipes.values.where(test).length;

  List<Recipe> query(RecipeFilter f) {
    final terms = f.text.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    bool matchText(Recipe r) {
      if (terms.isEmpty) return true;
      String hay;
      switch (f.field) {
        case SearchField.everything:
          hay = r.searchBlob;
        case SearchField.name:
          hay = r.title.toLowerCase();
        case SearchField.ingredient:
          hay = r.ingredients.join(' ').toLowerCase();
        case SearchField.author:
          hay = '${r.author} ${r.source}'.toLowerCase();
        case SearchField.keyword:
          hay = [...r.keywords, ...r.cuisines, ...r.mealTypes, ...r.seasons, ...r.holidays].join(' ').toLowerCase();
      }
      return terms.every(hay.contains);
    }

    final out = _recipes.values.where((r) {
      if (f.collection != null && r.collection != f.collection) return false;
      if (f.cuisine != null && !r.cuisines.contains(f.cuisine)) return false;
      if (f.mealType != null && !r.mealTypes.contains(f.mealType)) return false;
      if (f.season != null && !r.seasons.contains(f.season)) return false;
      if (f.holiday != null && !r.holidays.contains(f.holiday)) return false;
      if (f.favoritesOnly && !r.favorite) return false;
      if (f.maxMinutes != null && (r.totalMinutes == 0 || r.totalMinutes > f.maxMinutes!)) return false;
      return matchText(r);
    }).toList();

    // Rank: title matches first, then alphabetical.
    out.sort((a, b) {
      if (terms.isNotEmpty) {
        final at = terms.every(a.title.toLowerCase().contains) ? 0 : 1;
        final bt = terms.every(b.title.toLowerCase().contains) ? 0 : 1;
        if (at != bt) return at - bt;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return out;
  }
}

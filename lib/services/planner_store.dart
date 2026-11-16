import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe.dart';
import 'db.dart';
import 'grocery.dart';
import 'scaler.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseDay(String k) => DateTime.parse(k);
DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// One day on the calendar: what's planned for it and what was actually cooked.
class DayPlan {
  final String date; // yyyy-mm-dd
  List<String> menu; // recipe ids planned for the day
  List<String> made; // recipe ids cooked that day
  String note;

  DayPlan(this.date, {List<String>? menu, List<String>? made, this.note = ''})
      : menu = menu ?? [],
        made = made ?? [];

  bool get isEmpty => menu.isEmpty && made.isEmpty && note.isEmpty;

  Map<String, dynamic> toJson() => {'date': date, 'menu': menu, 'made': made, 'note': note};
  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        j['date'],
        menu: List<String>.from(j['menu'] ?? []),
        made: List<String>.from(j['made'] ?? []),
        note: j['note'] ?? '',
      );
}

class GroceryItem {
  final String id;
  String text;
  String dept;
  bool checked;
  String source; // recipe title(s) it came from, or '' for items typed in
  int checkedAt;

  GroceryItem({required this.id, required this.text, required this.dept, this.checked = false, this.source = '', this.checkedAt = 0});

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'dept': dept, 'checked': checked, 'source': source, 'checkedAt': checkedAt};
  factory GroceryItem.fromJson(Map<String, dynamic> j) => GroceryItem(
        id: j['id'],
        text: j['text'] ?? '',
        dept: j['dept'] ?? 'other',
        checked: j['checked'] ?? false,
        source: j['source'] ?? '',
        checkedAt: (j['checkedAt'] as num?)?.toInt() ?? 0,
      );
}

class GroceryList {
  final String id;
  String title;
  final int created;
  int opened; // last time it was opened; the most recent one opens from the home page
  List<GroceryItem> items;

  GroceryList({required this.id, required this.title, required this.created, int? opened, List<GroceryItem>? items})
      : items = items ?? [],
        opened = opened ?? created;

  int get remaining => items.where((i) => !i.checked).length;

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'created': created, 'opened': opened, 'items': items.map((i) => i.toJson()).toList()};
  factory GroceryList.fromJson(Map<String, dynamic> j) => GroceryList(
        id: j['id'],
        title: j['title'] ?? 'Grocery list',
        created: (j['created'] as num?)?.toInt() ?? 0,
        opened: (j['opened'] as num?)?.toInt(),
        items: ((j['items'] as List?) ?? []).map((e) => GroceryItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      );

  String asText() {
    final b = StringBuffer('$title\n');
    for (final d in Dept.all) {
      final list = items.where((i) => i.dept == d.key && !i.checked).toList();
      if (list.isEmpty) continue;
      b.writeln('\n${d.label.toUpperCase()}');
      for (final i in list) {
        b.writeln('☐ ${i.text}');
      }
    }
    return b.toString();
  }
}

/// Menus by day, "I made this" history and grocery lists. Stored on the device
/// in the same database as the recipes (one JSON document).
class PlannerStore extends ChangeNotifier {
  final RecipeDb _db = RecipeDb();
  final Map<String, DayPlan> days = {};
  final List<GroceryList> lists = []; // newest first
  bool loaded = false;

  /// false = keep everything in memory only (used by tests and screenshots).
  bool persist = true;

  Future<void> init() async {
    try {
      final raw = await _db.getMeta('planner');
      if (raw != null) _apply(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Planner load failed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  void _apply(Map<String, dynamic> j) {
    days.clear();
    lists.clear();
    for (final d in (j['days'] as List? ?? [])) {
      final p = DayPlan.fromJson(Map<String, dynamic>.from(d));
      days[p.date] = p;
    }
    for (final l in (j['lists'] as List? ?? [])) {
      lists.add(GroceryList.fromJson(Map<String, dynamic>.from(l)));
    }
    lists.sort((a, b) => b.opened.compareTo(a.opened));
  }

  Map<String, dynamic> toJson() => {
        'days': days.values.where((d) => !d.isEmpty).map((d) => d.toJson()).toList(),
        'lists': lists.map((l) => l.toJson()).toList(),
      };

  /// Used when restoring a backup: merges days and lists into what's here.
  Future<void> mergeFrom(Map<String, dynamic> j) async {
    for (final d in (j['days'] as List? ?? [])) {
      final p = DayPlan.fromJson(Map<String, dynamic>.from(d));
      final cur = days[p.date];
      if (cur == null) {
        days[p.date] = p;
      } else {
        cur.menu = {...cur.menu, ...p.menu}.toList();
        cur.made = {...cur.made, ...p.made}.toList();
        if (cur.note.isEmpty) cur.note = p.note;
      }
    }
    for (final l in (j['lists'] as List? ?? [])) {
      final g = GroceryList.fromJson(Map<String, dynamic>.from(l));
      if (!lists.any((x) => x.id == g.id)) lists.add(g);
    }
    lists.sort((a, b) => b.opened.compareTo(a.opened));
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    if (persist) await _db.setMeta('planner', jsonEncode(toJson()));
  }

  // ---------- menus ----------

  DayPlan day(DateTime d) => days.putIfAbsent(dayKey(d), () => DayPlan(dayKey(d)));
  DayPlan? peek(DateTime d) => days[dayKey(d)];

  Future<void> addToMenu(DateTime d, Iterable<String> recipeIds) async {
    final p = day(d);
    for (final id in recipeIds) {
      if (!p.menu.contains(id)) p.menu.add(id);
    }
    await _save();
  }

  Future<void> removeFromMenu(DateTime d, String recipeId) async {
    day(d).menu.remove(recipeId);
    await _save();
  }

  Future<void> moveInMenu(DateTime d, int from, int to) async {
    final m = day(d).menu;
    final id = m.removeAt(from);
    m.insert(to.clamp(0, m.length), id);
    await _save();
  }

  Future<void> setNote(DateTime d, String note) async {
    day(d).note = note.trim();
    await _save();
  }

  // ---------- "I made this" ----------

  Future<void> markMade(DateTime d, String recipeId) async {
    final p = day(d);
    if (!p.made.contains(recipeId)) p.made.add(recipeId);
    await _save();
  }

  Future<void> unmarkMade(DateTime d, String recipeId) async {
    day(d).made.remove(recipeId);
    await _save();
  }

  /// Dates the recipe was cooked, newest first.
  List<DateTime> madeDates(String recipeId) {
    final out = days.values.where((d) => d.made.contains(recipeId)).map((d) => parseDay(d.date)).toList();
    out.sort((a, b) => b.compareTo(a));
    return out;
  }

  /// Upcoming days (today on) that have this recipe on the menu.
  List<DateTime> plannedDates(String recipeId) {
    final t = today();
    final out = days.values
        .where((d) => d.menu.contains(recipeId) && !parseDay(d.date).isBefore(t))
        .map((d) => parseDay(d.date))
        .toList();
    out.sort();
    return out;
  }

  // ---------- grocery lists ----------

  GroceryList? get latestList => lists.isEmpty ? null : lists.first;
  GroceryList? listById(String id) => lists.where((l) => l.id == id).firstOrNull;

  Future<GroceryList> newList(String title) async {
    final l = GroceryList(id: const Uuid().v4(), title: title, created: DateTime.now().millisecondsSinceEpoch);
    lists.insert(0, l);
    await _save();
    return l;
  }

  /// Adds every ingredient of [r] (scaled by [factor]) to the list.
  /// Identical lines from different recipes are merged into one item.
  Future<int> addRecipe(GroceryList l, Recipe r, {double factor = 1}) async {
    var added = 0;
    for (final line in r.ingredients) {
      if (line.startsWith('#') || line.trim().isEmpty || GroceryClassifier.skip(line)) continue;
      final text = IngredientScaler.scaleLine(line, factor).replaceAll(RegExp(r'\s+'), ' ').trim();
      final existing = l.items.where((i) => i.text.toLowerCase() == text.toLowerCase()).firstOrNull;
      if (existing != null) {
        if (!existing.source.split(' • ').contains(r.title)) existing.source = '${existing.source} • ${r.title}';
        continue;
      }
      l.items.add(GroceryItem(
        id: const Uuid().v4(),
        text: text,
        dept: GroceryClassifier.classify(line).key,
        source: r.title,
      ));
      added++;
    }
    await _save();
    return added;
  }

  Future<void> addItem(GroceryList l, String text, {String? dept}) async {
    if (text.trim().isEmpty) return;
    l.items.add(GroceryItem(
      id: const Uuid().v4(),
      text: text.trim(),
      dept: dept ?? GroceryClassifier.classify(text).key,
    ));
    await _save();
  }

  Future<void> toggle(GroceryList l, GroceryItem i) async {
    i.checked = !i.checked;
    i.checkedAt = i.checked ? DateTime.now().millisecondsSinceEpoch : 0;
    await _save();
  }

  Future<void> setDept(GroceryList l, GroceryItem i, String dept) async {
    i.dept = dept;
    await _save();
  }

  Future<void> removeItem(GroceryList l, GroceryItem i) async {
    l.items.remove(i);
    await _save();
  }

  Future<void> uncheckAll(GroceryList l) async {
    for (final i in l.items) {
      i.checked = false;
    }
    await _save();
  }

  Future<void> clearChecked(GroceryList l) async {
    l.items.removeWhere((i) => i.checked);
    await _save();
  }

  Future<void> renameList(GroceryList l, String title) async {
    l.title = title.trim().isEmpty ? l.title : title.trim();
    await _save();
  }

  Future<void> deleteList(GroceryList l) async {
    lists.remove(l);
    await _save();
  }

  /// Moves a list to the top so it opens from the home page.
  Future<void> makeCurrent(GroceryList l) async {
    l.opened = DateTime.now().millisecondsSinceEpoch;
    lists.sort((a, b) => b.opened.compareTo(a.opened));
    await _save();
  }
}

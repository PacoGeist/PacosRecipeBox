import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../models/taxonomy.dart';
import '../services/recipe_store.dart';
import '../widgets/recipe_card.dart';
import 'home_screen.dart';

enum _Sort { favorites, az, quickest, newest }

extension on _Sort {
  String get label => switch (this) {
        _Sort.favorites => 'Favorites first',
        _Sort.az => 'A to Z',
        _Sort.quickest => 'Quickest first',
        _Sort.newest => 'Newest first',
      };
}

class RecipeListScreen extends StatefulWidget {
  final String title;
  final RecipeFilter filter;
  final Color? color;
  final bool showMealTypeChips;
  final String? authorExact;
  final String? addCollection; // when set, the + button adds into this collection

  const RecipeListScreen({
    super.key,
    required this.title,
    required this.filter,
    this.color,
    this.showMealTypeChips = false,
    this.authorExact,
    this.addCollection,
  });

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  String text = '';
  String? mealType;
  _Sort sort = _Sort.favorites;

  int _minutes(Recipe r) => r.totalMinutes == 0 ? 99999 : r.totalMinutes;

  void _sortList(List<Recipe> list) {
    switch (sort) {
      case _Sort.favorites:
      case _Sort.az:
        break; // query() already returns A to Z
      case _Sort.quickest:
        list.sort((a, b) => _minutes(a).compareTo(_minutes(b)));
      case _Sort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Widget _header(BuildContext context, String text, {Color? color}) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        sliver: SliverToBoxAdapter(
          child: Row(children: [
            Container(width: 5, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    var f = widget.filter.copyWith(text: text, field: SearchField.everything);
    if (mealType != null) f = f.copyWith(mealType: mealType);
    var list = store.query(f);
    if (widget.authorExact != null) {
      list = list.where((r) => r.author.trim() == widget.authorExact).toList();
    }
    _sortList(list);

    // "Favorites first": favorites get their own section at the top.
    final splitFavorites = sort == _Sort.favorites && !widget.filter.favoritesOnly;
    final favs = splitFavorites ? list.where((r) => r.favorite).toList() : <Recipe>[];
    final rest = splitFavorites ? list.where((r) => !r.favorite).toList() : list;

    final accent = widget.color ?? Theme.of(context).colorScheme.primary;
    final showChips = widget.showMealTypeChips || widget.filter.mealType == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(4), child: Container(height: 4, color: accent)),
        actions: [
          PopupMenuButton<_Sort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: sort,
            onSelected: (s) => setState(() => sort = s),
            itemBuilder: (_) => [for (final s in _Sort.values) PopupMenuItem(value: s, child: Text(s.label))],
          ),
        ],
      ),
      floatingActionButton: widget.addCollection == null
          ? null
          : FloatingActionButton(
              onPressed: () => HomeScreen.showAddMenu(context, collection: widget.addCollection!),
              child: const Icon(Icons.add),
            ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search in ${widget.title}',
                isDense: true,
              ),
              onChanged: (v) => setState(() => text = v),
            ),
          ),
        ),
        if (showChips)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: mealType == null,
                      onSelected: (_) => setState(() => mealType = null),
                    ),
                  ),
                  for (final m in MealTypes.all)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${m.emoji} ${m.label}'),
                        selected: mealType == m.key,
                        selectedColor: m.color.withValues(alpha: 0.3),
                        onSelected: (s) => setState(() => mealType = s ? m.key : null),
                      ),
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '${list.length == 1 ? '1 recipe' : '${list.length} recipes'} · ${sort.label}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        if (list.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: RecipeGrid([]))
        else ...[
          if (favs.isNotEmpty) ...[
            _header(context, '❤️  Your favorites', color: const Color(0xFFE91E63)),
            SliverRecipeGrid(favs),
            if (rest.isNotEmpty) _header(context, 'More recipes', color: accent),
          ],
          SliverRecipeGrid(rest),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ]),
    );
  }
}

/// Helper so other screens can show a count string.
String recipeCount(List<Recipe> l) => l.length == 1 ? '1 recipe' : '${l.length} recipes';

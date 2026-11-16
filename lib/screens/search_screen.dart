import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/taxonomy.dart';
import '../services/recipe_store.dart';
import '../widgets/recipe_card.dart';

/// Search across all recipes by name, keyword, author or ingredient,
/// with optional cuisine / meal type / season / holiday / time filters.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  RecipeFilter f = const RecipeFilter();
  bool showFilters = false;

  int get activeFilters => [f.cuisine, f.mealType, f.season, f.holiday, f.maxMinutes, f.collection]
          .where((e) => e != null)
          .length +
      (f.favoritesOnly ? 1 : 0);

  Widget _dropdown(String label, String? value, List<Category> options, void Function(String?) onChanged) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem(value: null, child: Text('Any')),
          for (final o in options) DropdownMenuItem(value: o.key, child: Text('${o.emoji ?? ''} ${o.label}')),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    final hasQuery = f.text.trim().isNotEmpty || activeFilters > 0;
    final results = hasQuery ? store.query(f) : const <dynamic>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: switch (f.field) {
              SearchField.ingredient => 'e.g. chicken rice',
              SearchField.author => 'Who wrote it?',
              SearchField.name => 'Recipe name',
              SearchField.keyword => 'e.g. spicy, vegetarian, grilled',
              SearchField.everything => 'Search recipes…',
            },
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 18),
          onChanged: (v) => setState(() => f = f.copyWith(text: v)),
        ),
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: Badge(
              isLabelVisible: activeFilters > 0,
              label: Text('$activeFilters'),
              child: Icon(showFilters ? Icons.filter_alt_off : Icons.tune),
            ),
            onPressed: () => setState(() => showFilters = !showFilters),
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final sf in SearchField.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(sf.label),
                    selected: f.field == sf,
                    onSelected: (_) => setState(() => f = f.copyWith(field: sf)),
                  ),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: !showFilters
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _dropdown('Cuisine', f.cuisine, Cuisines.all, (v) => setState(() => f = f.copyWith(cuisine: v))),
                      _dropdown('Meal type', f.mealType, MealTypes.all,
                          (v) => setState(() => f = f.copyWith(mealType: v))),
                      _dropdown('Season', f.season, Seasons.all, (v) => setState(() => f = f.copyWith(season: v))),
                      _dropdown('Holiday', f.holiday, Holidays.all, (v) => setState(() => f = f.copyWith(holiday: v))),
                      _dropdown('Collection', f.collection, Collections.all,
                          (v) => setState(() => f = f.copyWith(collection: v))),
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<int?>(
                          initialValue: f.maxMinutes,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Total time', isDense: true),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Any')),
                            DropdownMenuItem(value: 20, child: Text('20 min or less')),
                            DropdownMenuItem(value: 30, child: Text('30 min or less')),
                            DropdownMenuItem(value: 60, child: Text('1 hour or less')),
                            DropdownMenuItem(value: 120, child: Text('2 hours or less')),
                          ],
                          onChanged: (v) => setState(() => f = f.copyWith(maxMinutes: v)),
                        ),
                      ),
                      FilterChip(
                        label: const Text('❤️ Favorites only'),
                        selected: f.favoritesOnly,
                        onSelected: (v) => setState(() => f = f.copyWith(favoritesOnly: v)),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => f = RecipeFilter(text: f.text, field: f.field)),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ),
        ),
        const Divider(height: 1),
        Expanded(
          child: !hasQuery
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('🔎', style: TextStyle(fontSize: 56)),
                      SizedBox(height: 8),
                      Text('Type a recipe name, an ingredient, an author or a keyword.\n'
                          'Use the filter button to narrow by cuisine, meal type, season or holiday.',
                          textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${results.length} found', style: Theme.of(context).textTheme.labelLarge)),
                  ),
                  Expanded(child: RecipeGrid(store.query(f))),
                ]),
        ),
      ]),
    );
  }
}

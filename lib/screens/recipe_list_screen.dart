import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../models/taxonomy.dart';
import '../services/recipe_store.dart';
import '../widgets/recipe_card.dart';
import 'home_screen.dart';

enum _Sort { az, quickest, newest }

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
  _Sort sort = _Sort.az;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    var f = widget.filter.copyWith(text: text, field: SearchField.everything);
    if (mealType != null) f = f.copyWith(mealType: mealType);
    var list = store.query(f);
    if (widget.authorExact != null) {
      list = list.where((r) => r.author.trim() == widget.authorExact).toList();
    }
    switch (sort) {
      case _Sort.az:
        break;
      case _Sort.quickest:
        list.sort((a, b) => (a.totalMinutes == 0 ? 99999 : a.totalMinutes)
            .compareTo(b.totalMinutes == 0 ? 99999 : b.totalMinutes));
      case _Sort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final accent = widget.color ?? Theme.of(context).colorScheme.primary;
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
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.az, child: Text('A to Z')),
              PopupMenuItem(value: _Sort.quickest, child: Text('Quickest first')),
              PopupMenuItem(value: _Sort.newest, child: Text('Newest first')),
            ],
          ),
        ],
      ),
      floatingActionButton: widget.addCollection == null
          ? null
          : FloatingActionButton(
              onPressed: () => HomeScreen.showAddMenu(context, collection: widget.addCollection!),
              child: const Icon(Icons.add),
            ),
      body: Column(children: [
        Padding(
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
        if (widget.showMealTypeChips || widget.filter.mealType == null)
          SizedBox(
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(list.length == 1 ? '1 recipe' : '${list.length} recipes',
                style: Theme.of(context).textTheme.labelLarge),
          ),
        ),
        Expanded(child: RecipeGrid(list)),
      ]),
    );
  }
}

/// Helper so other screens can show a count string.
String recipeCount(List<Recipe> l) => l.length == 1 ? '1 recipe' : '${l.length} recipes';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/taxonomy.dart';
import '../services/recipe_store.dart';
import '../widgets/decor.dart';
import 'recipe_list_screen.dart';

const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 210, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.25);

String _count(int n) => n == 1 ? '1 recipe' : '$n recipes';

class CuisinesScreen extends StatelessWidget {
  const CuisinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cuisines')),
      body: IngredientCorners(
        size: 50,
        child: GridView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          gridDelegate: _gridDelegate,
          children: [
            for (final c in Cuisines.all)
              CategoryTile(
                label: c.label,
                emoji: c.emoji,
                icon: c.icon,
                color: c.color,
                subtitle: _count(store.countWhere((r) => r.cuisines.contains(c.key))),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MealTypeMenuScreen(
                      title: c.label,
                      filter: RecipeFilter(cuisine: c.key),
                      color: c.color,
                      emoji: c.emoji,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SeasonalScreen extends StatelessWidget {
  const SeasonalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    Widget tiles(List<Category> cats, RecipeFilter Function(String) f, bool Function(dynamic, String) has) =>
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: _gridDelegate,
            delegate: SliverChildListDelegate([
              for (final c in cats)
                CategoryTile(
                  label: c.label,
                  emoji: c.emoji,
                  icon: c.icon,
                  color: c.color,
                  subtitle: _count(store.countWhere((r) => has(r, c.key))),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MealTypeMenuScreen(title: c.label, filter: f(c.key), color: c.color, emoji: c.emoji),
                    ),
                  ),
                ),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Seasonal Recipes')),
      body: IngredientCorners(
        size: 50,
        child: CustomScrollView(slivers: [
          const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16), sliver: SliverToBoxAdapter(child: SectionHeader('By Season'))),
          tiles(Seasons.all, (k) => RecipeFilter(season: k), (r, k) => r.seasons.contains(k)),
          const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: SectionHeader('By Holiday'))),
          tiles(Holidays.all, (k) => RecipeFilter(holiday: k), (r, k) => r.holidays.contains(k)),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ]),
      ),
    );
  }
}

class AuthorsScreen extends StatefulWidget {
  const AuthorsScreen({super.key});
  @override
  State<AuthorsScreen> createState() => _AuthorsScreenState();
}

class _AuthorsScreenState extends State<AuthorsScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    final counts = <String, int>{};
    for (final r in store.all) {
      final a = r.author.trim();
      if (a.isNotEmpty) counts[a] = (counts[a] ?? 0) + 1;
    }
    final names = counts.keys.where((n) => n.toLowerCase().contains(q.toLowerCase())).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes by Author')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Find an author'),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: names.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = names[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.primaries[n.hashCode % Colors.primaries.length],
                  child: Text(n.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(n),
                trailing: Text(_count(counts[n]!)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeListScreen(
                      title: n,
                      filter: const RecipeFilter(),
                      authorExact: n,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}


/// After choosing a cuisine (or season/holiday): one button per meal type,
/// so people pick "Desserts" first instead of facing 50 recipes at once.
class MealTypeMenuScreen extends StatelessWidget {
  final String title;
  final RecipeFilter filter;
  final Color color;
  final String? emoji;
  const MealTypeMenuScreen({super.key, required this.title, required this.filter, required this.color, this.emoji});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    final inGroup = store.query(filter);
    final favs = inGroup.where((r) => r.favorite).length;
    void open(String t, RecipeFilter f, Color c) => Navigator.push(
        context, MaterialPageRoute(builder: (_) => RecipeListScreen(title: t, filter: f, color: c)));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(4), child: Container(height: 4, color: color)),
      ),
      body: IngredientCorners(
        size: 50,
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${emoji ?? ''} ${inGroup.length} $title recipes — what are you making?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            sliver: SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildListDelegate([
                if (favs > 0)
                  CategoryTile(
                    label: 'Favorites',
                    emoji: '❤️',
                    icon: Icons.favorite,
                    color: const Color(0xFFE91E63),
                    subtitle: _count(favs),
                    onTap: () => open('$title Favorites', filter.copyWith(favoritesOnly: true), const Color(0xFFE91E63)),
                  ),
                for (final m in MealTypes.all)
                  if (inGroup.any((r) => r.mealTypes.contains(m.key)))
                    CategoryTile(
                      label: m.label,
                      emoji: m.emoji,
                      icon: m.icon,
                      color: m.color,
                      subtitle: _count(inGroup.where((r) => r.mealTypes.contains(m.key)).length),
                      onTap: () => open('$title ${m.label}', filter.copyWith(mealType: m.key), m.color),
                    ),
                CategoryTile(
                  label: 'All $title',
                  emoji: '📖',
                  icon: Icons.menu_book,
                  color: color,
                  subtitle: _count(inGroup.length),
                  onTap: () => open('$title Recipes', filter, color),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

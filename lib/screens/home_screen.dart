import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/taxonomy.dart';
import '../services/recipe_store.dart';
import '../services/share_service.dart';
import '../services/startup_log.dart';
import '../theme/app_theme.dart';
import '../widgets/decor.dart';
import 'category_screens.dart';
import 'recipe_edit_screen.dart';
import 'recipe_list_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'web_import_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static Future<void> showAddMenu(BuildContext context, {String collection = Collections.family}) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.edit_note)),
            title: const Text('Write a recipe'),
            subtitle: const Text('Type in your own or a family recipe'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => RecipeEditScreen(newCollection: collection)));
            },
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.travel_explore)),
            title: const Text('Import from a website'),
            subtitle: const Text('Paste a link to a recipe page'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WebImportScreen()));
            },
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.file_open)),
            title: const Text('Open a shared recipe file'),
            subtitle: const Text('A .recipe file a friend sent you'),
            onTap: () async {
              Navigator.pop(ctx);
              await ShareService.importRecipeFileFlow(context);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    final t = Theme.of(context);
    final p = context.palette;

    void openList(String title, RecipeFilter f, {Color? color, String? collection}) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RecipeListScreen(title: title, filter: f, color: color, addCollection: collection)));

    String countLabel(int n) => n == 1 ? '1 recipe' : '$n recipes';

    const grid = SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.25);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('🍲 ', style: TextStyle(fontSize: 24)),
          Text(appTitle, style: t.appBarTheme.titleTextStyle?.copyWith(fontSize: 26)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddMenu(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: IngredientCorners(
        size: 58,
        opacity: 0.85,
        child: !store.loaded
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<int>(
                      valueListenable: StartupLog.changes,
                      builder: (context, _, _) => StartupLog.serious.isEmpty
                          ? const SizedBox.shrink()
                          : Card(
                              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              color: Theme.of(context).colorScheme.errorContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Recipe Box ran into a problem while starting.',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(StartupLog.serious.first.split('\n').first, maxLines: 3),
                                  TextButton.icon(
                                    onPressed: () => Clipboard.setData(
                                        ClipboardData(text: StartupLog.entries.join('\n\n'))),
                                    icon: const Icon(Icons.copy),
                                    label: const Text('Copy details'),
                                  ),
                                ]),
                              ),
                            ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Material(
                        color: p.card,
                        elevation: 2,
                        shadowColor: Colors.brown.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), side: BorderSide(color: p.border)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () =>
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Row(children: [
                              Icon(Icons.search, color: t.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Search ${store.count} recipes by name, ingredient, author…',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: t.colorScheme.onSurface.withValues(alpha: 0.65))),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _section(context, 'My Recipe Box'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid.count(
                      crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        for (final c in Collections.all)
                          CategoryTile(
                            label: c.label,
                            emoji: c.emoji,
                            icon: c.icon,
                            color: c.color,
                            subtitle: countLabel(store.countWhere((r) => r.collection == c.key)),
                            onTap: () => openList(c.label, RecipeFilter(collection: c.key),
                                color: c.color, collection: c.key),
                          ),
                        CategoryTile(
                          label: 'Favorites',
                          emoji: '❤️',
                          icon: Icons.favorite,
                          color: const Color(0xFFE91E63),
                          subtitle: countLabel(store.countWhere((r) => r.favorite)),
                          onTap: () => openList('Favorites', const RecipeFilter(favoritesOnly: true),
                              color: const Color(0xFFE91E63)),
                        ),
                      ],
                    ),
                  ),
                  _section(context, 'Browse'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: grid,
                      delegate: SliverChildListDelegate([
                        CategoryTile(
                          label: 'Cuisines',
                          emoji: '🌎',
                          icon: Icons.public,
                          color: const Color(0xFF00897B),
                          subtitle: '${Cuisines.all.length} kitchens',
                          onTap: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => const CuisinesScreen())),
                        ),
                        CategoryTile(
                          label: 'Seasonal',
                          emoji: '🍂',
                          icon: Icons.calendar_month,
                          color: const Color(0xFFEF6C00),
                          subtitle: 'Seasons & holidays',
                          onTap: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => const SeasonalScreen())),
                        ),
                        CategoryTile(
                          label: 'By Author',
                          emoji: '✍️',
                          icon: Icons.person,
                          color: const Color(0xFF5D4037),
                          subtitle: '${store.authors.length} cooks',
                          onTap: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => const AuthorsScreen())),
                        ),
                        CategoryTile(
                          label: 'All Recipes',
                          emoji: '📖',
                          icon: Icons.menu_book,
                          color: const Color(0xFF3949AB),
                          subtitle: countLabel(store.count),
                          onTap: () => openList('All Recipes', const RecipeFilter()),
                        ),
                      ]),
                    ),
                  ),
                  _section(context, 'Meal Types'),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverGrid(
                      gridDelegate: grid,
                      delegate: SliverChildListDelegate([
                        for (final m in MealTypes.all)
                          CategoryTile(
                            label: m.label,
                            emoji: m.emoji,
                            icon: m.icon,
                            color: m.color,
                            subtitle: countLabel(store.countWhere((r) => r.mealTypes.contains(m.key))),
                            onTap: () => openList(m.label, RecipeFilter(mealType: m.key), color: m.color),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: SectionHeader(title)),
      );
}

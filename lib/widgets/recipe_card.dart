import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../screens/recipe_detail_screen.dart';
import '../services/recipe_store.dart';
import 'recipe_image.dart';

/// Photo-first card used in recipe grids.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  const RecipeCard(this.recipe, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(tag: 'photo-${recipe.id}', child: RecipeImage(recipe)),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black38,
                      shape: const CircleBorder(),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(recipe.favorite ? Icons.favorite : Icons.favorite_border,
                            color: recipe.favorite ? Colors.pinkAccent : Colors.white),
                        onPressed: () => context.read<RecipeStore>().toggleFavorite(recipe),
                      ),
                    ),
                  ),
                  if (recipe.totalMinutes > 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration:
                            BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(formatMinutes(recipe.totalMinutes),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
                  const SizedBox(height: 2),
                  Text(
                    [if (recipe.cuisines.isNotEmpty) recipe.cuisines.first, if (recipe.author.isNotEmpty) recipe.author]
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive grid of recipe cards (2 columns on phones, more on tablets).
class RecipeGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final EdgeInsets padding;
  const RecipeGrid(this.recipes, {super.key, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🥄', style: TextStyle(fontSize: 56)),
            SizedBox(height: 12),
            Text('No recipes here yet.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Tap + to add one, or try a different search.', textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: recipes.length,
      itemBuilder: (_, i) => RecipeCard(recipes[i]),
    );
  }
}

/// Sliver version of [RecipeGrid] for screens with several sections.
class SliverRecipeGrid extends StatelessWidget {
  final List<Recipe> recipes;
  const SliverRecipeGrid(this.recipes, {super.key});

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          delegate: SliverChildBuilderDelegate((_, i) => RecipeCard(recipes[i]), childCount: recipes.length),
        ),
      );
}

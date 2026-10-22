import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe.dart';
import '../models/taxonomy.dart';
import '../services/planner_store.dart';
import '../services/recipe_store.dart';
import '../services/scaler.dart';
import '../services/settings.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/planner_actions.dart';
import '../widgets/recipe_image.dart';
import 'recipe_edit_screen.dart';
import 'recipe_list_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});
  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  double factor = 1;
  final Set<int> checked = {};

  static final multipliers = <double, String>{0.5: '½×', 1: '1×', 2: '2×', 3: '3×'};

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    final settings = context.watch<AppSettings>();
    final r = store.byId(widget.recipeId);
    if (r == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('This recipe was deleted.')));
    }
    final t = Theme.of(context);
    final p = context.palette;
    final fs = settings.recipeFontScale;
    final bodyStyle = t.textTheme.bodyLarge!.copyWith(fontSize: 16.5 * fs, height: 1.45);
    final h = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: h * 0.42,
            pinned: true,
            stretch: true,
            backgroundColor: t.colorScheme.primary,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white, shadows: [Shadow(blurRadius: 6)]),
            actions: [
              IconButton(
                tooltip: r.favorite ? 'Remove from favorites' : 'Add to favorites',
                icon: Icon(r.favorite ? Icons.favorite : Icons.favorite_border,
                    color: r.favorite ? Colors.pinkAccent : Colors.white),
                onPressed: () => store.toggleFavorite(r),
              ),
              IconButton(
                tooltip: 'Edit recipe',
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: r))),
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share),
                onPressed: () => ShareService.showShareMenu(context, r, factor),
              ),
              PopupMenuButton<String>(
                iconColor: Colors.white,
                onSelected: (v) async {
                  if (v == 'edit') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: r)));
                  } else if (v == 'copy') {
                    final c = r.copy()
                      ..id = 'u-${DateTime.now().microsecondsSinceEpoch}'
                      ..title = '${r.title} (my version)'
                      ..collection = Collections.family
                      ..favorite = false
                      ..createdAt = DateTime.now().millisecondsSinceEpoch;
                    await store.save(c);
                    if (context.mounted) {
                      Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: c)));
                    }
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete recipe?'),
                        content: Text('“${r.title}” and its photos will be removed from this device.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      Navigator.pop(context);
                      await store.delete(r);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
                  PopupMenuItem(
                      value: 'copy', child: ListTile(leading: Icon(Icons.copy), title: Text('Make my own version'))),
                  PopupMenuItem(
                      value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              titlePadding: const EdgeInsetsDirectional.only(start: 56, end: 140, bottom: 14),
              title: LayoutBuilder(builder: (c, box) {
                // Show the title in the bar only when collapsed.
                final collapsed = box.maxHeight < kToolbarHeight + MediaQuery.paddingOf(context).top + 10;
                return AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18)),
                );
              }),
              background: GestureDetector(
                onTap: r.photo == null ? null : () => _openPhoto(context, r.photo!, r.photoCredit),
                child: Stack(fit: StackFit.expand, children: [
                  Hero(tag: 'photo-${r.id}', child: RecipeImage(r)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x88000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
                        stops: [0, 0.25, 0.55, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title,
                          style: t.textTheme.headlineMedium?.copyWith(
                              color: Colors.white, shadows: const [Shadow(blurRadius: 8, color: Colors.black)])),
                      if (r.author.isNotEmpty)
                        Text('by ${r.author}',
                            style: const TextStyle(
                                color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 15)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _infoRow(context, r),
                    if (r.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(r.description, style: bodyStyle.copyWith(fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 14),
                    _planBar(context, r),
                    const SizedBox(height: 18),
                    _multiplierBar(context, r, settings),
                    const SizedBox(height: 10),
                    LayoutBuilder(builder: (c, box) {
                      final ingredients = _ingredients(context, r, bodyStyle);
                      final steps = _steps(context, r, bodyStyle);
                      if (box.maxWidth > 720) {
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 4, child: ingredients),
                          const SizedBox(width: 16),
                          Expanded(flex: 6, child: steps),
                        ]);
                      }
                      return Column(children: [ingredients, const SizedBox(height: 16), steps]);
                    }),
                    if (r.notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _panel(context,
                          title: 'Notes', icon: Icons.sticky_note_2, child: Text(r.notes, style: bodyStyle)),
                    ],
                    const SizedBox(height: 16),
                    _myNotes(context, r, bodyStyle),
                    const SizedBox(height: 16),
                    _tags(context, r),
                    const SizedBox(height: 16),
                    _credits(context, r, p),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Add to menu · Grocery list · I made this — plus when it was last made.
  Widget _planBar(BuildContext context, Recipe r) {
    final planner = context.watch<PlannerStore>();
    final made = planner.madeDates(r.id);
    final planned = planner.plannedDates(r.id);
    final t = Theme.of(context);
    ButtonStyle style(Color c) => FilledButton.styleFrom(
          backgroundColor: c.withValues(alpha: 0.14),
          foregroundColor: c,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
    Widget btn(Color c, IconData icon, String label, VoidCallback onTap) => Expanded(
          child: FilledButton(
            style: style(c),
            onPressed: onTap,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        btn(const Color(0xFF3949AB), Icons.event_note, 'Add to menu', () => addToMenuFlow(context, r)),
        const SizedBox(width: 8),
        btn(AppTheme.basil, Icons.shopping_cart, 'Grocery list', () => addToGroceryFlow(context, [r], factor: factor)),
        const SizedBox(width: 8),
        btn(AppTheme.tomato, Icons.check_circle_outline, 'I made this', () => madeItFlow(context, r)),
      ]),
      if (made.isNotEmpty || planned.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 12, runSpacing: 4, children: [
            if (made.isNotEmpty)
              Text(
                '✅ Made ${made.length == 1 ? 'once' : '${made.length} times'} · last ${fmtRelative(made.first).toLowerCase() == 'today' ? 'today' : fmtShort(made.first)}',
                style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            if (planned.isNotEmpty)
              Text('📅 On the menu ${fmtRelative(planned.first)}',
                  style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }

  /// The user's own notes for this recipe.
  Widget _myNotes(BuildContext context, Recipe r, TextStyle style) {
    Future<void> edit() async {
      final c = TextEditingController(text: r.myNotes);
      final store = context.read<RecipeStore>();
      final saved = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('My notes'),
          content: SizedBox(
            width: 500,
            child: TextField(
              controller: c,
              autofocus: true,
              maxLines: 8,
              minLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Used half the sugar — perfect. Doubled it for the potluck.'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Save')),
          ],
        ),
      );
      if (saved != null) await store.setMyNotes(r, saved);
    }

    if (r.myNotes.isEmpty) {
      return OutlinedButton.icon(
        onPressed: edit,
        icon: const Icon(Icons.edit_note),
        label: const Padding(padding: EdgeInsets.all(10), child: Text('Add my notes')),
      );
    }
    return _panel(
      context,
      title: 'My notes',
      icon: Icons.edit_note,
      trailing: IconButton(tooltip: 'Edit my notes', icon: const Icon(Icons.edit), onPressed: edit),
      child: Text(r.myNotes, style: style),
    );
  }

  Widget _infoRow(BuildContext context, Recipe r) {
    final t = Theme.of(context);
    Widget item(IconData i, String label, String value, Color c) => Expanded(
          child: Column(children: [
            CircleAvatar(radius: 20, backgroundColor: c.withValues(alpha: 0.15), child: Icon(i, color: c)),
            const SizedBox(height: 4),
            Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(label, style: t.textTheme.bodySmall),
          ]),
        );
    final servings = r.servings * factor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(children: [
          item(Icons.content_cut, 'Prep', formatMinutes(r.prepMinutes), AppTheme.basil),
          item(Icons.local_fire_department, 'Cook', formatMinutes(r.cookMinutes), AppTheme.tomato),
          item(Icons.schedule, 'Total', formatMinutes(r.totalMinutes), const Color(0xFF6A1B9A)),
          item(Icons.people, 'Servings',
              r.servings > 0 ? IngredientScaler.format(servings) : '—', const Color(0xFFF57F17)),
        ]),
      ),
    );
  }

  Widget _multiplierBar(BuildContext context, Recipe r, AppSettings settings) {
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Make the recipe', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      SegmentedButton<double>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: t.colorScheme.primary,
          selectedForegroundColor: Colors.white,
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: settings.fontFamily),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        segments: [
          for (final e in multipliers.entries)
            ButtonSegment(
              value: e.key,
              label: Text(e.value),
              tooltip: switch (e.key) { 0.5 => 'Half', 1 => 'Original', 2 => 'Double', _ => 'Triple' },
            ),
        ],
        selected: {factor},
        onSelectionChanged: (s) => setState(() => factor = s.first),
      ),
      if (factor != 1 && r.servings > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Ingredients adjusted to ${IngredientScaler.format(r.servings * factor)} servings '
            '(${multipliers[factor]} the original ${r.servings}).',
            style: t.textTheme.bodySmall,
          ),
        ),
    ]);
  }

  Widget _panel(BuildContext context, {required String title, required IconData icon, required Widget child, Widget? trailing}) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: t.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: t.textTheme.headlineSmall?.copyWith(fontSize: 21))),
            ?trailing,
          ]),
          const Divider(height: 18),
          child,
        ]),
      ),
    );
  }

  Widget _ingredients(BuildContext context, Recipe r, TextStyle style) {
    final t = Theme.of(context);
    return _panel(
      context,
      title: 'Ingredients',
      icon: Icons.shopping_basket,
      trailing: checked.isEmpty
          ? null
          : TextButton(onPressed: () => setState(checked.clear), child: const Text('Reset')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < r.ingredients.length; i++)
          if (r.ingredients[i].startsWith('#'))
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Text(r.ingredients[i].replaceFirst(RegExp(r'^#+\s*'), ''),
                  style: style.copyWith(fontWeight: FontWeight.w800, color: t.colorScheme.secondary)),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => checked.contains(i) ? checked.remove(i) : checked.add(i)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: Icon(checked.contains(i) ? Icons.check_circle : Icons.circle_outlined,
                        size: 20 * (style.fontSize! / 16.5),
                        color: checked.contains(i) ? AppTheme.basil : t.colorScheme.primary.withValues(alpha: 0.6)),
                  ),
                  Expanded(child: _ingredientText(r.ingredients[i], style, checked.contains(i), t)),
                ]),
              ),
            ),
      ]),
    );
  }

  Widget _ingredientText(String line, TextStyle style, bool done, ThemeData t) {
    final scaled = IngredientScaler.scaleLine(line, factor);
    final (qty, rest) = IngredientScaler.splitQuantity(scaled);
    final deco = done ? TextDecoration.lineThrough : null;
    final c = done ? style.color?.withValues(alpha: 0.45) : style.color;
    return Text.rich(TextSpan(children: [
      if (qty.isNotEmpty)
        TextSpan(
            text: qty,
            style: style.copyWith(
                fontWeight: FontWeight.w900,
                color: factor != 1 && !done ? t.colorScheme.primary : c,
                decoration: deco)),
      TextSpan(text: rest, style: style.copyWith(color: c, decoration: deco)),
    ]));
  }

  Widget _steps(BuildContext context, Recipe r, TextStyle style) {
    final t = Theme.of(context);
    return _panel(
      context,
      title: 'Directions',
      icon: Icons.format_list_numbered,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < r.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 14 * (style.fontSize! / 16.5),
                backgroundColor: Colors.primaries[(i * 3) % Colors.primaries.length].shade600,
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13 * (style.fontSize! / 16.5))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(r.steps[i].text, style: style),
                  if (r.steps[i].photo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => _openPhoto(context, r.steps[i].photo!, ''),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(aspectRatio: 4 / 3, child: PhotoView(r.steps[i].photo)),
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        if (r.steps.isEmpty) Text('No directions entered.', style: t.textTheme.bodyMedium),
      ]),
    );
  }

  Widget _tags(BuildContext context, Recipe r) {
    final chips = <Widget>[];
    void add(List<String> values, List<Category> cats, RecipeFilter Function(String) f) {
      for (final v in values) {
        final c = cats.where((x) => x.key == v).firstOrNull;
        chips.add(ActionChip(
          avatar: Text(c?.emoji ?? '🏷️'),
          label: Text(c?.label ?? v),
          backgroundColor: (c?.color ?? Colors.grey).withValues(alpha: 0.12),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => RecipeListScreen(title: c?.label ?? v, filter: f(v), color: c?.color))),
        ));
      }
    }

    add(r.cuisines, Cuisines.all, (v) => RecipeFilter(cuisine: v));
    add(r.mealTypes, MealTypes.all, (v) => RecipeFilter(mealType: v));
    add(r.seasons, Seasons.all, (v) => RecipeFilter(season: v));
    add(r.holidays, Holidays.all, (v) => RecipeFilter(holiday: v));
    for (final k in r.keywords) {
      chips.add(ActionChip(
        label: Text('#$k'),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    RecipeListScreen(title: '#$k', filter: RecipeFilter(text: k, field: SearchField.keyword)))),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _credits(BuildContext context, Recipe r, AppPalette p) {
    final t = Theme.of(context);
    final small = t.textTheme.bodyMedium;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, style: BorderStyle.solid),
        color: t.colorScheme.secondary.withValues(alpha: 0.07),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified, size: 18, color: t.colorScheme.secondary),
          const SizedBox(width: 6),
          Text('Recipe credit', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        if (r.author.isNotEmpty) Text('Author: ${r.author}', style: small),
        if (r.source.isNotEmpty) Text('Source: ${r.source}', style: small),
        if (r.sourceUrl.isNotEmpty)
          InkWell(
            onTap: () => launchUrl(Uri.parse(r.sourceUrl), mode: LaunchMode.externalApplication),
            child: Text(r.sourceUrl,
                style: small?.copyWith(color: t.colorScheme.primary, decoration: TextDecoration.underline)),
          ),
        if (r.license.isNotEmpty) Text(r.license, style: t.textTheme.bodySmall),
        if (r.photoCredit.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Photo: ${r.photoCredit}', style: t.textTheme.bodySmall),
        ],
        Text('Collection: ${Collections.byKey(r.collection).label}', style: t.textTheme.bodySmall),
      ]),
    );
  }

  void _openPhoto(BuildContext context, String photo, String credit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Column(children: [
            Expanded(child: InteractiveViewer(child: Center(child: PhotoView(photo, fit: BoxFit.contain)))),
            if (credit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(credit, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
          ]),
        ),
      ),
    );
  }
}

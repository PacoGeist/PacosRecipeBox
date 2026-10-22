import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../models/taxonomy.dart';
import '../services/planner_store.dart';
import '../services/recipe_store.dart';
import '../theme/app_theme.dart';
import '../widgets/planner_actions.dart';
import '../widgets/recipe_image.dart';
import 'recipe_detail_screen.dart';

/// Plan a day's menu: pick several recipes, mark what you made, and turn the
/// whole menu into a grocery list.
class MenuPlannerScreen extends StatefulWidget {
  final DateTime? initialDay;
  const MenuPlannerScreen({super.key, this.initialDay});
  @override
  State<MenuPlannerScreen> createState() => _MenuPlannerScreenState();
}

class _MenuPlannerScreenState extends State<MenuPlannerScreen> {
  late DateTime day = widget.initialDay ?? today();

  DateTime get _weekStart => day.subtract(Duration(days: day.weekday - 1));

  Future<void> _addRecipes() async {
    final planner = context.read<PlannerStore>();
    final current = planner.peek(day)?.menu ?? const <String>[];
    final ids = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => RecipePickerScreen(title: 'Menu for ${fmtRelative(day)}', already: current)),
    );
    if (ids != null && ids.isNotEmpty) await planner.addToMenu(day, ids);
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerStore>();
    final store = context.watch<RecipeStore>();
    final t = Theme.of(context);
    final plan = planner.peek(day);
    final menu = (plan?.menu ?? []).map(store.byId).whereType<Recipe>().toList();
    final made = plan?.made ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Planner'),
        actions: [
          IconButton(
            tooltip: 'Menu history calendar',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MenuHistoryScreen(initialDay: day))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecipes,
        icon: const Icon(Icons.add),
        label: const Text('Add recipes', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
        children: [
          // Day picker
          Row(children: [
            IconButton(
              tooltip: 'Previous day',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => day = day.subtract(const Duration(days: 1))),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final d = await pickDay(context, initial: day);
                  if (d != null) setState(() => day = d);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    Text(fmtRelative(day), style: t.textTheme.headlineSmall),
                    Text(fmtLong(day), style: t.textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next day',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => day = day.add(const Duration(days: 1))),
            ),
          ]),
          // Week strip
          SizedBox(
            height: 64,
            child: Row(children: [
              for (var i = 0; i < 7; i++)
                Builder(builder: (context) {
                  final d = _weekStart.add(Duration(days: i));
                  final sel = dayKey(d) == dayKey(day);
                  final p = planner.peek(d);
                  final hasMenu = p != null && p.menu.isNotEmpty;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Material(
                        color: sel ? t.colorScheme.primary : context.palette.card,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.palette.border)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => day = d),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                                style: TextStyle(fontSize: 12, color: sel ? Colors.white : null)),
                            Text('${d.day}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16, color: sel ? Colors.white : null)),
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasMenu ? (sel ? Colors.white : const Color(0xFF3949AB)) : Colors.transparent,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
            ]),
          ),
          const SizedBox(height: 12),
          if (menu.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Text('🍽️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('Nothing planned for ${fmtRelative(day).toLowerCase() == 'today' ? 'today' : fmtShort(day)} yet.',
                      textAlign: TextAlign.center, style: t.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text('Tap “Add recipes” to pick dishes for this day — a main, sides, dessert, drinks…',
                      textAlign: TextAlign.center),
                ]),
              ),
            )
          else ...[
            Row(children: [
              Expanded(child: Text('Menu · ${menu.length} ${menu.length == 1 ? 'dish' : 'dishes'}', style: t.textTheme.titleLarge)),
              FilledButton.icon(
                onPressed: () => addToGroceryFlow(context, menu, newTitle: 'Menu for ${fmtShort(day)}'),
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Grocery list'),
              ),
            ]),
            const SizedBox(height: 8),
            for (final r in menu)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id))),
                  child: Row(children: [
                    SizedBox(width: 84, height: 84, child: RecipeImage(r)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(
                          [
                            ...r.mealTypes.map((m) => MealTypes.all.where((x) => x.key == m).firstOrNull?.label ?? m),
                            if (r.totalMinutes > 0) formatMinutes(r.totalMinutes),
                          ].join(' · '),
                          style: t.textTheme.bodySmall,
                        ),
                      ]),
                    ),
                    Column(children: [
                      IconButton(
                        tooltip: made.contains(r.id) ? 'Made it ✓' : 'Mark as made',
                        icon: Icon(made.contains(r.id) ? Icons.check_circle : Icons.check_circle_outline,
                            color: made.contains(r.id) ? AppTheme.basil : null),
                        onPressed: () => made.contains(r.id)
                            ? planner.unmarkMade(day, r.id)
                            : planner.markMade(day, r.id),
                      ),
                      IconButton(
                        tooltip: 'Remove from menu',
                        icon: const Icon(Icons.close),
                        onPressed: () => planner.removeFromMenu(day, r.id),
                      ),
                    ]),
                  ]),
                ),
              ),
            Text('Tap the check mark when you make a dish — it’s saved in your menu history.', style: t.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          TextFormField(
            key: ValueKey('note-${dayKey(day)}'),
            initialValue: plan?.note ?? '',
            decoration: const InputDecoration(
                labelText: 'Note for this day', hintText: 'e.g. Grandma’s birthday dinner — 8 people', prefixIcon: Icon(Icons.notes)),
            onChanged: (v) => planner.setNote(day, v),
          ),
        ],
      ),
    );
  }
}

/// Choose several recipes at once (used by the menu planner).
class RecipePickerScreen extends StatefulWidget {
  final String title;
  final List<String> already;
  const RecipePickerScreen({super.key, required this.title, this.already = const []});
  @override
  State<RecipePickerScreen> createState() => _RecipePickerScreenState();
}

class _RecipePickerScreenState extends State<RecipePickerScreen> {
  final Set<String> picked = {};
  String text = '';
  String? meal;
  bool favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecipeStore>();
    var list = store.query(RecipeFilter(text: text, mealType: meal, favoritesOnly: favoritesOnly));
    list.sort((a, b) => (b.favorite ? 1 : 0) - (a.favorite ? 1 : 0)); // favorites first, still A to Z
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: picked.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context, picked.toList()),
              icon: const Icon(Icons.check),
              label: Text('Add ${picked.length} to menu', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search recipes', isDense: true),
            onChanged: (v) => setState(() => text = v),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('❤️ Favorites'),
                  selected: favoritesOnly,
                  onSelected: (v) => setState(() => favoritesOnly = v),
                ),
              ),
              for (final m in MealTypes.all)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${m.emoji} ${m.label}'),
                    selected: meal == m.key,
                    onSelected: (s) => setState(() => meal = s ? m.key : null),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final r = list[i];
              final already = widget.already.contains(r.id);
              return CheckboxListTile(
                value: already || picked.contains(r.id),
                onChanged: already ? null : (v) => setState(() => v! ? picked.add(r.id) : picked.remove(r.id)),
                secondary: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 52, height: 52, child: RecipeImage(r)),
                ),
                title: Text('${r.favorite ? '❤️ ' : ''}${r.title}', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  already
                      ? 'Already on this menu'
                      : [if (r.cuisines.isNotEmpty) r.cuisines.first, if (r.totalMinutes > 0) formatMinutes(r.totalMinutes)]
                          .join(' · '),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Calendar of past (and planned) menus and what was cooked each day.
class MenuHistoryScreen extends StatefulWidget {
  final DateTime? initialDay;
  const MenuHistoryScreen({super.key, this.initialDay});
  @override
  State<MenuHistoryScreen> createState() => _MenuHistoryScreenState();
}

class _MenuHistoryScreenState extends State<MenuHistoryScreen> {
  late DateTime selected = widget.initialDay ?? today();
  late DateTime month = DateTime(selected.year, selected.month);

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerStore>();
    final store = context.watch<RecipeStore>();
    final t = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final lead = first.weekday - 1; // Monday-first grid
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = lead + daysInMonth;
    final plan = planner.peek(selected);
    List<Recipe> recipes(List<String> ids) => ids.map(store.byId).whereType<Recipe>().toList();

    Widget recipeTile(Recipe r, {bool made = false}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 48, height: 48, child: RecipeImage(r)),
          ),
          title: Text(r.title),
          trailing: made ? const Icon(Icons.check_circle, color: AppTheme.basil) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id))),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Menu History')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
            ),
            Expanded(child: Text(fmtMonth(month), textAlign: TextAlign.center, style: t.textTheme.headlineSmall)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
            ),
          ]),
          Row(children: [
            for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
              Expanded(child: Text(d, textAlign: TextAlign.center, style: t.textTheme.labelMedium)),
          ]),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemCount: ((cells + 6) ~/ 7) * 7,
            itemBuilder: (_, i) {
              final n = i - lead + 1;
              if (n < 1 || n > daysInMonth) return const SizedBox.shrink();
              final d = DateTime(month.year, month.month, n);
              final p = planner.peek(d);
              final sel = dayKey(d) == dayKey(selected);
              final isToday = dayKey(d) == dayKey(today());
              return Material(
                color: sel ? t.colorScheme.primary : context.palette.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isToday ? t.colorScheme.primary : context.palette.border, width: isToday ? 2 : 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => selected = d),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$n', style: TextStyle(fontWeight: FontWeight.w800, color: sel ? Colors.white : null)),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (p != null && p.menu.isNotEmpty) _dot(sel ? Colors.white : const Color(0xFF3949AB)),
                      if (p != null && p.made.isNotEmpty) _dot(sel ? Colors.white : AppTheme.basil),
                    ]),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            _dot(const Color(0xFF3949AB)),
            const Text(' planned menu   '),
            _dot(AppTheme.basil),
            const Text(' made'),
          ]),
          const Divider(height: 28),
          Row(children: [
            Expanded(child: Text(fmtLong(selected), style: t.textTheme.titleLarge)),
            TextButton.icon(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MenuPlannerScreen(initialDay: selected))),
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Plan this day'),
            ),
          ]),
          if (plan == null || plan.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No menu or cooking recorded for this day.'))
          else ...[
            if (plan.note.isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('📝 ${plan.note}')),
            if (plan.menu.isNotEmpty) ...[
              Text('Menu', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              for (final r in recipes(plan.menu)) recipeTile(r, made: plan.made.contains(r.id)),
            ],
            if (plan.made.any((id) => !plan.menu.contains(id))) ...[
              const SizedBox(height: 8),
              Text('Also made', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              for (final r in recipes(plan.made.where((id) => !plan.menu.contains(id)).toList())) recipeTile(r, made: true),
            ],
          ],
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

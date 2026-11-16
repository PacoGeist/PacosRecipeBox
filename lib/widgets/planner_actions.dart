import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../screens/grocery_screens.dart';
import '../screens/menu_screens.dart';
import '../services/planner_store.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November',
  'December',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _daysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String fmtShort(DateTime d) => '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
String fmtLong(DateTime d) => '${_daysLong[d.weekday - 1]}, ${_monthsLong[d.month - 1]} ${d.day}, ${d.year}';
String fmtMonth(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

/// Friendly name for a day: Today / Tomorrow / Yesterday / Mon, Oct 26.
String fmtRelative(DateTime d) {
  final t = today();
  final diff = DateTime(d.year, d.month, d.day).difference(t).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return fmtShort(d);
}

Future<DateTime?> pickDay(BuildContext context, {DateTime? initial, String? help}) => showDatePicker(
      context: context,
      initialDate: initial ?? today(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: help,
    );

/// "Add to menu": choose a day, then the recipe goes on that day's menu.
Future<void> addToMenuFlow(BuildContext context, Recipe r) async {
  final planner = context.read<PlannerStore>();
  final messenger = ScaffoldMessenger.of(context);
  final d = await pickDay(context, help: 'Add “${r.title}” to the menu for…');
  if (d == null) return;
  await planner.addToMenu(d, [r.id]);
  messenger.showSnackBar(SnackBar(
    content: Text('Added to the menu for ${fmtRelative(d)}'),
    action: SnackBarAction(
      label: 'Open menu',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MenuPlannerScreen(initialDay: d))),
    ),
  ));
}

/// "I made this": records the day it was cooked (today by default).
Future<void> madeItFlow(BuildContext context, Recipe r) async {
  final planner = context.read<PlannerStore>();
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.today),
          title: const Text('I made it today'),
          onTap: () => Navigator.pop(c, 'today'),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_month),
          title: const Text('Pick another day…'),
          onTap: () => Navigator.pop(c, 'pick'),
        ),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  final d = choice == 'today' ? today() : await pickDay(context, help: 'When did you make it?');
  if (d == null) return;
  await planner.markMade(d, r.id);
  messenger.showSnackBar(SnackBar(content: Text('Saved: you made “${r.title}” ${fmtRelative(d).toLowerCase()}.')));
}

/// Adds one or more recipes' ingredients to a grocery list (new or existing).
Future<void> addToGroceryFlow(BuildContext context, List<Recipe> recipes, {double factor = 1, String? newTitle}) async {
  final planner = context.read<PlannerStore>();
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final existing = planner.lists.take(4).toList();
  final pick = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              recipes.length == 1 ? 'Add ingredients for “${recipes.first.title}” to…' : 'Add ingredients for ${recipes.length} recipes to…',
              style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.add)),
            title: const Text('A new grocery list'),
            onTap: () => Navigator.pop(c, '*new'),
          ),
          for (final l in existing)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.shopping_cart)),
              title: Text(l.title),
              subtitle: Text('${l.remaining} items still to buy'),
              onTap: () => Navigator.pop(c, l.id),
            ),
        ]),
      ),
    ),
  );
  if (pick == null) return;
  final list = pick == '*new'
      ? await planner.newList(newTitle ?? (recipes.length == 1 ? recipes.first.title : 'Grocery list · ${fmtShort(today())}'))
      : planner.listById(pick)!;
  var added = 0;
  for (final r in recipes) {
    added += await planner.addRecipe(list, r, factor: factor);
  }
  await planner.makeCurrent(list);
  messenger.showSnackBar(SnackBar(
    content: Text('Added $added items to “${list.title}”'),
    action: SnackBarAction(
      label: 'Open list',
      onPressed: () => nav.push(MaterialPageRoute(builder: (_) => GroceryListScreen(listId: list.id))),
    ),
  ));
}

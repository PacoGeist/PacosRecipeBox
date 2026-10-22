import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/grocery.dart';
import '../services/planner_store.dart';
import '../theme/app_theme.dart';
import '../widgets/planner_actions.dart';

/// One grocery list, grouped by store department. Checked items drop to an
/// "In the cart" section at the bottom so what's left to buy stays on top.
class GroceryListScreen extends StatefulWidget {
  final String? listId; // null = the most recent list
  const GroceryListScreen({super.key, this.listId});
  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final _add = TextEditingController();
  String? _id;

  @override
  void initState() {
    super.initState();
    _id = widget.listId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<PlannerStore>();
      final l = _id == null ? p.latestList : p.listById(_id!);
      if (l != null) {
        _id = l.id;
        p.makeCurrent(l);
      }
    });
  }

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  Future<void> _newList() async {
    final p = context.read<PlannerStore>();
    final title = await _askText(context, 'New grocery list', 'Grocery list · ${fmtShort(today())}');
    if (title == null) return;
    final l = await p.newList(title);
    setState(() => _id = l.id);
  }

  Future<void> _pickDept(GroceryList l, GroceryItem i) async {
    final p = context.read<PlannerStore>();
    final d = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Move “${i.text}” to…', style: Theme.of(c).textTheme.titleMedium),
            ),
            for (final d in Dept.all)
              ListTile(
                leading: Text(d.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(d.label),
                trailing: d.key == i.dept ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(c, d.key),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove from list'),
              onTap: () => Navigator.pop(c, '*delete'),
            ),
          ]),
        ),
      ),
    );
    if (d == null) return;
    if (d == '*delete') {
      await p.removeItem(l, i);
    } else {
      await p.setDept(l, i, d);
    }
  }

  Widget _item(PlannerStore p, GroceryList l, GroceryItem i, {Color? color}) {
    final t = Theme.of(context);
    return Dismissible(
      key: ValueKey(i.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => p.removeItem(l, i),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: i.checked,
        activeColor: color ?? AppTheme.basil,
        onChanged: (_) {
          HapticFeedback.selectionClick();
          p.toggle(l, i);
        },
        title: Text(
          i.text,
          style: i.checked
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: t.colorScheme.onSurface.withValues(alpha: 0.5),
                )
              : const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: i.source.isEmpty
            ? null
            : Text('for ${i.source}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
        secondary: IconButton(
          tooltip: 'Change department',
          icon: const Icon(Icons.more_vert),
          onPressed: () => _pickDept(l, i),
        ),
        dense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerStore>();
    final t = Theme.of(context);
    final l = _id == null ? p.latestList : p.listById(_id!);

    if (l == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grocery List')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🛒', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text('No grocery list yet', style: t.textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Open any recipe and tap “Grocery list”, or plan a day’s menu and make one list for everything. '
                'You can also start an empty list and type items in.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _newList, icon: const Icon(Icons.add), label: const Text('Start a list')),
            ]),
          ),
        ),
      );
    }

    final unchecked = l.items.where((i) => !i.checked).toList();
    final checked = l.items.where((i) => i.checked).toList()..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
    final total = l.items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Share list',
            icon: const Icon(Icons.share),
            onPressed: () => SharePlus.instance.share(ShareParams(text: l.asText(), subject: l.title)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'lists':
                  final id = await Navigator.push<String>(
                      context, MaterialPageRoute(builder: (_) => const GroceryListsScreen(pick: true)));
                  if (id != null) {
                    setState(() => _id = id);
                    final nl = p.listById(id);
                    if (nl != null) p.makeCurrent(nl);
                  }
                case 'new':
                  await _newList();
                case 'rename':
                  if (!context.mounted) return;
                  final s = await _askText(context, 'Rename list', l.title);
                  if (s != null) p.renameList(l, s);
                case 'uncheck':
                  p.uncheckAll(l);
                case 'clear':
                  p.clearChecked(l);
                case 'delete':
                  if (!context.mounted) return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete this list?'),
                      content: Text('“${l.title}” will be deleted.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await p.deleteList(l);
                    setState(() => _id = null);
                  }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'lists', child: ListTile(leading: Icon(Icons.list_alt), title: Text('All my lists'))),
              PopupMenuItem(value: 'new', child: ListTile(leading: Icon(Icons.add), title: Text('New list'))),
              PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit), title: Text('Rename'))),
              PopupMenuItem(
                  value: 'uncheck', child: ListTile(leading: Icon(Icons.restart_alt), title: Text('Uncheck everything'))),
              PopupMenuItem(
                  value: 'clear', child: ListTile(leading: Icon(Icons.cleaning_services), title: Text('Remove checked items'))),
              PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Delete list'))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                unchecked.isEmpty ? 'All done — everything is in the cart! 🎉' : '${unchecked.length} of $total left to buy',
                style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: checked.length / total, minHeight: 8, color: AppTheme.basil),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _add,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Add an item (e.g. paper towels, 2 lemons)',
              prefixIcon: const Icon(Icons.add_shopping_cart),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  p.addItem(l, _add.text);
                  _add.clear();
                },
              ),
            ),
            onSubmitted: (v) {
              p.addItem(l, v);
              _add.clear();
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              if (total == 0)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('This list is empty. Type items above, or add a recipe’s ingredients from its page.',
                      textAlign: TextAlign.center),
                ),
              for (final d in Dept.all)
                if (unchecked.any((i) => i.dept == d.key)) ...[
                  _DeptHeader(d, unchecked.where((i) => i.dept == d.key).length),
                  for (final i in unchecked.where((i) => i.dept == d.key)) _item(p, l, i, color: d.color),
                ],
              if (checked.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  color: t.colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(children: [
                    const Icon(Icons.shopping_cart_checkout, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('In the cart (${checked.length})',
                          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    TextButton(onPressed: () => p.clearChecked(l), child: const Text('Clear')),
                  ]),
                ),
                for (final i in checked) _item(p, l, i),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _DeptHeader extends StatelessWidget {
  final Dept d;
  final int n;
  const _DeptHeader(this.d, this.n);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: BoxDecoration(
          color: d.color.withValues(alpha: 0.14),
          border: Border(left: BorderSide(color: d.color, width: 5)),
        ),
        child: Row(children: [
          Text(d.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text('$n', style: TextStyle(fontWeight: FontWeight.w800, color: d.color)),
        ]),
      );
}

/// Every grocery list, most recently used first.
class GroceryListsScreen extends StatelessWidget {
  final bool pick; // true = return the chosen id instead of opening it
  const GroceryListsScreen({super.key, this.pick = false});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Grocery Lists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final title = await _askText(context, 'New grocery list', 'Grocery list · ${fmtShort(today())}');
          if (title == null) return;
          final l = await p.newList(title);
          if (!context.mounted) return;
          if (pick) {
            Navigator.pop(context, l.id);
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => GroceryListScreen(listId: l.id)));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
      body: p.lists.isEmpty
          ? const Center(child: Text('No grocery lists yet.'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                for (final l in p.lists)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: l.remaining == 0 ? AppTheme.basil : AppTheme.saffron,
                      child: Icon(l.remaining == 0 && l.items.isNotEmpty ? Icons.check : Icons.shopping_cart,
                          color: Colors.white),
                    ),
                    title: Text(l.title),
                    subtitle: Text(
                        '${l.remaining} of ${l.items.length} left · made ${fmtShort(DateTime.fromMillisecondsSinceEpoch(l.created))}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (pick) {
                        Navigator.pop(context, l.id);
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => GroceryListScreen(listId: l.id)));
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

Future<String?> _askText(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(d, v.trim())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

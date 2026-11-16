import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe.dart';
import '../models/taxonomy.dart';
import '../services/photo_service.dart';
import '../services/recipe_store.dart';
import '../widgets/recipe_image.dart';
import 'recipe_detail_screen.dart';

/// Create or edit a recipe, including the finished-dish photo and step photos.
class RecipeEditScreen extends StatefulWidget {
  final Recipe? recipe;
  final String newCollection;
  const RecipeEditScreen({super.key, this.recipe, this.newCollection = Collections.family});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _StepDraft {
  final TextEditingController text;
  String? photo;
  _StepDraft(String t, this.photo) : text = TextEditingController(text: t);
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _form = GlobalKey<FormState>();
  late Recipe r;
  late final TextEditingController title, author, source, sourceUrl, description, servings, prep, cook, ingredients,
      keywords, notes;
  late List<_StepDraft> steps;
  bool get isNew => widget.recipe == null;

  @override
  void initState() {
    super.initState();
    r = widget.recipe?.copy() ??
        Recipe(id: 'u-${const Uuid().v4()}', title: '', collection: widget.newCollection, servings: 4);
    title = TextEditingController(text: r.title);
    author = TextEditingController(text: r.author);
    source = TextEditingController(text: r.source);
    sourceUrl = TextEditingController(text: r.sourceUrl);
    description = TextEditingController(text: r.description);
    servings = TextEditingController(text: r.servings > 0 ? '${r.servings}' : '');
    prep = TextEditingController(text: r.prepMinutes > 0 ? '${r.prepMinutes}' : '');
    cook = TextEditingController(text: r.cookMinutes > 0 ? '${r.cookMinutes}' : '');
    ingredients = TextEditingController(text: r.ingredients.join('\n'));
    keywords = TextEditingController(text: r.keywords.join(', '));
    notes = TextEditingController(text: r.notes);
    steps = r.steps.map((s) => _StepDraft(s.text, s.photo)).toList();
    if (steps.isEmpty) steps.add(_StepDraft('', null));
  }

  Future<String?> _pickPhoto() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(c, true)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(c, false)),
        ]),
      ),
    );
    if (camera == null) return null;
    try {
      return await PhotoService.pick(camera: camera);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get photo: $e')));
      return null;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    r
      ..title = title.text.trim()
      ..author = author.text.trim()
      ..source = source.text.trim()
      ..sourceUrl = sourceUrl.text.trim()
      ..description = description.text.trim()
      ..servings = int.tryParse(servings.text.trim()) ?? 0
      ..prepMinutes = int.tryParse(prep.text.trim()) ?? 0
      ..cookMinutes = int.tryParse(cook.text.trim()) ?? 0
      ..ingredients = ingredients.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
      ..keywords = keywords.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
      ..notes = notes.text.trim()
      ..steps = steps
          .where((s) => s.text.text.trim().isNotEmpty || s.photo != null)
          .map((s) => RecipeStep(s.text.text.trim(), photo: s.photo))
          .toList();
    final store = context.read<RecipeStore>();
    await store.save(r);
    if (!mounted) return;
    if (isNew) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)));
    } else {
      Navigator.pop(context);
    }
  }

  Widget _chips(String label, List<Category> cats, List<String> selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in cats)
              FilterChip(
                label: Text('${c.emoji ?? ''} ${c.label}'),
                selected: selected.contains(c.key),
                selectedColor: c.color.withValues(alpha: 0.28),
                onSelected: (v) => setState(() => v ? selected.add(c.key) : selected.remove(c.key)),
              ),
          ]),
        ],
      );

  InputDecoration _dec(String label, {String? hint, IconData? icon}) =>
      InputDecoration(labelText: label, hintText: hint, prefixIcon: icon == null ? null : Icon(icon));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Recipe' : 'Edit Recipe'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Save')),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
          children: [
            // Finished dish photo — shown first on the recipe page.
            GestureDetector(
              onTap: () async {
                final ph = await _pickPhoto();
                if (ph != null) setState(() => r.photo = ph);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(fit: StackFit.expand, children: [
                    r.photo == null
                        ? Container(
                            color: t.colorScheme.primary.withValues(alpha: 0.1),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.add_a_photo, size: 48, color: t.colorScheme.primary),
                              const SizedBox(height: 8),
                              const Text('Add a photo of the finished dish',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                          )
                        : PhotoView(r.photo),
                    if (r.photo != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Row(children: [
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final ph = await _pickPhoto();
                              if (ph != null) setState(() => r.photo = ph);
                            },
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Change'),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            onPressed: () => setState(() => r.photo = null),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ),
            ),
            gap,
            TextFormField(
              controller: title,
              decoration: _dec('Recipe name *', icon: Icons.restaurant),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Please give the recipe a name' : null,
            ),
            gap,
            Row(children: [
              Expanded(
                child: TextFormField(
                    controller: author,
                    decoration: _dec('Author / cook', hint: 'e.g. Grandma Rose', icon: Icons.person),
                    textCapitalization: TextCapitalization.words),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                    controller: source,
                    decoration: _dec('Source', hint: 'e.g. Church cookbook', icon: Icons.menu_book)),
              ),
            ]),
            gap,
            TextFormField(
                controller: sourceUrl,
                decoration: _dec('Web address (optional)', icon: Icons.link),
                keyboardType: TextInputType.url),
            gap,
            Text('Which box does it go in?', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: [
                for (final c in Collections.all)
                  ButtonSegment(value: c.key, label: Text(c.label.split(' ').first.replaceAll("'", '')), icon: Icon(c.icon)),
              ],
              selected: {r.collection},
              onSelectionChanged: (s) => setState(() => r.collection = s.first),
            ),
            gap,
            TextFormField(
                controller: description,
                decoration: _dec('Short description', icon: Icons.notes),
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences),
            gap,
            Row(children: [
              Expanded(
                child: TextFormField(
                    controller: servings, decoration: _dec('Servings'), keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                    controller: prep, decoration: _dec('Prep (min)'), keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                    controller: cook, decoration: _dec('Cook (min)'), keyboardType: TextInputType.number),
              ),
            ]),
            const SizedBox(height: 18),
            Text('Ingredients', style: t.textTheme.headlineSmall),
            Text('One per line, amount first (e.g. "1 1/2 cups flour") so the ½× 2× 3× buttons can scale it. '
                'Start a line with # to make a heading, like "# For the frosting".',
                style: t.textTheme.bodySmall),
            const SizedBox(height: 6),
            TextFormField(
              controller: ingredients,
              maxLines: null,
              minLines: 6,
              decoration: const InputDecoration(hintText: '2 cups flour\n1 tsp salt\n3 eggs'),
            ),
            const SizedBox(height: 18),
            Text('Directions', style: t.textTheme.headlineSmall),
            Text('Add a photo to any step to show how it should look.', style: t.textTheme.bodySmall),
            const SizedBox(height: 6),
            for (var i = 0; i < steps.length; i++) _stepEditor(i),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => steps.add(_StepDraft('', null))),
                icon: const Icon(Icons.add),
                label: const Text('Add step'),
              ),
            ),
            _chips('Cuisine', Cuisines.all, r.cuisines),
            _chips('Meal type', MealTypes.all, r.mealTypes),
            _chips('Season', Seasons.all, r.seasons),
            _chips('Holiday', Holidays.all, r.holidays),
            const SizedBox(height: 14),
            TextFormField(
                controller: keywords,
                decoration: _dec('Keywords', hint: 'comma separated: spicy, quick, kid friendly', icon: Icons.tag)),
            gap,
            TextFormField(
                controller: notes,
                decoration: _dec('Notes & tips', icon: Icons.sticky_note_2),
                maxLines: null,
                minLines: 2),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Padding(padding: EdgeInsets.all(12), child: Text('Save Recipe', style: TextStyle(fontSize: 17))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepEditor(int i) {
    final s = steps[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 14, child: Text('${i + 1}')),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: s.text,
                maxLines: null,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: 'Step ${i + 1}', isDense: true),
              ),
            ),
            Column(children: [
              IconButton(
                tooltip: 'Add step photo',
                icon: const Icon(Icons.add_a_photo_outlined),
                onPressed: () async {
                  final ph = await _pickPhoto();
                  if (ph != null) setState(() => s.photo = ph);
                },
              ),
              IconButton(
                tooltip: 'Move up',
                icon: const Icon(Icons.arrow_upward),
                onPressed: i == 0 ? null : () => setState(() => steps.insert(i - 1, steps.removeAt(i))),
              ),
              IconButton(
                tooltip: 'Remove step',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => steps.removeAt(i)),
              ),
            ]),
          ]),
          if (s.photo != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 36),
              child: Stack(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(height: 140, width: double.infinity, child: PhotoView(s.photo))),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                      onPressed: () => setState(() => s.photo = null), icon: const Icon(Icons.close)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

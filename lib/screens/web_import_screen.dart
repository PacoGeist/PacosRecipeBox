import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/recipe_store.dart';
import '../services/settings.dart';
import '../services/web_import.dart';
import '../widgets/recipe_image.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_screen.dart';

/// Pull a recipe in from a website by pasting its link.
class WebImportScreen extends StatefulWidget {
  final String? initialUrl;
  const WebImportScreen({super.key, this.initialUrl});
  @override
  State<WebImportScreen> createState() => _WebImportScreenState();
}

class _WebImportScreenState extends State<WebImportScreen> {
  late final TextEditingController url = TextEditingController(text: widget.initialUrl ?? '');
  final search = TextEditingController();
  bool busy = false;
  String? error;
  WebImportResult? result;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl == null) _pasteIfLink();
  }

  Future<void> _pasteIfLink() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (t.startsWith('http') && mounted && url.text.isEmpty) setState(() => url.text = t);
  }

  Future<void> _fetch() async {
    if (url.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final proxy = context.read<AppSettings>().webImportProxy;
      final r = await WebImporter.fetch(url.text, proxy: proxy);
      await WebImporter.downloadImage(r, proxy: proxy);
      setState(() => result = r);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = result?.recipe;
    return Scaffold(
      appBar: AppBar(title: const Text('Import from the Web')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('1. Find a recipe', style: t.textTheme.titleLarge),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: search,
                decoration: const InputDecoration(hintText: 'e.g. chicken enchiladas', isDense: true),
                onSubmitted: (_) => _openSearch(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(onPressed: _openSearch, icon: const Icon(Icons.travel_explore), label: const Text('Search')),
          ]),
          const SizedBox(height: 4),
          Text('Opens your web browser. When you find a recipe you like, use Share ▸ Copy link, then come back here.',
              style: t.textTheme.bodySmall),
          const SizedBox(height: 20),
          Text('2. Paste the recipe link', style: t.textTheme.titleLarge),
          const SizedBox(height: 6),
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://…',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                tooltip: 'Paste',
                icon: const Icon(Icons.content_paste),
                onPressed: () async {
                  final d = await Clipboard.getData(Clipboard.kTextPlain);
                  if (d?.text != null) setState(() => url.text = d!.text!.trim());
                },
              ),
            ),
            onSubmitted: (_) => _fetch(),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy ? null : _fetch,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            label: const Padding(padding: EdgeInsets.all(10), child: Text('Get Recipe')),
          ),
          if (error != null)
            Card(
              color: t.colorScheme.errorContainer,
              margin: const EdgeInsets.only(top: 16),
              child: Padding(padding: const EdgeInsets.all(14), child: Text(error!)),
            ),
          if (r != null) ...[
            const SizedBox(height: 20),
            if (!result!.looksEnglish)
              Card(
                color: Colors.amber.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Heads up: this page does not appear to be in English.',
                      style: TextStyle(color: Colors.black87)),
                ),
              ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (r.photo != null)
                  SizedBox(height: 200, child: PhotoView(r.photo)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.title, style: t.textTheme.headlineSmall),
                    Text('by ${r.author} · ${r.source}', style: t.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text('${r.ingredients.length} ingredients · ${r.steps.length} steps'
                        '${r.servings > 0 ? ' · serves ${r.servings}' : ''}'),
                    if (r.cuisines.isNotEmpty || r.mealTypes.isNotEmpty)
                      Text('Filed under: ${[...r.cuisines, ...r.mealTypes].join(', ')}', style: t.textTheme.bodySmall),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: r))),
                  icon: const Icon(Icons.edit),
                  label: const Text('Review & edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await context.read<RecipeStore>().save(r);
                    if (context.mounted) {
                      Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)));
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('The original author and website are saved with the recipe as its credit.',
                style: t.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  void _openSearch() {
    final q = search.text.trim();
    final uri = Uri.https('www.google.com', '/search', {'q': '${q.isEmpty ? '' : '$q '}recipe'});
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}


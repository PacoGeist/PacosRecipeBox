import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/recipe.dart';
import '../models/taxonomy.dart';
import 'auto_tagger.dart';
import 'photo_service.dart';

class WebImportResult {
  final Recipe recipe;
  final String? imageUrl;
  final String? language;
  WebImportResult(this.recipe, this.imageUrl, this.language);
  bool get looksEnglish => language == null || language!.toLowerCase().startsWith('en');
}

/// Reads recipes from web pages using the schema.org "Recipe" data that
/// almost every recipe website (AllRecipes, Food Network, BBC Good Food, NYT,
/// blogs using WP Recipe Maker / Tasty Recipes, …) embeds for search engines.
class WebImporter {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36';

  /// Browsers block web apps from reading other websites directly (CORS), so the
  /// web app (PWA) goes through a small "import helper" proxy set in Settings.
  static Uri _target(String u, String proxy) {
    if (!kIsWeb) return Uri.parse(u);
    if (proxy.trim().isEmpty) {
      throw Exception('In the web version, importing from websites needs the "Web import helper" address '
          '(Settings ▸ Web import helper). See the README for the free 5-minute setup. '
          'You can still type recipes in yourself.');
    }
    return Uri.parse('${proxy.trim()}${proxy.contains('?') ? '&' : '?'}url=${Uri.encodeComponent(u)}');
  }

  static Future<WebImportResult> fetch(String url, {String proxy = ''}) async {
    var u = url.trim();
    if (!u.startsWith('http')) u = 'https://$u';
    final res = await http.get(_target(u, proxy),
        headers: kIsWeb ? {} : {'User-Agent': _ua, 'Accept-Language': 'en-US,en;q=0.9'});
    if (res.statusCode >= 400) throw Exception('The site answered with error ${res.statusCode}.');
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    final result = parseHtml(body, u);
    if (result == null) {
      throw Exception('No recipe found on that page. Try the page for a single recipe '
          '(not a list or search page), or type it in yourself.');
    }
    return result;
  }

  /// Downloads the recipe image to the device and attaches it.
  static Future<void> downloadImage(WebImportResult r, {String proxy = ''}) async {
    if (r.imageUrl == null) return;
    try {
      final res = await http.get(_target(r.imageUrl!, proxy), headers: kIsWeb ? {} : {'User-Agent': _ua});
      if (res.statusCode == 200 && res.bodyBytes.length > 1000) {
        final ct = res.headers['content-type'] ?? '';
        final ext = ct.contains('png') ? '.png' : (ct.contains('webp') ? '.webp' : '.jpg');
        r.recipe.photo = await PhotoService.saveBytes(res.bodyBytes, ext: ext);
      }
    } catch (_) {/* photo is optional */}
  }

  // ---------- parsing (pure, unit-testable) ----------

  static WebImportResult? parseHtml(String body, String url) {
    final doc = html_parser.parse(body);
    final lang = doc.documentElement?.attributes['lang'];
    for (final s in doc.querySelectorAll('script[type="application/ld+json"]')) {
      dynamic data;
      try {
        data = jsonDecode(s.text.trim());
      } catch (_) {
        continue;
      }
      final node = _findRecipe(data);
      if (node != null) {
        final siteName = doc.querySelector('meta[property="og:site_name"]')?.attributes['content'];
        return _fromSchema(node, url, siteName, (node['inLanguage'] as String?) ?? lang);
      }
    }
    return null;
  }

  static Map<String, dynamic>? _findRecipe(dynamic d) {
    if (d is List) {
      for (final x in d) {
        final r = _findRecipe(x);
        if (r != null) return r;
      }
    } else if (d is Map<String, dynamic>) {
      final type = d['@type'];
      final isRecipe = type == 'Recipe' || (type is List && type.contains('Recipe'));
      if (isRecipe) return d;
      for (final k in ['@graph', 'mainEntity', 'itemListElement']) {
        if (d[k] != null) {
          final r = _findRecipe(d[k]);
          if (r != null) return r;
        }
      }
    }
    return null;
  }

  static String clean(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final text = html_parser.parseFragment(s).text ?? s;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> _list(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.expand(_list).toList();
    if (v is String) return v.contains(',') ? v.split(',').map(clean).where((e) => e.isNotEmpty).toList() : [clean(v)];
    if (v is Map && v['name'] != null) return [clean(v['name'])];
    return [clean(v)];
  }

  static List<String> _lines(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.expand(_lines).toList();
    return v.toString().split('\n').map(clean).where((e) => e.isNotEmpty).toList();
  }

  static String _author(dynamic a) {
    if (a == null) return '';
    if (a is String) return clean(a);
    if (a is List) return a.map(_author).where((e) => e.isNotEmpty).join(', ');
    if (a is Map) return clean(a['name']);
    return '';
  }

  static String? _image(dynamic i) {
    if (i == null) return null;
    if (i is String) return i;
    if (i is List) return i.isEmpty ? null : _image(i.last is String ? i.last : i.first);
    if (i is Map) return (i['url'] ?? i['contentUrl'])?.toString();
    return null;
  }

  /// ISO-8601 duration (PT1H30M, P0DT0H45M) -> minutes.
  static int isoMinutes(dynamic v) {
    if (v == null) return 0;
    final m = RegExp(r'P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?', caseSensitive: false)
        .firstMatch(v.toString());
    if (m == null) return 0;
    int g(int i) => int.tryParse(m[i] ?? '') ?? 0;
    return g(1) * 1440 + g(2) * 60 + g(3);
  }

  static List<RecipeStep> _steps(dynamic v) {
    if (v == null) return [];
    if (v is String) {
      final parts = v.split(RegExp(r'\n+|(?<=\.)\s{2,}')).map(clean).where((e) => e.isNotEmpty);
      return parts.map((e) => RecipeStep(e)).toList();
    }
    if (v is List) return v.expand(_steps).toList();
    if (v is Map) {
      final t = v['@type'];
      if (t == 'HowToSection' || v['itemListElement'] != null) {
        final steps = _steps(v['itemListElement']);
        final name = clean(v['name']);
        if (name.isNotEmpty && steps.isNotEmpty) steps.first.text = '$name: ${steps.first.text}';
        return steps;
      }
      final text = clean(v['text'] ?? v['name']);
      return text.isEmpty ? [] : [RecipeStep(text)];
    }
    return [];
  }

  static int _servings(dynamic y) {
    if (y == null) return 0;
    if (y is num) return y.toInt();
    if (y is List) {
      for (final e in y) {
        final n = _servings(e);
        if (n > 0) return n;
      }
      return 0;
    }
    final m = RegExp(r'\d+').firstMatch(y.toString());
    return m == null ? 0 : int.parse(m[0]!);
  }

  static WebImportResult _fromSchema(Map<String, dynamic> n, String url, String? siteName, String? lang) {
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
    var prep = isoMinutes(n['prepTime']);
    var cook = isoMinutes(n['cookTime']);
    final total = isoMinutes(n['totalTime']);
    if (prep == 0 && cook == 0 && total > 0) cook = total;
    if (total > prep + cook && prep > 0 && cook == 0) cook = total - prep;

    final cuisinesRaw = _list(n['recipeCuisine']);
    final categoriesRaw = _list(n['recipeCategory']);
    final keywords = _list(n['keywords']).take(12).toList();
    final r = Recipe(
      id: 'w-${const Uuid().v4()}',
      title: clean(n['name']).isEmpty ? 'Imported recipe' : clean(n['name']),
      description: clean(n['description']),
      author: _author(n['author']).isEmpty ? (siteName ?? host) : _author(n['author']),
      source: siteName ?? host,
      sourceUrl: url,
      license: 'Imported for personal use from $host. All rights remain with the original author.',
      collection: Collections.internet,
      servings: _servings(n['recipeYield']),
      yieldText: _list(n['recipeYield']).join(', '),
      prepMinutes: prep,
      cookMinutes: cook,
      ingredients: _lines(n['recipeIngredient'] ?? n['ingredients']),
      steps: _steps(n['recipeInstructions']),
      keywords: keywords,
    );
    AutoTagger.tag(r, extraCuisines: cuisinesRaw, extraCategories: categoriesRaw);
    return WebImportResult(r, _image(n['image']), lang);
  }
}

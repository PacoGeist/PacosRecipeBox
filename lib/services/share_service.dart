import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../models/taxonomy.dart';
import 'photo_service.dart';
import 'recipe_store.dart';
import 'scaler.dart';

/// Sharing: PDF (email/text/print), plain text, Facebook-friendly photo+text,
/// and ".recipe" files that another Recipe Box user can open.
class ShareService {
  static const fileExtension = 'recipe';

  static Future<Uint8List?> photoBytes(String? ref) async {
    if (ref == null) return null;
    try {
      if (PhotoService.isAsset(ref)) {
        final d = await rootBundle.load(PhotoService.assetPath(ref));
        return d.buffer.asUint8List();
      }
      return await PhotoService.readBytes(ref);
    } catch (_) {}
    return null;
  }


  static String _safeName(String s) {
    final n = s.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    return n.isEmpty ? 'recipe' : (n.length > 50 ? n.substring(0, 50) : n);
  }

  // ---------------- share menu ----------------

  static Future<void> showShareMenu(BuildContext context, Recipe r, double factor) {
    final origin = _origin(context);
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (factor != 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Ingredient amounts will be shared at ${IngredientScaler.format(factor)}× the recipe.',
                    style: Theme.of(ctx).textTheme.bodySmall),
              ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFD32F2F), child: Icon(Icons.picture_as_pdf, color: Colors.white)),
              title: const Text('Email or text as a PDF'),
              subtitle: const Text('A printable recipe card attached to a message'),
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await buildPdf(r, factor);
                await SharePlus.instance.share(ShareParams(
                  files: [XFile.fromData(bytes, name: '${_safeName(r.title)}.pdf', mimeType: 'application/pdf')],
                  fileNameOverrides: ['${_safeName(r.title)}.pdf'],
                  subject: 'Recipe: ${r.title}',
                  text: 'Here is my recipe for ${r.title}.',
                  sharePositionOrigin: origin,
                ));
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF455A64), child: Icon(Icons.print, color: Colors.white)),
              title: const Text('Print'),
              onTap: () async {
                Navigator.pop(ctx);
                await Printing.layoutPdf(name: r.title, onLayout: (_) => buildPdf(r, factor));
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF43A047), child: Icon(Icons.sms, color: Colors.white)),
              title: const Text('Share as text'),
              subtitle: const Text('Paste into a text message, email or note'),
              onTap: () async {
                Navigator.pop(ctx);
                await SharePlus.instance
                    .share(ShareParams(text: asText(r, factor), subject: r.title, sharePositionOrigin: origin));
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF1877F2), child: Icon(Icons.facebook, color: Colors.white)),
              title: const Text('Share photo & recipe (Facebook, etc.)'),
              subtitle: const Text('Recipe text is copied so you can paste it into your post'),
              onTap: () async {
                Navigator.pop(ctx);
                final text = asText(r, factor);
                await Clipboard.setData(ClipboardData(text: text));
                final img = await photoBytes(r.photo);
                final files = <XFile>[];
                if (img != null) {
                  files.add(XFile.fromData(img, name: '${_safeName(r.title)}.jpg', mimeType: 'image/jpeg'));
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Recipe copied — long-press in your post and choose Paste.')));
                }
                await SharePlus.instance.share(ShareParams(
                    files: files.isEmpty ? null : files, text: text, subject: r.title, sharePositionOrigin: origin));
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFEF6C00), child: Icon(Icons.send_to_mobile, color: Colors.white)),
              title: const Text('Send to another Recipe Box user'),
              subtitle: const Text('Includes photos — they can add it to their own app'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareRecipeFiles([r], origin: origin);
              },
            ),
          ]),
        ),
      ),
    );
  }

  static Rect? _origin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  // ---------------- plain text ----------------

  static String asText(Recipe r, double factor) {
    final b = StringBuffer()..writeln(r.title.toUpperCase());
    if (r.author.isNotEmpty) b.writeln('By ${r.author}');
    if (r.description.isNotEmpty) b.writeln('\n${r.description}');
    final info = [
      if (r.servings > 0) 'Serves ${IngredientScaler.format(r.servings * factor)}',
      if (r.prepMinutes > 0) 'Prep ${formatMinutes(r.prepMinutes)}',
      if (r.cookMinutes > 0) 'Cook ${formatMinutes(r.cookMinutes)}',
    ];
    if (info.isNotEmpty) b.writeln('\n${info.join(' • ')}');
    b.writeln('\nINGREDIENTS${factor != 1 ? ' (${IngredientScaler.format(factor)}× recipe)' : ''}');
    for (final i in r.ingredients) {
      b.writeln(i.startsWith('#') ? '\n${i.replaceFirst(RegExp(r'^#+\s*'), '')}:' : '• ${IngredientScaler.scaleLine(i, factor)}');
    }
    b.writeln('\nDIRECTIONS');
    for (var i = 0; i < r.steps.length; i++) {
      b.writeln('${i + 1}. ${r.steps[i].text}');
    }
    if (r.notes.isNotEmpty) b.writeln('\nNOTES\n${r.notes}');
    b.writeln('\nSource: ${[r.source, r.sourceUrl].where((e) => e.isNotEmpty).join(' – ')}');
    b.writeln('Shared from $appTitle');
    return b.toString();
  }

  // ---------------- PDF ----------------

  static Future<Uint8List> buildPdf(Recipe r, double factor) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Nunito-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Nunito-Bold.ttf'));
    final title = pw.Font.ttf(await rootBundle.load('assets/fonts/PlayfairDisplay-Bold.ttf'));
    final img = await photoBytes(r.photo);
    final stepImgs = <int, Uint8List>{};
    for (var i = 0; i < r.steps.length; i++) {
      final b = await photoBytes(r.steps[i].photo);
      if (b != null) stepImgs[i] = b;
    }
    const tomato = PdfColor.fromInt(0xFFD84315);
    const basil = PdfColor.fromInt(0xFF558B2F);
    const ink = PdfColor.fromInt(0xFF3E2723);

    final doc = pw.Document(title: r.title, author: r.author, creator: appTitle);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Shared from $appTitle', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text('${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ]),
      build: (c) => [
        if (img != null)
          pw.ClipRRect(
            horizontalRadius: 10,
            verticalRadius: 10,
            child: pw.Image(pw.MemoryImage(img), height: 260, width: double.infinity, fit: pw.BoxFit.cover),
          ),
        pw.SizedBox(height: 12),
        pw.Text(r.title, style: pw.TextStyle(font: title, fontSize: 28, color: ink)),
        if (r.author.isNotEmpty)
          pw.Text('by ${r.author}', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
        if (r.description.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text(_p(r.description))),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFFF3E0),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _pdfInfo('Prep', formatMinutes(r.prepMinutes), bold),
            _pdfInfo('Cook', formatMinutes(r.cookMinutes), bold),
            _pdfInfo('Total', formatMinutes(r.totalMinutes), bold),
            _pdfInfo('Servings', r.servings > 0 ? IngredientScaler.format(r.servings * factor) : '—', bold),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.Text('Ingredients${factor != 1 ? '  (${IngredientScaler.format(factor)}× recipe)' : ''}',
            style: pw.TextStyle(font: title, fontSize: 18, color: tomato)),
        pw.Divider(color: tomato, thickness: 1),
        ...r.ingredients.map((i) => i.startsWith('#')
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
                child: pw.Text(i.replaceFirst(RegExp(r'^#+\s*'), ''), style: pw.TextStyle(font: bold, color: basil)))
            : pw.Bullet(text: _p(IngredientScaler.scaleLine(i, factor)), bulletColor: tomato)),
        pw.SizedBox(height: 14),
        pw.Text('Directions', style: pw.TextStyle(font: title, fontSize: 18, color: tomato)),
        pw.Divider(color: tomato, thickness: 1),
        for (var i = 0; i < r.steps.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(
                width: 20,
                height: 20,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(color: basil, shape: pw.BoxShape.circle),
                child: pw.Text('${i + 1}', style: pw.TextStyle(color: PdfColors.white, font: bold, fontSize: 10)),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(_p(r.steps[i].text), style: const pw.TextStyle(lineSpacing: 2)),
                  if (stepImgs[i] != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Image(pw.MemoryImage(stepImgs[i]!), height: 120, fit: pw.BoxFit.contain),
                    ),
                ]),
              ),
            ]),
          ),
        if (r.notes.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Notes', style: pw.TextStyle(font: title, fontSize: 16, color: tomato)),
          pw.Text(_p(r.notes)),
        ],
        pw.SizedBox(height: 14),
        pw.Text(
          [
            if (r.author.isNotEmpty) 'Recipe by ${r.author}',
            if (r.source.isNotEmpty) 'Source: ${r.source}',
            if (r.sourceUrl.isNotEmpty) r.sourceUrl,
            if (r.license.isNotEmpty) r.license,
            if (r.photoCredit.isNotEmpty) 'Photo: ${r.photoCredit}',
          ].join('\n'),
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ));
    return doc.save();
  }

  static String _p(String s) => IngredientScaler.asciiFractions(s);

  static pw.Widget _pdfInfo(String label, String value, pw.Font bold) => pw.Column(children: [
        pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 12)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ]);

  // ---------------- .recipe files ----------------

  /// Packs recipes (and their photos) into a zip archive.
  static Future<Uint8List> packRecipes(List<Recipe> recipes, {Map<String, dynamic>? extra}) async {
    final archive = Archive();
    final photos = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final r in recipes) {
      final j = r.toJson();
      // Embed asset photos as files so the recipe works anywhere.
      Future<String?> pack(String? ref) async {
        if (ref == null) return null;
        final name = PhotoService.isAsset(ref) ? 'a_${p.basename(PhotoService.assetPath(ref))}' : p.basename(ref);
        if (photos.add(name)) {
          final b = await photoBytes(ref);
          if (b == null) return null;
          archive.add(ArchiveFile.bytes('photos/$name', b));
        }
        return name;
      }

      j['photo'] = await pack(r.photo);
      final steps = <Map<String, dynamic>>[];
      for (final s in r.steps) {
        steps.add({'text': s.text, if (s.photo != null) 'photo': await pack(s.photo)});
      }
      j['steps'] = steps;
      list.add(j);
    }
    final manifest = {'app': appTitle, 'format': 1, 'exported': DateTime.now().toIso8601String(), 'recipes': list, ...?extra};
    archive.add(ArchiveFile.string('recipes.json', jsonEncode(manifest)));
    return ZipEncoder().encodeBytes(archive);
  }

  static Future<void> shareRecipeFiles(List<Recipe> recipes, {Rect? origin}) async {
    final bytes = await packRecipes(recipes);
    final name = recipes.length == 1 ? _safeName(recipes.first.title) : 'recipes_${recipes.length}';
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: '$name.$fileExtension', mimeType: 'application/zip')],
      fileNameOverrides: ['$name.$fileExtension'],
      subject: recipes.length == 1 ? 'Recipe: ${recipes.first.title}' : '${recipes.length} recipes',
      text: 'Open this in $appTitle (Add Recipe ▸ Open a shared recipe file).',
      sharePositionOrigin: origin,
    ));
  }

  /// Reads recipes from a zip archive. Photos are saved to the device with new names.
  static Future<(List<Recipe>, Map<String, dynamic>)> unpackRecipes(Uint8List bytes,
      {required bool asFriend, bool keepIds = false}) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.findFile('recipes.json');
    if (manifestFile == null) throw Exception('This file does not contain recipes.');
    final manifest = jsonDecode(utf8.decode(manifestFile.readBytes()!)) as Map<String, dynamic>;
    final renamed = <String, String>{};
    Future<String?> unpack(String? name) async {
      if (name == null) return null;
      if (renamed.containsKey(name)) return renamed[name];
      final f = archive.findFile('photos/$name');
      if (f == null) return null;
      final newName = keepIds ? p.basename(name) : '${const Uuid().v4()}${p.extension(name)}';
      await PhotoService.saveAs(newName, f.readBytes()!);
      return renamed[name] = newName;
    }

    final out = <Recipe>[];
    for (final j in (manifest['recipes'] as List)) {
      final r = Recipe.fromJson(Map<String, dynamic>.from(j));
      r.photo = await unpack(r.photo);
      for (final s in r.steps) {
        s.photo = await unpack(s.photo);
      }
      r.builtIn = false;
      if (asFriend) {
        r.collection = Collections.friend;
        r.favorite = false;
        if (!keepIds) r.id = 'f-${const Uuid().v4()}';
      }
      out.add(r);
    }
    return (out, manifest);
  }

  static Future<void> importRecipeFileFlow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final store = context.read<RecipeStore>();
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      final (recipes, _) = await unpackRecipes(bytes, asFriend: true);
      await store.saveMany(recipes);
      messenger.showSnackBar(SnackBar(
          content: Text(recipes.length == 1
              ? 'Added “${recipes.first.title}” to Friends\' Recipes'
              : 'Added ${recipes.length} recipes to Friends\' Recipes')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open that file: $e')));
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../models/taxonomy.dart';
import '../services/photo_service.dart';

/// Shows a recipe photo from assets or the device, or a colorful placeholder.
class PhotoView extends StatelessWidget {
  final String? photo;
  final BoxFit fit;
  final Widget? placeholder;
  const PhotoView(this.photo, {super.key, this.fit = BoxFit.cover, this.placeholder});

  @override
  Widget build(BuildContext context) {
    final ph = placeholder ?? const _Placeholder(emoji: '🍽️', color: Color(0xFFD84315));
    if (photo == null) return ph;
    if (PhotoService.isAsset(photo)) {
      return Image.asset(PhotoService.assetPath(photo!), fit: fit, errorBuilder: (_, _, _) => ph);
    }
    if (kIsWeb) {
      final bytes = PhotoService.memoryBytes(photo);
      if (bytes == null) return ph;
      return Image.memory(bytes, fit: fit, errorBuilder: (_, _, _) => ph, cacheWidth: 1200, gaplessPlayback: true);
    }
    final path = PhotoService.filePath(photo);
    if (path == null) return ph;
    return Image.file(File(path), fit: fit, errorBuilder: (_, _, _) => ph, cacheWidth: 1200);
  }
}

class RecipeImage extends StatelessWidget {
  final Recipe recipe;
  final BoxFit fit;
  const RecipeImage(this.recipe, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final mt = MealTypes.all.where((m) => recipe.mealTypes.contains(m.key)).firstOrNull;
    return PhotoView(
      recipe.photo,
      fit: fit,
      placeholder: _Placeholder(emoji: mt?.emoji ?? '🍽️', color: mt?.color ?? const Color(0xFFD84315)),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String emoji;
  final Color color;
  const _Placeholder({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.85), Color.lerp(color, Colors.amber, 0.5)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (c, box) => Text(emoji, style: TextStyle(fontSize: (box.maxHeight.isFinite ? box.maxHeight : 120) * 0.42)),
        ),
      );
}

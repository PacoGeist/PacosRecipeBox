import 'package:flutter/foundation.dart';

/// Collects problems that happen while the app starts, so they can be shown
/// on screen (and copied) instead of leaving a blank screen.
class StartupLog {
  static final List<String> entries = [];
  static final ValueNotifier<int> changes = ValueNotifier(0);

  /// Problems that stop the app from loading (shown in the on-screen banner).
  static List<String> get serious => entries.where((e) => !e.startsWith('[ui]')).toList();

  static void add(String where, Object error, [StackTrace? stack]) {
    final lines = (stack?.toString() ?? '').split('\n').take(6).join('\n');
    entries.add('[$where] $error\n$lines');
    debugPrint('RecipeBox startup problem [$where]: $error\n$stack');
    changes.value++;
  }
}

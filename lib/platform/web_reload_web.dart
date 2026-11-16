import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Clears the cached app shell and reloads so the newest version loads.
Future<void> reloadWebApp() async {
  try {
    final keys = (await web.window.caches.keys().toDart).toDart;
    for (final k in keys) {
      await web.window.caches.delete(k.toDart).toDart;
    }
  } catch (_) {}
  web.window.location.reload();
}

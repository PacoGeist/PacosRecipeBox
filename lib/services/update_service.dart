import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform/web_reload.dart';

/// Where new versions are published. Change these if the repository moves.
class UpdateConfig {
  static const githubOwner = 'PacoGeist';
  static const githubRepo = 'PacosRecipeBox';
  static String get releasesPage => 'https://github.com/$githubOwner/$githubRepo/releases';
  static String get repoPage => 'https://github.com/$githubOwner/$githubRepo';
  static String get latestApi => 'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
}

class ReleaseInfo {
  final String version;
  final String notes;
  final String? apkUrl;
  final String pageUrl;
  ReleaseInfo(this.version, this.notes, this.apkUrl, this.pageUrl);
}

class UpdateService {
  /// Compares dotted versions: returns >0 if a is newer than b.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) =>
        v.replaceFirst(RegExp(r'^[vV]'), '').split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// Web app: the newest version is whatever is published on GitHub Pages.
  static Future<String> _webLatestVersion() async {
    final res = await http.get(Uri.parse('version.json?t=${DateTime.now().millisecondsSinceEpoch}'));
    if (res.statusCode != 200) throw Exception('Could not reach the Recipe Box website.');
    return (jsonDecode(res.body)['version'] ?? '0.0.0').toString();
  }

  static Future<void> _checkWeb(BuildContext context, String current) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final v = await _webLatestVersion();
      if (!context.mounted) return;
      if (compareVersions(v, current) <= 0) {
        messenger.showSnackBar(SnackBar(content: Text('You have the latest version ($current).')));
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Version $v is available'),
          content: Text('You have $current. Updating just reloads the app — your recipes stay on this device.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Later')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Update now')),
          ],
        ),
      );
      if (go == true) await reloadWebApp();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not check for updates: $e')));
    }
  }

  static Future<ReleaseInfo> latest() async {
    final res = await http.get(Uri.parse(UpdateConfig.latestApi), headers: {'Accept': 'application/vnd.github+json'});
    if (res.statusCode == 404) throw Exception('No releases have been published yet.');
    if (res.statusCode != 200) throw Exception('GitHub answered ${res.statusCode}.');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    String? apk;
    for (final a in (j['assets'] as List? ?? [])) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      if (name.endsWith('.apk')) apk = a['browser_download_url'];
    }
    return ReleaseInfo((j['tag_name'] ?? '0.0.0').toString(), (j['body'] ?? '').toString(), apk,
        (j['html_url'] ?? UpdateConfig.releasesPage).toString());
  }

  static Future<void> checkAndUpdate(BuildContext context) async {
    if (kIsWeb) {
      final current = (await PackageInfo.fromPlatform()).version;
      if (context.mounted) await _checkWeb(context, current);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text('Checking for updates…')]),
      ),
    );
    ReleaseInfo? info;
    String? error;
    final current = (await PackageInfo.fromPlatform()).version;
    try {
      info = await latest();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (!context.mounted) return;
    Navigator.pop(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text('Could not check for updates: $error')));
      return;
    }
    if (compareVersions(info!.version, current) <= 0) {
      messenger.showSnackBar(SnackBar(content: Text('You have the latest version ($current).')));
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Version ${info!.version.replaceFirst('v', '')} is available'),
        content: SingleChildScrollView(
          child: Text('You have $current.\n\n${info.notes.isEmpty ? 'Bug fixes and improvements.' : info.notes}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Update now')),
        ],
      ),
    );
    if (go != true || !context.mounted) return;

    if (Platform.isAndroid && info.apkUrl != null) {
      await _androidInstall(context, info.apkUrl!);
    } else {
      // iOS apps cannot install themselves; open the download page instead.
      await launchUrl(Uri.parse(info.pageUrl), mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _androidInstall(BuildContext context, String url) async {
    final progress = ValueNotifier<String>('Starting download…');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Updating'),
        content: ValueListenableBuilder<String>(
          valueListenable: progress,
          builder: (_, v, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(v),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hide'))],
      ),
    );
    try {
      OtaUpdate().execute(url, destinationFilename: 'RecipeBox-update.apk').listen((e) {
        switch (e.status) {
          case OtaStatus.DOWNLOADING:
            progress.value = 'Downloading… ${e.value ?? 0}%';
          case OtaStatus.INSTALLING:
            progress.value = 'Opening installer… Tap “Update” when Android asks. Your recipes are kept.';
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            progress.value = 'Please allow Recipe Box to install apps (Android Settings ▸ Install unknown apps), then try again.';
          default:
            if (e.status.toString().contains('ERROR')) progress.value = 'Update failed: ${e.value ?? e.status}';
        }
      });
    } catch (e) {
      progress.value = 'Update failed: $e';
    }
  }
}

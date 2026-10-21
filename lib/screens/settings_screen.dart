import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backup_service.dart';
import '../services/recipe_store.dart';
import '../services/settings.dart';
import '../services/share_service.dart';
import '../services/update_service.dart';
import '../widgets/decor.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const swatches = <Color>[
    // tomatoes & peppers
    Color(0xFFD84315), Color(0xFFC62828), Color(0xFFE53935), Color(0xFFFF7043),
    // citrus & spice
    Color(0xFFF9A825), Color(0xFFFFB300), Color(0xFFFFCA28), Color(0xFFEF6C00),
    // herbs & greens
    Color(0xFF558B2F), Color(0xFF2E7D32), Color(0xFF7CB342), Color(0xFF00897B),
    // berries & plums
    Color(0xFF6A1B9A), Color(0xFFAD1457), Color(0xFF3949AB), Color(0xFF1565C0),
    // breads & chocolate
    Color(0xFF8D6E63), Color(0xFF5D4037), Color(0xFF3E2723), Color(0xFFA1887F),
    // creams & parchments
    Color(0xFFFFF6E9), Color(0xFFFFF8E1), Color(0xFFFFFDE7), Color(0xFFF1F8E9),
    Color(0xFFFCE4EC), Color(0xFFE3F2FD), Color(0xFFFFFFFF), Color(0xFFF5F5F5),
    // darks
    Color(0xFF1E1612), Color(0xFF2E231C), Color(0xFF212121), Color(0xFF000000),
  ];

  Future<void> _pickColor(BuildContext context, String key, String label, Color? current) async {
    final s = context.read<AppSettings>();
    final picked = await showDialog<Object>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 320,
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final col in swatches)
              InkWell(
                onTap: () => Navigator.pop(c, col),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: current?.toARGB32() == col.toARGB32() ? Colors.blueAccent : Colors.black26,
                        width: current?.toARGB32() == col.toARGB32() ? 3 : 1),
                  ),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'default'), child: const Text('Use default')),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ],
      ),
    );
    if (picked == 'default') {
      await s.setColor(key, null);
    } else if (picked is Color) {
      await s.setColor(key, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final t = Theme.of(context);

    Widget colorTile(String key, String label, String help, Color? value, Color fallback) => ListTile(
          title: Text(label),
          subtitle: Text(value == null ? '$help · default' : help),
          trailing: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: value ?? fallback, shape: BoxShape.circle, border: Border.all(color: Colors.black26)),
          ),
          onTap: () => _pickColor(context, key, label, value),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
        children: [
          const SectionHeader('Look & Feel'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android), label: Text('Auto')),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => s.setThemeMode(v.first),
                  ),
                ),
                colorTile('accent', 'Accent color', 'Buttons and highlights', s.accentColor, t.colorScheme.primary),
                colorTile('bg', 'Background', 'Behind everything', s.backgroundColor, t.scaffoldBackgroundColor),
                colorTile('fg', 'Foreground (cards)', 'Recipe panels and tiles', s.foregroundColor, t.colorScheme.surface),
                colorTile('border', 'Borders', 'Outlines around cards', s.borderColor, t.dividerColor),
                colorTile('text', 'Text color', 'Words throughout the app', s.textColor, t.colorScheme.onSurface),
                ListTile(
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('Reset colors to the food-themed defaults'),
                  onTap: s.resetColors,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Font', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: s.fontFamily,
                  isExpanded: true,
                  items: [
                    for (final e in AppSettings.fonts.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value, style: TextStyle(fontFamily: e.key, fontSize: 17))),
                  ],
                  onChanged: (v) => v == null ? null : s.setFontFamily(v),
                ),
                const SizedBox(height: 16),
                Text('Recipe text size  (${(s.recipeFontScale * 100).round()}%)',
                    style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Slider(
                  value: s.recipeFontScale,
                  min: 0.8,
                  max: 2.0,
                  divisions: 12,
                  label: '${(s.recipeFontScale * 100).round()}%',
                  onChanged: s.setRecipeFontScale,
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('2 cups all-purpose flour\nPreheat the oven to 350°F.',
                      style: t.textTheme.bodyLarge?.copyWith(fontSize: 16.5 * s.recipeFontScale)),
                ),
                const SizedBox(height: 16),
                Text('Whole-app text size  (${(s.appFontScale * 100).round()}%)',
                    style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Slider(
                  value: s.appFontScale,
                  min: 0.85,
                  max: 1.5,
                  divisions: 13,
                  label: '${(s.appFontScale * 100).round()}%',
                  onChanged: s.setAppFontScale,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Show cookbook cover when opening'),
              value: s.showSplash,
              onChanged: s.setShowSplash,
            ),
          ),
          if (kIsWeb) ...[
            const SectionHeader('Web import helper'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Web browsers don\'t let web apps read other websites directly. To import recipes from '
                      'websites in this web version, paste your helper address here (see the README for the free setup).'),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: s.webImportProxy,
                    decoration: const InputDecoration(hintText: 'https://recipe-helper.yourname.workers.dev'),
                    keyboardType: TextInputType.url,
                    onFieldSubmitted: s.setWebImportProxy,
                    onChanged: s.setWebImportProxy,
                  ),
                ]),
              ),
            ),
          ],
          const SectionHeader('My Recipes'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Back up all my recipes'),
                subtitle: const Text('Save a backup file with your recipes, photos and favorites'),
                onTap: () => BackupService.saveBackup(context),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Send backup to email / Google Drive / iCloud'),
                onTap: () => BackupService.shareBackup(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore from a backup'),
                subtitle: const Text('Adds your recipes back; nothing is deleted'),
                onTap: () => BackupService.restore(context),
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Share all my own recipes with a friend'),
                subtitle: const Text('Creates a .recipe file they can open in Recipe Box'),
                onTap: () {
                  final mine = context.read<RecipeStore>().all.where((r) => !r.builtIn).toList();
                  if (mine.isEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('You have not added any recipes yet.')));
                    return;
                  }
                  ShareService.shareRecipeFiles(mine);
                },
              ),
            ]),
          ),
          const SectionHeader('App'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('Check for updates'),
                subtitle: Text('Downloads the newest version from github.com/${UpdateConfig.githubOwner}'),
                onTap: () => UpdateService.checkAndUpdate(context),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                subtitle: const Text('Version, credits and licenses'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

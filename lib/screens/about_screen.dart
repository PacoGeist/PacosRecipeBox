import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/recipe_store.dart';
import '../services/update_service.dart';
import '../widgets/decor.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final store = context.watch<RecipeStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: IngredientCorners(
        size: 54,
        opacity: 0.6,
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final info = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/images/icon.png', width: 110, height: 110),
                  ),
                ),
                const SizedBox(height: 12),
                Text(appTitle, textAlign: TextAlign.center, style: t.textTheme.headlineLarge),
                Text(
                  info == null ? '' : 'Version ${info.version} (build ${info.buildNumber})',
                  textAlign: TextAlign.center,
                  style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.w800),
                ),
                Text('Recipe library edition ${store.libraryVersion} · ${store.count} recipes on this device',
                    textAlign: TextAlign.center, style: t.textTheme.bodySmall),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'A free, offline cookbook for your family recipes, recipes from friends and recipes from '
                      'around the web. Everything is stored only on this device — no account, no ads, no tracking.\n\n'
                      'Made available free of charge by PacoGeist. Not for sale.',
                      style: t.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('Project page on GitHub'),
                      subtitle: Text(UpdateConfig.repoPage),
                      onTap: () => launchUrl(Uri.parse(UpdateConfig.repoPage), mode: LaunchMode.externalApplication),
                    ),
                    ListTile(
                      leading: const Icon(Icons.system_update),
                      title: const Text('Check for updates'),
                      onTap: () => UpdateService.checkAndUpdate(context),
                    ),
                  ]),
                ),
                const SectionHeader('Credits'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Built-in recipes: every recipe shows its own author and source on its page.\n\n'
                      '• Wikibooks Cookbook contributors (en.wikibooks.org/wiki/Cookbook) — text available under the '
                      'Creative Commons Attribution-ShareAlike License (CC BY-SA). Recipes may have been reformatted.\n'
                      '• Recipe Box Kitchen — original recipes written for this app.\n\n'
                      'Photos: Wikimedia Commons and Flickr contributors (found via Openverse); each photo\'s author and license is listed on its recipe.\n\n'
                      'Cover: a collage of recipe photos from Wikimedia Commons on a wood texture by Amal Kumar / Poly Haven (CC0) — see Cover photo credits below.\n\n'
                      'Ingredient illustrations: Twemoji by Twitter, Inc. and contributors, CC BY 4.0.\n\n'
                      'Fonts: Nunito, Lora, Playfair Display, Atkinson Hyperlegible and Caveat — SIL Open Font License.\n\n'
                      'Recipes you import from websites stay credited to their original authors and are for your '
                      'personal use.',
                      style: t.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Cover photo credits'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      FutureBuilder<String>(
                        future: rootBundle.loadString('assets/seed/cover_credits.txt'),
                        builder: (_, s) => Text(s.data ?? '', style: t.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: appTitle,
                    applicationVersion: info?.version,
                  ),
                  icon: const Icon(Icons.gavel),
                  label: const Text('Open-source licenses'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

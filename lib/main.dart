import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/recipe_store.dart';
import 'services/settings.dart';
import 'theme/app_theme.dart';

const appTitle = 'Recipe Box';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  final store = RecipeStore();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: store),
      ],
      child: const RecipeApp(),
    ),
  );
  // Load the database while the cover is showing.
  store.init();
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: s.themeMode,
      theme: AppTheme.build(s, Brightness.light),
      darkTheme: AppTheme.build(s, Brightness.dark),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * s.appFontScale)),
          child: child!,
        );
      },
      home: s.showSplash ? const SplashScreen() : const HomeScreen(),
    );
  }
}

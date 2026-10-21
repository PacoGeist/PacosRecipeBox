import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/recipe_store.dart';
import 'services/settings.dart';
import 'services/startup_log.dart';
import 'theme/app_theme.dart';

const appTitle = 'Recipe Box';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      StartupLog.add('ui', d.exception, d.stack);
    };
    // Show the cookbook cover right away; load settings and recipes behind it.
    final settings = AppSettings();
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
    try {
      await settings.load().timeout(const Duration(seconds: 8));
    } catch (e, s) {
      StartupLog.add('settings', e, s);
    }
    await store.init();
  }, (e, s) => StartupLog.add('app', e, s));
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

// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders key screens to PNGs for visual review:
//   flutter test tool/screens/screens_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recipe_box/models/recipe.dart';
import 'package:recipe_box/screens/category_screens.dart';
import 'package:recipe_box/screens/home_screen.dart';
import 'package:recipe_box/screens/recipe_detail_screen.dart';
import 'package:recipe_box/screens/recipe_list_screen.dart';
import 'package:recipe_box/screens/settings_screen.dart';
import 'package:recipe_box/screens/splash_screen.dart';
import 'package:recipe_box/screens/grocery_screens.dart';
import 'package:recipe_box/screens/menu_screens.dart';
import 'package:recipe_box/services/planner_store.dart';
import 'package:recipe_box/services/recipe_store.dart';
import 'package:recipe_box/services/settings.dart';
import 'package:recipe_box/theme/app_theme.dart';

Future<void> loadFont(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  late List<Recipe> recipes;
  setUpAll(() async {
    await loadFont('Nunito', ['assets/fonts/Nunito-Regular.ttf', 'assets/fonts/Nunito-Bold.ttf', 'assets/fonts/Nunito-ExtraBold.ttf']);
    await loadFont('PlayfairDisplay', ['assets/fonts/PlayfairDisplay-Bold.ttf', 'assets/fonts/PlayfairDisplay-Black.ttf']);
    await loadFont('Lora', ['assets/fonts/Lora-Regular.ttf', 'assets/fonts/Lora-Italic.ttf']);
    await loadFont('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await loadFont('NotoColorEmoji', ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf']);
    final j = jsonDecode(File('assets/seed/recipes.json').readAsStringSync());
    recipes = (j['recipes'] as List).map((e) => Recipe.fromJson(e)).toList();
  });

  Future<void> shot(WidgetTester tester, String name, Widget screen,
      {Size size = const Size(412, 892), bool dark = false, Future<void> Function()? before}) async {
    SharedPreferences.setMockInitialValues({'themeMode': dark ? 2 : 1});
    final settings = AppSettings();
    await settings.load();
    final store = RecipeStore()..debugLoad(recipes.map((r) => r.copy()).toList());
    final planner = PlannerStore()..persist = false;
    final t0 = today();
    Recipe pickR(String w) => store.all.firstWhere((r) => r.title.toLowerCase().contains(w));
    final menu = [pickR('pot roast'), pickR('mashed'), pickR('apple')];
    await planner.addToMenu(t0, menu.map((r) => r.id));
    await planner.markMade(t0, menu.first.id);
    await planner.addToMenu(t0.subtract(const Duration(days: 2)), [pickR('taco').id]);
    await planner.markMade(t0.subtract(const Duration(days: 2)), pickR('taco').id);
    await planner.markMade(t0.subtract(const Duration(days: 5)), pickR('chili').id);
    for (final r in store.all.where((r) => r.cuisines.contains('Irish')).take(3)) {
      r.favorite = true;
    }
    final gl = await planner.newList('Menu for today');
    for (final r in menu) {
      await planner.addRecipe(gl, r);
    }
    await planner.addItem(gl, 'paper towels');
    for (final i in gl.items.take(4)) {
      await planner.toggle(gl, i);
    }
    tester.view.physicalSize = size * 2.625;
    tester.view.devicePixelRatio = 2.625;
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: settings), ChangeNotifierProvider.value(value: store), ChangeNotifierProvider.value(value: planner)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: AppTheme.build(settings, Brightness.light),
        darkTheme: AppTheme.build(settings, Brightness.dark),
        home: screen,
      ),
    ));
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        final img = e.widget as Image;
        await precacheImage(img.image, e);
      }
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 100));
    if (before != null) await before();
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('splash', (t) async => shot(t, '01_splash', const SplashScreen()));
  testWidgets('home', (t) async => shot(t, '02_home', const HomeScreen()));
  testWidgets('home dark', (t) async => shot(t, '03_home_dark', const HomeScreen(), dark: true));
  testWidgets('cuisines', (t) async => shot(t, '04_cuisines', const CuisinesScreen()));
  testWidgets('seasonal', (t) async => shot(t, '05_seasonal', const SeasonalScreen()));
  testWidgets('list', (t) async => shot(t, '06_list_irish',
      const RecipeListScreen(title: 'Irish Recipes', filter: RecipeFilter(cuisine: 'Irish'), showMealTypeChips: true)));
  testWidgets('detail', (t) async {
    final id = recipes.firstWhere((r) => r.photo != null && r.title.contains('Soda Bread'), orElse: () => recipes.firstWhere((r) => r.photo != null)).id;
    await shot(t, '07_detail', RecipeDetailScreen(recipeId: id), size: const Size(412, 1800));
  });
  testWidgets('detail doubled', (t) async {
    final id = recipes.firstWhere((r) => r.photo != null && r.title.contains('Soda Bread'), orElse: () => recipes.firstWhere((r) => r.photo != null)).id;
    await shot(t, '08_detail_2x', RecipeDetailScreen(recipeId: id), size: const Size(412, 1800), before: () async {
      await t.tap(find.text('2×'));
    });
  });
  testWidgets('settings', (t) async => shot(t, '09_settings', const SettingsScreen(), size: const Size(412, 1300)));
  testWidgets('menu planner', (t) async => shot(t, '11_menu_planner', const MenuPlannerScreen()));
  testWidgets('grocery list', (t) async => shot(t, '12_grocery', const GroceryListScreen(), size: const Size(412, 1400)));
  testWidgets('menu history', (t) async => shot(t, '13_history', const MenuHistoryScreen(), size: const Size(412, 1100)));
  testWidgets('cuisine meal types', (t) async => shot(t, '14_cuisine_menu',
      const MealTypeMenuScreen(title: 'Irish', filter: RecipeFilter(cuisine: 'Irish'), color: Color(0xFF2E7D32), emoji: '🍀')));
  testWidgets('tablet home', (t) async => shot(t, '10_tablet_home', const HomeScreen(), size: const Size(1024, 1366)));
}

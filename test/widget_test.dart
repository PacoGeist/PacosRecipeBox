import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_box/services/scaler.dart';
import 'package:recipe_box/services/update_service.dart';
import 'package:recipe_box/services/web_import.dart';

void main() {
  group('IngredientScaler', () {
    String s(String l, double f) => IngredientScaler.scaleLine(l, f);
    test('whole numbers', () {
      expect(s('2 cups flour', 2), '4 cups flour');
      expect(s('3 eggs', 0.5), '1 1/2 eggs');
      expect(s('1 onion, chopped', 3), '3 onion, chopped');
    });
    test('fractions and mixed numbers', () {
      expect(s('1/2 cup sugar', 2), '1 cup sugar');
      expect(s('1 1/2 cups milk', 2), '3 cups milk');
      expect(s('1-1/2 tsp salt', 0.5), '3/4 tsp salt');
      expect(s('3/4 cup butter', 3), '2 1/4 cup butter');
      expect(s('1/3 cup oil', 0.5), '1/6 cup oil'.replaceAll('1/6', IngredientScaler.format(1 / 6)));
    });
    test('unicode fractions', () {
      expect(s('½ tsp pepper', 2), '1 tsp pepper');
      expect(s('1½ cups rice', 2), '3 cups rice');
    });
    test('ranges', () {
      expect(s('2-3 cloves garlic', 2), '4-6 cloves garlic');
      expect(s('2 to 3 tbsp honey', 3), '6 to 9 tbsp honey');
    });
    test('decimals and metric', () {
      expect(s('200g flour', 1.5), '300g flour');
      expect(s('0.5 kg beef', 3), '1.5 kg beef');
      expect(s('250 ml stock', 0.5), '125 ml stock');
    });
    test('no quantity / headings unchanged', () {
      expect(s('Salt to taste', 2), 'Salt to taste');
      expect(s('# For the sauce', 2), '# For the sauce');
    });
    test('package sizes in parentheses stay put', () {
      expect(s('1 (14 oz) can tomatoes', 2), '2 (14 oz) can tomatoes');
    });
    test('equivalents in parentheses scale too', () {
      expect(s('32 fl oz (1 L) hot water', 2), '64 fl oz (2 L) hot water');
      expect(s('1 lb (450 g) beef', 2), '2 lb (900 g) beef');
    });
    test('ascii fractions', () {
      expect(IngredientScaler.asciiFractions('1½ cups and ⅓ tsp'), '1 1/2 cups and 1/3 tsp');
    });
    test('splitQuantity', () {
      expect(IngredientScaler.splitQuantity('1 1/2 cups flour'), ('1 1/2', ' cups flour'));
      expect(IngredientScaler.splitQuantity('pinch of salt'), ('', 'pinch of salt'));
    });
  });

  test('version compare', () {
    expect(UpdateService.compareVersions('v1.2.0', '1.1.9') > 0, true);
    expect(UpdateService.compareVersions('1.0.0', '1.0.0'), 0);
    expect(UpdateService.compareVersions('1.0.10', '1.0.9') > 0, true);
  });

  test('web import parses schema.org JSON-LD', () {
    const html = '''<html lang="en"><head>
<meta property="og:site_name" content="Test Kitchen">
<script type="application/ld+json">{"@context":"https://schema.org","@graph":[{"@type":"WebPage"},
{"@type":["Recipe"],"name":"Best Chicken Tacos","author":{"@type":"Person","name":"Jane Cook"},
"recipeYield":["4","4 servings"],"prepTime":"PT15M","cookTime":"PT1H5M",
"recipeIngredient":["1 lb chicken, diced","8 tortillas"],
"recipeInstructions":[{"@type":"HowToStep","text":"Cook the chicken."},{"@type":"HowToStep","text":"Fill &amp; serve."}],
"recipeCuisine":"Mexican","recipeCategory":"Dinner","image":["https://x.test/a.jpg"]}]}</script></head><body></body></html>''';
    final r = WebImporter.parseHtml(html, 'https://www.test.com/tacos')!;
    expect(r.recipe.title, 'Best Chicken Tacos');
    expect(r.recipe.author, 'Jane Cook');
    expect(r.recipe.servings, 4);
    expect(r.recipe.prepMinutes, 15);
    expect(r.recipe.cookMinutes, 65);
    expect(r.recipe.ingredients, ['1 lb chicken, diced', '8 tortillas']);
    expect(r.recipe.steps.map((s) => s.text).toList(), ['Cook the chicken.', 'Fill & serve.']);
    expect(r.recipe.cuisines.contains('Mexican'), true);
    expect(r.recipe.source, 'Test Kitchen');
    expect(r.imageUrl, 'https://x.test/a.jpg');
    expect(r.looksEnglish, true);
  });
}

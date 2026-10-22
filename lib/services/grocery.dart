import 'package:flutter/material.dart';

/// Grocery store departments, in the order a list is shown.
class Dept {
  final String key;
  final String label;
  final String emoji;
  final Color color;
  const Dept(this.key, this.label, this.emoji, this.color);

  static const produce = Dept('produce', 'Produce', '🥕', Color(0xFF43A047));
  static const meat = Dept('meat', 'Meat & Seafood', '🥩', Color(0xFFC62828));
  static const dairy = Dept('dairy', 'Dairy & Eggs', '🧀', Color(0xFFF9A825));
  static const bakery = Dept('bakery', 'Bakery', '🥖', Color(0xFF8D6E63));
  static const dry = Dept('dry', 'Dry Goods & Canned', '🥫', Color(0xFFEF6C00));
  static const frozen = Dept('frozen', 'Frozen', '🧊', Color(0xFF0288D1));
  static const other = Dept('other', 'Other', '🛒', Color(0xFF6D4C41));

  static const all = [produce, meat, dairy, bakery, dry, frozen, other];
  static Dept byKey(String k) => all.firstWhere((d) => d.key == k, orElse: () => other);
}

/// Sorts an ingredient line into a grocery department.
///
/// Rules: anything canned/jarred/boxed goes to Dry Goods; frozen items to Frozen;
/// then meat, dairy, bakery and produce keywords; spices, flours, sugars, oils,
/// sauces etc. are Dry Goods.
class GroceryClassifier {
  static final Map<String, RegExp> _cache = {};

  /// Whole-word match that also accepts simple plurals (tomato/tomatoes, berry/berries).
  static bool _any(String s, List<String> words) => words.any((w) {
        final re = _cache.putIfAbsent(w, () {
          final e = RegExp.escape(w.trim());
          final forms = [e, '${e}s', '${e}es', if (w.endsWith('y')) '${RegExp.escape(w.substring(0, w.length - 1))}ies'];
          return RegExp('(?<![a-z])(${forms.join('|')})(?![a-z])', caseSensitive: false);
        });
        return re.hasMatch(s);
      });

  static const _canned = [
    'can', 'canned', 'tin', 'tinned', 'jar', 'jarred', 'bottled', 'box of', 'packet', 'package of',
    'envelope', 'condensed', 'evaporated', 'dried', 'dry', 'powder', 'powdered', 'instant',
    'cake mix', 'pancake mix', 'baking mix', 'bouillon', 'broth', 'stock', 'paste', 'sauce', 'ketchup', 'mustard', 'mayonnaise', 'vinegar', 'oil',
    'syrup', 'honey', 'molasses', 'jam', 'jelly', 'preserves', 'peanut butter', 'extract', 'salsa', 'starch', 'cornstarch',
    'tomato juice', 'apple juice', 'cranberry juice', 'pineapple juice', 'grape juice', 'vegetable juice',
  ];
  static const _frozen = ['frozen'];
  static const _meat = [
    'beef', 'steak', 'brisket', 'ground chuck', 'chuck', 'sirloin', 'ribeye', 'veal', 'pork', 'ham', 'bacon',
    'sausage', 'bratwurst', 'chorizo', 'pancetta', 'prosciutto', 'salami', 'pepperoni', 'hot dog', 'lamb',
    'mutton', 'goat', 'venison', 'bison', 'chicken', 'turkey', 'duck', 'goose', 'quail', 'rabbit', 'ribs',
    'fish', 'salmon', 'tuna', 'cod', 'haddock', 'halibut', 'tilapia', 'trout', 'catfish', 'snapper', 'walleye',
    'mackerel', 'sardine', 'anchovy', 'shrimp', 'prawn', 'crab', 'lobster', 'clam', 'mussel', 'oyster',
    'scallop', 'squid', 'octopus', 'meat', 'mince', 'oxtail', 'tripe', 'liver', 'corned',
  ];
  static const _dairy = [
    'milk', 'buttermilk', 'cream', 'half-and-half', 'half and half', 'butter', 'cheese', 'cheddar', 'mozzarella',
    'parmesan', 'ricotta', 'feta', 'paneer', 'yogurt', 'yoghurt', 'sour cream', 'crème', 'creme fraiche', 'egg',
    'ghee', 'margarine', 'cottage', 'mascarpone', 'quark', 'kefir',
  ];
  static const _bakery = [
    'bread', 'loaf', 'loaves', 'baguette', 'hamburger bun', 'hot dog bun', 'burger bun', 'dinner roll', 'sub roll', 'tortilla', 'pita', 'naan', 'bagel', 'croissant',
    'english muffin', 'brioche', 'pie crust', 'pie shell', 'puff pastry', 'phyllo', 'filo', 'wonton wrapper',
    'dumpling wrapper', 'crumpet', 'hamburger bun', 'hot dog bun',
  ];
  static const _produce = [
    'tofu',
    'apple', 'banana', 'orange', 'lemon', 'lime', 'grapefruit', 'berry', 'strawberry', 'blueberry',
    'raspberry', 'blackberry', 'cranberry', 'huckleberry', 'cherry', 'grape', 'peach', 'pear', 'plum', 'apricot',
    'mango', 'pineapple', 'papaya', 'kiwi', 'melon', 'watermelon', 'avocado', 'tomato', 'tomatillo', 'potato',
    'sweet potato', 'yam', 'onion', 'shallot', 'scallion', 'green onion', 'spring onion', 'leek', 'garlic',
    'ginger', 'carrot', 'celery', 'pepper', 'bell pepper', 'chile', 'chili', 'jalapeño', 'jalapeno', 'serrano',
    'poblano', 'habanero', 'cabbage', 'lettuce', 'spinach', 'kale', 'chard', 'collard', 'arugula', 'broccoli',
    'cauliflower', 'zucchini', 'squash', 'pumpkin', 'cucumber', 'eggplant', 'aubergine', 'mushroom', 'corn',
    'pea', 'green bean', 'snap pea', 'snow pea', 'beet', 'radish', 'turnip', 'parsnip', 'rutabaga', 'okra', 'asparagus', 'artichoke',
    'fennel', 'bok choy', 'sprouts', 'bean sprouts', 'herb', 'parsley', 'cilantro', 'coriander leaves', 'basil', 'mint', 'dill',
    'chives', 'thyme sprig', 'rosemary sprig', 'sage leaves', 'lemongrass', 'rhubarb', 'fig', 'date', 'plantain',
    'cassava', 'taro', 'jicama', 'sunchoke', 'ramp', 'fiddlehead', 'cabbage', 'lettuce leaves', 'salad greens', 'greens', 'fresh',
  ];

  static Dept classify(String line) {
    final s = line.toLowerCase();
    if (_any(s, _frozen)) return Dept.frozen;
    if (_any(s, _canned)) return Dept.dry;
    // "fresh" herbs/produce beat generic words like "ground pepper" (spice)
    if (_any(s, _meat) && !_any(s, ['broth', 'stock', 'bouillon'])) return Dept.meat;
    if (_any(s, _dairy) && !_any(s, ['peanut butter', 'coconut milk', 'coconut cream', 'almond milk', 'soy milk', 'cream of tartar', 'eggplant', 'egg noodle', 'egg roll wrapper', 'butternut'])) {
      return Dept.dairy;
    }
    if (_any(s, _bakery) && !_any(s, ['bread crumb', 'breadcrumb', 'panko'])) return Dept.bakery;
    if (_any(s, ['ground pepper', 'black pepper', 'white pepper', 'peppercorn', 'pepper flakes', 'cayenne',
          'paprika', 'chili powder', 'chile powder', 'red pepper flakes', 'garlic powder', 'onion powder',
          'dried', 'ground ginger', 'ground cumin', 'ground coriander', 'seed', 'ground cinnamon'])) {
      return Dept.dry;
    }
    if (_any(s, _produce)) return Dept.produce;
    return Dept.dry; // flour, sugar, rice, pasta, spices, nuts, salt...
  }

  /// Lines that aren't worth buying (water, ice) are skipped.
  static const _waterWords = {
    'water', 'ice', 'cubes', 'cube', 'cold', 'warm', 'hot', 'boiling', 'lukewarm', 'tepid', 'tap', 'filtered',
    'cup', 'cups', 'fl', 'oz', 'l', 'ml', 'liter', 'liters', 'litre', 'litres', 'quart', 'quarts', 'pint', 'pints',
    'gallon', 'gallons', 'tbsp', 'tsp', 'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons', 'about', 'plus',
    'more', 'extra', 'as', 'needed', 'to', 'taste', 'for', 'of', 'or', 'and', 'the', 'a', 'very', 'divided',
  };

  /// True for lines you never buy, like "2 cups water" or "32 fl oz (1 L) hot water".
  static bool skip(String line) {
    final words = line.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ').split(' ').where((w) => w.isNotEmpty).toList();
    if (!words.contains('water') && !words.contains('ice')) return false;
    return words.every(_waterWords.contains);
  }
}

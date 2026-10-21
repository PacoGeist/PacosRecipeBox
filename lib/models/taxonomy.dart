import 'package:flutter/material.dart';

/// A browsable category (cuisine, meal type, season, holiday, collection).
class Category {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String? emoji;
  const Category(this.key, this.label, this.icon, this.color, {this.emoji});
}

/// Where a recipe came from. Drives the three "collection" buttons on the home page.
class Collections {
  static const family = 'family';
  static const friend = 'friend';
  static const internet = 'internet';

  static const all = <Category>[
    Category(family, 'My & Family Recipes', Icons.family_restroom, Color(0xFFD84315), emoji: '👵'),
    Category(friend, "Friends' Recipes", Icons.people_alt, Color(0xFF6A1B9A), emoji: '🤝'),
    Category(internet, 'Internet Recipes', Icons.public, Color(0xFF00838F), emoji: '🌐'),
  ];

  static Category byKey(String k) => all.firstWhere((c) => c.key == k, orElse: () => all.first);
}

class Cuisines {
  static const all = <Category>[
    Category('American', 'American', Icons.flag, Color(0xFF1565C0), emoji: '🍔'),
    Category('Mexican', 'Mexican', Icons.local_fire_department, Color(0xFF2E7D32), emoji: '🌮'),
    Category('Japanese', 'Japanese', Icons.ramen_dining, Color(0xFFC62828), emoji: '🍣'),
    Category('Chinese', 'Chinese', Icons.rice_bowl, Color(0xFFD32F2F), emoji: '🥟'),
    Category('British', 'British', Icons.coffee, Color(0xFF283593), emoji: '🫖'),
    Category('Irish', 'Irish', Icons.grass, Color(0xFF388E3C), emoji: '☘️'),
    Category('German', 'German', Icons.sports_bar, Color(0xFFF9A825), emoji: '🥨'),
    Category('Indian', 'Indian', Icons.soup_kitchen, Color(0xFFEF6C00), emoji: '🍛'),
    Category('Native American', 'Native American', Icons.park, Color(0xFF8D6E63), emoji: '🌽'),
    Category('BBQ', 'BBQ', Icons.outdoor_grill, Color(0xFF4E342E), emoji: '🍖'),
    Category('Slow Cooker', 'Slow Cooker', Icons.timer, Color(0xFF795548), emoji: '🍲'),
    Category('Potluck', 'Potluck', Icons.celebration, Color(0xFFAD1457), emoji: '🥗'),
  ];
  static List<String> get keys => all.map((c) => c.key).toList();
}

class MealTypes {
  static const all = <Category>[
    Category('Breakfast', 'Breakfast', Icons.free_breakfast, Color(0xFFFFA000), emoji: '🥞'),
    Category('Appetizer', 'Appetizers & Snacks', Icons.tapas, Color(0xFF7CB342), emoji: '🧀'),
    Category('Entree', 'Entrees', Icons.dinner_dining, Color(0xFFBF360C), emoji: '🍗'),
    Category('Side Dish', 'Side Dishes', Icons.eco, Color(0xFF558B2F), emoji: '🥦'),
    Category('Soup & Salad', 'Soups & Salads', Icons.soup_kitchen, Color(0xFF00897B), emoji: '🥣'),
    Category('Bread', 'Breads', Icons.bakery_dining, Color(0xFFA1887F), emoji: '🍞'),
    Category('Dessert', 'Desserts', Icons.cake, Color(0xFFEC407A), emoji: '🍰'),
    Category('Beverage', 'Beverages', Icons.local_drink, Color(0xFF0288D1), emoji: '🥤'),
  ];
  static List<String> get keys => all.map((c) => c.key).toList();
}

class Seasons {
  static const all = <Category>[
    Category('Spring', 'Spring', Icons.local_florist, Color(0xFF66BB6A), emoji: '🌷'),
    Category('Summer', 'Summer', Icons.wb_sunny, Color(0xFFFFB300), emoji: '☀️'),
    Category('Fall', 'Fall', Icons.forest, Color(0xFFE65100), emoji: '🍂'),
    Category('Winter', 'Winter', Icons.ac_unit, Color(0xFF42A5F5), emoji: '❄️'),
  ];
  static List<String> get keys => all.map((c) => c.key).toList();
}

class Holidays {
  static const all = <Category>[
    Category("New Year's", "New Year's", Icons.celebration, Color(0xFF5E35B1), emoji: '🎆'),
    Category('Lunar New Year', 'Lunar New Year', Icons.festival, Color(0xFFC62828), emoji: '🧧'),
    Category("Valentine's Day", "Valentine's Day", Icons.favorite, Color(0xFFE91E63), emoji: '💝'),
    Category("St. Patrick's Day", "St. Patrick's Day", Icons.grass, Color(0xFF2E7D32), emoji: '🍀'),
    Category('Easter', 'Easter', Icons.egg, Color(0xFFBA68C8), emoji: '🐣'),
    Category('Passover', 'Passover', Icons.wine_bar, Color(0xFF3949AB), emoji: '🍷'),
    Category('Cinco de Mayo', 'Cinco de Mayo', Icons.music_note, Color(0xFF43A047), emoji: '🪅'),
    Category('Fourth of July', 'Fourth of July', Icons.flag, Color(0xFF1E88E5), emoji: '🎇'),
    Category('Oktoberfest', 'Oktoberfest', Icons.sports_bar, Color(0xFFFFA000), emoji: '🍺'),
    Category('Halloween', 'Halloween', Icons.nightlight, Color(0xFFEF6C00), emoji: '🎃'),
    Category('Diwali', 'Diwali', Icons.light_mode, Color(0xFFFF8F00), emoji: '🪔'),
    Category('Thanksgiving', 'Thanksgiving', Icons.restaurant, Color(0xFF8D6E63), emoji: '🦃'),
    Category('Hanukkah', 'Hanukkah', Icons.local_fire_department, Color(0xFF1565C0), emoji: '🕎'),
    Category('Christmas', 'Christmas', Icons.park, Color(0xFFC62828), emoji: '🎄'),
    Category('Game Day', 'Game Day', Icons.sports_football, Color(0xFF6D4C41), emoji: '🏈'),
  ];
  static List<String> get keys => all.map((c) => c.key).toList();
}

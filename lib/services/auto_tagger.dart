import '../models/recipe.dart';

/// Guesses cuisine, meal type, season and holiday tags from a recipe's
/// title, keywords and ingredients. Used when importing from the web so
/// imported recipes show up under the right home-page buttons.
class AutoTagger {
  static bool _has(String hay, List<String> words) =>
      words.any((w) => RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(hay));

  static const cuisineWords = <String, List<String>>{
    'American': ['american', 'southern', 'cajun', 'creole', 'tex-mex', 'new england', 'meatloaf', 'mac and cheese', 'cornbread', 'buffalo'],
    'Mexican': ['mexican', 'taco', 'tacos', 'enchilada', 'enchiladas', 'tamale', 'tamales', 'salsa', 'guacamole', 'quesadilla', 'burrito', 'pozole', 'mole', 'churros', 'tortilla', 'tortillas', 'fajita', 'fajitas', 'chilaquiles', 'horchata'],
    'Japanese': ['japanese', 'sushi', 'miso', 'teriyaki', 'ramen', 'tempura', 'udon', 'soba', 'katsu', 'onigiri', 'mochi', 'dashi', 'yakitori', 'gyoza', 'matcha', 'tonkatsu', 'okonomiyaki'],
    'Chinese': ['chinese', 'szechuan', 'sichuan', 'cantonese', 'wonton', 'dumpling', 'dumplings', 'chow mein', 'lo mein', 'kung pao', 'fried rice', 'bok choy', 'hoisin', 'dim sum', 'mapo', 'char siu', 'congee'],
    'British': ['british', 'english', 'scottish', 'welsh', 'scone', 'scones', 'shepherd', 'yorkshire', 'trifle', 'crumpet', 'bangers', 'toad in the hole', 'cornish', 'sticky toffee', 'shortbread', 'haggis', 'fish and chips'],
    'Irish': ['irish', 'colcannon', 'boxty', 'soda bread', 'guinness', 'coddle', 'champ', 'barmbrack'],
    'German': ['german', 'bavarian', 'schnitzel', 'sauerkraut', 'bratwurst', 'spaetzle', 'spätzle', 'strudel', 'pretzel', 'sauerbraten', 'kuchen', 'stollen', 'lebkuchen', 'rouladen', 'black forest'],
    'Indian': ['indian', 'curry', 'masala', 'tikka', 'dal', 'dhal', 'paneer', 'biryani', 'naan', 'chapati', 'samosa', 'tandoori', 'korma', 'vindaloo', 'chutney', 'raita', 'pakora', 'lassi', 'chana', 'aloo', 'gobi', 'roti'],
    'Native American': ['native american', 'fry bread', 'frybread', 'wild rice', 'succotash', 'pemmican', 'three sisters', 'hominy', 'bannock', 'wojapi'],
    'BBQ': ['bbq', 'barbecue', 'barbeque', 'grilled', 'smoked', 'brisket', 'pulled pork', 'ribs', 'grill', 'smoker'],
    'Slow Cooker': ['slow cooker', 'crock pot', 'crockpot', 'crock-pot', 'slow-cooker'],
    'Potluck': ['potluck', 'casserole', 'dip', 'bake', 'party', 'crowd', 'pasta salad', 'potato salad', 'deviled eggs', 'bars'],
  };

  static const mealWords = <String, List<String>>{
    'Breakfast': ['breakfast', 'brunch', 'pancake', 'pancakes', 'waffle', 'waffles', 'omelet', 'omelette', 'granola', 'oatmeal', 'porridge', 'french toast', 'frittata', 'scrambled'],
    'Appetizer': ['appetizer', 'appetiser', 'starter', 'snack', 'dip', 'finger food', 'hors d', 'canape', 'bruschetta', 'wings', 'nachos'],
    'Soup & Salad': ['soup', 'salad', 'stew', 'chowder', 'bisque', 'gazpacho', 'broth', 'chili'],
    'Side Dish': ['side', 'side dish', 'sides', 'slaw', 'coleslaw', 'mashed', 'pilaf', 'roasted vegetables'],
    'Bread': ['bread', 'loaf', 'rolls', 'biscuit', 'biscuits', 'muffin', 'muffins', 'naan', 'flatbread', 'focaccia', 'bagel', 'scone', 'scones', 'cornbread', 'tortillas'],
    'Dessert': ['dessert', 'cake', 'cookie', 'cookies', 'pie', 'tart', 'pudding', 'brownie', 'brownies', 'ice cream', 'candy', 'fudge', 'cheesecake', 'cobbler', 'crisp', 'custard', 'sweet'],
    'Beverage': ['beverage', 'drink', 'drinks', 'smoothie', 'lemonade', 'tea', 'coffee', 'cocktail', 'punch', 'shake', 'cider', 'lassi', 'eggnog', 'hot chocolate'],
    'Entree': ['main', 'main course', 'main dish', 'entree', 'entrée', 'dinner', 'lunch'],
  };

  static const seasonWords = <String, List<String>>{
    'Spring': ['spring', 'asparagus', 'rhubarb', 'peas', 'strawberry', 'strawberries', 'easter', 'lamb'],
    'Summer': ['summer', 'grilled', 'bbq', 'barbecue', 'zucchini', 'tomato salad', 'corn on the cob', 'peach', 'peaches', 'watermelon', 'berries', 'lemonade', 'ice cream', 'gazpacho', 'popsicle'],
    'Fall': ['fall', 'autumn', 'pumpkin', 'apple', 'apples', 'squash', 'sweet potato', 'cranberry', 'pecan', 'cider', 'thanksgiving'],
    'Winter': ['winter', 'stew', 'chili', 'soup', 'roast', 'braised', 'hot chocolate', 'gingerbread', 'eggnog', 'christmas', 'pot roast'],
  };

  static const holidayWords = <String, List<String>>{
    "New Year's": ['new year', 'black-eyed peas', 'hoppin john'],
    'Lunar New Year': ['lunar new year', 'chinese new year', 'dumplings', 'spring rolls', 'nian gao'],
    "Valentine's Day": ['valentine', 'chocolate-covered', 'red velvet'],
    "St. Patrick's Day": ['st. patrick', 'corned beef', 'soda bread', 'colcannon', 'irish stew', 'guinness'],
    'Easter': ['easter', 'hot cross', 'deviled eggs', 'glazed ham'],
    'Passover': ['passover', 'matzo', 'matzah', 'charoset', 'haroset'],
    'Cinco de Mayo': ['cinco de mayo', 'margarita', 'guacamole', 'tacos', 'enchiladas'],
    'Fourth of July': ['fourth of july', '4th of july', 'independence day', 'hot dog', 'hamburger', 'burgers', 'potato salad', 'apple pie'],
    'Oktoberfest': ['oktoberfest', 'bratwurst', 'pretzel', 'sauerkraut', 'schnitzel', 'beer'],
    'Halloween': ['halloween', 'pumpkin', 'candy apple', 'caramel apple'],
    'Diwali': ['diwali', 'ladoo', 'laddu', 'barfi', 'burfi', 'gulab jamun', 'halwa', 'jalebi', 'kheer'],
    'Thanksgiving': ['thanksgiving', 'turkey', 'stuffing', 'cranberry', 'pumpkin pie', 'green bean casserole', 'sweet potato'],
    'Hanukkah': ['hanukkah', 'chanukah', 'latkes', 'latke', 'sufganiyot', 'brisket'],
    'Christmas': ['christmas', 'gingerbread', 'eggnog', 'fruitcake', 'stollen', 'yule', 'sugar cookies', 'mince pie', 'figgy'],
    'Game Day': ['game day', 'super bowl', 'wings', 'nachos', 'sliders', 'chili', 'dip', 'jalapeño poppers'],
  };

  static void tag(Recipe r, {List<String> extraCuisines = const [], List<String> extraCategories = const []}) {
    final titleKw = [r.title, ...r.keywords, ...extraCuisines, ...extraCategories].join(' ').toLowerCase();
    final all = '$titleKw ${r.ingredients.join(' ').toLowerCase()} ${r.steps.map((s) => s.text).join(' ').toLowerCase()}';

    void addAll(List<String> target, Map<String, List<String>> words, String hay) {
      for (final e in words.entries) {
        if (!target.contains(e.key) && _has(hay, e.value)) target.add(e.key);
      }
    }

    addAll(r.cuisines, cuisineWords, titleKw);
    if (_has(all, cuisineWords['Slow Cooker']!) && !r.cuisines.contains('Slow Cooker')) r.cuisines.add('Slow Cooker');
    addAll(r.mealTypes, mealWords, titleKw);
    if (r.mealTypes.isEmpty) r.mealTypes.add('Entree');
    addAll(r.seasons, seasonWords, titleKw);
    addAll(r.holidays, holidayWords, titleKw);
  }
}

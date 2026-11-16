import json, re, collections

CUISINE_CATS = {
    'American': ['United States recipes', 'American recipes', 'Southern U.S. recipes', 'Tex-Mex recipes', 'Cajun recipes',
                 'Creole recipes', 'Soul food recipes', 'New England recipes', 'Pennsylvania Dutch recipes',
                 'Hawaiian recipes', 'Southwestern recipes', 'Appalachian recipes', 'Midwestern recipes',
                 'Californian recipes', 'Louisiana recipes', 'New York recipes', 'Amish recipes'],
    'Mexican': ['Mexican recipes', 'Oaxacan recipes', 'Yucatecan recipes'],
    'Japanese': ['Japanese recipes', 'Okinawan recipes'],
    'Chinese': ['Chinese recipes', 'Cantonese recipes', 'Sichuan recipes', 'Szechuan recipes', 'Hong Kong recipes',
                'Hunan recipes', 'Shanghainese recipes', 'Hakka recipes', 'Fujian recipes', 'Chinese-American recipes',
                'Beijing recipes', 'Teochew recipes'],
    'British': ['English recipes', 'British recipes', 'Scottish recipes', 'Welsh recipes', 'United Kingdom recipes',
                'Cornish recipes', 'Northern Irish recipes', 'Yorkshire recipes'],
    'Irish': ['Irish recipes'],
    'German': ['German recipes', 'Bavarian recipes', 'Swabian recipes', 'Franconian recipes', 'Saxon recipes'],
    'Indian': ['Indian recipes', 'Bengali recipes', 'Punjabi recipes', 'Gujarati recipes', 'South Indian recipes',
               'Kerala recipes', 'Keralite recipes', 'Tamil recipes', 'Goan recipes', 'Hyderabadi recipes',
               'Kashmiri recipes', 'Maharashtrian recipes', 'Rajasthani recipes', 'Mughlai recipes', 'Parsi recipes',
               'Udupi recipes', 'Chettinad recipes', 'Konkani recipes', 'Mangalorean recipes', 'Andhra recipes',
               'Karnataka recipes', 'Odia recipes', 'Malayali recipes', 'North Indian recipes', 'Sindhi recipes',
               'Assamese recipes', 'Bihari recipes', 'Kannada recipes', 'Telugu recipes', 'Anglo-Indian recipes'],
    'Native American': ['Native American recipes', 'Cherokee recipes', 'Navajo recipes', 'Indigenous American recipes',
                        'First Nations recipes', 'Ojibwe recipes', 'Hopi recipes', 'Iroquois recipes'],
    'BBQ': ['Barbecue recipes', 'Smoked recipes', 'Recipes for barbecue sauce', 'Grilled recipes'],
    'Slow Cooker': ['Slow cooker recipes', 'Crock pot recipes'],
}
CUISINE_LINKS = {
    'American': ['Cuisine of the United States', 'Cuisine of the Southern United States', 'Cajun cuisine', 'Tex-Mex cuisine',
                 'Soul food', 'Cuisine of New England', 'Pennsylvania Dutch cuisine', 'Cuisine of Hawaii'],
    'Mexican': ['Cuisine of Mexico'],
    'Japanese': ['Cuisine of Japan'],
    'Chinese': ['Cuisine of China'],
    'British': ['Cuisine of the United Kingdom', 'Cuisine of Scotland', 'Cuisine of Wales', 'Cuisine of England'],
    'Irish': ['Cuisine of Ireland'],
    'German': ['Cuisine of Germany', 'Cuisine of Bavaria'],
    'Indian': ['Cuisine of India', 'Cuisine of Punjab', 'Cuisine of Bengal', 'Cuisine of Kerala', 'Cuisine of Gujarat',
               'Cuisine of Tamil Nadu'],
    'Native American': ['Native American cuisine'],
    'BBQ': ['Barbecue', 'Grilling', 'Smoking'],
    'Slow Cooker': ['Slow Cooker', 'Slow cooker', 'Crock pot'],
}
TITLE_KW = {
    'Mexican': r'\b(taco|tacos|enchiladas?|tamales?|quesadillas?|burritos?|pozole|mole|guacamole|salsa|chilaquiles|churros|horchata|tortillas?|carnitas|fajitas?|elote|sopapillas?|flan|menudo|tostadas?|chiles? rellenos?|pico de gallo|mexican)\b',
    'Japanese': r'\b(sushi|miso|teriyaki|ramen|tempura|udon|soba|katsu|onigiri|mochi|dashi|yakitori|gyoza|matcha|tonkatsu|okonomiyaki|sukiyaki|tamagoyaki|donburi|oyakodon|japanese|wasabi|edamame|nikujaga|karaage|takoyaki|shabu)\b',
    'Chinese': r'\b(chinese|szechuan|sichuan|cantonese|wonton|chow mein|lo mein|kung pao|bok choy|hoisin|dim sum|mapo|char siu|congee|egg foo young|sweet and sour|moo shu|general tso|dan dan|bao|jiaozi|zongzi|mooncake|hot and sour)\b',
    'British': r'\b(scones?|shepherd|yorkshire|trifle|crumpets?|bangers|toad in the hole|cornish|sticky toffee|shortbread|haggis|welsh|scotch|bubble and squeak|spotted dick|eton mess|bakewell|victoria sponge|cottage pie|ploughman|english|british|treacle|kedgeree|pasties|parkin|flapjacks?|cock-a-leekie|cullen skink|bara brith)\b',
    'Irish': r'\b(irish|colcannon|boxty|soda bread|guinness|coddle|champ|barmbrack|brack)\b',
    'German': r'\b(german|bavarian|schnitzel|sauerkraut|bratwurst|sp[äa]etzle|strudel|pretzels?|brezel|sauerbraten|kuchen|stollen|lebkuchen|rouladen|black forest|kartoffel|spätzle|knödel|kn[oö]del|pfeffern[uü]sse|bienenstich|currywurst|maultaschen|schwarzw[aä]lder|apfel|berliner)\b',
    'Indian': r'\b(indian|curry|masala|tikka|dal|dhal|daal|paneer|biryani|naan|chapati|samosas?|tandoori|korma|vindaloo|chutney|raita|pakoras?|lassi|chana|aloo|gobi|roti|dosa|idli|sambar|rasam|halwa|kheer|ladoo|laddu|jalebi|gulab|pulao|paratha|puri|bhaji|keema|saag|palak|rajma|upma|poha|khichdi|kulfi|barfi|burfi)\b',
    'Native American': r'\b(native american|fry ?bread|wild rice|succotash|pemmican|three sisters|hominy|bannock|wojapi|cherokee|navajo|ojibwe|acorn)\b',
    'BBQ': r'\b(bbq|barbecued?|barbeque|grilled|smoked|brisket|pulled pork|spare ?ribs|ribs|burnt ends|kebabs?|kabobs?|on the grill|grilling|dry rub|rub)\b',
    'Slow Cooker': r'\b(slow[- ]cooker|crock[- ]?pot)\b',
}
POTLUCK_KW = r'\b(casserole|dip|deviled eggs?|potato salad|pasta salad|macaroni salad|coleslaw|cole slaw|baked beans|mac(aroni)? (and|&) cheese|meatballs|brownies?|bars|sheet cake|cornbread|chili|lasagna|lasagne|jell-?o|ambrosia|seven layer|7-layer|cookies|pigs in a blanket|sloppy joes?|cobbler|banana bread|punch|cheese ball|bean salad|three bean|tater tots?|hotdish|stuffed eggs|layer salad|green bean|scalloped|pinwheels|party mix|snack mix|sausage balls|spinach dip|queso|enchilada casserole|bread pudding|pound cake|crisp|slaw|cupcakes?|muffins?|devilled)\b'

MEAL_CATS = {
    'Breakfast': ['Breakfast recipes', 'Recipes for pancakes', 'Recipes for omelettes', 'Recipes for waffles',
                  'Recipes for porridge', 'Recipes for granola', 'Brunch recipes', 'Recipes for crepes'],
    'Appetizer': ['Appetizer recipes', 'Snack recipes', 'Recipes for dip', 'Recipes for appetizers', 'Hors d\'oeuvre recipes',
                  'Recipes for snacks', 'Recipes for fritters', 'Finger food recipes', 'Recipes for salsa'],
    'Entree': ['Main course recipes', 'Recipes for curry', 'Recipes for stew', 'Recipes for casserole',
               'Recipes for sandwiches', 'Recipes for hamburgers', 'Recipes for chili', 'Recipes for pizza',
               'Recipes for pasta', 'Recipes for pot pie', 'Recipes for meatloaf', 'Recipes for tacos',
               'Recipes for dumplings', 'Recipes for stir fry', 'Recipes for noodles', 'Recipes for macaroni and cheese'],
    'Side Dish': ['Side dish recipes', 'Recipes for stuffing and dressing', 'Recipes for rice', 'Vegetable recipes',
                  'Recipes for potato salad'],
    'Soup & Salad': ['Recipes for soup', 'Recipes for salad', 'Recipes for potato salad', 'Recipes for stew',
                     'Recipes for chowder', 'Recipes for salad dressing'],
    'Bread': ['Recipes for bread', 'Recipes for flatbread', 'Recipes for muffins', 'Recipes for banana bread',
              'Recipes for biscuits', 'Recipes for rolls', 'Recipes for scones', 'Bread recipes', 'Recipes for quick bread',
              'Recipes for yeast bread', 'Recipes for buns', 'Recipes for bagels', 'Recipes for cornbread'],
    'Dessert': ['Recipes for dessert', 'Recipes for cake', 'Recipes for cookies', 'Recipes for pudding',
                'Recipes for pies and tarts', 'Recipes for confections', 'Recipes for brownies', 'Recipes for custard',
                'Recipes for pastries', 'Recipes for ice cream', 'Recipes for fudge', 'Recipes for candy',
                'Recipes for cobbler', 'Recipes for cheesecake', 'Recipes for meringue', 'Recipes for mousse',
                'Recipes for caramel', 'Recipes for apple pie', 'Recipes for banana cream pie', 'Recipes for bars',
                'Recipes for doughnuts', 'Recipes for frosting and icing'],
    'Beverage': ['Recipes for beverages', 'Recipes for smoothies', 'Recipes for tea and tisanes', 'Recipes for soda pop',
                 'Recipes for lemonade', 'Recipes for alcoholic beverages', 'Recipes for cocktails', 'Recipes for coffee',
                 'Recipes for plant milk', 'Recipes for milkshakes', 'Recipes for punch', 'Recipes for hot chocolate',
                 'Recipes for lassi', 'Recipes for juice'],
}
SUMMARY_MEAL = {
    'Breakfast': ['breakfast', 'pancake', 'egg recipes', 'porridge', 'waffle'],
    'Appetizer': ['appetizer', 'snack', 'dip', 'fritter', 'finger'],
    'Entree': ['main course', 'meat', 'chicken', 'beef', 'pork', 'lamb', 'fish', 'seafood', 'curry', 'pasta', 'casserole',
               'sandwich', 'hamburger', 'duck', 'shrimp', 'salmon', 'pizza', 'noodle', 'stew', 'turkey', 'poultry',
               'dumpling', 'tofu', 'sausage', 'goat', 'mutton', 'venison', 'game'],
    'Side Dish': ['side dish', 'vegetable', 'rice', 'potato', 'bean', 'stuffing', 'pickle', 'corn', 'eggplant', 'legume',
                  'lentil', 'mushroom', 'greens', 'cabbage'],
    'Soup & Salad': ['soup', 'salad', 'stew', 'chowder'],
    'Bread': ['bread', 'flatbread', 'muffin', 'biscuit', 'roll', 'scone', 'bun', 'dough'],
    'Dessert': ['dessert', 'cake', 'cookie', 'pudding', 'pie', 'confection', 'pastr', 'custard', 'candy', 'frosting',
                'ice cream', 'sweet', 'brownie', 'fudge', 'chocolate'],
    'Beverage': ['beverage', 'drink', 'smoothie', 'tea', 'coffee', 'cocktail', 'punch', 'juice', 'lassi'],
}
TITLE_MEAL = {
    'Breakfast': r'\b(breakfast|pancakes?|waffles?|omelets?|omelettes?|granola|oatmeal|porridge|french toast|frittata|scrambled|hash browns?|eggs benedict|crepes?|grits)\b',
    'Appetizer': r'\b(appetizers?|dip|salsa|guacamole|hummus|nachos|wings|bruschetta|deviled|crostini|canap[eé]s?|spring rolls?|egg rolls?|samosas?|pakoras?|fritters?|tapas|poppers|chips|cheese ball|edamame|gyoza|wontons?)\b',
    'Soup & Salad': r'\b(soup|salad|chowder|bisque|gazpacho|broth|stew|slaw|coleslaw|ramen|pho|minestrone)\b',
    'Side Dish': r'\b(mashed|roasted (potatoes|vegetables|carrots)|pilaf|fried rice|rice|beans|greens|coleslaw|stuffing|dressing|gratin|scalloped|succotash|colcannon|champ|boxty|sauerkraut|spaetzle|spätzle|raita|chutney|dal|dhal|aloo|gobi|corn on the cob|potatoes|fries)\b',
    'Bread': r'\b(bread|loaf|rolls?|biscuits?|muffins?|naan|chapati|roti|paratha|puri|flatbread|focaccia|bagels?|scones?|cornbread|tortillas?|pretzels?|buns?|brioche|soda bread|bannock|fry ?bread|barmbrack)\b',
    'Dessert': r'\b(desserts?|cakes?|cookies?|pies?|tarts?|puddings?|brownies?|ice cream|candy|fudge|cheesecake|cobbler|crisp|custard|mousse|trifle|shortbread|flan|churros|mochi|kheer|halwa|ladoo|laddu|jalebi|kulfi|barfi|burfi|strudel|kuchen|stollen|lebkuchen|meringues?|truffles?|macaroons?|gingerbread|sorbet|crumble|toffee|caramel)\b',
    'Beverage': r'\b(beverages?|drinks?|smoothies?|lemonade|tea|coffee|cocktails?|punch|shakes?|cider|lassi|eggnog|hot chocolate|cocoa|horchata|juice|milk|sangria|toddy|wassail|chai|soda|latte|limeade|agua fresca)\b',
}

SEASON_KW = {
    'Spring': r'\b(spring|asparagus|rhubarb|peas|strawberr(y|ies)|easter|lamb|radish|artichoke|hot cross)\b',
    'Summer': r'\b(summer|grilled|bbq|barbecue|zucchini|corn on the cob|peach(es)?|watermelon|berr(y|ies)|lemonade|ice cream|gazpacho|popsicles?|salsa|tomato salad|cucumber|potato salad|coleslaw|iced|smoothies?|sorbet|limeade|agua fresca|kebabs?)\b',
    'Fall': r'\b(fall|autumn|pumpkin|apples?|squash|sweet potato(es)?|cranberr(y|ies)|pecan|cider|thanksgiving|butternut|pear|maple|harvest|stuffing)\b',
    'Winter': r'\b(winter|stew|chili|soup|roast|braised|hot chocolate|cocoa|gingerbread|eggnog|christmas|pot roast|chowder|casserole|mulled|wassail|stollen|toddy|pot pie|dumplings?|cassoulet|goulash)\b',
}
HOLIDAY_KW = {
    "New Year's": r'\b(new year|black[- ]eyed peas|hoppin.? john|champagne)\b',
    'Lunar New Year': r'\b(lunar new year|chinese new year|jiaozi|nian gao|spring rolls?|dumplings|longevity noodles|tangyuan)\b',
    "Valentine's Day": r'\b(valentine|chocolate[- ]covered|red velvet|truffles?|chocolate mousse)\b',
    "St. Patrick's Day": r'\b(st\.? patrick|corned beef|soda bread|colcannon|irish stew|guinness|boxty|shepherd.?s pie|champ)\b',
    'Easter': r'\b(easter|hot cross|deviled eggs?|glazed ham|lamb|carrot cake|simnel|paska|kulich)\b',
    'Passover': r'\b(passover|matzo|matzah|charoset|haroset|kugel)\b',
    'Cinco de Mayo': r'\b(cinco de mayo|margaritas?|guacamole|tacos?|enchiladas?|churros|salsa|tamales|horchata)\b',
    'Fourth of July': r'\b(fourth of july|4th of july|independence day|hot dogs?|hamburgers?|burgers?|potato salad|apple pie|coleslaw|baked beans|corn on the cob|ribs|barbecue|bbq)\b',
    'Oktoberfest': r'\b(oktoberfest|bratwurst|pretzels?|brezel|sauerkraut|schnitzel|beer|spaetzle|spätzle|obatzda|weisswurst|sauerbraten)\b',
    'Halloween': r'\b(halloween|pumpkin|candy apples?|caramel apples?|popcorn balls?|cider|soul cakes?|barmbrack)\b',
    'Diwali': r'\b(diwali|ladoo|laddu|barfi|burfi|gulab jamun|halwa|jalebi|kheer|samosas?|chakli|kaju katli|rasgulla|mathri)\b',
    'Thanksgiving': r'\b(thanksgiving|turkey|stuffing|dressing|cranberr(y|ies)|pumpkin pie|green bean casserole|sweet potato(es)?|pecan pie|gravy|mashed potatoes|cornbread)\b',
    'Hanukkah': r'\b(hanukkah|chanukah|latkes?|sufganiyot|brisket|rugelach|jelly doughnuts?)\b',
    'Christmas': r'\b(christmas|gingerbread|eggnog|fruitcake|stollen|yule|sugar cookies|mince pies?|figgy|lebkuchen|wassail|panettone|bûche|shortbread|roast goose|plum pudding|peppermint|spritz)\b',
    'Game Day': r'\b(game day|super bowl|wings|nachos|sliders|chili|dip|poppers|queso|buffalo|pigs in a blanket|sloppy joes?|pizza|party mix)\b',
}
HOLIDAY_CATS = {'Christmas recipes': 'Christmas', 'Easter recipes': 'Easter', 'Kosher for Passover recipes': 'Passover',
                'Thanksgiving recipes': 'Thanksgiving', 'Halloween recipes': 'Halloween', 'Hanukkah recipes': 'Hanukkah',
                'Diwali recipes': 'Diwali', 'Chinese New Year recipes': 'Lunar New Year', 'Passover recipes': 'Passover'}


def classify(r, link_index):
    t = r['title'].lower()
    cats = set(r['cats'])
    cuisines = set()
    for c, cl in CUISINE_CATS.items():
        if cats & set(cl):
            cuisines.add(c)
    for c, ll in CUISINE_LINKS.items():
        if set(r['cuisine_links']) & set(ll):
            cuisines.add(c)
    for c, pat in TITLE_KW.items():
        if c in ('BBQ', 'Slow Cooker'):
            continue
        if re.search(pat, t) and c not in ('Indian',):
            cuisines.add(c)
    body = (' '.join(r['ingredients']) + ' ' + ' '.join(r['steps'])).lower()
    if re.search(TITLE_KW['Slow Cooker'], t + ' ' + body):
        cuisines.add('Slow Cooker')
    if re.search(TITLE_KW['BBQ'], t) and not re.search(r'\b(rubs? for|sauce)\b', t):
        cuisines.add('BBQ')
    # meal types
    meals = set()
    for m, cl in MEAL_CATS.items():
        if cats & set(cl):
            meals.add(m)
    sc = r['summary_category'].lower()
    for m, kws in SUMMARY_MEAL.items():
        if any(k in sc for k in kws):
            meals.add(m)
    for m, pat in TITLE_MEAL.items():
        if re.search(pat, t):
            meals.add(m)
    # A dessert pie isn't an entree; resolve a few conflicts
    if 'Dessert' in meals and re.search(r'\b(pot pie|meat pie|shepherd|cottage pie|pork pie|pasty)\b', t):
        meals.discard('Dessert'); meals.add('Entree')
    if 'Beverage' in meals and not re.search(TITLE_MEAL['Beverage'], t) and 'beverage' not in sc and not (cats & set(MEAL_CATS['Beverage'])):
        meals.discard('Beverage')
    if re.search(r'\b(sauce|gravy|dressing|marinade|rub|spice mix|seasoning|stock|paste|chutney|pickle|relish|jam|jelly|frosting|icing|syrup|condiment|ketchup|mayonnaise|vinaigrette|masala powder|garam masala|ghee|butter)\b', t) and not meals:
        meals.add('Side Dish')
    if not meals:
        meals.add('Entree' if re.search(r'\b(chicken|beef|pork|lamb|fish|shrimp|turkey|duck|salmon|tofu|sausage|steak)\b', t) else 'Side Dish')
    seasons = {s for s, pat in SEASON_KW.items() if re.search(pat, t)}
    holidays = {h for h, pat in HOLIDAY_KW.items() if re.search(pat, t)}
    for c, h in HOLIDAY_CATS.items():
        if c in cats:
            holidays.add(h)
    if not seasons:
        # year-round dishes: infer gently from type
        if meals & {'Soup & Salad'} and re.search(r'soup|stew|chowder', t):
            seasons.add('Winter')
    potluck_score = len(re.findall(POTLUCK_KW, t))
    return sorted(cuisines), sorted(meals), sorted(seasons), sorted(holidays), potluck_score


if __name__ == '__main__':
    parsed = json.load(open('parsed.json'))
    try:
        links = json.load(open('cuisine_links.json'))
    except Exception:
        links = {}
    cnt = collections.Counter()
    cnt_img = collections.Counter()
    pot = 0
    for r in parsed:
        if len(r['ingredients']) < 2 or len(r['steps']) < 2:
            continue
        c, m, s, h, p = classify(r, links)
        for x in c:
            cnt[x] += 1
            if r['image']:
                cnt_img[x] += 1
        if p:
            pot += 1
    for k in CUISINE_CATS:
        print(k, cnt[k], 'with image', cnt_img[k])
    print('potluck candidates', pot)

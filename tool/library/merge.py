import json, re, glob, unicodedata
from classify import classify, SEASON_KW, HOLIDAY_KW

data = json.load(open('classified.json'))
MEALS = ['Breakfast', 'Appetizer', 'Entree', 'Side Dish', 'Soup & Salad', 'Bread', 'Dessert', 'Beverage']


def slug(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode()
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')[:60]


def est_cook(steps):
    total = 0
    for s in steps:
        for m in re.finditer(r'(\d+)(?:\s*(?:-|–|to)\s*(\d+))?\s*(hours?|hrs?|minutes?|mins?)\b', s.lower()):
            a = int(m.group(1)); b = int(m.group(2) or a)
            v = (a + b) / 2
            if m.group(3).startswith('h'):
                v *= 60
            if v <= 24 * 60:
                total += v
    return int(round(total / 5.0) * 5)


def est_prep(ingredients):
    n = len([i for i in ingredients if not i.startswith('#')])
    return int(min(45, max(5, round((5 + n * 1.5) / 5) * 5)))


recipes = {}
for f in sorted(glob.glob('curated/*.json')) + sorted(glob.glob('curated_extra/*.json')):
    cur = json.load(open(f))
    cuisine = cur['cuisine'] if 'cuisine' in cur else f.split('/')[-1][:-5].replace('_', ' ')
    for s in cur['selected']:
        p = s['page']
        r = data[p]
        rid = 'lib-wb-' + slug(r['title'])
        e = recipes.get(rid)
        if not e:
            notes = r['notes']
            prep, cook = r['prep'], r['cook']
            estimated = False
            if not prep and not cook:
                cook = est_cook(r['steps'])
                prep = est_prep(r['ingredients'])
                estimated = True
            elif not prep:
                prep = est_prep(r['ingredients'])
                estimated = True
            servings = r['servings']
            serv_est = False
            if not servings:
                servings = 4
                serv_est = True
            extra = []
            if estimated:
                extra.append('Prep/cook times are estimates.')
            if serv_est:
                extra.append('Number of servings is an estimate.')
            if extra:
                notes = (notes + ' ' if notes else '') + '(' + ' '.join(extra) + ')'
            e = recipes[rid] = {
                'id': rid,
                'title': r['title'],
                'description': r['description'],
                'author': 'Wikibooks Cookbook contributors',
                'source': 'Wikibooks Cookbook',
                'sourceUrl': r['url'],
                'license': 'Text from the Wikibooks Cookbook (en.wikibooks.org) by its contributors, licensed CC BY-SA 4.0. Reformatted for this app.',
                'servings': servings,
                'yieldText': r['yield'],
                'prepMinutes': prep,
                'cookMinutes': cook,
                'ingredients': r['ingredients'],
                'steps': [{'text': t} for t in r['steps']],
                'notes': notes,
                'cuisines': [], 'mealTypes': [], 'seasons': [], 'holidays': [], 'keywords': [],
                '_image': r['image'],
                '_query': r['title'],
            }
            # heuristic seasons/holidays from title
            t = r['title'].lower()
            e['seasons'] = [k for k, pat in SEASON_KW.items() if re.search(pat, t)]
            e['holidays'] = [k for k, pat in HOLIDAY_KW.items() if re.search(pat, t)]
        if cuisine not in e['cuisines']:
            e['cuisines'].append(cuisine)
        for k in ('mealTypes', 'seasons', 'holidays', 'keywords'):
            for v in s.get(k, []):
                if v not in e[k]:
                    e[k].append(v)
    for o in cur.get('original', []):
        rid = 'lib-rb-' + slug(o['title'])
        e = recipes.get(rid)
        if not e:
            e = recipes[rid] = {
                'id': rid,
                'title': o['title'],
                'description': o.get('description', ''),
                'author': 'Recipe Box Kitchen',
                'source': 'Recipe Box original recipe',
                'sourceUrl': '',
                'license': 'Original recipe written for Recipe Box. Free to share.',
                'servings': o.get('servings') or 4,
                'yieldText': '',
                'prepMinutes': o.get('prepMinutes') or 0,
                'cookMinutes': o.get('cookMinutes') or 0,
                'ingredients': o['ingredients'],
                'steps': [{'text': t} for t in o['steps']],
                'notes': o.get('notes', ''),
                'cuisines': [], 'mealTypes': [], 'seasons': [], 'holidays': [], 'keywords': [],
                '_image': None,
                '_query': o.get('photoQuery') or o['title'],
            }
        if cuisine and cuisine not in e['cuisines']:
            e['cuisines'].append(cuisine)
        for k in ('mealTypes', 'seasons', 'holidays', 'keywords'):
            for v in o.get(k, []):
                if v not in e[k]:
                    e[k].append(v)

VAL = re.compile(r'\b(chocolate|strawberr|red velvet|truffle|raspberr|heart|fondue|tiramisu)', re.I)
SPR = re.compile(r'\b(asparagus|rhubarb|peas?|lamb|strawberr|radish|artichoke|spring|lemon|leek|herb|hot cross|easter|mint)', re.I)
for e in recipes.values():
    if VAL.search(e['title']) and 'Dessert' in e['mealTypes'] and "Valentine's Day" not in e['holidays']:
        e['holidays'].append("Valentine's Day")
    if SPR.search(e['title']) and 'Spring' not in e['seasons']:
        e['seasons'].append('Spring')
for e in recipes.values():
    e['mealTypes'] = [m for m in MEALS if m in e['mealTypes']] or ['Entree']

json.dump(list(recipes.values()), open('merged.json', 'w'), indent=1)
import collections
c = collections.Counter(x for e in recipes.values() for x in e['cuisines'])
m = collections.Counter(x for e in recipes.values() for x in e['mealTypes'])
print('unique recipes', len(recipes), 'wb', sum(1 for k in recipes if k.startswith('lib-wb')),
      'with wb image', sum(1 for e in recipes.values() if e['_image']))
print(dict(c)); print(dict(m))

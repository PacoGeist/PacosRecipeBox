import json, os, shutil, re
from PIL import Image

LIB_VERSION = 1
FR = {'½': '1/2', '⅓': '1/3', '⅔': '2/3', '¼': '1/4', '¾': '3/4', '⅕': '1/5', '⅖': '2/5', '⅗': '3/5', '⅘': '4/5',
      '⅙': '1/6', '⅚': '5/6', '⅛': '1/8', '⅜': '3/8', '⅝': '5/8', '⅞': '7/8'}
def asciifrac(t):
    return re.sub('(\\d?)([' + ''.join(FR) + '])', lambda m: (m.group(1) + ' ' if m.group(1) else '') + FR[m.group(2)], t)
merged = json.load(open('merged.json'))
meta = json.load(open('photos_meta_ov.json')) if os.path.exists('photos_meta_ov.json') else {}
meta.update(json.load(open('photos_meta.json')) if os.path.exists('photos_meta.json') else {})
meta.update(json.load(open('photos_meta_wp.json')) if os.path.exists('photos_meta_wp.json') else {})
for k, v in json.load(open('photo_override.json')).items() if os.path.exists('photo_override.json') else []:
    meta[k] = v
reject = set(json.load(open('photo_reject.json'))) if os.path.exists('photo_reject.json') else set()
dst = '/home/claude/recipe_box/assets/photos'
os.makedirs(dst, exist_ok=True)
for f in os.listdir(dst):
    if f.endswith('.jpg'):
        os.remove(os.path.join(dst, f))
out = []
with_photo = 0
for e in merged:
    r = {k: v for k, v in e.items() if not k.startswith('_')}
    r['ingredients'] = [asciifrac(x) for x in r['ingredients']]
    r['steps'] = [{'text': asciifrac(x['text'])} for x in r['steps']]
    r['notes'] = asciifrac(r.get('notes', ''))
    m = meta.get(e['id'])
    src = f"photos/{e['id']}.jpg"
    if m and e['id'] not in reject and os.path.exists(src):
        im = Image.open(src).convert('RGB')
        if im.width > 720:
            im = im.resize((720, int(im.height * 720 / im.width)), Image.LANCZOS)
        if im.height > 720:
            im = im.crop((0, (im.height - 720) // 2, im.width, (im.height - 720) // 2 + 720))
        im.save(f"{dst}/{e['id']}.jpg", 'JPEG', quality=70, optimize=True, progressive=True)
        r['photo'] = f"asset:assets/photos/{e['id']}.jpg"
        r['photoCredit'] = m['credit'] + (f" — {m['page']}" if m.get('page') else '')
        with_photo += 1
    else:
        r['photo'] = None
        r['photoCredit'] = ''
    r['collection'] = 'internet'
    r['builtIn'] = True
    r['favorite'] = False
    r['createdAt'] = 1760000000000
    r['updatedAt'] = 1760000000000
    out.append(r)
out.sort(key=lambda r: r['title'].lower())
json.dump({'version': LIB_VERSION, 'recipes': out}, open('/home/claude/recipe_box/assets/seed/recipes.json', 'w'),
          ensure_ascii=False, separators=(',', ':'))
print('recipes', len(out), 'with photo', with_photo,
      'json KB', os.path.getsize('/home/claude/recipe_box/assets/seed/recipes.json') // 1024,
      'photos MB', sum(os.path.getsize(os.path.join(dst, f)) for f in os.listdir(dst)) // 1048576)

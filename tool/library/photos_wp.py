import json, os, re
from wb import api
from photos import download, credit, ok_license, OUT
merged = json.load(open('merged.json'))
MF = 'photos_meta_wp.json'
meta = json.load(open(MF)) if os.path.exists(MF) else {}
def have():
    s = set(meta)
    for f in ('photos_meta.json', 'photos_meta_ov.json'):
        if os.path.exists(f): s |= set(json.load(open(f)))
    return s
STRIP = r'\b(slow[- ]cooker|crock[- ]?pot|homemade|easy|simple|classic|traditional|basic|best|quick|old[- ]fashioned|style|recipe|I|II|III|IV|my|grandma\'?s)\b'
WPMAP = json.load(open('wp_map.json'))
def names(e):
    t = e['title']; out = []
    if t in WPMAP: return [WPMAP[t]]
    q = e.get('_query') or t
    for x in [q, re.sub(r'\s*\(.*?\)', '', t), *re.findall(r'\((.*?)\)', t)]:
        x = re.sub(STRIP, '', x, flags=re.I); x = re.sub(r'\s+', ' ', x).strip(' -,')
        if x and x not in out and len(x) > 2: out.append(x)
    return out
h = have()
REJ = set(json.load(open('photo_reject.json')))
for k in REJ: meta.pop(k, None)
todo = [e for e in merged if e['id'] not in h or e['id'] in REJ]
print('todo', len(todo), flush=True)
# map candidate title -> recipe ids
cand = {}
for e in todo:
    for n in names(e)[:3]:
        cand.setdefault(n, []).append(e['id'])
titles = list(cand)
found = {}  # recipe id -> file name
for i in range(0, len(titles), 50):
    batch = titles[i:i+50]
    r = api({'action': 'query', 'titles': '|'.join(batch), 'prop': 'pageimages', 'piprop': 'name', 'pilicense': 'free', 'redirects': 1}, host='en.wikipedia.org')
    q = r['query']
    mp = {t: t for t in batch}
    for n in q.get('normalized', []):
        for k, v in list(mp.items()):
            if v == n['from']: mp[k] = n['to']
    for n in q.get('redirects', []):
        for k, v in list(mp.items()):
            if v == n['from']: mp[k] = n['to']
    img = {p['title']: p.get('pageimage') for p in q['pages'] if not p.get('missing')}
    for orig in batch:
        f = img.get(mp[orig])
        if not f: continue
        for rid in cand[orig]:
            if rid not in found: found[rid] = (f, mp[orig])
print('found', len(found), flush=True)
files = list({f for f, _ in found.values()})
infos = {}
for i in range(0, len(files), 40):
    b = files[i:i+40]
    r = api({'action': 'query', 'titles': '|'.join('File:' + x for x in b), 'prop': 'imageinfo', 'iiprop': 'url|size|extmetadata|mime', 'iiurlwidth': 960}, host='commons.wikimedia.org')
    norm = {n['to']: n['from'] for n in r['query'].get('normalized', [])}
    for p in r['query']['pages']:
        if 'imageinfo' in p:
            infos[norm.get(p['title'], p['title'])[5:]] = p['imageinfo'][0]
            infos[p['title'][5:]] = p['imageinfo'][0]
for rid, (f, article) in found.items():
    if rid in have() and rid not in REJ: continue
    ii = infos.get(f) or infos.get(f.replace('_', ' '))
    if not ii or ii.get('mime') not in ('image/jpeg', 'image/png', 'image/webp'): continue
    cr, url, lic = credit(ii, f)
    if not ok_license(lic): continue
    if download(ii.get('thumburl') or ii['url'], f"{OUT}/{rid}.jpg"):
        REJ.discard(rid)
        meta[rid] = {'credit': cr, 'file': f, 'page': url, 'from': 'wikipedia:' + article}
        json.dump(meta, open(MF, 'w'), indent=1)
        print('ok', rid, '<-', article, '|', f[:50], flush=True)
print('done', len(meta))

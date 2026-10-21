"""Find and download one photo per recipe from Wikimedia Commons, with credits."""
import json, re, os, io, sys, time, html, urllib.request
from PIL import Image
from wb import api, UA

OUT = '/home/claude/seed/photos'
os.makedirs(OUT, exist_ok=True)
merged = json.load(open('merged.json'))
meta = json.load(open('photos_meta.json')) if os.path.exists('photos_meta.json') else {}
cands = json.load(open('photo_cands.json')) if os.path.exists('photo_cands.json') else {}

BAD_WORDS = re.compile(r'(logo|map|diagram|drawing|illustration|svg|chart|sign|menu|label|packag|advert|poster|stamp|coat of arms|flag|book|page|scan|manuscript|engraving|painting|portrait|statue|restaurant|building|store|shop|market stall|festival|plant|tree|field|seeds?\b|flower|leaf|leaves|herbarium|botanical|specimen|museum|wikimania|people|man |woman|girl|boy|church|street|station|truck|kiosk)', re.I)


def strip_html(s):
    s = re.sub(r'<[^>]+>', '', s or '')
    return html.unescape(s).strip()


def info_for_files(titles, host='en.wikibooks.org'):
    out = {}
    for i in range(0, len(titles), 40):
        batch = titles[i:i + 40]
        r = api({'action': 'query', 'titles': '|'.join('File:' + t for t in batch), 'prop': 'imageinfo',
                 'iiprop': 'url|size|extmetadata|mime', 'iiurlwidth': 960, 'redirects': 1}, host=host)
        norm = {n['to']: n['from'] for n in r['query'].get('normalized', [])}
        for p in r['query']['pages']:
            if 'imageinfo' not in p:
                continue
            ii = p['imageinfo'][0]
            orig = norm.get(p['title'], p['title'])
            out[orig[5:]] = ii
            out[p['title'][5:]] = ii
    return out


def credit(ii, title):
    md = ii.get('extmetadata', {})
    artist = strip_html(md.get('Artist', {}).get('value', '')) or 'Unknown author'
    artist = re.sub(r'\s+', ' ', artist)[:80]
    lic = md.get('LicenseShortName', {}).get('value', '') or 'see file page'
    return f"{artist} / Wikimedia Commons, {lic}", ii.get('descriptionurl', ''), lic


def ok_license(lic):
    l = (lic or '').lower()
    return not ('nc' in l.split('-') or 'non-commercial' in l or 'nd' in l.split('-') or 'fair use' in l or 'all rights' in l)


def thumb_variants(url):
    u = url.split('?')[0]
    m = re.match(r'(https://upload\.wikimedia\.org/wikipedia/(commons|en)/)(?!thumb/)(\w/\w\w/)([^/]+)$', u)
    if not m:
        return [url]
    base, _, hp, name = m.groups()
    return [f"{base}thumb/{hp}{name}/{w}px-{name}" for w in (960, 500)] + [u]


def download(url, path):
    for v in thumb_variants(url):
        if _download(v, path):
            return True
    return False


def _download(url, path):
    for i in range(3):
        try:
            b = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': UA}), timeout=60).read()
            im = Image.open(io.BytesIO(b))
            im = im.convert('RGB')
            w, h = im.size
            if w > 900:
                im = im.resize((900, int(h * 900 / w)), Image.LANCZOS)
            im.save(path, 'JPEG', quality=74, optimize=True, progressive=True)
            return True
        except Exception as e:
            time.sleep(3 + i * 5)
    return False


def search(query, limit=10):
    r = api({'action': 'query', 'generator': 'search', 'gsrsearch': f'filetype:bitmap {query}', 'gsrnamespace': 6,
             'gsrlimit': limit, 'prop': 'imageinfo', 'iiprop': 'url|size|extmetadata|mime', 'iiurlwidth': 960},
            host='commons.wikimedia.org')
    pages = sorted(r.get('query', {}).get('pages', []), key=lambda p: p.get('index', 99))
    res = []
    for p in pages:
        ii = p['imageinfo'][0]
        t = p['title'][5:]
        lic = ii.get('extmetadata', {}).get('LicenseShortName', {}).get('value', '')
        if ii.get('mime') not in ('image/jpeg', 'image/png', 'image/webp'):
            continue
        if ii['width'] < 500 or ii['height'] < 350:
            continue
        if not ok_license(lic):
            continue
        if BAD_WORDS.search(t):
            continue
        res.append((t, ii))
    return res


STOP = {'the', 'a', 'and', 'with', 'of', 'in', 'style', 'recipe', 'i', 'ii', 'iii', 'homemade', 'easy', 'simple',
        'classic', 'traditional', 'basic', 'best', 'my', 'quick', 'old', 'fashioned', 'american', 'irish', 'german',
        'mexican', 'japanese', 'chinese', 'indian', 'british', 'english', 'slow', 'cooker', 'crock', 'pot'}


def words(s):
    return [w for w in re.findall(r'[a-zà-ÿ]+', s.lower()) if w not in STOP and len(w) > 2]


def score(fname, query):
    fw = set(words(fname))
    qw = words(query)
    if not qw:
        return 0
    hit = sum(1 for w in qw if w in fw or any(f.startswith(w[:5]) for f in fw if len(w) >= 5))
    return hit / len(qw)


def stage_wikibooks():
    need = [e for e in merged if e['_image'] and e['id'] not in meta]
    files = list({e['_image'] for e in need})
    infos = info_for_files(files)
    for e in need:
        ii = infos.get(e['_image']) or infos.get(e['_image'].replace('_', ' '))
        if not ii:
            continue
        cr, url, lic = credit(ii, e['_image'])
        if not ok_license(lic):
            continue
        path = f"{OUT}/{e['id']}.jpg"
        if download(ii.get('thumburl') or ii['url'], path):
            meta[e['id']] = {'credit': cr, 'file': e['_image'], 'page': url, 'from': 'wikibooks'}
            print('wb', e['id'], flush=True)
    json.dump(meta, open('photos_meta.json', 'w'), indent=1)


def stage_search(pick_index=None):
    def taken():
        t = set(meta)
        for f in ('photos_meta_wp.json', 'photos_meta_ov.json'):
            if os.path.exists(f): t |= set(json.load(open(f)))
        return t
    need = [e for e in merged if e['id'] not in taken()]
    for n, e in enumerate(need):
        if e['id'] in taken():
            continue
        q = e['_query']
        q = re.sub(r'\((.*?)\)', r' \1 ', q)
        q = re.sub(r'\b(I|II|III|IV)\b', '', q).strip()
        key = e['id']
        if key not in cands:
            res = search(q + ' food')
            if len(res) < 2:
                res += search(q)
            scored = []
            seen = set()
            for t, ii in res:
                if t in seen:
                    continue
                seen.add(t)
                scored.append((score(t, q), t, ii))
            scored.sort(key=lambda x: -x[0])
            cands[key] = [{'file': t, 'score': s, 'thumb': ii.get('thumburl'), 'credit': credit(ii, t)[0],
                           'page': ii.get('descriptionurl', '')} for s, t, ii in scored[:6]]
            json.dump(cands, open('photo_cands.json', 'w'))
        c = [x for x in cands[key] if x['score'] >= 0.5]
        if not c:
            print('none', key, '|', q, flush=True)
            continue
        best = c[0]
        path = f"{OUT}/{key}.jpg"
        if download(best['thumb'], path):
            meta[key] = {'credit': best['credit'], 'file': best['file'], 'page': best['page'], 'from': 'search'}
            print('ok', key, '<-', best['file'][:70], flush=True)
        if n % 10 == 0:
            json.dump(meta, open('photos_meta.json', 'w'), indent=1)
    json.dump(meta, open('photos_meta.json', 'w'), indent=1)


if __name__ == '__main__':
    if 'wb' in sys.argv:
        stage_wikibooks()
    if 'search' in sys.argv:
        stage_search()
    print('have photos', len(meta), 'of', len(merged))

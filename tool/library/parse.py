"""Parse Wikibooks Cookbook wikitext into structured recipes."""
import json, re, html
import mwparserfromhell as mw

UNITS_TPL = {'F': '°F', 'C': '°C', 'g': 'g', 'kg': 'kg', 'ml': 'ml', 'mL': 'ml', 'l': 'L', 'L': 'L', 'oz': 'oz',
             'lb': 'lb', 'in': 'inch', 'cm': 'cm', 'mm': 'mm', 'cup': 'cup', 'floz': 'fl oz', 'tsp': 'tsp', 'tbsp': 'tbsp'}


def _tpl_text(t):
    name = str(t.name).strip().lower()
    params = [str(p.value).strip() for p in t.params if not p.showkey]
    if name in ('convert', 'cvt'):
        if len(params) >= 2:
            if len(params) >= 4 and params[1] in ('-', 'to', 'and', '–'):
                return f"{params[0]}–{params[2]} {UNITS_TPL.get(params[3], params[3])}"
            return f"{params[0]} {UNITS_TPL.get(params[1], params[1])}".replace(' °', '°')
    if name in ('frac', 'fraction') and params:
        if len(params) == 3:
            return f"{params[0]} {params[1]}/{params[2]}"
        if len(params) == 2:
            return f"{params[0]}/{params[1]}"
        return f"1/{params[0]}"
    if name in ('w', 'wp', 'wikipedia', 'lang', 'nowrap', 'nobr', 'small', 'smaller', 'big'):
        return params[-1] if params else ''
    if name in ('ndash',):
        return '–'
    if name in ('ref', 'cite', 'cite web', 'cite book', 'citation', 'clarify', 'cn', 'citation needed', 'sic', 'reflist'):
        return ''
    return ''


def clean(text):
    if text is None:
        return ''
    text = re.sub(r'<ref[^>]*/>', '', text)
    text = re.sub(r'<ref.*?</ref>', '', text, flags=re.S)
    text = re.sub(r'<!--.*?-->', '', text, flags=re.S)
    text = text.replace('<nowiki/>', '')
    code = mw.parse(text)
    for t in code.filter_templates(recursive=False):
        try:
            code.replace(t, _tpl_text(t))
        except ValueError:
            pass
    for l in code.filter_wikilinks():
        title = str(l.title)
        if title.lower().startswith(('file:', 'image:', 'category:')):
            try:
                code.remove(l)
            except ValueError:
                pass
            continue
        disp = str(l.text) if l.text else title.split(':', 1)[-1].split('#')[0]
        try:
            code.replace(l, disp)
        except ValueError:
            pass
    for l in code.filter_external_links():
        try:
            code.replace(l, str(l.title) if l.title else '')
        except ValueError:
            pass
    s = str(code)
    s = re.sub(r"'''''|'''|''", '', s)
    s = re.sub(r'<br\s*/?>', ' ', s)
    s = re.sub(r'</?[a-zA-Z][^>]*>', '', s)
    s = html.unescape(s)
    s = s.replace(' ', ' ')
    s = re.sub(r'\s+', ' ', s).strip()
    s = re.sub(r'\s+([,.;:!?)])', r'\1', s)
    s = re.sub(r'\(\s+', '(', s)
    return s


ING_HEAD = re.compile(r'^(ingredients?|ingredient list)\b', re.I)
PROC_HEAD = re.compile(r'^(procedure|directions?|method|instructions?|preparation|steps|cooking|assembly)\b', re.I)
NOTES_HEAD = re.compile(r'^(notes|tips|variations|notes, tips)', re.I)


def sections(wikitext):
    """Split into [(level, heading, body)] with level 0 for intro."""
    parts = re.split(r'^(={2,6})\s*(.*?)\s*\1\s*$', wikitext, flags=re.M)
    out = [(0, '', parts[0])]
    for i in range(1, len(parts), 3):
        out.append((len(parts[i]), parts[i + 1], parts[i + 2]))
    return out


def summary_fields(wikitext):
    code = mw.parse(wikitext)
    for t in code.filter_templates(recursive=False):
        n = str(t.name).strip().lower().replace('_', ' ')
        if n in ('recipe summary', 'recipesummary'):
            return {str(p.name).strip().lower(): str(p.value).strip() for p in t.params}
    return {}


def find_image(wikitext, fields):
    for k in ('image', 'picture'):
        v = fields.get(k, '')
        m = re.search(r'(?:File|Image):([^|\]]+)', v, re.I)
        if m:
            return m.group(1).strip()
        if v and re.search(r'\.(jpe?g|png|gif|webp|tiff?)$', v.strip(), re.I):
            return v.strip()
    m = re.search(r'\[\[\s*(?:File|Image)\s*:\s*([^|\]]+)', wikitext, re.I)
    return m.group(1).strip() if m else None


def parse_minutes(s):
    s = clean(s).lower()
    if not s:
        return 0
    total = 0
    found = False
    for m in re.finditer(r'(\d+(?:\.\d+)?)(?:\s*(?:-|–|to)\s*(\d+(?:\.\d+)?))?\s*(days?|d\b|hours?|hrs?|h\b|minutes?|mins?|m\b)', s):
        a = float(m.group(1))
        b = float(m.group(2)) if m.group(2) else a
        v = (a + b) / 2
        u = m.group(3)
        if u.startswith('d'):
            v *= 1440
        elif u.startswith('h'):
            v *= 60
        total += v
        found = True
    return int(round(total)) if found else 0


def parse_time_field(s):
    """Returns (prep, cook) minutes from the 'time' field."""
    if not s:
        return 0, 0
    raw = re.sub(r'<br\s*/?>', '\n', s)
    prep = cook = 0
    labelled = False
    for line in re.split(r'[\n;,]+', raw):
        l = line.lower()
        mins = parse_minutes(line)
        if not mins:
            continue
        if 'prep' in l or 'marinat' in l or 'rest' in l or 'chill' in l or 'soak' in l or 'rise' in l or 'prov' in l:
            prep += mins
            labelled = True
        elif 'total' in l:
            labelled = True
            if cook == 0:
                cook = max(0, mins - prep)
        elif any(w in l for w in ('cook', 'bak', 'roast', 'fry', 'grill', 'simmer', 'boil', 'steam')):
            cook += mins
            labelled = True
        else:
            cook += mins
    return prep, cook


def parse_servings(fields):
    for k in ('servings', 'serves', 'yield', 'portions'):
        v = clean(fields.get(k, ''))
        m = re.search(r'\d+', v)
        if m:
            n = int(m.group(0))
            if 0 < n <= 200:
                return n, v
    return 0, ''


def list_items(body, marker):
    """Return list items (marker '*' or '#') with nesting depth, plus heading lines."""
    items = []
    for line in body.split('\n'):
        st = line.strip()
        if not st:
            continue
        m = re.match(r'^([*#:]+)\s*(.*)$', st)
        if m:
            marks, txt = m.group(1), m.group(2)
            items.append(('item', marks, txt))
        elif re.match(r"^;\s*(.+)$", st):
            items.append(('head', '', st[1:]))
        elif re.match(r"^'''[^']+'''\s*:?\s*$", st) or re.match(r"^'''[^']+:'''\s*$", st):
            items.append(('head', '', st))
        else:
            items.append(('text', '', st))
    return items


def parse_page(title, page):
    wt = page['wikitext']
    if re.match(r'^\s*#redirect', wt, re.I):
        return None
    fields = summary_fields(wt)
    secs = sections(wt)
    ingredients, steps, notes = [], [], []
    intro = ''
    mode = None
    for level, head, body in secs:
        h = clean(head)
        if level == 0:
            intro = body
            continue
        if ING_HEAD.match(h):
            mode = 'ing'
        elif PROC_HEAD.match(h):
            mode = 'proc'
        elif NOTES_HEAD.match(h):
            mode = 'notes'
        elif level >= 3 and mode in ('ing', 'proc'):
            # sub-heading within ingredients/procedure ("For the sauce")
            if mode == 'ing':
                ingredients.append('# ' + h)
            else:
                steps.append({'text': h + ':', 'head': True})
        else:
            mode = None if level == 2 else mode
            if mode is None:
                continue
        for kind, marks, txt in list_items(body, '*'):
            c = clean(txt)
            if not c:
                continue
            if mode == 'ing':
                if kind == 'item':
                    ingredients.append(c)
                elif kind == 'head':
                    ingredients.append('# ' + c.rstrip(':'))
            elif mode == 'proc':
                if kind == 'item':
                    if len(marks) > 1 and steps:
                        steps[-1]['text'] += ' ' + c
                    else:
                        steps.append({'text': c})
                elif kind == 'head':
                    steps.append({'text': c.rstrip(':') + ':', 'head': True})
                elif kind == 'text' and len(c) > 30 and not steps:
                    # paragraph-style directions
                    for sent in [c]:
                        steps.append({'text': sent})
            elif mode == 'notes':
                if kind in ('item', 'text') and len(notes) < 6:
                    notes.append(c)
    # merge "head" pseudo-steps into following step
    merged = []
    pending = ''
    for s in steps:
        if s.get('head'):
            pending = s['text'] + ' '
        else:
            merged.append((pending + s['text']).strip())
            pending = ''
    steps = [s for s in merged if len(s) > 2]
    ingredients = [i for i in ingredients if len(i) > 1]
    # description: first paragraph of intro after removing templates
    desc = ''
    intro = re.sub(r'__\w+__', '', intro)
    intro = re.sub(r'\{\{\s*recipe\s*\}\}[^\n]*', '', intro, flags=re.I)
    for para in re.split(r'\n\s*\n', intro):
        p = para.strip()
        if not p or p.startswith('{{') and p.endswith('}}'):
            continue
        c = clean(p)
        c = re.sub(r'^(\|\s*[^|]*)+', '', c) if c.startswith('|') else c
        if c.startswith('|') or c.count(' | ') >= 2:
            continue
        if len(c) > 40 and not c.lower().startswith(('recipe', '| ')):
            desc = c
            break
    if len(desc) > 420:
        cut = desc[:420]
        desc = cut[:cut.rfind('. ') + 1] if '. ' in cut else cut + '…'
    prep, cook = parse_time_field(fields.get('time', ''))
    servings, yield_text = parse_servings(fields)
    cuisine_links = re.findall(r'\[\[\s*Cookbook:(Cuisine of [^|\]]+|[^|\]]*cuisine[^|\]]*)', wt, re.I)
    return {
        'title': title.split(':', 1)[1].strip(),
        'page': title,
        'url': page.get('url') or 'https://en.wikibooks.org/wiki/' + title.replace(' ', '_'),
        'summary_category': clean(fields.get('category', '')),
        'difficulty': clean(fields.get('difficulty', '')),
        'image': find_image(wt, fields),
        'prep': prep,
        'cook': cook,
        'servings': servings,
        'yield': yield_text,
        'ingredients': ingredients,
        'steps': steps,
        'notes': ' '.join(notes)[:900],
        'description': desc,
        'cats': [c.split(':', 1)[1] for c in page['cats']],
        'cuisine_links': list({c.strip() for c in cuisine_links}),
    }


if __name__ == '__main__':
    pages = json.load(open('pages.json'))
    out = []
    bad = 0
    for t, p in pages.items():
        try:
            r = parse_page(t, p)
        except Exception as e:
            bad += 1
            continue
        if r:
            out.append(r)
    json.dump(out, open('parsed.json', 'w'), indent=0)
    ok = [r for r in out if len(r['ingredients']) >= 2 and len(r['steps']) >= 2]
    print('parsed', len(out), 'errors', bad, 'usable', len(ok), 'with image', sum(1 for r in ok if r['image']))

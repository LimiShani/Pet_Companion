"""Generate Israel's list of localities for the app and the server.

The list is shared: Find a vet uses it to search "near Rehovot" without a
server call, dog parks store the locality code of each park, and meetups
will pick a city and a radius from it.

    python tool/gen_il_localities.py                 # fetch OSM, merge, write
    python tool/gen_il_localities.py --osm FILE      # use a saved Overpass answer
    python tool/gen_il_localities.py --offline       # no OSM: the JSON + EXTRA_ISRAELI_LOCALITIES

Source of truth: tool/data/il_localities.json (committed). Every entry has a
stable code (a lowercase slug), English and Hebrew names, the centre and the
other spellings people type. A run only ADDS places and aliases: codes,
names and coordinates already in the file never change, so a park that
stores a locality code keeps pointing at the same place.

New places come from OpenStreetMap (one Overpass query; data (c)
OpenStreetMap contributors, ODbL): every place=city and place=town inside
OSM's boundary of Israel, and the place=village nodes that are local
councils (LOCAL_COUNCILS below) or have a population tag of 5,000 or more.
Kibbutzim, moshavim and small villages are left out on purpose: their
parks are found by distance from the nearest town.

The Israeli cities and local councils of Judea and Samaria lie outside
OSM's boundary of Israel, so the query above never returns them. They come
from an explicit list instead (EXTRA_ISRAELI_LOCALITIES below, owner
decision 2026-10-11), with the same criterion as the rest: cities and local
councils, no regional councils and no Palestinian localities. The list was
checked on 2026-10-11 against the local authorities of the Judea and
Samaria Area: 4 cities and 14 local councils (Sha'ar Shomron, made from
Sha'arei Tikva and Etz Efraim in 2022, is the newest; Giv'at Ze'ev is on
its way to city status). Their centres are fixed coordinates read from
OSM's place nodes that day (Ma'ale Adumim: its place=town area; Sha'ar
Shomron: halfway between its two villages). They are added on every run,
--offline included, under the same append-only rule: a code already in the
JSON keeps its names and coordinates and only gains missing aliases. Their
JSON entries carry "area": "judea-samaria", and the server's list exports
their codes (IL_JUDEA_SAMARIA_CODES) so the dog parks import searches
around each of them as well as inside OSM's boundary. Each of them reaches
JUDEA_SAMARIA_REACH_M from its centre: the import takes parks that close,
and a point further out is given another locality when one is within
15 km (Pisgat Ze'ev, nearer Ma'ale Adumim's centre than Jerusalem's, stays
in Jerusalem). The app gets it as `reachM` on those entries, the server
as IL_JUDEA_SAMARIA_REACH_M.

Outputs (generated, do not edit by hand):
    lib/services/findvet/regions/il_localities.dart
    supabase/functions/_shared/regions/il_localities.ts
A node test (supabase/functions/_tests/localities.test.ts) checks that the
two files hold the same list.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'tool' / 'data' / 'il_localities.json'
DART_OUT = ROOT / 'lib' / 'services' / 'findvet' / 'regions' / 'il_localities.dart'
TS_OUT = ROOT / 'supabase' / 'functions' / '_shared' / 'regions' / 'il_localities.ts'
LEGACY_DART = ROOT / 'lib' / 'services' / 'findvet' / 'regions' / 'il.dart'

OVERPASS_URL = 'https://overpass-api.de/api/interpreter'
USER_AGENT = 'PetLoopLocalities/1.0 (+https://github.com/LimiShani/Pet_Companion; one-off list of Israeli towns)'
QUERY = (
    '[out:json][timeout:180];'
    'area["ISO3166-1"="IL"][admin_level=2]->.il;'
    'node[place~"^(city|town|village)$"]["name:he"](area.il);'
    'out body;'
)

# Local councils (and a few large Bedouin and Arab towns) that OSM tags as
# villages, by their Hebrew name in OSM.
LOCAL_COUNCILS = {
    # Jewish local councils
    'אזור', 'אליכין', 'בני עי"ש', 'בנימינה', 'גן יבנה', 'גני תקווה', 'יבנאל',
    'יסוד המעלה', 'כפר ורדים', 'כפר יונה', 'כפר שמריהו', 'כפר תבור', 'להבים',
    'מגדל', 'מטולה', 'פרדסיה', 'קדימה', 'קרית יערים', 'קרית עקרון', 'תל מונד',
    'רמת ישי', 'צור הדסה', 'צור יצחק',
    # Arab, Druze and Bedouin local councils
    'אבו גוש', 'אבו סנאן', 'בוקעאתא', 'ביר אל מכסור', "בית ג'ן", 'בסמת טבעון',
    "בעינה נג'ידת", "ג'וליס", "ג'ש", 'ג׳דיידה-מכר', 'ג׳סר א־זרקא', 'ג׳ת',
    'דבוריה', 'דיר חנא', 'דלית אל-כרמל', 'זרזיר', 'חורפיש', 'טובא זנגריה',
    'טורעאן', 'ירכא', 'כאבול', 'כסיפה', 'כפר יאסיף', 'כפר כמא', 'כפר מנדא',
    'כפר ברא', 'לקיה', "מג'ד אל-כרום", "מג'דל שמס", 'מגאר', 'מזרעה', 'מסעדה',
    'מעיליא', 'עין קנייא', 'עיבלין', 'עלוט', 'עספיא', 'ערערה', 'ערערה בנגב',
    'פוריידיס', 'פסוטה', 'פקיעין', 'ראמה', 'ריינה', 'שבלי - אום אל-גנם',
    'שגב שלום', 'שעב', 'כיסרא', 'כפר סומיע', 'סאג׳ור', 'איכסל', "ע'ג'ר",
    'עילבון', "כאוכב אבו אל-היג'א", 'ינוח',
}
MIN_VILLAGE_POPULATION = 5000

# Clearer English than OSM's for a few new places.
EN_OVERRIDES = {
    'Kalanswa': 'Qalansawe',
    'Taibe': 'Tayibe',
    'Tira': 'Tira',
    'Yehud Monosson': 'Yehud-Monosson',
    'Kochav Yair Tzur Yigal': 'Kokhav Yair-Tzur Yigal',
    'Mevaseret Tsiyon': 'Mevaseret Zion',
    'Yoqneam Illit': "Yokne'am Illit",
    'Qiryat Bialik': 'Kiryat Bialik',
    'Barta`a': "Barta'a",
}

SAME_PLACE_M = 300

# The Israeli cities and local councils of Judea and Samaria (see the module
# docstring). Append-only like the JSON: never change a code, name or
# centre here once released; add aliases freely. Centres: OSM place nodes,
# read 2026-10-11 (the OSM id is kept for the record).
JUDEA_SAMARIA = 'judea-samaria'
# Metres from the centre: enough for the largest (Ma'ale Adumim, Ariel:
# about 2.5 km from the centre to the edge), short of the next towns.
JUDEA_SAMARIA_REACH_M = 3500
EXTRA_ISRAELI_LOCALITIES = [
    # Cities
    {'code': 'ariel', 'en': 'Ariel', 'he': 'אריאל', 'lat': 32.1061, 'lng': 35.1851,
     'aliases': [], 'osm': 'node/1695006618'},
    {'code': 'maale-adumim', 'en': "Ma'ale Adumim", 'he': 'מעלה אדומים', 'lat': 31.7706, 'lng': 35.2985,
     'aliases': ['Maale Adumim', "Ma'ale Edomim"], 'osm': 'way/659365950 (place=town area)'},
    {'code': 'modiin-illit', 'en': "Modi'in Illit", 'he': 'מודיעין עילית', 'lat': 31.9324, 'lng': 35.0433,
     'aliases': ['Modiin Illit', 'Modiin Ilit', 'Kiryat Sefer', 'קריית ספר', 'קרית ספר'],
     'osm': 'node/432287759'},
    {'code': 'beitar-illit', 'en': 'Beitar Illit', 'he': 'ביתר עילית', 'lat': 31.6989, 'lng': 35.1137,
     'aliases': ['Betar Illit', 'Beitar Ilit', 'Betar Ilit'], 'osm': 'node/415000885'},
    # Local councils
    {'code': 'alfei-menashe', 'en': 'Alfei Menashe', 'he': 'אלפי מנשה', 'lat': 32.1731, 'lng': 35.0158,
     'aliases': ['Alfe Menashe'], 'osm': 'node/702291529'},
    {'code': 'beit-aryeh-ofarim', 'en': 'Beit Aryeh-Ofarim', 'he': 'בית אריה-עופרים', 'lat': 32.0341, 'lng': 35.0502,
     'aliases': ['Beit Aryeh', 'Bet Arye', 'Bet Arye - Ofarim', 'Ofarim', 'בית אריה', 'עופרים'],
     'osm': 'node/286402706'},
    {'code': 'beit-el', 'en': 'Beit El', 'he': 'בית אל', 'lat': 31.9421, 'lng': 35.2224,
     'aliases': ['Bet El'], 'osm': 'node/353156244'},
    {'code': 'efrat', 'en': 'Efrat', 'he': 'אפרת', 'lat': 31.6536, 'lng': 35.1509,
     'aliases': ['Efrata', 'אפרתה'], 'osm': 'node/431636494'},
    {'code': 'elkana', 'en': 'Elkana', 'he': 'אלקנה', 'lat': 32.1116, 'lng': 35.0355,
     'aliases': [], 'osm': 'node/876967646'},
    {'code': 'givat-zeev', 'en': "Giv'at Ze'ev", 'he': 'גבעת זאב', 'lat': 31.8623, 'lng': 35.1687,
     'aliases': ['Givat Zeev', "Givat Ze'ev"], 'osm': 'node/246843692'},
    {'code': 'har-adar', 'en': 'Har Adar', 'he': 'הר אדר', 'lat': 31.8269, 'lng': 35.1296,
     'aliases': [], 'osm': 'node/222478918'},
    {'code': 'immanuel', 'en': 'Immanuel', 'he': 'עמנואל', 'lat': 32.1619, 'lng': 35.1361,
     'aliases': ['Emanuel', 'Emmanuel'], 'osm': 'node/257450411'},
    {'code': 'karnei-shomron', 'en': 'Karnei Shomron', 'he': 'קרני שומרון', 'lat': 32.171, 'lng': 35.0892,
     'aliases': ['Karne Shomron'], 'osm': 'node/768030451'},
    {'code': 'kedumim', 'en': 'Kedumim', 'he': 'קדומים', 'lat': 32.2177, 'lng': 35.1604,
     'aliases': ['Kdumim'], 'osm': 'node/768024862'},
    {'code': 'kiryat-arba', 'en': 'Kiryat Arba', 'he': 'קריית ארבע', 'lat': 31.5278, 'lng': 35.1192,
     'aliases': ['Qiryat Arba', 'קרית ארבע'], 'osm': 'node/768027338'},
    {'code': 'maale-efraim', 'en': "Ma'ale Efraim", 'he': 'מעלה אפרים', 'lat': 32.0708, 'lng': 35.4034,
     'aliases': ['Maale Efraim', "Ma'ale Ephraim"], 'osm': 'node/354962707'},
    {'code': 'oranit', 'en': 'Oranit', 'he': 'אורנית', 'lat': 32.1309, 'lng': 34.992,
     'aliases': [], 'osm': 'node/699996912'},
    {'code': 'shaar-shomron', 'en': "Sha'ar Shomron", 'he': 'שער שומרון', 'lat': 32.1199, 'lng': 35.0381,
     'aliases': ['Shaar Shomron', "Sha'arei Tikva", 'Shaarei Tikva', 'Etz Efraim', 'Ets Efraim',
                 'שערי תקווה', 'שערי תקוה', 'עץ אפרים'],
     'osm': 'halfway between node/699991141 (Sha\'arei Tikva) and node/699987693 (Etz Efraim)'},
]


def normalize(text: str) -> str:
    """The app's normalizePlaceName, plus the two spellings of Kiryat."""
    text = text.lower()
    text = re.sub(r"[\-–—'’`״׳\".,()־]", ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text.replace('קריית', 'קרית')


def slug(english: str) -> str:
    s = english.lower().replace("'", '').replace('’', '').replace('`', '')
    s = re.sub(r'[^a-z0-9]+', '-', s).strip('-')
    return s


def distance_m(a_lat: float, a_lng: float, b_lat: float, b_lng: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(a_lat), math.radians(b_lat)
    dp = p2 - p1
    dl = math.radians(b_lng - a_lng)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(h)))


def legacy_entries() -> list[dict]:
    """The hand-written list that il.dart held before this generator."""
    text = LEGACY_DART.read_text(encoding='utf-8')
    pattern = re.compile(
        r"_l\(\s*(['\"])(.*?)\1,\s*'(.*?)',\s*([\d.]+),\s*([\d.]+)\s*(?:,\s*\[(.*?)\])?\s*,?\s*\)",
        re.S,
    )
    out = []
    for m in pattern.finditer(text):
        aliases = re.findall(r"(['\"])(.*?)\1", m.group(6) or '')
        out.append({
            'en': m.group(2),
            'he': m.group(3),
            'lat': float(m.group(4)),
            'lng': float(m.group(5)),
            'aliases': [a for _, a in aliases],
        })
    for entry in out:
        entry['code'] = slug(entry['en'])
    return out


def load() -> list[dict]:
    if DATA.exists():
        return json.loads(DATA.read_text(encoding='utf-8'))['localities']
    entries = legacy_entries()
    if not entries:
        sys.exit('No tool/data/il_localities.json and no legacy list in il.dart.')
    return entries


def fetch_osm() -> dict:
    data = urllib.parse.urlencode({'data': QUERY}).encode()
    request = urllib.request.Request(OVERPASS_URL, data=data, headers={'User-Agent': USER_AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return json.loads(response.read().decode('utf-8'))


def wanted(tags: dict) -> bool:
    if not tags.get('name:he') or not tags.get('name:en'):
        return False
    place = tags.get('place')
    if place in ('city', 'town'):
        return True
    if place != 'village':
        return False
    if tags['name:he'] in LOCAL_COUNCILS:
        return True
    population = tags.get('population', '')
    return population.isdigit() and int(population) >= MIN_VILLAGE_POPULATION


def merge(entries: list[dict], osm: dict) -> tuple[int, int]:
    by_name: dict[str, dict] = {}
    for entry in entries:
        for name in [entry['he'], entry['en'], *entry['aliases']]:
            by_name.setdefault(normalize(name), entry)
    codes = {entry['code'] for entry in entries}
    added = aliases = 0
    places = [e for e in osm.get('elements', []) if wanted(e.get('tags', {}))]
    places.sort(key=lambda e: (e['tags'].get('place') != 'city', e['tags']['name:en']))
    for element in places:
        tags = element['tags']
        he, en = tags['name:he'].strip(), tags['name:en'].strip()
        lat, lng = float(element['lat']), float(element['lon'])
        match = (by_name.get(normalize(he)) or by_name.get(normalize(en))
                 or by_name.get(normalize(EN_OVERRIDES.get(en, en))))
        if match is None:
            for entry in entries:
                if distance_m(entry['lat'], entry['lng'], lat, lng) < SAME_PLACE_M:
                    match = entry
                    break
        if match is not None:
            # Same place: remember OSM's spellings as aliases, change nothing else.
            known = {normalize(n) for n in [match['he'], match['en'], *match['aliases']]}
            for name in (en, he):
                if normalize(name) not in known:
                    match['aliases'].append(name)
                    known.add(normalize(name))
                    by_name.setdefault(normalize(name), match)
                    aliases += 1
            continue
        english = EN_OVERRIDES.get(en, en)
        code = slug(english)
        n = 2
        while code in codes:
            code = f'{slug(english)}-{n}'
            n += 1
        codes.add(code)
        entry = {
            'code': code,
            'en': english,
            'he': he,
            'lat': round(lat, 4),
            'lng': round(lng, 4),
            'aliases': [en] if english != en else [],
        }
        entries.append(entry)
        for name in [he, english, en]:
            by_name.setdefault(normalize(name), entry)
        added += 1
    return added, aliases


def add_extras(entries: list[dict]) -> tuple[int, int]:
    """EXTRA_ISRAELI_LOCALITIES into the list: new codes appended, known ones only gain aliases."""
    by_code = {entry['code']: entry for entry in entries}
    added = aliases = 0
    for extra in EXTRA_ISRAELI_LOCALITIES:
        entry = by_code.get(extra['code'])
        if entry is None:
            entry = {
                'code': extra['code'],
                'en': extra['en'],
                'he': extra['he'],
                'lat': extra['lat'],
                'lng': extra['lng'],
                'aliases': list(extra['aliases']),
                'area': JUDEA_SAMARIA,
            }
            entries.append(entry)
            by_code[entry['code']] = entry
            added += 1
            continue
        known = {normalize(n) for n in [entry['he'], entry['en'], *entry['aliases']]}
        for name in extra['aliases']:
            if normalize(name) not in known:
                entry['aliases'].append(name)
                known.add(normalize(name))
                aliases += 1
    return added, aliases


def dart_string(text: str) -> str:
    if "'" in text and '"' not in text:
        return '"' + text.replace('\\', '\\\\').replace('$', '\\$') + '"'
    return "'" + text.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def write_dart(entries: list[dict]) -> None:
    lines = [
        '// Generated by tool/gen_il_localities.py from tool/data/il_localities.json.',
        '// Do not edit by hand: change the JSON (or the generator) and run it again.',
        '//',
        '// Places from OpenStreetMap: (c) OpenStreetMap contributors, ODbL.',
        "import 'region.dart';",
        '',
        "/// Israel's cities, towns and local councils: a stable code (stored by",
        '/// dog parks and meetups), the names, the centre and other spellings.',
        "/// The Israeli towns of Judea and Samaria (outside OpenStreetMap's",
        '/// boundary of Israel, added by the generator) carry a `reachM`.',
        'const israelLocalities = <Locality>[',
    ]
    for e in entries:
        aliases = ', '.join(dart_string(a) for a in e['aliases'])
        lines.append(
            f"  Locality(code: {dart_string(e['code'])}, "
            f"names: {{'en': {dart_string(e['en'])}, 'he': {dart_string(e['he'])}}}, "
            f"point: GeoPoint({e['lat']}, {e['lng']})"
            + (f', reachM: {JUDEA_SAMARIA_REACH_M}' if e.get('area') == JUDEA_SAMARIA else '')
            + (f', aliases: [{aliases}]' if e['aliases'] else '')
            + '),'
        )
    lines += ['];', '']
    DART_OUT.write_text('\n'.join(lines), encoding='utf-8', newline='\n')


def write_ts(entries: list[dict]) -> None:
    lines = [
        '// Generated by tool/gen_il_localities.py from tool/data/il_localities.json.',
        '// Do not edit by hand: change the JSON (or the generator) and run it again.',
        '// The app has the same list in lib/services/findvet/regions/il_localities.dart.',
        '//',
        '// Places from OpenStreetMap: (c) OpenStreetMap contributors, ODbL.',
        '',
        "import type { Locality } from './types.ts';",
        '',
        'export const IL_LOCALITIES: readonly Locality[] = Object.freeze([',
    ]
    for e in entries:
        lines.append('  ' + json.dumps({
            'code': e['code'], 'en': e['en'], 'he': e['he'],
            'lat': e['lat'], 'lng': e['lng'], 'aliases': e['aliases'],
        }, ensure_ascii=False) + ',')
    lines += [']);', '']
    codes = [e['code'] for e in entries if e.get('area') == JUDEA_SAMARIA]
    lines += [
        '/**',
        ' * The Israeli cities and local councils of Judea and Samaria (in the list',
        " * above). They lie outside OpenStreetMap's boundary of Israel, so the dog",
        ' * parks import also searches around each of them.',
        ' */',
        'export const IL_JUDEA_SAMARIA_CODES: readonly string[] = Object.freeze([',
    ]
    lines += [f'  {json.dumps(code)},' for code in codes]
    lines += [']);', '']
    lines += [
        '/**',
        ' * How far from its centre each of them reaches, in metres: the parks import',
        ' * takes the parks that close, and a point further out is given another',
        " * locality when one is in range (the app's entries say `reachM`).",
        ' */',
        f'export const IL_JUDEA_SAMARIA_REACH_M = {JUDEA_SAMARIA_REACH_M};',
        '',
    ]
    TS_OUT.write_text('\n'.join(lines), encoding='utf-8', newline='\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--osm', type=Path, help='a saved Overpass JSON answer to the query above')
    parser.add_argument('--offline', action='store_true', help='only rewrite the outputs from the JSON')
    args = parser.parse_args()

    entries = load()
    added, aliases = add_extras(entries)
    print(f'Judea and Samaria (explicit list): {added} new localities, {aliases} new aliases.')
    if not args.offline:
        osm = json.loads(args.osm.read_text(encoding='utf-8')) if args.osm else fetch_osm()
        added, aliases = merge(entries, osm)
        print(f'OpenStreetMap: {added} new localities, {aliases} new aliases.')
    codes = [e['code'] for e in entries]
    if len(codes) != len(set(codes)):
        sys.exit('Duplicate locality codes.')
    DATA.parent.mkdir(parents=True, exist_ok=True)
    DATA.write_text(
        json.dumps({'source': 'OpenStreetMap (c) OpenStreetMap contributors, ODbL; see tool/gen_il_localities.py',
                    'localities': entries}, ensure_ascii=False, indent=1) + '\n',
        encoding='utf-8', newline='\n',
    )
    write_dart(entries)
    write_ts(entries)
    print(f'{len(entries)} localities written.')


if __name__ == '__main__':
    main()

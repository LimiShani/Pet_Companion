"""Generate Israel's list of localities for the app and the server.

The list is shared: Find a vet uses it to search "near Rehovot" without a
server call, dog parks store the locality code of each park, and meetups
will pick a city and a radius from it.

    python tool/gen_il_localities.py                 # fetch OSM, merge, write
    python tool/gen_il_localities.py --osm FILE      # use a saved Overpass answer
    python tool/gen_il_localities.py --offline       # rewrite outputs from the JSON only

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
        'const israelLocalities = <Locality>[',
    ]
    for e in entries:
        aliases = ', '.join(dart_string(a) for a in e['aliases'])
        lines.append(
            f"  Locality(code: {dart_string(e['code'])}, "
            f"names: {{'en': {dart_string(e['en'])}, 'he': {dart_string(e['he'])}}}, "
            f"point: GeoPoint({e['lat']}, {e['lng']})"
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
    TS_OUT.write_text('\n'.join(lines), encoding='utf-8', newline='\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--osm', type=Path, help='a saved Overpass JSON answer to the query above')
    parser.add_argument('--offline', action='store_true', help='only rewrite the outputs from the JSON')
    args = parser.parse_args()

    entries = load()
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

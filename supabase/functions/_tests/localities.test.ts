import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { localityByCode, nearestLocality } from '../_shared/localities.ts';
import { IL_JUDEA_SAMARIA_CODES, IL_LOCALITIES } from '../_shared/regions/il_localities.ts';

// The app's copy of the list (generated from the same JSON).
const DART = new URL('../../../lib/services/findvet/regions/il_localities.dart', import.meta.url);

const BACKSLASH = String.fromCharCode(92);

/** Reads a Dart string literal ('...' or "...") at the start of text. */
function dartString(text: string): string {
  const quote = text[0];
  let out = '';
  for (let i = 1; i < text.length; i++) {
    const c = text[i];
    if (c === BACKSLASH) {
      out += text[++i];
    } else if (c === quote) {
      return out;
    } else {
      out += c;
    }
  }
  throw new Error('Unterminated Dart string');
}

function dartStrings(text: string): string[] {
  const out: string[] = [];
  for (let i = 0; i < text.length; i++) {
    if (text[i] === "'" || text[i] === '"') {
      const s = dartString(text.slice(i));
      out.push(s);
      // Skip past the literal (an escaped character takes two places).
      let j = i + 1;
      while (text[j] !== text[i]) j += text[j] === BACKSLASH ? 2 : 1;
      i = j;
    }
  }
  return out;
}

function dartLocalities() {
  const lines = readFileSync(DART, 'utf-8').split('\n').filter((l) => l.trim().startsWith('Locality('));
  return lines.map((line) => {
    const point = /GeoPoint\(([-\d.]+), ([-\d.]+)\)/.exec(line)!;
    const head = line.slice(0, line.indexOf('point:'));
    const [code, , en, , he] = dartStrings(head);
    const aliasPart = line.includes('aliases: [') ? line.slice(line.indexOf('aliases: [') + 10, line.lastIndexOf(']')) : '';
    return { code, en, he, lat: Number(point[1]), lng: Number(point[2]), aliases: dartStrings(aliasPart) };
  });
}

test('the app and the server hold the same localities', () => {
  const app = dartLocalities();
  assert.ok(app.length > 150, `the app has ${app.length} localities`);
  assert.deepEqual(app, IL_LOCALITIES.map((l) => ({ ...l, aliases: [...l.aliases] })));
});

test('locality codes are unique lowercase slugs', () => {
  const codes = IL_LOCALITIES.map((l) => l.code);
  assert.equal(new Set(codes).size, codes.length);
  for (const code of codes) assert.match(code, /^[a-z0-9]+(-[a-z0-9]+)*$/);
});

test('every locality has both names and lies in Israel', () => {
  for (const l of IL_LOCALITIES) {
    assert.ok(l.en && l.he, l.code);
    assert.ok(l.lat > 29.3 && l.lat < 33.5 && l.lng > 34.2 && l.lng < 35.95, l.code);
  }
});

test('the codes stored before the list grew are still there', () => {
  for (const code of ['jerusalem', 'tel-aviv-yafo', 'raanana', 'kfar-saba', 'rehovot', 'modiin-maccabim-reut', 'beersheba']) {
    assert.ok(localityByCode(IL_LOCALITIES, code), code);
  }
});

test('nearest locality within a limit', () => {
  // A point in central Ra'anana.
  assert.equal(nearestLocality(IL_LOCALITIES, { lat: 32.186, lng: 34.87 })?.code, 'raanana');
  // The middle of the sea is near nothing.
  assert.equal(nearestLocality(IL_LOCALITIES, { lat: 32.5, lng: 33.5 }), undefined);
});

test('the Israeli cities and local councils of Judea and Samaria are in the list', () => {
  const expected = [
    'ariel', 'maale-adumim', 'modiin-illit', 'beitar-illit',
    'alfei-menashe', 'beit-aryeh-ofarim', 'beit-el', 'efrat', 'elkana', 'givat-zeev', 'har-adar',
    'immanuel', 'karnei-shomron', 'kedumim', 'kiryat-arba', 'maale-efraim', 'oranit', 'shaar-shomron',
  ];
  assert.deepEqual([...IL_JUDEA_SAMARIA_CODES], expected);
  for (const code of expected) assert.ok(localityByCode(IL_LOCALITIES, code), code);
  // Appended after the places that were there before.
  const index = (code: string) => IL_LOCALITIES.findIndex((l) => l.code === code);
  assert.ok(index('ariel') > index('raanana'));
  assert.equal(localityByCode(IL_LOCALITIES, 'maale-adumim')?.he, 'מעלה אדומים');
  assert.ok(localityByCode(IL_LOCALITIES, 'modiin-illit')?.aliases.includes('Modiin Illit'));
  assert.ok(localityByCode(IL_LOCALITIES, 'maale-adumim')?.aliases.includes('Maale Adumim'));
  // Nearest to a point in Ariel and one in Beitar Illit.
  assert.equal(nearestLocality(IL_LOCALITIES, { lat: 32.105, lng: 35.19 })?.code, 'ariel');
  assert.equal(nearestLocality(IL_LOCALITIES, { lat: 31.7, lng: 35.115 })?.code, 'beitar-illit');
});

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { getRegion, registryLookup, REGIONS } from '../_shared/regions/index.ts';
import { IL } from '../_shared/regions/il.ts';
import { inRegion, parseRequest } from '../_shared/validation.ts';
import type { SearchRequest } from '../_shared/validation.ts';
import { lookupWith, ZZ } from './helpers.ts';

const search = (extra: Record<string, unknown>) =>
  parseRequest({ action: 'search', mode: 'emergency', lat: 31.778, lng: 35.235, ...extra }, registryLookup);

test('registry: Israel is the only registered region; ZZ is not', () => {
  assert.deepEqual(Object.keys(REGIONS), ['IL']);
  assert.equal(getRegion('il'), IL);
  assert.equal(getRegion('ZZ'), undefined);
});

test('Israel bounding box: inside, edges, outside', () => {
  assert.equal(inRegion(IL, 31.778, 35.235), true); // Jerusalem
  assert.equal(inRegion(IL, 29.3, 34.2), true); // corner on the edge
  assert.equal(inRegion(IL, 33.5, 35.95), true);
  assert.equal(inRegion(IL, 29.29, 34.95), false); // south of Eilat
  assert.equal(inRegion(IL, 32.0, 36.0), false); // east of the box
  assert.equal(inRegion(IL, 48.85, 2.35), false); // Paris
});

test('search: coordinates outside the region are rejected', () => {
  const r = search({ lat: 48.85, lng: 2.35 });
  assert.equal(r.ok, false);
  assert.equal(!r.ok && r.error, 'invalid_request');
  assert.equal(search({ lat: '31.7' }).ok, false);
  assert.equal(search({ lat: Number.NaN }).ok, false);
});

test('search: radius rules', () => {
  // Default = first ladder step.
  const d = search({});
  assert.ok(d.ok);
  assert.equal((d.request as SearchRequest).radiusM, 10_000);
  const lt = search({ mode: 'long_term' });
  assert.ok(lt.ok);
  assert.equal((lt.request as SearchRequest).radiusM, 5_000);

  assert.equal(search({ radiusM: 499 }).ok, false);
  assert.equal(search({ radiusM: 500 }).ok, true);
  // Emergency reaches the top of the curated ladder (120 km).
  assert.equal(search({ radiusM: 120_000 }).ok, true);
  assert.equal(search({ radiusM: 120_001 }).ok, false);
  // Long term stops at the provider cap (50 km).
  assert.equal(search({ mode: 'long_term', radiusM: 50_000 }).ok, true);
  assert.equal(search({ mode: 'long_term', radiusM: 50_001 }).ok, false);
  assert.equal(search({ radiusM: '10000' }).ok, false);
});

test('mode, lang and action are validated', () => {
  assert.equal(search({ mode: 'routine' }).ok, false);
  assert.equal(search({ lang: 'fr' }).ok, false);
  const en = search({ lang: 'en' });
  assert.ok(en.ok && (en.request as SearchRequest).lang === 'en');
  const he = search({});
  assert.ok(he.ok && (he.request as SearchRequest).lang === 'he');
  assert.equal(parseRequest({ action: 'delete' }, registryLookup).ok, false);
  assert.equal(parseRequest([], registryLookup).ok, false);
  assert.equal(parseRequest(null, registryLookup).ok, false);
});

test('geocode: query length 2-120 after trimming', () => {
  const q = (query: unknown) => parseRequest({ action: 'geocode', query }, registryLookup);
  assert.equal(q('a').ok, false);
  assert.equal(q('  a  ').ok, false);
  assert.equal(q('ab').ok, true);
  assert.equal(q('x'.repeat(120)).ok, true);
  assert.equal(q('x'.repeat(121)).ok, false);
  assert.equal(q(42).ok, false);
  const ok = q('  הרצל   10  רחובות ');
  assert.ok(ok.ok);
  assert.equal((ok.request as { query: string }).query, 'הרצל 10 רחובות');
});

test('region: default IL, any case accepted, unknown -> unsupported_region', () => {
  const def = search({});
  assert.ok(def.ok && (def.request as SearchRequest).region.code === 'IL');
  const lower = search({ region: 'il' });
  assert.ok(lower.ok && (lower.request as SearchRequest).region.code === 'IL');
  for (const region of ['US', 'ZZ', 'ISR', '', 'I1']) {
    const r = search({ region });
    assert.equal(r.ok, false, region);
    assert.equal(!r.ok && r.error, 'unsupported_region', region);
  }
  // Even with other errors, an unknown region is reported as such.
  const both = parseRequest({ action: 'search', region: 'FR', mode: 'nope' }, registryLookup);
  assert.equal(!both.ok && both.error, 'unsupported_region');
  assert.equal(!search({ region: 7 }).ok && (search({ region: 7 }) as { error: string }).error, 'invalid_request');
});

test('a second region (ZZ, passed directly) brings its own bounds, languages and ladders', () => {
  const lookup = lookupWith(ZZ);
  const inZZ = parseRequest({ action: 'search', region: 'ZZ', mode: 'emergency', lat: 10.5, lng: 20.5 }, lookup);
  assert.ok(inZZ.ok);
  const req = inZZ.request as SearchRequest;
  assert.equal(req.region.code, 'ZZ');
  assert.equal(req.lang, 'fr');
  assert.equal(req.radiusM, 8_000);
  // Israeli coordinates are outside ZZ...
  assert.equal(parseRequest({ action: 'search', region: 'ZZ', mode: 'emergency', ...{ lat: 31.778, lng: 35.235 } }, lookup).ok, false);
  // ...and ZZ coordinates are outside Israel.
  assert.equal(parseRequest({ action: 'search', mode: 'emergency', lat: 10.5, lng: 20.5 }, lookup).ok, false);
  // Hebrew is not a ZZ language.
  assert.equal(parseRequest({ action: 'search', region: 'ZZ', mode: 'emergency', lat: 10.5, lng: 20.5, lang: 'he' }, lookup).ok, false);
});

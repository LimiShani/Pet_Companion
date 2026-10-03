// find-vet handler end to end (Request in, Response out), plus the client
// hash used for rate limiting.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { createFindVetHandler } from '../_shared/find_vet_handler.ts';
import type { FindVetDeps } from '../_shared/find_vet_handler.ts';
import { noneProvider } from '../_shared/providers/none.ts';
import { clientBucket, clientIp, positiveIntOr } from '../_shared/quota.ts';
import { registryLookup } from '../_shared/regions/index.ts';
import { MemoryStore } from '../_shared/store.ts';
import { ADVERTISED, facility, fakeProvider, JERUSALEM, NOW, offset, place } from './helpers.ts';

const post = (body: unknown, headers: Record<string, string> = {}) =>
  new Request('https://example.test/functions/v1/find-vet', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-forwarded-for': '203.0.113.7', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });

function handler(over: Partial<FindVetDeps> = {}) {
  const store = new MemoryStore({
    now: () => NOW,
    curated: [
      facility({ id: 'A', ...offset(JERUSALEM, 2_000, 0), emergency: ADVERTISED }),
      facility({ id: 'B', ...offset(JERUSALEM, 4_000, 0), emergency: ADVERTISED }),
    ],
  });
  const logs: string[] = [];
  const deps: FindVetDeps = {
    provider: fakeProvider({ status: 'ok', value: [place({ placeId: 'p1', ...offset(JERUSALEM, 500, 0) })] }),
    store,
    regions: registryLookup,
    now: () => NOW,
    quotaSecret: 'server-secret',
    dailyPlacesCap: 30,
    dailyGeocodeCap: 300,
    log: (l) => logs.push(l),
    ...over,
  };
  return { h: createFindVetHandler(deps), store, logs, deps };
}

const searchBody = { action: 'search', mode: 'emergency', lat: JERUSALEM.lat, lng: JERUSALEM.lng, radiusM: 10_000, lang: 'he' };

test('search: 200 with region echoed, CORS headers', async () => {
  const { h } = handler();
  const res = await h(post(searchBody));
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), '*');
  const body = await res.json();
  assert.equal(body.region, 'IL');
  assert.deepEqual(body.results.map((r: { key: string }) => r.key), ['f:A', 'f:B', 'g:p1']);
  assert.equal(body.provider.attribution, 'Google Maps');
});

test('unsupported region -> 400 {"error":"unsupported_region"}', async () => {
  const { h } = handler();
  const res = await h(post({ ...searchBody, region: 'ZZ' }));
  assert.equal(res.status, 400);
  assert.deepEqual(await res.json(), { error: 'unsupported_region' });
});

test('invalid request -> 400 invalid_request with detail; bad JSON too', async () => {
  const { h } = handler();
  const res = await h(post({ ...searchBody, lat: 48.85, lng: 2.35 }));
  assert.equal(res.status, 400);
  const body = await res.json();
  assert.equal(body.error, 'invalid_request');
  assert.match(body.detail, /outside IL/);
  const bad = await h(post('{not json'));
  assert.equal(bad.status, 400);
  assert.equal((await bad.json()).error, 'invalid_request');
});

test('regions action lists served regions and languages', async () => {
  const { h } = handler();
  const res = await h(post({ action: 'regions' }));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {
    regions: [{ code: 'IL', languages: ['he', 'en'], defaultLanguage: 'he' }],
    defaultRegion: 'IL',
  });
});

test('OPTIONS preflight and wrong method', async () => {
  const { h } = handler();
  const pre = await h(new Request('https://example.test/', { method: 'OPTIONS' }));
  assert.equal(pre.status, 204);
  assert.match(pre.headers.get('Access-Control-Allow-Headers') ?? '', /apikey/);
  assert.equal((await h(new Request('https://example.test/', { method: 'GET' }))).status, 405);
});

test('per-client limit: 30 per 10 minutes, then 429', async () => {
  const { h } = handler({ provider: noneProvider });
  for (let i = 0; i < 30; i++) assert.equal((await h(post(searchBody))).status, 200, `call ${i + 1}`);
  const limited = await h(post(searchBody));
  assert.equal(limited.status, 429);
  assert.deepEqual(await limited.json(), { error: 'rate_limited' });
  // Another client is not affected.
  assert.equal((await h(post(searchBody, { 'x-forwarded-for': '198.51.100.9' }))).status, 200);
});

test('daily provider cap: provider skipped, curated still returned', async () => {
  const provider = fakeProvider({ status: 'ok', value: [] });
  const { h } = handler({ provider, dailyPlacesCap: 2 });
  for (let i = 0; i < 2; i++) assert.equal((await (await h(post(searchBody))).json()).provider.status, 'ok');
  const third = await (await h(post(searchBody))).json();
  assert.equal(third.provider.status, 'quota');
  assert.deepEqual(third.results.map((r: { key: string }) => r.key), ['f:A', 'f:B']);
  assert.equal(provider.calls.length, 2);
});

test('geocode: ok, region echoed; disabled provider -> 503; own daily cap', async () => {
  const provider = fakeProvider({ status: 'ok', value: [] }, { status: 'ok', value: [{ label: 'x', lat: 31.9, lng: 34.8 }] });
  const { h } = handler({ provider, dailyGeocodeCap: 1 });
  const ok = await h(post({ action: 'geocode', query: 'הרצל 10 רחובות' }));
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), { region: 'IL', results: [{ label: 'x', lat: 31.9, lng: 34.8 }] });
  assert.deepEqual(provider.geocodeCalls, [{ query: 'הרצל 10 רחובות', lang: 'he', region: 'IL' }]);
  assert.equal((await h(post({ action: 'geocode', query: 'שוב' }))).status, 503);

  const { h: h2 } = handler({ provider: noneProvider });
  const off = await h2(post({ action: 'geocode', query: 'הרצל' }));
  assert.equal(off.status, 503);
  assert.deepEqual(await off.json(), { error: 'unavailable' });
});

test('both sources down -> 503 unavailable', async () => {
  const { h, store } = handler({ provider: fakeProvider({ status: 'error' }) });
  store.fail.add('curatedNear');
  const res = await h(post(searchBody));
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { error: 'unavailable' });
});

test('heuristic matches are recorded as link candidates', async () => {
  const store = new MemoryStore({
    now: () => NOW,
    curated: [facility({ id: 'V', name: 'Vet Center', phone: '+97299668133', ...offset(JERUSALEM, 1_000, 0), emergency: ADVERTISED })],
  });
  const provider = fakeProvider({ status: 'ok', value: [place({ placeId: 'pV', name: 'Vet Center', nationalPhone: '09-9668133', ...offset(JERUSALEM, 1_030, 0) })] });
  const { h } = handler({ store, provider });
  assert.equal((await h(post(searchBody))).status, 200);
  assert.deepEqual(store.linkCandidates, [{ facilityId: 'V', placeId: 'pV', matchedOn: 'phone' }]);
});

test('logs never contain coordinates, queries or the IP', async () => {
  const { h, logs } = handler({ provider: fakeProvider({ status: 'error' }) });
  await h(post(searchBody));
  await h(post({ action: 'geocode', query: 'רחוב סודי 5' }));
  const all = logs.join('\n');
  assert.ok(logs.length > 0);
  for (const secret of ['31.778', '35.235', 'רחוב סודי', '203.0.113.7']) assert.ok(!all.includes(secret), secret);
});

test('client hash: never contains the raw IP, changes daily, stable within a day', async () => {
  const headers = new Headers({ 'x-forwarded-for': '203.0.113.7, 10.0.0.1' });
  assert.equal(clientIp(headers), '203.0.113.7');
  assert.equal(clientIp(new Headers({ 'cf-connecting-ip': '198.51.100.1' })), '198.51.100.1');
  assert.equal(clientIp(new Headers()), 'unknown');

  const a = await clientBucket(headers, NOW, 's');
  assert.match(a, /^client:[0-9a-f]{32}$/);
  assert.ok(!a.includes('203.0.113.7') && !a.includes('203'));
  assert.equal(await clientBucket(headers, new Date('2026-10-05T23:59:59Z'), 's'), a);
  assert.notEqual(await clientBucket(headers, new Date('2026-10-06T00:00:00Z'), 's'), a);
  assert.notEqual(await clientBucket(headers, NOW, 'other secret'), a);
  assert.notEqual(await clientBucket(new Headers({ 'x-forwarded-for': '203.0.113.8' }), NOW, 's'), a);
});

test('env integers', () => {
  assert.equal(positiveIntOr(undefined, 30), 30);
  assert.equal(positiveIntOr('', 30), 30);
  assert.equal(positiveIntOr('120', 30), 120);
  assert.equal(positiveIntOr('-1', 30), 30);
  assert.equal(positiveIntOr('abc', 30), 30);
});

// The monthly dog parks import: parsing Overpass, naming by the nearest
// street, details from tags, the run (idempotent, failures recorded) and
// the handler's secret. Fixtures are made up (not OpenStreetMap data).

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  createParksImportHandler,
  createPostgrestParksStore,
  detailsOf,
  distanceToLineM,
  MemoryParksStore,
  namesOf,
  nearestStreet,
  overpassQuery,
  parkRow,
  parseOverpass,
  periodKey,
  runParksImport,
  REFERER,
  tri,
  USER_AGENT,
} from '../_shared/parks_import.ts';
import type { ParksImportDeps } from '../_shared/parks_import.ts';
import { IL_LOCALITIES } from '../_shared/regions/il_localities.ts';

const NOW = new Date('2026-10-03T01:00:00Z');

// Ra'anana-ish coordinates, invented for the tests.
const ANSWER = {
  version: 0.6,
  elements: [
    // A street far from every park.
    { type: 'way', id: 900, tags: { highway: 'residential', name: 'Lost' }, geometry: [{ lat: 32.1, lon: 34.8 }, { lat: 32.1, lon: 34.81 }] },
    {
      type: 'way', id: 1, center: { lat: 32.18600, lon: 34.87200 },
      tags: { leisure: 'dog_park', barrier: 'fence', lit: 'no', drinking_water: 'yes', small_dog: 'separate' },
    },
    // Two streets: Ahuza runs 30 m north of the park, Weizmann 100 m south.
    {
      type: 'way', id: 101, tags: { highway: 'tertiary', name: 'אחוזה', 'name:en': 'Ahuza' },
      geometry: [{ lat: 32.18627, lon: 34.8700 }, { lat: 32.18627, lon: 34.8740 }],
    },
    {
      type: 'way', id: 102, tags: { highway: 'residential', name: 'ויצמן' },
      geometry: [{ lat: 32.1851, lon: 34.8700 }, { lat: 32.1851, lon: 34.8740 }],
    },
    { type: 'node', id: 2, lat: 32.18, lon: 34.88, tags: { leisure: 'dog_park', name: 'גינת הכלבים בפארק', 'name:en': 'Park Dog Run', opening_hours: '06:00-23:00' } },
    // A relation without a centre cannot be placed.
    { type: 'relation', id: 3, tags: { leisure: 'dog_park' } },
    // A park far from every town (the middle of the Negev, invented).
    { type: 'way', id: 4, center: { lat: 30.2, lon: 34.95 }, tags: { leisure: 'dog_park', fence: 'no' } },
  ],
};

test('the query asks for dog parks in Israel and the named streets near their points', () => {
  const q = overpassQuery();
  assert.match(q, /^\[out:json\]\[timeout:90\]\[maxsize:67108864\];/);
  assert.match(q, /area\["ISO3166-1"="IL"\]\[admin_level=2\]/);
  assert.match(q, /nwr\[leisure=dog_park\]\(area\.country\)->\.parks;\.parks out tags center;/);
  assert.match(q, /node\(w\.parks\)->\.p2;way\(r\.parks\)->\.rw;node\(w\.rw\)->\.p3;/);
  assert.match(q, /way\(around\.points:100\)\[highway~"\^\(primary\|/);
  assert.doesNotMatch(q, /foreach/);
});

test('parsing finds the parks and the streets near each one', () => {
  const parks = parseOverpass(ANSWER);
  assert.deepEqual(parks.map((p) => p.sourceId), ['way/1', 'node/2', 'way/4']);
  assert.deepEqual(parks[0].streets.map((s) => s.tags.name).sort(), ['אחוזה', 'ויצמן']);
  assert.equal(parks[2].streets.length, 0, 'nothing near the remote park');
  assert.ok(!parks.some((p) => p.streets.some((s) => s.tags.name === 'Lost')), 'a far street names nothing');
  assert.throws(() => parseOverpass({ nope: true }));
});

test('the nearest street names an unnamed park', () => {
  const [park] = parseOverpass(ANSWER);
  assert.equal(nearestStreet(park)?.tags.name, 'אחוזה');
  const row = parkRow(park, IL_LOCALITIES);
  assert.equal(row.name_he, null);
  assert.equal(row.street_he, 'אחוזה');
  assert.equal(row.street_en, 'Ahuza');
  assert.equal(row.locality_code, 'raanana');
});

test('distance to a street is to its closest segment, not its middle', () => {
  const line = [{ lat: 32, lng: 34.8 }, { lat: 32, lng: 34.9 }];
  const d = distanceToLineM({ lat: 32.001, lng: 34.85 }, line);
  assert.ok(d > 100 && d < 120, `${d}`);
  assert.equal(distanceToLineM({ lat: 32, lng: 34.8 }, []), Infinity);
});

test('names come from name:he / name:en, else from name by its script', () => {
  assert.deepEqual(namesOf({ name: 'גינה', 'name:en': 'Garden' }), { he: 'גינה', en: 'Garden' });
  assert.deepEqual(namesOf({ name: 'Dog Run' }), { he: null, en: 'Dog Run' });
  assert.deepEqual(namesOf({}), { he: null, en: null });
});

test('details: the usual tags, unknown when absent', () => {
  assert.deepEqual(detailsOf(ANSWER.elements[1].tags as Record<string, string>), {
    fenced: 'yes', water: 'yes', shade: 'unknown', lighting: 'no', small_dogs: 'yes', benches: 'unknown',
  });
  assert.equal(detailsOf({ fence: 'no' }).fenced, 'no');
  assert.equal(tri('maybe'), 'unknown');
  assert.equal(tri(undefined), 'unknown');
  assert.equal(tri('No'), 'no');
});

test('a named park keeps its names and hours; a remote one gets no locality', () => {
  const [, named, remote] = parseOverpass(ANSWER).map((p) => parkRow(p, IL_LOCALITIES));
  assert.equal(named.name_he, 'גינת הכלבים בפארק');
  assert.equal(named.name_en, 'Park Dog Run');
  assert.equal(named.opening_hours, '06:00-23:00');
  assert.equal(remote.locality_code, null);
  assert.equal(remote.fenced, 'no');
});

function deps(over: Partial<ParksImportDeps> = {}, answer: unknown = ANSWER, status = 200) {
  const store = new MemoryParksStore();
  const requests: { url: string; init?: RequestInit }[] = [];
  const logs: string[] = [];
  const d: ParksImportDeps = {
    store,
    fetch: async (url, init) => {
      requests.push({ url, init });
      return new Response(typeof answer === 'string' ? answer : JSON.stringify(answer), { status });
    },
    now: () => NOW,
    localities: IL_LOCALITIES,
    log: (l) => logs.push(l),
    ...over,
  };
  return { d, store, requests, logs };
}

test('a run downloads once, with an honest user agent, and imports every park', async () => {
  const { d, store, requests, logs } = deps();
  const r = await runParksImport(d);
  assert.equal(r.status, 'succeeded');
  assert.equal(r.period, '2026-10');
  assert.equal(requests.length, 1);
  const headers = requests[0].init?.headers as Record<string, string>;
  assert.equal(headers['User-Agent'], USER_AGENT);
  assert.equal(headers.Referer, REFERER, 'overpass-api.de refuses a request with neither');
  assert.match(String(requests[0].init?.body), /^data=/);
  assert.equal(store.imported[0].rows.length, 3);
  assert.equal(r.stats.named, 1);
  assert.equal(r.stats.namedByStreet, 1);
  assert.equal(r.stats.withoutLocality, 1);
  assert.equal(JSON.parse(logs[0]).status, 'succeeded');
});

test('a month that succeeded is not downloaded again unless forced', async () => {
  const { d, store, requests } = deps();
  await runParksImport(d);
  const again = await runParksImport(d);
  assert.equal(again.reused, true);
  assert.equal(requests.length, 1);
  const forced = await runParksImport(d, { force: true });
  assert.equal(forced.reused, false);
  assert.equal(requests.length, 2);
  assert.equal(store.imported[1].force, true);
});

test('a failed download is recorded and imports nothing', async () => {
  for (const [answer, status, error] of [
    ['busy', 504, 'overpass_http_504'],
    ['not json', 200, 'overpass_bad_answer'],
    [{ elements: [] }, 200, 'empty_download'],
    [{ remark: 'runtime error: Query timed out in "query" at line 1 after 120 seconds.', elements: [] }, 200, 'overpass_timeout'],
  ] as const) {
    const { d, store } = deps({}, answer, status);
    const r = await runParksImport(d);
    assert.equal(r.status, 'failed');
    assert.equal(r.error, error);
    assert.equal(store.imported.length, 0);
    assert.equal(store.runs.get('2026-10')?.status, 'failed');
  }
});

test('the database refusing a suspicious download is recorded', async () => {
  const { d, store } = deps();
  store.failWith = 'suspicious_import';
  const r = await runParksImport(d);
  assert.equal(r.status, 'failed');
  assert.match(r.error!, /suspicious_import/);
});

test('a download that never answers times out', async () => {
  const { d } = deps({
    timeoutMs: 20,
    fetch: (_url, init) =>
      new Promise((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')));
      }),
  });
  const r = await runParksImport(d);
  assert.equal(r.error, 'overpass_timeout');
});

test('a refused or busy first server falls back once to the second', async () => {
  for (const firstStatus of [406, 429, 504]) {
    const urls: string[] = [];
    const { d, store, logs } = deps({
      overpassUrl: 'https://first.test/api/interpreter',
      fallbackUrl: 'https://second.test/api/interpreter',
      fetch: async (url) => {
        urls.push(url);
        return url.startsWith('https://first.test')
          ? new Response('no', { status: firstStatus })
          : new Response(JSON.stringify(ANSWER), { status: 200 });
      },
    });
    const r = await runParksImport(d);
    assert.equal(r.status, 'succeeded', `after ${firstStatus}`);
    assert.deepEqual(urls, ['https://first.test/api/interpreter', 'https://second.test/api/interpreter']);
    assert.equal(store.imported.length, 1);
    assert.match(logs[0], new RegExp(`overpass_http_${firstStatus}`));
  }
});

test('both servers failing records both reasons; a bad answer does not fall back', async () => {
  const both = deps({ fallbackUrl: 'https://second.test/api/interpreter' }, 'busy', 504);
  const r = await runParksImport(both.d);
  assert.equal(r.status, 'failed');
  assert.equal(r.error, 'overpass_http_504; fallback overpass_http_504');
  assert.equal(both.requests.length, 2);

  const bad = deps({ fallbackUrl: 'https://second.test/api/interpreter' }, 'not json', 200);
  const r2 = await runParksImport(bad.d);
  assert.equal(r2.error, 'overpass_bad_answer');
  assert.equal(bad.requests.length, 1);
});

test('periods are UTC months', () => {
  assert.equal(periodKey(new Date('2026-12-31T23:30:00Z')), '2026-12');
  assert.equal(periodKey(new Date('2027-01-01T00:00:00Z')), '2027-01');
});

test('handler: secret checked, force passed, failures answer 502', async () => {
  const { d, store } = deps();
  const handler = createParksImportHandler({ ...d, jobSecret: 's3cret' });
  const post = (headers: Record<string, string>, body = '{}') =>
    handler(new Request('https://x.test/functions/v1/parks-import', { method: 'POST', headers, body }));
  assert.equal((await post({})).status, 401);
  assert.equal((await post({ 'x-job-secret': 'wrong' })).status, 401);
  assert.equal((await handler(new Request('https://x.test', { method: 'GET' }))).status, 405);
  const ok = await post({ 'x-job-secret': 's3cret' }, '{"force": true}');
  assert.equal(ok.status, 200);
  assert.equal(store.imported[0].force, true);
  const unconfigured = createParksImportHandler({ ...d, jobSecret: '' });
  assert.equal((await unconfigured(new Request('https://x.test', { method: 'POST', body: '{}' }))).status, 503);
  const failing = createParksImportHandler({ ...deps({}, 'busy', 504).d, jobSecret: 's3cret' });
  assert.equal((await failing(new Request('https://x.test', { method: 'POST', headers: { 'x-job-secret': 's3cret' }, body: '{}' }))).status, 502);
});

test('PostgREST store: the run lookup, the import call and a failed run', async () => {
  const calls: { url: string; method?: string; body?: string; prefer?: string }[] = [];
  const store = createPostgrestParksStore({
    url: 'https://abc.supabase.co/',
    serviceKey: 'service',
    fetch: async (url, init) => {
      const headers = init?.headers as Record<string, string>;
      calls.push({ url, method: init?.method, body: init?.body as string, prefer: headers.Prefer });
      if (url.includes('rpc/dog_parks_import')) return new Response('{"added":3}', { status: 200 });
      if (init?.method === 'GET') return new Response('[]', { status: 200 });
      return new Response('', { status: 201 });
    },
  });
  assert.equal(await store.getRun('2026-10'), null);
  assert.match(calls[0].url, /dog_park_import_runs\?select=.*period_key=eq\.2026-10$/);
  assert.deepEqual(await store.importParks('2026-10', [], false), { added: 3 });
  assert.deepEqual(JSON.parse(calls[1].body!), { p_period: '2026-10', p_parks: [], p_force: false });
  await store.saveFailedRun('2026-10', 'overpass_timeout');
  assert.match(calls[2].prefer!, /merge-duplicates/);

  const refusing = createPostgrestParksStore({
    url: 'https://abc.supabase.co',
    serviceKey: 'service',
    fetch: async () => new Response('{"message":"suspicious_import","code":"P0001"}', { status: 400 }),
  });
  await assert.rejects(refusing.importParks('2026-10', [], false), /suspicious_import/);
});

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { createGoogleProvider, NEARBY_FIELD_MASK, NEARBY_URL } from '../_shared/providers/google.ts';
import { IL } from '../_shared/regions/il.ts';
import { ZZ } from './helpers.ts';

interface Captured {
  url: string;
  init: RequestInit;
}

function capture(respond: (url: string) => Response | Promise<Response>) {
  const calls: Captured[] = [];
  const fetch = (url: string, init: RequestInit = {}): Promise<Response> => {
    calls.push({ url, init });
    return Promise.resolve(respond(url));
  };
  return { fetch, calls };
}

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

const query = { lat: 31.778, lng: 35.235, radiusM: 10_000, lang: 'he', maxResults: 20, region: IL };

test('nearby: exact URL, headers, field mask and body', async () => {
  const { fetch, calls } = capture(() => jsonResponse({}));
  const g = createGoogleProvider({ apiKey: 'test-key', fetch });
  const out = await g.nearbyVets({ ...query, radiusM: 120_000, maxResults: 50 });
  assert.deepEqual(out, { status: 'ok', value: [] });
  assert.equal(calls.length, 1);
  const { url, init } = calls[0];
  assert.equal(url, 'https://places.googleapis.com/v1/places:searchNearby');
  assert.equal(url, NEARBY_URL);
  assert.equal(init.method, 'POST');
  const headers = init.headers as Record<string, string>;
  assert.equal(headers['X-Goog-Api-Key'], 'test-key');
  assert.equal(
    headers['X-Goog-FieldMask'],
    'places.id,places.displayName,places.formattedAddress,places.location,places.nationalPhoneNumber,' +
      'places.internationalPhoneNumber,places.websiteUri,places.googleMapsUri,places.businessStatus,' +
      'places.currentOpeningHours.openNow,places.currentOpeningHours.weekdayDescriptions',
  );
  assert.equal(headers['X-Goog-FieldMask'], NEARBY_FIELD_MASK);
  assert.deepEqual(JSON.parse(init.body as string), {
    includedTypes: ['veterinary_care'],
    maxResultCount: 20,
    rankPreference: 'DISTANCE',
    locationRestriction: { circle: { center: { latitude: 31.778, longitude: 35.235 }, radius: 50_000 } },
    languageCode: 'he',
    regionCode: 'IL',
  });
  assert.ok(init.signal instanceof AbortSignal);
});

test('nearby: the region code comes from the RegionConfig', async () => {
  const { fetch, calls } = capture(() => jsonResponse({}));
  await createGoogleProvider({ apiKey: 'k', fetch }).nearbyVets({ ...query, region: ZZ, lang: 'fr' });
  assert.equal(JSON.parse(calls[0].init.body as string).regionCode, 'ZZ');
});

test('nearby: response mapping', async () => {
  const { fetch } = capture(() =>
    jsonResponse({
      places: [
        {
          id: 'ChIJ1',
          displayName: { text: 'Vet Center', languageCode: 'en' },
          formattedAddress: 'המרץ 7, ראש העין, ישראל',
          location: { latitude: 32.1, longitude: 34.96 },
          nationalPhoneNumber: '09-966-8133',
          internationalPhoneNumber: '+972 9-966-8133',
          websiteUri: 'https://www.vetcenter.co.il/',
          googleMapsUri: 'https://maps.google.com/?cid=1',
          businessStatus: 'OPERATIONAL',
          currentOpeningHours: { openNow: true, weekdayDescriptions: ['Monday: Open 24 hours'] },
        },
        { id: 'ChIJ2', location: { latitude: 32, longitude: 35 }, businessStatus: 'CLOSED_PERMANENTLY' },
        { displayName: { text: 'no id' }, location: { latitude: 1, longitude: 2 } },
      ],
    }),
  );
  const out = await createGoogleProvider({ apiKey: 'k', fetch }).nearbyVets(query);
  assert.equal(out.status, 'ok');
  if (out.status !== 'ok') return;
  assert.equal(out.value.length, 2);
  assert.deepEqual(out.value[0], {
    placeId: 'ChIJ1',
    name: 'Vet Center',
    address: 'המרץ 7, ראש העין, ישראל',
    lat: 32.1,
    lng: 34.96,
    nationalPhone: '09-966-8133',
    internationalPhone: '+972 9-966-8133',
    website: 'https://www.vetcenter.co.il/',
    mapsUri: 'https://maps.google.com/?cid=1',
    businessStatus: 'operational',
    openNow: true,
    weekdayText: ['Monday: Open 24 hours'],
  });
  assert.equal(out.value[1].businessStatus, 'closed_permanently');
  assert.equal(out.value[1].openNow, null);
  assert.equal(out.value[1].name, '');
});

test('nearby: HTTP errors map to error / quota; network failure to error', async () => {
  const g500 = createGoogleProvider({ apiKey: 'k', fetch: capture(() => jsonResponse({ error: {} }, 500)).fetch });
  assert.deepEqual(await g500.nearbyVets(query), { status: 'error', detail: 'http 500' });
  const g403 = createGoogleProvider({ apiKey: 'k', fetch: capture(() => jsonResponse({}, 403)).fetch });
  assert.equal((await g403.nearbyVets(query)).status, 'error');
  const g429 = createGoogleProvider({ apiKey: 'k', fetch: capture(() => jsonResponse({}, 429)).fetch });
  assert.equal((await g429.nearbyVets(query)).status, 'quota');
  const down = createGoogleProvider({ apiKey: 'k', fetch: () => Promise.reject(new TypeError('dns')) });
  assert.deepEqual(await down.nearbyVets(query), { status: 'error', detail: 'network' });
  const badJson = createGoogleProvider({ apiKey: 'k', fetch: () => Promise.resolve(new Response('<html>', { status: 200 })) });
  assert.equal((await badJson.nearbyVets(query)).status, 'error');
});

test('nearby: timeout aborts the request', async () => {
  let aborted = false;
  const hang = (_url: string, init: RequestInit = {}): Promise<Response> =>
    new Promise((_resolve, reject) => {
      init.signal?.addEventListener('abort', () => {
        aborted = true;
        reject(new DOMException('aborted', 'AbortError'));
      });
    });
  const g = createGoogleProvider({ apiKey: 'k', fetch: hang, timeoutMs: 20 });
  assert.deepEqual(await g.nearbyVets(query), { status: 'timeout' });
  assert.equal(aborted, true);
});

test('geocode: URL carries the region filter; results outside the region are dropped', async () => {
  const { fetch, calls } = capture(() =>
    jsonResponse({
      status: 'OK',
      results: [
        { formatted_address: 'הרצל 10, רחובות, ישראל', geometry: { location: { lat: 31.89, lng: 34.81 } } },
        { formatted_address: 'Herzl St 10, Somewhere abroad', geometry: { location: { lat: 40.7, lng: -74 } } },
      ],
    }),
  );
  const out = await createGoogleProvider({ apiKey: 'k', fetch }).geocode('הרצל 10 רחובות', 'he', IL);
  assert.deepEqual(out, { status: 'ok', value: [{ label: 'הרצל 10, רחובות, ישראל', lat: 31.89, lng: 34.81 }] });
  const u = new URL(calls[0].url);
  assert.equal(u.origin + u.pathname, 'https://maps.googleapis.com/maps/api/geocode/json');
  assert.equal(u.searchParams.get('address'), 'הרצל 10 רחובות');
  assert.equal(u.searchParams.get('components'), 'country:IL');
  assert.equal(u.searchParams.get('region'), 'il');
  assert.equal(u.searchParams.get('language'), 'he');
  assert.equal(u.searchParams.get('key'), 'k');
});

test('geocode: statuses map to ok-empty / quota / error', async () => {
  const run = async (status: string) =>
    createGoogleProvider({ apiKey: 'k', fetch: capture(() => jsonResponse({ status, results: [] })).fetch }).geocode('xx', 'he', IL);
  assert.deepEqual(await run('ZERO_RESULTS'), { status: 'ok', value: [] });
  assert.equal((await run('OVER_QUERY_LIMIT')).status, 'quota');
  assert.equal((await run('OVER_DAILY_LIMIT')).status, 'quota');
  assert.equal((await run('REQUEST_DENIED')).status, 'error');
  assert.equal((await run('INVALID_REQUEST')).status, 'error');
});

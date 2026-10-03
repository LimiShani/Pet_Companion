import { test } from 'node:test';
import assert from 'node:assert/strict';

import { EvidenceLevel, evidenceLevels } from '../_shared/evidence.ts';
import { noneProvider } from '../_shared/providers/none.ts';
import type { ProviderOutcome, ProviderPlace } from '../_shared/providers/types.ts';
import { IL } from '../_shared/regions/il.ts';
import { runSearch, SearchUnavailable } from '../_shared/search.ts';
import type { SearchDeps } from '../_shared/search.ts';
import { MemoryStore } from '../_shared/store.ts';
import type { CuratedFacility, IntakeRow } from '../_shared/types.ts';
import type { SearchRequest } from '../_shared/validation.ts';
import { ADVERTISED, facility, fakeProvider, JERUSALEM, NOW, offset, place, UNVERIFIED, ZZ } from './helpers.ts';

const req = (over: Partial<SearchRequest> = {}): SearchRequest => ({
  action: 'search',
  region: IL,
  mode: 'emergency',
  lat: JERUSALEM.lat,
  lng: JERUSALEM.lng,
  radiusM: 10_000,
  lang: 'he',
  ...over,
});

const at = (northM: number) => offset(JERUSALEM, northM, 0);

// Two advertised hospitals inside 10 km, one unverified, one plain clinic.
function curatedSet(): CuratedFacility[] {
  return [
    facility({ id: 'A', name: 'Alpha Animal Hospital', nameHe: 'בית החולים אלפא', ...at(3_000), emergency: ADVERTISED, placeIds: ['pA'], phone: '+97221111111' }),
    facility({ id: 'D', name: 'Delta Vets', ...at(8_000), emergency: ADVERTISED }),
    facility({ id: 'B', name: 'Beta Vets', ...at(6_000), emergency: UNVERIFIED }),
    facility({ id: 'P', name: 'Plain Clinic', ...at(2_000) }),
  ];
}

function deps(store: MemoryStore, nearby: ProviderOutcome<ProviderPlace[]>, gate: 'ok' | 'quota' | 'error' = 'ok') {
  const provider = fakeProvider(nearby);
  let gateCalls = 0;
  const d: SearchDeps = {
    provider,
    store,
    now: () => NOW,
    allowProviderCall: () => {
      gateCalls++;
      return Promise.resolve(gate);
    },
  };
  return { d, provider, gateCalls: () => gateCalls };
}

test('ok: curated + provider merged, tiers then distance, provider-only "Emergency" name stays a listing', async () => {
  const store = new MemoryStore({ curated: curatedSet() });
  const providerPlaces = [
    place({ placeId: 'pA', name: 'Alpha Hospital (Google name)', ...at(3_000), openNow: true, weekdayText: ['Monday: Open 24 hours'] }),
    place({ placeId: 'pC', name: 'Emergency Vet Hospital 24/7', ...at(1_000) }),
  ];
  const { d, provider } = deps(store, { status: 'ok', value: providerPlaces });
  const { response, linkCandidates } = await runSearch(req(), d);

  assert.equal(response.region, 'IL');
  assert.equal(response.searchedAt, NOW.toISOString());
  assert.deepEqual(response.provider, { name: 'google', status: 'ok', attribution: 'Google Maps' });
  assert.equal(response.radiusM, 10_000);
  assert.equal(response.expanded, false);
  assert.deepEqual(response.notices, []);
  assert.deepEqual(response.results.map((r) => r.key), ['f:A', 'f:D', 'f:B', 'g:pC']);
  assert.equal(linkCandidates.length, 0); // the match was by place ID

  const a = response.results[0];
  assert.equal(a.fromCurated && a.fromProvider, true);
  assert.equal(a.placeId, 'pA');
  assert.equal(a.name, 'בית החולים אלפא'); // curated Hebrew name for lang he
  assert.equal(a.mapsUri, 'https://maps.google.com/?cid=pA'); // kept for attribution
  assert.equal(a.emergency.state, 'advertised');
  assert.equal(a.open.basis, 'provider_hours');
  assert.equal(a.phone, '+97221111111');
  assert.equal(a.distanceM, 3_000);

  const c = response.results[3];
  assert.equal(c.emergency.state, 'not_listed');
  assert.ok(!evidenceLevels(c).includes(EvidenceLevel.emergencyAdvertised));
  assert.equal(c.facilityId, null);

  // The plain curated clinic is not an emergency option and the provider did not list it.
  assert.ok(!response.results.some((r) => r.key === 'f:P'));

  assert.equal(provider.calls.length, 1);
  assert.equal(provider.calls[0].radiusM, 10_000);
  assert.equal(provider.calls[0].maxResults, 20);
  assert.equal(provider.calls[0].region.code, 'IL');
});

test('provider error: curated emergency-advertised records only, with provider_unavailable', async () => {
  const store = new MemoryStore({ curated: curatedSet() });
  const { d } = deps(store, { status: 'error', detail: 'http 500' });
  const { response } = await runSearch(req(), d);
  assert.equal(response.provider.status, 'error');
  assert.equal(response.provider.attribution, null);
  assert.deepEqual(response.notices, ['provider_unavailable']);
  assert.deepEqual(response.results.map((r) => r.key), ['f:A', 'f:D']);
  assert.ok(response.results.every((r) => r.emergency.checkedAt !== null)); // labelled with their check date
});

test('provider timeout behaves like an error', async () => {
  const store = new MemoryStore({ curated: curatedSet() });
  const { d } = deps(store, { status: 'timeout' });
  const { response } = await runSearch(req(), d);
  assert.equal(response.provider.status, 'timeout');
  assert.deepEqual(response.results.map((r) => r.key), ['f:A', 'f:D']);
});

test('disabled provider: not called, no quota spent', async () => {
  const store = new MemoryStore({ curated: curatedSet() });
  let gateCalls = 0;
  const { response } = await runSearch(req(), {
    provider: noneProvider,
    store,
    now: () => NOW,
    allowProviderCall: () => {
      gateCalls++;
      return Promise.resolve('ok');
    },
  });
  assert.equal(gateCalls, 0);
  assert.equal(response.provider.status, 'disabled');
  assert.equal(response.provider.name, 'none');
  assert.ok(response.notices.includes('provider_unavailable'));
  assert.deepEqual(response.results.map((r) => r.key), ['f:A', 'f:D']);
});

test('daily cap reached: provider skipped with status quota', async () => {
  const store = new MemoryStore({ curated: curatedSet() });
  const { d, provider } = deps(store, { status: 'ok', value: [] }, 'quota');
  const { response } = await runSearch(req(), d);
  assert.equal(provider.calls.length, 0);
  assert.equal(response.provider.status, 'quota');
  assert.deepEqual(response.results.map((r) => r.key), ['f:A', 'f:D']);
});

test('empty area: radius expanded to the top and no_results', async () => {
  const store = new MemoryStore();
  const { d, provider } = deps(store, { status: 'ok', value: [] });
  const { response } = await runSearch(req(), d);
  assert.equal(response.radiusM, 120_000);
  assert.equal(response.expanded, true);
  assert.deepEqual(response.notices, ['radius_expanded', 'no_results']);
  assert.equal(provider.calls[0].radiusM, 50_000); // provider capped at 50 km
});

test('one advertised nearby: radius expands to find a second option', async () => {
  const store = new MemoryStore({
    curated: [
      facility({ id: 'near', ...at(4_000), emergency: ADVERTISED }),
      facility({ id: 'second', ...at(20_000), emergency: ADVERTISED }),
      facility({ id: 'far', ...at(40_000), emergency: ADVERTISED }),
    ],
  });
  const { d, provider } = deps(store, { status: 'ok', value: [] });
  const { response } = await runSearch(req(), d);
  assert.equal(response.radiusM, 25_000);
  assert.equal(response.expanded, true);
  assert.deepEqual(response.notices, ['radius_expanded']);
  assert.deepEqual(response.results.map((r) => r.key), ['f:near', 'f:second']);
  assert.equal(provider.calls[0].radiusM, 25_000);
});

test('live intake: fresh accepting first; expired is unknown', async () => {
  const intake: IntakeRow[] = [
    { facilityId: 'D', status: 'accepting', species: ['dog'], updatedAt: '2026-10-05T08:30:00Z', expiresAt: '2026-10-05T10:00:00Z' },
    { facilityId: 'A', status: 'accepting', species: ['cat'], updatedAt: '2026-10-05T03:00:00Z', expiresAt: NOW.toISOString() },
  ];
  const store = new MemoryStore({ curated: curatedSet(), intake });
  const { d } = deps(store, { status: 'ok', value: [] });
  const { response } = await runSearch(req(), d);
  assert.equal(response.results[0].key, 'f:D');
  assert.equal(response.results[0].intake.state, 'accepting');
  const a = response.results.find((r) => r.key === 'f:A')!;
  assert.equal(a.intake.state, 'unknown');
});

test('heuristic match merges and becomes a link candidate (place ID only)', async () => {
  const store = new MemoryStore({
    curated: [facility({ id: 'V', name: 'Vet Center', phone: '+97299668133', ...at(2_000), emergency: ADVERTISED })],
  });
  const p = place({ placeId: 'pV', name: 'Vet Center', nationalPhone: '09-966-8133', ...at(2_050) });
  const { d } = deps(store, { status: 'ok', value: [p] });
  const { response, linkCandidates } = await runSearch(req(), d);
  assert.equal(response.results.filter((r) => r.key === 'f:V').length, 1);
  assert.ok(!response.results.some((r) => r.key === 'g:pV'));
  assert.deepEqual(linkCandidates, [{ facilityId: 'V', placeId: 'pV', matchedOn: 'phone' }]);
});

test('curated store down: provider results with curated_unavailable; both down: unavailable', async () => {
  const store = new MemoryStore({ curated: curatedSet() });
  store.fail.add('curatedNear');
  const { d } = deps(store, { status: 'ok', value: [place({ placeId: 'p1', ...at(500) })] });
  const { response } = await runSearch(req(), d);
  assert.ok(response.notices.includes('curated_unavailable'));
  assert.deepEqual(response.results.map((r) => r.key), ['g:p1']);

  const { d: d2 } = deps(store, { status: 'error' });
  await assert.rejects(runSearch(req(), d2), SearchUnavailable);
});

test('long term: distance order, closed permanently dropped, radius 5 -> 10 km when fewer than 3', async () => {
  const store = new MemoryStore({ curated: [facility({ id: 'C1', ...at(7_000) })] });
  const places = [
    place({ placeId: 'p1', ...at(1_000) }),
    place({ placeId: 'gone', ...at(1_500), businessStatus: 'closed_permanently' }),
    place({ placeId: 'p2', ...at(4_000) }),
    place({ placeId: 'p3', ...at(9_000) }),
    place({ placeId: 'p4', ...at(15_000) }),
  ];
  const { d, provider } = deps(store, { status: 'ok', value: places });
  const { response } = await runSearch(req({ mode: 'long_term', radiusM: 5_000 }), d);
  assert.equal(provider.calls[0].radiusM, 20_000); // one call at the ladder's top
  assert.equal(response.radiusM, 10_000);
  assert.equal(response.expanded, true);
  assert.deepEqual(response.results.map((r) => r.key), ['g:p1', 'g:p2', 'f:C1', 'g:p3']);
});

test('long term: enough results in the first step, no expansion', async () => {
  const store = new MemoryStore();
  const places = [1_000, 2_000, 3_000, 8_000].map((m, i) => place({ placeId: `p${i}`, ...at(m) }));
  const { d } = deps(store, { status: 'ok', value: places });
  const { response } = await runSearch(req({ mode: 'long_term', radiusM: 5_000 }), d);
  assert.equal(response.radiusM, 5_000);
  assert.equal(response.expanded, false);
  assert.equal(response.results.length, 3);
});

test('curated records of another country are never mixed in', async () => {
  const store = new MemoryStore({
    curated: [facility({ id: 'zz', countryCode: 'ZZ', ...at(1_000), emergency: ADVERTISED }), ...curatedSet()],
  });
  const { d } = deps(store, { status: 'ok', value: [] });
  const { response } = await runSearch(req(), d);
  assert.ok(!response.results.some((r) => r.key === 'f:zz'));
});

test('a ZZ search uses ZZ ladders and echoes ZZ', async () => {
  const center = { lat: 10.5, lng: 20.5 };
  const store = new MemoryStore({ curated: [facility({ id: 'z1', countryCode: 'ZZ', ...offset(center, 20_000, 0), emergency: ADVERTISED })] });
  const { d } = deps(store, { status: 'ok', value: [] });
  const { response } = await runSearch(req({ region: ZZ, lat: center.lat, lng: center.lng, radiusM: 8_000, lang: 'fr' }), d);
  assert.equal(response.region, 'ZZ');
  assert.equal(response.radiusM, 30_000); // ZZ ladder 8 km -> 30 km
  assert.deepEqual(response.results.map((r) => r.key), ['f:z1']);
});

test('two Google listings linked to one facility show as ONE result, carried by the nearer listing', async () => {
  // The Hebrew University hospital case: the building and a street-address
  // pin ~770 m apart, both linked by an admin to the same facility.
  const curated = [facility({ id: 'H', name: 'Teaching Hospital', ...at(3_000), emergency: ADVERTISED, placeIds: ['pBuilding', 'pPin'] })];
  const store = new MemoryStore({ curated });
  const providerPlaces = [
    place({ placeId: 'pPin', name: 'Teaching Hospital near the junction', ...at(3_770) }),
    place({ placeId: 'pBuilding', name: 'Teaching Hospital', ...at(3_000) }),
  ];
  const { d } = deps(store, { status: 'ok', value: providerPlaces });
  const { response, linkCandidates } = await runSearch(req(), d);

  const forH = response.results.filter((r) => r.facilityId === 'H');
  assert.equal(forH.length, 1);
  assert.equal(forH[0].placeId, 'pBuilding'); // the nearer listing carries it
  assert.equal(forH[0].emergency.state, 'advertised');
  assert.equal(response.results.some((r) => r.key === 'g:pPin'), false); // no stray duplicate
  assert.equal(linkCandidates.length, 0);
});

test('an unlinked second listing of a linked facility stays a separate listing (until an admin links it)', async () => {
  const curated = [facility({ id: 'H', name: 'Teaching Hospital', ...at(3_000), emergency: ADVERTISED, placeIds: ['pBuilding'] })];
  const store = new MemoryStore({ curated });
  const providerPlaces = [
    place({ placeId: 'pBuilding', name: 'Teaching Hospital', ...at(3_000) }),
    place({ placeId: 'pPin', name: 'Teaching Hospital near the junction', ...at(3_770) }),
  ];
  const { d } = deps(store, { status: 'ok', value: providerPlaces });
  const { response } = await runSearch(req(), d);
  assert.equal(response.results.filter((r) => r.facilityId === 'H').length, 1);
  const pin = response.results.find((r) => r.key === 'g:pPin');
  assert.ok(pin, 'the second listing is still shown');
  assert.equal(pin!.fromCurated, false);
  assert.equal(pin!.emergency.state, 'not_listed'); // never inherits the claim by name
});

// Test helpers: builders, fakes and a made-up second region ('ZZ') that is
// passed to the code directly and NEVER registered, to prove that bounds,
// phone formats and words come from the RegionConfig and not from Israel.

import type { ProviderOutcome, PlacesProvider, NearbyQuery, ProviderPlace, GeocodeResult } from '../_shared/providers/types.ts';
import type { RegionLookup } from '../_shared/regions/index.ts';
import { IL } from '../_shared/regions/il.ts';
import type { RegionConfig } from '../_shared/regions/types.ts';
import type { WeeklyClaim, WeeklyFacility } from '../_shared/store.ts';
import type { CuratedFacility, VetResult } from '../_shared/types.ts';

/** Monday 2026-10-05 09:00 UTC (ISO week 2026-W41). */
export const NOW = new Date('2026-10-05T09:00:00Z');

export const JERUSALEM = { lat: 31.778, lng: 35.235 };

/** A fictional country: different box, calling code 99, trunk 8, French words. */
export const ZZ: RegionConfig = {
  code: 'ZZ',
  name: 'Testland',
  bounds: [{ minLat: 10, maxLat: 11, minLng: 20, maxLng: 21 }],
  provider: { regionCode: 'ZZ', geocodeComponents: 'country:ZZ' },
  defaultLanguage: 'fr',
  languages: ['fr'],
  radii: { emergencyCuratedM: [8_000, 30_000], longTermM: [4_000, 12_000] },
  phone: {
    countryCallingCode: '99',
    trunkPrefix: '8',
    scanPattern: String.raw`(?<!\d)(?:\+99|8)(?:[\s-]?\d){7}(?!\d)`,
  },
  nameStopWords: ['clinique', 'veterinaire', 'urgences', 'de', 'la'],
  nameStopWordPrefixes: [],
  streetWords: ['rue', 'avenue'],
  evidencePatterns: { emergency: ['urgences 24h'] },
  closureWords: ['fermé définitivement'],
  timeZone: 'UTC',
};

/** A lookup with Israel (as registered) plus extras for tests. */
export function lookupWith(...extra: RegionConfig[]): RegionLookup {
  const all = [IL, ...extra];
  return {
    get: (code: string) => all.find((r) => r.code === String(code).trim().toUpperCase()),
    list: () => all,
    defaultCode: 'IL',
  };
}

/** A point moved north/east by metres (good enough at city scale). */
export function offset(from: { lat: number; lng: number }, northM: number, eastM: number): { lat: number; lng: number } {
  const dLat = northM / 111_195;
  const dLng = eastM / (111_195 * Math.cos((from.lat * Math.PI) / 180));
  return { lat: from.lat + dLat, lng: from.lng + dLng };
}

export function facility(over: Partial<CuratedFacility> & { id: string }): CuratedFacility {
  return {
    countryCode: 'IL',
    name: `Facility ${over.id}`,
    nameHe: null,
    address: null,
    city: null,
    lat: JERUSALEM.lat,
    lng: JERUSALEM.lng,
    phone: null,
    website: null,
    facilityType: 'clinic',
    reviewStatus: 'approved',
    lastCheckedAt: '2026-10-01T00:00:00Z',
    lastConfirmedAt: '2026-09-01T00:00:00Z',
    emergency: null,
    facts: [],
    placeIds: [],
    ...over,
  };
}

export const ADVERTISED = {
  state: 'advertised' as const,
  schedule: '24/7',
  sourceUrl: 'https://vet.example.co.il/emergency',
  checkedAt: '2026-10-01T00:00:00Z',
  confirmedAt: '2026-09-01T00:00:00Z',
};

export const UNVERIFIED = { ...ADVERTISED, state: 'unverified' as const };

export function place(over: Partial<ProviderPlace> & { placeId: string }): ProviderPlace {
  return {
    name: `Place ${over.placeId}`,
    address: null,
    lat: JERUSALEM.lat,
    lng: JERUSALEM.lng,
    nationalPhone: null,
    internationalPhone: null,
    website: null,
    mapsUri: `https://maps.google.com/?cid=${over.placeId}`,
    businessStatus: 'operational',
    openNow: null,
    weekdayText: [],
    ...over,
  };
}

export interface FakeProvider extends PlacesProvider {
  calls: NearbyQuery[];
  geocodeCalls: { query: string; lang: string; region: string }[];
}

export function fakeProvider(
  nearby: ProviderOutcome<ProviderPlace[]>,
  geocode: ProviderOutcome<GeocodeResult[]> = { status: 'ok', value: [] },
): FakeProvider {
  const calls: NearbyQuery[] = [];
  const geocodeCalls: { query: string; lang: string; region: string }[] = [];
  return {
    name: 'google',
    enabled: true,
    attribution: 'Google Maps',
    calls,
    geocodeCalls,
    nearbyVets(q: NearbyQuery) {
      calls.push(q);
      return Promise.resolve(nearby);
    },
    geocode(query: string, lang: string, region: RegionConfig) {
      geocodeCalls.push({ query, lang, region: region.code });
      return Promise.resolve(geocode);
    },
  };
}

/** A finished VetResult for ranking tests. */
export function result(over: Partial<VetResult> & { key: string }): VetResult {
  return {
    facilityId: null,
    placeId: null,
    name: over.key,
    address: null,
    location: JERUSALEM,
    distanceM: 1000,
    phone: null,
    website: null,
    mapsUri: null,
    fromProvider: true,
    fromCurated: false,
    businessStatus: 'operational',
    emergency: { state: 'not_listed', schedule: null, sourceUrl: null, checkedAt: null, confirmedAt: null },
    open: { state: 'unknown', basis: 'none', weekdayText: [] },
    intake: { state: 'unknown', species: [], updatedAt: null, expiresAt: null },
    facts: [],
    lastCheckedAt: null,
    stale: false,
    reviewStatus: null,
    ...over,
  };
}

// --- weekly-job fixtures ----------------------------------------------------

export function claim(over: Partial<WeeklyClaim> & { id: string }): WeeklyClaim {
  return {
    key: 'emergency',
    value: { schedule: '24/7' },
    sourceUrl: 'https://vet.example.co.il/emergency',
    sourceKind: 'facility_site',
    status: 'current',
    evidencePatterns: ['24 שעות ביממה'],
    checkedAt: '2026-10-01T00:00:00Z',
    confirmedAt: '2026-09-01T00:00:00Z',
    createdAt: '2026-08-01T00:00:00Z',
    ...over,
  };
}

export function weeklyFacility(over: Partial<WeeklyFacility> & { id: string }): WeeklyFacility {
  return {
    countryCode: 'IL',
    name: `Facility ${over.id}`,
    phone: '+97239688588',
    website: 'https://vet.example.co.il/',
    reviewStatus: 'approved',
    lastCheckedAt: null,
    claims: [],
    ...over,
  };
}

export type Route = { status: number; body?: string } | 'timeout' | 'network';

/**
 * A fake fetch answering from a URL -> route table. Unknown URLs answer 404
 * (so robots.txt is "no rules" unless given). 'timeout' waits for the abort
 * signal; 'network' rejects at once. Every requested URL is recorded.
 */
export function fakeFetch(routes: Record<string, Route>) {
  const requested: string[] = [];
  const fn = (input: string, init?: RequestInit): Promise<Response> => {
    requested.push(input);
    const route = routes[input] ?? { status: 404, body: '' };
    if (route === 'network') return Promise.reject(new TypeError('network down'));
    if (route === 'timeout') {
      return new Promise((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')));
      });
    }
    return Promise.resolve(new Response(route.body ?? '', { status: route.status }));
  };
  return { fetch: fn, requested };
}

/** Wraps text in a minimal HTML page. */
export function html(text: string): string {
  return `<!doctype html><html><head><title>t</title><script>var x = "חירום 24/7";</script></head><body><p>${text}</p></body></html>`;
}

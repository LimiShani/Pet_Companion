// Google adapter: Places API (New) Nearby Search for vets, and the
// Geocoding API for typed addresses. Region specifics (regionCode, the
// geocode country filter, the bounding box) come from the RegionConfig.
//
// Cost note: with phone, website and hours in the field mask, Nearby Search
// bills at the Enterprise SKU, so the field mask is kept to exactly the
// fields the app shows and the function caps calls per day.

import { inAnyBox } from '../geo.ts';
import type { RegionConfig } from '../regions/types.ts';
import type { BusinessStatus } from '../types.ts';
import { PROVIDER_MAX_RADIUS_M } from '../validation.ts';
import type { GeocodeResult, NearbyQuery, PlacesProvider, ProviderOutcome, ProviderPlace } from './types.ts';

export const NEARBY_URL = 'https://places.googleapis.com/v1/places:searchNearby';
export const GEOCODE_URL = 'https://maps.googleapis.com/maps/api/geocode/json';
export const GOOGLE_TIMEOUT_MS = 6_000;
export const GOOGLE_MAX_RESULTS = 20;
export const GOOGLE_ATTRIBUTION = 'Google Maps';

/** Exactly the fields we show; anything more costs money and is not needed. */
export const NEARBY_FIELD_MASK = [
  'places.id',
  'places.displayName',
  'places.formattedAddress',
  'places.location',
  'places.nationalPhoneNumber',
  'places.internationalPhoneNumber',
  'places.websiteUri',
  'places.googleMapsUri',
  'places.businessStatus',
  'places.currentOpeningHours.openNow',
  'places.currentOpeningHours.weekdayDescriptions',
].join(',');

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export interface GoogleProviderOptions {
  apiKey: string;
  fetch?: FetchLike;
  timeoutMs?: number;
}

const BUSINESS_STATUS: Record<string, BusinessStatus> = {
  OPERATIONAL: 'operational',
  CLOSED_TEMPORARILY: 'closed_temporarily',
  CLOSED_PERMANENTLY: 'closed_permanently',
};

const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);

/** Maps one Places API (New) place to the provider-neutral shape (null if unusable). */
export function mapGooglePlace(p: unknown): ProviderPlace | null {
  if (typeof p !== 'object' || p === null) return null;
  const o = p as Record<string, any>;
  const id = str(o.id);
  const lat = o.location?.latitude;
  const lng = o.location?.longitude;
  if (id === null || typeof lat !== 'number' || typeof lng !== 'number') return null;
  const hours = o.currentOpeningHours;
  return {
    placeId: id,
    name: str(o.displayName?.text) ?? '',
    address: str(o.formattedAddress),
    lat,
    lng,
    nationalPhone: str(o.nationalPhoneNumber),
    internationalPhone: str(o.internationalPhoneNumber),
    website: str(o.websiteUri),
    mapsUri: str(o.googleMapsUri),
    businessStatus: BUSINESS_STATUS[o.businessStatus as string] ?? null,
    openNow: typeof hours?.openNow === 'boolean' ? hours.openNow : null,
    weekdayText: Array.isArray(hours?.weekdayDescriptions)
      ? hours.weekdayDescriptions.filter((d: unknown): d is string => typeof d === 'string')
      : [],
  };
}

/** The Nearby Search request body (exported so tests can pin it). */
export function nearbyBody(q: NearbyQuery): Record<string, unknown> {
  return {
    includedTypes: ['veterinary_care'],
    maxResultCount: Math.max(1, Math.min(GOOGLE_MAX_RESULTS, Math.floor(q.maxResults))),
    rankPreference: 'DISTANCE',
    locationRestriction: {
      circle: {
        center: { latitude: q.lat, longitude: q.lng },
        radius: Math.min(PROVIDER_MAX_RADIUS_M, q.radiusM),
      },
    },
    languageCode: q.lang,
    regionCode: q.region.provider.regionCode,
  };
}

/** The geocode URL (exported so tests can pin it). */
export function geocodeUrl(query: string, lang: string, region: RegionConfig, apiKey: string): string {
  const u = new URL(GEOCODE_URL);
  u.searchParams.set('address', query);
  u.searchParams.set('components', region.provider.geocodeComponents);
  u.searchParams.set('region', region.provider.regionCode.toLowerCase());
  u.searchParams.set('language', lang);
  u.searchParams.set('key', apiKey);
  return u.toString();
}

/**
 * Runs a fetch with a hard timeout. Never puts the URL, key or body in an
 * error message (the URL carries the key and the user's query).
 */
async function timedFetch<T>(
  doFetch: FetchLike,
  url: string,
  init: RequestInit,
  timeoutMs: number,
  read: (res: Response) => Promise<ProviderOutcome<T>>,
): Promise<ProviderOutcome<T>> {
  const ctrl = new AbortController();
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    ctrl.abort();
  }, timeoutMs);
  try {
    const res = await doFetch(url, { ...init, signal: ctrl.signal });
    return await read(res);
  } catch (_e) {
    return timedOut ? { status: 'timeout' } : { status: 'error', detail: 'network' };
  } finally {
    clearTimeout(timer);
  }
}

export function createGoogleProvider(opts: GoogleProviderOptions): PlacesProvider {
  const doFetch: FetchLike = opts.fetch ?? ((input, init) => fetch(input, init));
  const timeoutMs = opts.timeoutMs ?? GOOGLE_TIMEOUT_MS;

  return {
    name: 'google',
    enabled: true,
    attribution: GOOGLE_ATTRIBUTION,

    nearbyVets(q: NearbyQuery): Promise<ProviderOutcome<ProviderPlace[]>> {
      return timedFetch(
        doFetch,
        NEARBY_URL,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': opts.apiKey,
            'X-Goog-FieldMask': NEARBY_FIELD_MASK,
          },
          body: JSON.stringify(nearbyBody(q)),
        },
        timeoutMs,
        async (res) => {
          if (res.status === 429) return { status: 'quota', detail: 'http 429' };
          if (!res.ok) return { status: 'error', detail: `http ${res.status}` };
          const json = (await res.json()) as { places?: unknown[] };
          const places = Array.isArray(json?.places) ? json.places : [];
          const mapped = places.map(mapGooglePlace).filter((p): p is ProviderPlace => p !== null);
          return { status: 'ok', value: mapped };
        },
      );
    },

    geocode(query: string, lang: string, region: RegionConfig): Promise<ProviderOutcome<GeocodeResult[]>> {
      return timedFetch(
        doFetch,
        geocodeUrl(query, lang, region, opts.apiKey),
        { method: 'GET' },
        timeoutMs,
        async (res) => {
          if (res.status === 429) return { status: 'quota', detail: 'http 429' };
          if (!res.ok) return { status: 'error', detail: `http ${res.status}` };
          const json = (await res.json()) as { status?: string; results?: any[] };
          switch (json?.status) {
            case 'OK':
              break;
            case 'ZERO_RESULTS':
              return { status: 'ok', value: [] };
            case 'OVER_QUERY_LIMIT':
            case 'OVER_DAILY_LIMIT':
              return { status: 'quota', detail: json.status };
            default:
              // REQUEST_DENIED, INVALID_REQUEST, UNKNOWN_ERROR...
              return { status: 'error', detail: String(json?.status ?? 'unknown') };
          }
          const out: GeocodeResult[] = [];
          for (const r of Array.isArray(json.results) ? json.results : []) {
            const lat = r?.geometry?.location?.lat;
            const lng = r?.geometry?.location?.lng;
            const label = str(r?.formatted_address);
            // The components filter is a strong hint, not a guarantee: keep
            // only points inside the region.
            if (label === null || typeof lat !== 'number' || typeof lng !== 'number') continue;
            if (!inAnyBox(region.bounds, lat, lng)) continue;
            out.push({ label, lat, lng });
            if (out.length === 5) break;
          }
          return { status: 'ok', value: out };
        },
      );
    },
  };
}

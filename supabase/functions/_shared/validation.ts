// Request validation for the find-vet function. Everything country-specific
// (bounds, languages, radius ladders) comes from the request's region.

import { inAnyBox } from './geo.ts';
import type { RegionLookup } from './regions/index.ts';
import type { RegionConfig } from './regions/types.ts';
import type { Mode } from './types.ts';

/** Smallest search radius a request may ask for. */
export const MIN_RADIUS_M = 500;
/** Places API (New) refuses circles above 50 km. */
export const PROVIDER_MAX_RADIUS_M = 50_000;
export const QUERY_MIN_LENGTH = 2;
export const QUERY_MAX_LENGTH = 120;

export const MODES: readonly Mode[] = ['emergency', 'long_term'];
export const ACTIONS = ['search', 'geocode', 'regions'] as const;

export interface SearchRequest {
  action: 'search';
  region: RegionConfig;
  mode: Mode;
  lat: number;
  lng: number;
  radiusM: number;
  lang: string;
}

export interface GeocodeRequest {
  action: 'geocode';
  region: RegionConfig;
  query: string;
  lang: string;
}

export interface RegionsRequest {
  action: 'regions';
}

export type ValidRequest = SearchRequest | GeocodeRequest | RegionsRequest;

export type ValidationResult =
  | { ok: true; request: ValidRequest }
  | { ok: false; error: 'invalid_request' | 'unsupported_region'; detail: string };

const bad = (detail: string): ValidationResult => ({ ok: false, error: 'invalid_request', detail });

/** True when the point is inside one of the region's bounding boxes. */
export function inRegion(region: RegionConfig, lat: number, lng: number): boolean {
  return inAnyBox(region.bounds, lat, lng);
}

/**
 * Largest radius a request may ask for: emergency searches reach the last
 * step of the region's curated ladder (the provider part is still capped at
 * 50 km); long-term searches stop at the provider cap.
 */
export function maxRadiusFor(mode: Mode, region: RegionConfig): number {
  if (mode === 'emergency') {
    const ladder = region.radii.emergencyCuratedM;
    return Math.max(PROVIDER_MAX_RADIUS_M, ladder[ladder.length - 1]);
  }
  return PROVIDER_MAX_RADIUS_M;
}

/** Radius used when the request does not give one: the ladder's first step. */
export function defaultRadiusFor(mode: Mode, region: RegionConfig): number {
  return mode === 'emergency' ? region.radii.emergencyCuratedM[0] : region.radii.longTermM[0];
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/**
 * Validates a parsed JSON body. The region is resolved first, so an unknown
 * region answers `unsupported_region` whatever else is wrong.
 */
export function parseRequest(body: unknown, regions: RegionLookup): ValidationResult {
  if (!isObject(body)) return bad('body must be a JSON object');
  const action = body.action;
  if (typeof action !== 'string' || !(ACTIONS as readonly string[]).includes(action)) {
    return bad('action must be one of search, geocode, regions');
  }
  if (action === 'regions') return { ok: true, request: { action: 'regions' } };

  // Region: optional, ISO 3166-1 alpha-2, default from the registry.
  let regionCode = regions.defaultCode;
  if (body.region !== undefined && body.region !== null) {
    if (typeof body.region !== 'string') return bad('region must be an ISO 3166-1 alpha-2 string');
    regionCode = body.region;
  }
  const region = /^[A-Za-z]{2}$/.test(regionCode.trim()) ? regions.get(regionCode) : undefined;
  if (region === undefined) {
    return { ok: false, error: 'unsupported_region', detail: 'region is not served' };
  }

  // Language: optional, one of the region's languages.
  let lang = region.defaultLanguage;
  if (body.lang !== undefined && body.lang !== null) {
    if (typeof body.lang !== 'string' || !region.languages.includes(body.lang)) {
      return bad(`lang must be one of ${region.languages.join(', ')}`);
    }
    lang = body.lang;
  }

  if (action === 'geocode') {
    if (typeof body.query !== 'string') return bad('query must be a string');
    const query = body.query.trim().replace(/\s+/g, ' ');
    if (query.length < QUERY_MIN_LENGTH || query.length > QUERY_MAX_LENGTH) {
      return bad(`query must be ${QUERY_MIN_LENGTH}-${QUERY_MAX_LENGTH} characters`);
    }
    return { ok: true, request: { action: 'geocode', region, query, lang } };
  }

  // search
  const mode = body.mode;
  if (typeof mode !== 'string' || !(MODES as readonly string[]).includes(mode)) {
    return bad('mode must be emergency or long_term');
  }
  const { lat, lng } = body;
  if (typeof lat !== 'number' || typeof lng !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lng)) {
    return bad('lat and lng must be numbers');
  }
  if (!inRegion(region, lat, lng)) return bad(`coordinates are outside ${region.code}`);

  let radiusM = defaultRadiusFor(mode as Mode, region);
  if (body.radiusM !== undefined && body.radiusM !== null) {
    if (typeof body.radiusM !== 'number' || !Number.isFinite(body.radiusM)) return bad('radiusM must be a number');
    radiusM = Math.round(body.radiusM);
  }
  const max = maxRadiusFor(mode as Mode, region);
  if (radiusM < MIN_RADIUS_M || radiusM > max) return bad(`radiusM must be ${MIN_RADIUS_M}-${max}`);

  return { ok: true, request: { action: 'search', region, mode: mode as Mode, lat, lng, radiusM, lang } };
}

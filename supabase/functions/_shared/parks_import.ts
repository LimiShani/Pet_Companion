// The monthly dog parks import (docs/dog_parks.md, "Import").
//
// One Overpass query asks OpenStreetMap for every leisure=dog_park inside
// Israel's boundary and around the Israeli localities of Judea and Samaria
// (outside that boundary), and the named streets around them. Each
// park becomes one row: its names, the nearest named street (an unnamed
// park shows as "Dog park · <street>"), its centre, the nearest locality
// of the app's list, the six details OSM may know (fence, water, shade,
// light, small-dog area, benches) and the opening hours. The rows go to
// dog_parks_import() in one call, which merges them (new parks added,
// locked fields kept, vanished parks to review, nothing deleted) and
// records the month's run.
//
// Usage policy (https://wiki.openstreetmap.org/wiki/Overpass_API): one
// query a month, an honest User-Agent, a server-side timeout, no retries in
// a loop. Data (c) OpenStreetMap contributors, ODbL: the app credits it on
// every park page and in Settings > About PetLoop.
//
// Idempotent: a month that already succeeded is not downloaded again
// unless forced.

import { distanceM } from './geo.ts';
import type { LatLng } from './geo.ts';
import { errorResponse, json, preflight, readJson } from './http.ts';
import { localityByCode, nearestLocality } from './localities.ts';
import { IL_JUDEA_SAMARIA_CODES, IL_JUDEA_SAMARIA_REACH_M, IL_LOCALITIES } from './regions/il_localities.ts';
import type { Locality } from './regions/types.ts';
import { constantTimeEqual } from './weekly.ts';

export const PARKS_JOB = 'parks-import';
export const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';
export const USER_AGENT =
  'PetLoopParksImport/1.0 (+https://github.com/LimiShani/Pet_Companion; monthly import of leisure=dog_park in Israel)';
/**
 * overpass-api.de answers 406 to a request without a User-Agent unless it
 * names a Referer, and the Edge Runtime may not pass our User-Agent on
 * (the first live run got 406 while the same request from a PC got 200).
 */
export const REFERER = 'https://github.com/LimiShani/Pet_Companion';
/** Another public instance, tried once when the first refuses or is busy. */
export const FALLBACK_OVERPASS_URL = 'https://maps.mail.ru/osm/tools/overpass/api/interpreter';
/** Only try the fallback if the first attempt failed within this time. */
export const FALLBACK_WITHIN_MS = 60_000;
/** The server stops the query after this many seconds; we wait a little longer. */
export const OVERPASS_TIMEOUT_S = 90;
export const FETCH_TIMEOUT_MS = 120_000;
/** Streets further than this from every point of a park's outline do not name it. */
export const STREET_RADIUS_M = 100;
/** A park further than this from every locality gets no locality code. */
export const LOCALITY_RADIUS_M = 15_000;

/**
 * Parks within this distance of an Israeli locality of Judea and Samaria
 * are imported too: the towns lie outside OSM's boundary of Israel. Large
 * enough for the biggest of them (Ma'ale Adumim, Ariel: about 2.5 km from
 * the centre to the edge), small enough to stay out of the neighbouring
 * towns. Generated with the list (tool/gen_il_localities.py); the app's
 * entries carry the same value as `reachM`.
 */
export const AROUND_LOCALITY_M = IL_JUDEA_SAMARIA_REACH_M;

/** The centres of the Israeli localities of Judea and Samaria (il_localities.ts). */
export const JUDEA_SAMARIA_CENTRES: readonly LatLng[] = Object.freeze(
  IL_JUDEA_SAMARIA_CODES.map((code) => {
    const l = localityByCode(IL_LOCALITIES, code);
    if (!l) throw new Error(`unknown locality ${code}`);
    return { lat: l.lat, lng: l.lng };
  }),
);

/** The vehicle and pedestrian streets that may name a park (not paths or service roads). */
const STREET_KINDS = 'primary|secondary|tertiary|residential|living_street|unclassified|pedestrian';
/** Asked of Overpass up front; a smaller budget is admitted sooner on a busy server. */
export const OVERPASS_MAXSIZE_BYTES = 64 * 1024 * 1024;

/**
 * The one query: the parks (with their centres), then the named streets
 * near any point of any park (a node park, or the outline of a way or a
 * multipolygon). "around" over points is cheap for Overpass; over the
 * park polygons themselves, or park by park in a foreach, it is slow
 * enough that the public servers refuse it (504, checked 2026-10-10).
 * Each park's nearest street is picked afterwards (parseOverpass).
 *
 * The parks are those inside the country's boundary plus those within
 * AROUND_LOCALITY_M of each point of [around] (by default the Israeli
 * localities of Judea and Samaria); a park in both is listed once.
 */
export function overpassQuery(countryCode = 'IL', around: readonly LatLng[] = JUDEA_SAMARIA_CENTRES): string {
  const near = around.map((p) => `nwr[leisure=dog_park](around:${AROUND_LOCALITY_M},${p.lat},${p.lng});`).join('');
  return [
    `[out:json][timeout:${OVERPASS_TIMEOUT_S}][maxsize:${OVERPASS_MAXSIZE_BYTES}];`,
    `area["ISO3166-1"="${countryCode}"][admin_level=2]->.country;`,
    `(nwr[leisure=dog_park](area.country);${near})->.parks;`,
    '.parks out tags center;',
    'node.parks->.p1;',
    'node(w.parks)->.p2;',
    'way(r.parks)->.rw;',
    'node(w.rw)->.p3;',
    '(.p1;.p2;.p3;)->.points;',
    `way(around.points:${STREET_RADIUS_M})[highway~"^(${STREET_KINDS})$"][name];`,
    'out tags geom;',
  ].join('');
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

type Tags = Record<string, string>;

interface OsmElement {
  type: string;
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  geometry?: { lat: number; lon: number }[];
  tags?: Tags;
}

export interface OsmStreet {
  tags: Tags;
  geometry: LatLng[];
}

export interface OsmPark {
  sourceId: string;
  center: LatLng;
  tags: Tags;
  /** The named streets that may name it (within a few hundred metres). */
  streets: OsmStreet[];
}

/** How far from a park's centre a street may be to be its candidate. */
export const STREET_CANDIDATE_M = 400;

/** The parks of an Overpass answer, each with the streets near it. */
export function parseOverpass(answer: unknown): OsmPark[] {
  const elements = (answer as { elements?: OsmElement[] } | null)?.elements;
  if (!Array.isArray(elements)) throw new Error('not an Overpass answer');
  const parks = new Map<string, OsmPark>();
  const streets: (OsmStreet & { box: { minLat: number; maxLat: number; minLng: number; maxLng: number } })[] = [];
  for (const e of elements) {
    const tags = e.tags ?? {};
    if (tags.leisure === 'dog_park') {
      const lat = e.type === 'node' ? e.lat : e.center?.lat;
      const lng = e.type === 'node' ? e.lon : e.center?.lon;
      if (typeof lat !== 'number' || typeof lng !== 'number') continue;
      const sourceId = `${e.type}/${e.id}`;
      if (!parks.has(sourceId)) parks.set(sourceId, { sourceId, center: { lat, lng }, tags, streets: [] });
    } else if (tags.highway && tags.name && Array.isArray(e.geometry) && e.geometry.length > 0) {
      const geometry = e.geometry.map((g) => ({ lat: g.lat, lng: g.lon }));
      streets.push({
        tags,
        geometry,
        box: {
          minLat: Math.min(...geometry.map((g) => g.lat)),
          maxLat: Math.max(...geometry.map((g) => g.lat)),
          minLng: Math.min(...geometry.map((g) => g.lng)),
          maxLng: Math.max(...geometry.map((g) => g.lng)),
        },
      });
    }
  }
  // A cheap box test first: only streets whose box comes within
  // STREET_CANDIDATE_M of the park's centre are measured.
  const dLat = STREET_CANDIDATE_M / 111_320;
  for (const park of parks.values()) {
    const dLng = dLat / Math.max(0.01, Math.cos((park.center.lat * Math.PI) / 180));
    for (const street of streets) {
      const b = street.box;
      if (
        b.maxLat >= park.center.lat - dLat && b.minLat <= park.center.lat + dLat &&
        b.maxLng >= park.center.lng - dLng && b.minLng <= park.center.lng + dLng
      ) {
        park.streets.push({ tags: street.tags, geometry: street.geometry });
      }
    }
  }
  return [...parks.values()];
}

// ---------------------------------------------------------------------------
// One park, one row
// ---------------------------------------------------------------------------

export type TriState = 'yes' | 'no' | 'unknown';

export interface ParkRow {
  source_id: string;
  name_he: string | null;
  name_en: string | null;
  street_he: string | null;
  street_en: string | null;
  lat: number;
  lng: number;
  locality_code: string | null;
  fenced: TriState;
  water: TriState;
  shade: TriState;
  lighting: TriState;
  small_dogs: TriState;
  benches: TriState;
  opening_hours: string | null;
}

const HEBREW = /[א-ת]/;
const LATIN = /[A-Za-z]/;

/** The Hebrew and English forms of a name: name:he / name:en, else `name` by its script. */
export function namesOf(tags: Tags): { he: string | null; en: string | null } {
  const plain = tags.name?.trim() || null;
  const he = tags['name:he']?.trim() || (plain && HEBREW.test(plain) ? plain : null);
  const en = tags['name:en']?.trim() || (plain && !HEBREW.test(plain) && LATIN.test(plain) ? plain : null);
  return { he, en };
}

/** 'yes' / 'no' for the usual OSM spellings, else 'unknown'. */
export function tri(value: string | undefined): TriState {
  const v = value?.trim().toLowerCase();
  if (v === undefined || v === '') return 'unknown';
  if (['yes', 'true', '1', 'separate', 'partial', 'limited'].includes(v)) return 'yes';
  if (['no', 'false', '0', 'none'].includes(v)) return 'no';
  return 'unknown';
}

/** The six details, from the tags OSM mappers use for them. */
export function detailsOf(tags: Tags): Pick<ParkRow, 'fenced' | 'water' | 'shade' | 'lighting' | 'small_dogs' | 'benches'> {
  const fenced = tri(tags.fenced ?? tags.fence) !== 'unknown'
    ? tri(tags.fenced ?? tags.fence)
    : tags.barrier === 'fence' || tags.barrier === 'wall'
    ? 'yes'
    : 'unknown';
  return {
    fenced,
    water: tri(tags.drinking_water),
    shade: tri(tags.shade ?? tags.covered),
    lighting: tri(tags.lit),
    small_dogs: tri(tags.small_dog ?? tags.small_dogs ?? tags['dog_park:small_dogs']),
    benches: tri(tags.bench ?? tags.benches),
  };
}

/** Metres from a point to a polyline (equirectangular, fine at street scale). */
export function distanceToLineM(point: LatLng, line: LatLng[]): number {
  if (line.length === 0) return Infinity;
  if (line.length === 1) return distanceM(point, line[0]);
  const mPerLat = 111_320;
  const mPerLng = 111_320 * Math.cos((point.lat * Math.PI) / 180);
  const xy = (p: LatLng) => ({ x: (p.lng - point.lng) * mPerLng, y: (p.lat - point.lat) * mPerLat });
  let best = Infinity;
  for (let i = 1; i < line.length; i++) {
    const a = xy(line[i - 1]);
    const b = xy(line[i]);
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len2 = dx * dx + dy * dy;
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, -(a.x * dx + a.y * dy) / len2));
    const d = Math.hypot(a.x + t * dx, a.y + t * dy);
    if (d < best) best = d;
  }
  return best;
}

/** The named street closest to the park's centre, or undefined. */
export function nearestStreet(park: OsmPark): OsmStreet | undefined {
  let best: OsmStreet | undefined;
  let bestM = Infinity;
  for (const street of park.streets) {
    const m = distanceToLineM(park.center, street.geometry);
    if (m < bestM) {
      best = street;
      bestM = m;
    }
  }
  return best;
}

const round = (n: number) => Math.round(n * 1e6) / 1e6;

const JUDEA_SAMARIA = new Set(IL_JUDEA_SAMARIA_CODES);

/**
 * The park's locality: the nearest centre within LOCALITY_RADIUS_M, except
 * that a locality of Judea and Samaria ([reachLimited]) claims only the
 * parks within AROUND_LOCALITY_M of its centre. Further out, the nearest
 * other locality is taken (when there is one), so Jerusalem's eastern
 * neighbourhoods (Pisgat Ze'ev, 7.0 km from Ma'ale Adumim's centre and
 * 7.2 km from Jerusalem's) stay in Jerusalem. The app's
 * VetRegion.nearestLocality applies the same rule.
 */
export function parkLocality(
  localities: readonly Locality[],
  point: LatLng,
  reachLimited: ReadonlySet<string> = JUDEA_SAMARIA,
): Locality | undefined {
  const nearest = nearestLocality(localities, point, LOCALITY_RADIUS_M);
  if (!nearest || !reachLimited.has(nearest.code) || distanceM(point, nearest) <= AROUND_LOCALITY_M) return nearest;
  return nearestLocality(localities.filter((l) => !reachLimited.has(l.code)), point, LOCALITY_RADIUS_M) ?? nearest;
}

export function parkRow(park: OsmPark, localities: readonly Locality[]): ParkRow {
  const names = namesOf(park.tags);
  const street = nearestStreet(park);
  const streetNames = street ? namesOf(street.tags) : { he: null, en: null };
  const hours = park.tags.opening_hours?.trim() || null;
  return {
    source_id: park.sourceId,
    name_he: names.he,
    name_en: names.en,
    street_he: streetNames.he,
    street_en: streetNames.en,
    lat: round(park.center.lat),
    lng: round(park.center.lng),
    locality_code: parkLocality(localities, park.center)?.code ?? null,
    ...detailsOf(park.tags),
    opening_hours: hours ? hours.slice(0, 200) : null,
  };
}

// ---------------------------------------------------------------------------
// The run
// ---------------------------------------------------------------------------

export interface ImportRunRow {
  period_key: string;
  status: 'running' | 'succeeded' | 'failed';
  stats: Record<string, unknown>;
  error: string | null;
}

/** Where the rows go: the database (PostgREST) or memory in tests. */
export interface ParksImportStore {
  getRun(period: string): Promise<ImportRunRow | null>;
  saveFailedRun(period: string, error: string): Promise<void>;
  /** dog_parks_import(): merges and records the succeeded run; returns its stats. */
  importParks(period: string, rows: ParkRow[], force: boolean): Promise<Record<string, unknown>>;
}

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export interface ParksImportDeps {
  store: ParksImportStore;
  fetch: FetchLike;
  now: () => Date;
  localities: readonly Locality[];
  overpassUrl?: string;
  /** Tried once after a refusal (406/429) or a busy answer (5xx) from [overpassUrl]. */
  fallbackUrl?: string;
  timeoutMs?: number;
  log?: (line: string) => void;
}

export interface ParksImportResult {
  status: 'succeeded' | 'failed';
  period: string;
  reused: boolean;
  stats: Record<string, unknown>;
  error?: string;
}

/** The month of a date in UTC, e.g. '2026-10'. */
export function periodKey(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

async function download(deps: ParksImportDeps): Promise<unknown> {
  const started = Date.now();
  try {
    return await downloadFrom(deps.overpassUrl ?? OVERPASS_URL, deps);
  } catch (e) {
    const first = message(e);
    const retryable = /^overpass_http_(406|429|5\d\d)$/.test(first);
    if (!deps.fallbackUrl || !retryable || Date.now() - started > FALLBACK_WITHIN_MS) throw e;
    (deps.log ?? console.log)(`parks-import: ${first} from the first Overpass server, trying the fallback`);
    try {
      return await downloadFrom(deps.fallbackUrl, deps);
    } catch (e2) {
      throw new Error(`${first}; fallback ${message(e2)}`);
    }
  }
}

async function downloadFrom(url: string, deps: ParksImportDeps): Promise<unknown> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), deps.timeoutMs ?? FETCH_TIMEOUT_MS);
  try {
    const res = await deps.fetch(url, {
      method: 'POST',
      headers: {
        'User-Agent': USER_AGENT,
        Referer: REFERER,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: new URLSearchParams({ data: overpassQuery() }).toString(),
      signal: controller.signal,
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`overpass_http_${res.status}`);
    // Overpass reports a server-side timeout inside a 200 answer.
    if (text.includes('"remark"') && /runtime error|timed out/i.test(text)) throw new Error('overpass_timeout');
    return JSON.parse(text);
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw new Error('overpass_timeout');
    if (e instanceof SyntaxError) throw new Error('overpass_bad_answer');
    throw e;
  } finally {
    clearTimeout(timer);
  }
}

const message = (e: unknown) => (e instanceof Error ? e.message : String(e)).slice(0, 300);

export async function runParksImport(deps: ParksImportDeps, opts: { force?: boolean } = {}): Promise<ParksImportResult> {
  const log = deps.log ?? console.log;
  const period = periodKey(deps.now());
  const force = opts.force === true;
  const previous = await deps.store.getRun(period);
  if (previous?.status === 'succeeded' && !force) {
    return { status: 'succeeded', period, reused: true, stats: previous.stats };
  }
  let rows: ParkRow[];
  try {
    const parks = parseOverpass(await download(deps));
    rows = parks.map((p) => parkRow(p, deps.localities));
    if (rows.length === 0) throw new Error('empty_download');
  } catch (e) {
    const error = message(e);
    await deps.store.saveFailedRun(period, error);
    log(JSON.stringify({ job: PARKS_JOB, period, status: 'failed', error }));
    return { status: 'failed', period, reused: false, stats: {}, error };
  }
  try {
    const stats = await deps.store.importParks(period, rows, force);
    const named = rows.filter((r) => r.name_he || r.name_en).length;
    const byStreet = rows.filter((r) => !r.name_he && !r.name_en && (r.street_he || r.street_en)).length;
    const result = { ...stats, named, namedByStreet: byStreet, withoutLocality: rows.filter((r) => !r.locality_code).length };
    log(JSON.stringify({ job: PARKS_JOB, period, status: 'succeeded', ...result }));
    return { status: 'succeeded', period, reused: false, stats: result };
  } catch (e) {
    const error = message(e);
    await deps.store.saveFailedRun(period, error);
    log(JSON.stringify({ job: PARKS_JOB, period, status: 'failed', error }));
    return { status: 'failed', period, reused: false, stats: {}, error };
  }
}

export interface ParksImportHandlerDeps extends ParksImportDeps {
  jobSecret: string;
}

/** POST with `x-job-secret`; body `{}` or `{"force": true}`. */
export function createParksImportHandler(deps: ParksImportHandlerDeps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return preflight();
    if (req.method !== 'POST') return errorResponse('method_not_allowed');
    if (deps.jobSecret === '') return errorResponse('unavailable');
    const given = req.headers.get('x-job-secret') ?? '';
    if (!constantTimeEqual(given, deps.jobSecret)) return errorResponse('unauthorized');
    const body = await readJson(req);
    const force = typeof body === 'object' && body !== null && (body as Record<string, unknown>).force === true;
    try {
      const result = await runParksImport(deps, { force });
      return json(result.status === 'succeeded' ? 200 : 502, result);
    } catch (e) {
      (deps.log ?? console.error)(JSON.stringify({ job: PARKS_JOB, error: message(e) }));
      return json(500, { error: 'job_failed' });
    }
  };
}

// ---------------------------------------------------------------------------
// Stores
// ---------------------------------------------------------------------------

/** A failed database call; names the path and status, never values. */
export class ParksStoreError extends Error {
  status: number;
  constructor(text: string, status: number) {
    super(text);
    this.name = 'ParksStoreError';
    this.status = status;
  }
}

export function createPostgrestParksStore(opts: { url: string; serviceKey: string; fetch?: FetchLike }): ParksImportStore {
  const base = opts.url.replace(/\/+$/, '') + '/rest/v1';
  const doFetch: FetchLike = opts.fetch ?? ((input, init) => fetch(input, init));
  const headers = (extra: Record<string, string> = {}) => ({
    apikey: opts.serviceKey,
    Authorization: `Bearer ${opts.serviceKey}`,
    Accept: 'application/json',
    'Content-Type': 'application/json',
    ...extra,
  });
  async function call(method: string, path: string, body?: unknown, extra?: Record<string, string>): Promise<any> {
    const res = await doFetch(`${base}/${path}`, {
      method,
      headers: headers(extra),
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    if (!res.ok) {
      // PostgREST puts the raised message ('suspicious_import') in "message".
      let reason = '';
      try {
        reason = String(JSON.parse(text)?.message ?? '').slice(0, 80);
      } catch (_e) {
        reason = '';
      }
      throw new ParksStoreError(`${method} ${path.split('?')[0]} failed${reason ? `: ${reason}` : ''}`, res.status);
    }
    return text === '' ? null : JSON.parse(text);
  }
  return {
    async getRun(period) {
      const rows = await call('GET', `dog_park_import_runs?select=period_key,status,stats,error&period_key=eq.${encodeURIComponent(period)}`);
      return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
    },
    async saveFailedRun(period, error) {
      await call(
        'POST',
        'dog_park_import_runs?on_conflict=period_key',
        { period_key: period, status: 'failed', error, finished_at: new Date().toISOString() },
        { Prefer: 'resolution=merge-duplicates,return=minimal' },
      );
    },
    async importParks(period, rows, force) {
      return await call('POST', 'rpc/dog_parks_import', { p_period: period, p_parks: rows, p_force: force });
    },
  };
}

/** In memory, for the tests: keeps runs and the last import's rows. */
export class MemoryParksStore implements ParksImportStore {
  runs = new Map<string, ImportRunRow>();
  imported: { period: string; rows: ParkRow[]; force: boolean }[] = [];
  failWith?: string;

  async getRun(period: string) {
    return this.runs.get(period) ?? null;
  }
  async saveFailedRun(period: string, error: string) {
    this.runs.set(period, { period_key: period, status: 'failed', stats: {}, error });
  }
  async importParks(period: string, rows: ParkRow[], force: boolean) {
    if (this.failWith) throw new ParksStoreError(`POST rpc/dog_parks_import failed: ${this.failWith}`, 400);
    this.imported.push({ period, rows, force });
    const stats = { received: rows.length, accepted: rows.length, added: rows.length, refreshed: 0, reappeared: 0, vanished: 0 };
    this.runs.set(period, { period_key: period, status: 'succeeded', stats, error: null });
    return stats;
  }
}

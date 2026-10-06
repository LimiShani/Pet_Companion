// The find-vet request handler, built from injected dependencies so the
// tests can call it with plain Request objects. find-vet/index.ts only reads
// the environment and passes real dependencies in.
//
// Privacy: this file never logs coordinates, queries or IPs. Errors are
// logged by kind only.

import { errorResponse, json, preflight, readJson } from './http.ts';
import type { PlacesProvider } from './providers/types.ts';
import {
  CLIENT_LIMIT,
  CLIENT_WINDOW_MINUTES,
  clientBucket,
  GEOCODE_BUCKET,
  PLACES_BUCKET,
} from './quota.ts';
import type { RegionLookup } from './regions/index.ts';
import { runSearch, SearchUnavailable } from './search.ts';
import type { DirectoryStore } from './store.ts';
import { parseRequest } from './validation.ts';

export interface FindVetDeps {
  authorize: (request: Request) => Promise<boolean>;
  provider: PlacesProvider;
  store: DirectoryStore;
  regions: RegionLookup;
  now: () => Date;
  /** Server-only secret mixed into the client hash (never the raw IP). */
  quotaSecret: string;
  /** Provider calls per UTC day (Nearby Search). */
  dailyPlacesCap: number;
  /** Geocoding calls per UTC day. */
  dailyGeocodeCap: number;
  log?: (line: string) => void;
}

export function createFindVetHandler(deps: FindVetDeps): (req: Request) => Promise<Response> {
  const log = deps.log ?? ((line: string) => console.error(line));

  /** A daily provider cap as the search's gate. */
  const gate = (bucket: string, cap: number) => async (): Promise<'ok' | 'quota' | 'error'> => {
    try {
      return (await deps.store.takeQuota(bucket, null, 1440, cap)) ? 'ok' : 'quota';
    } catch (_e) {
      log(JSON.stringify({ fn: 'find-vet', event: 'quota_store_error' }));
      return 'error';
    }
  };

  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return preflight();
    if (req.method !== 'POST') return errorResponse('method_not_allowed');

    try {
      if (!await deps.authorize(req)) return json(403, { error: 'feature_denied' });
    } catch (_) { return json(503, { error: 'unavailable' }); }

    const body = await readJson(req);
    if (body === undefined) return errorResponse('invalid_request', 'body must be JSON');
    const parsed = parseRequest(body, deps.regions);
    if (!parsed.ok) return errorResponse(parsed.error, parsed.detail);
    const request = parsed.request;

    if (request.action === 'regions') {
      return json(200, {
        regions: deps.regions.list().map((r) => ({
          code: r.code,
          languages: [...r.languages],
          defaultLanguage: r.defaultLanguage,
        })),
        defaultRegion: deps.regions.defaultCode,
      });
    }

    // Per-client rate limit (searches and geocodes together). If the counter
    // itself is down the request goes on: the provider gates below then fail
    // closed, so no unmetered provider call can happen.
    try {
      const bucket = await clientBucket(req.headers, deps.now(), deps.quotaSecret);
      if (!(await deps.store.takeQuota(bucket, CLIENT_LIMIT, CLIENT_WINDOW_MINUTES, null))) {
        return errorResponse('rate_limited');
      }
    } catch (_e) {
      log(JSON.stringify({ fn: 'find-vet', event: 'rate_limit_store_error' }));
    }

    if (request.action === 'geocode') {
      if (!deps.provider.enabled) return errorResponse('unavailable');
      const g = await gate(GEOCODE_BUCKET, deps.dailyGeocodeCap)();
      if (g !== 'ok') return errorResponse('unavailable');
      const out = await deps.provider.geocode(request.query, request.lang, request.region);
      if (out.status !== 'ok') {
        log(JSON.stringify({ fn: 'find-vet', event: 'geocode_failed', status: out.status }));
        return errorResponse('unavailable');
      }
      return json(200, { region: request.region.code, results: out.value });
    }

    try {
      const { response, linkCandidates } = await runSearch(request, {
        provider: deps.provider,
        store: deps.store,
        now: deps.now,
        allowProviderCall: gate(PLACES_BUCKET, deps.dailyPlacesCap),
      });
      if (response.provider.status !== 'ok' && response.provider.status !== 'disabled') {
        log(JSON.stringify({ fn: 'find-vet', event: 'provider_not_ok', status: response.provider.status }));
      }
      // Heuristic matches go to the admins' queue (place IDs only). Best
      // effort: a failure here never fails the search.
      await Promise.all(
        linkCandidates.map((c) =>
          deps.store.recordLinkCandidate(c).catch(() => {
            log(JSON.stringify({ fn: 'find-vet', event: 'link_candidate_store_error' }));
          }),
        ),
      );
      return json(200, response);
    } catch (e) {
      if (!(e instanceof SearchUnavailable)) {
        log(JSON.stringify({ fn: 'find-vet', event: 'search_error', error: e instanceof Error ? e.name : 'unknown' }));
      }
      return errorResponse('unavailable');
    }
  };
}

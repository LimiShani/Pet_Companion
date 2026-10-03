// The search pipeline: curated records + live provider results, matched,
// with live intake attached, ranked, the radius widened when there is too
// little, and notices for the app. Pure apart from its injected provider,
// store and clock, so the tests drive it end to end without a network.
//
// Order of work:
// 1. Curated facilities of the region within the largest radius we may need,
//    plus their live intake. A store failure is not fatal: provider results
//    still return with the `curated_unavailable` notice.
// 2. Emergency: pick the radius from curated data alone (only curated
//    records can be emergency-advertised), so the provider is called once.
//    Long term: call the provider once at the ladder's top (capped at 50 km;
//    results come nearest first) and pick the radius afterwards.
// 3. Provider call, unless disabled or over the daily cap. On any failure,
//    emergency searches fall back to the curated emergency-advertised
//    records (the `provider_unavailable` notice).
// 4. Match, merge, filter to the chosen radius, rank.

import { effectiveIntake, emergencyView, isStale, openView } from './evidence.ts';
import { distanceM } from './geo.ts';
import type { LatLng } from './geo.ts';
import { matchPlaces } from './matching.ts';
import { normalizePhone } from './phone.ts';
import type { PlacesProvider, ProviderPlace } from './providers/types.ts';
import { chooseRadius, EMERGENCY_MIN_STRONG, isStrongEmergency, LONG_TERM_MIN_RESULTS, radiusLadder, rankEmergency, rankLongTerm } from './ranking.ts';
import type { DirectoryStore } from './store.ts';
import type {
  CuratedFacility,
  IntakeRow,
  LinkCandidate,
  Notice,
  ProviderStatus,
  SearchResponse,
  VetResult,
} from './types.ts';
import { PROVIDER_MAX_RADIUS_M } from './validation.ts';
import type { SearchRequest } from './validation.ts';

/** Asked before every provider call; answers whether the daily cap allows it. */
export type ProviderGate = () => Promise<'ok' | 'quota' | 'error'>;

export interface SearchDeps {
  provider: PlacesProvider;
  store: DirectoryStore;
  now: () => Date;
  allowProviderCall: ProviderGate;
}

export interface SearchOutcome {
  response: SearchResponse;
  /** Heuristic matches to report to admins (place IDs only). */
  linkCandidates: LinkCandidate[];
}

/** Neither the database nor the provider could answer: the handler sends 503. */
export class SearchUnavailable extends Error {
  constructor() {
    super('search unavailable');
    this.name = 'SearchUnavailable';
  }
}

const PROVIDER_MAX_RESULTS = 20;

function joinAddress(address: string | null, city: string | null): string | null {
  if (address && city && !address.includes(city)) return `${address}, ${city}`;
  return address ?? city ?? null;
}

/** One result from a curated facility, a provider place, or both (a match). */
function buildResult(
  f: CuratedFacility | null,
  p: ProviderPlace | null,
  ctx: { center: LatLng; lang: string; now: Date; intake: Map<string, IntakeRow>; req: SearchRequest },
): VetResult {
  const location: LatLng =
    f !== null && f.lat !== null && f.lng !== null ? { lat: f.lat, lng: f.lng } : { lat: p!.lat, lng: p!.lng };
  const emergency = emergencyView(f?.emergency ?? null);
  const providerPhone = p ? p.internationalPhone ?? p.nationalPhone : null;
  const name = f !== null ? (ctx.lang === 'he' && f.nameHe ? f.nameHe : f.name) : p!.name;
  return {
    // 'g:' marks a Google place ID, as in the API contract.
    key: f !== null ? `f:${f.id}` : `g:${p!.placeId}`,
    facilityId: f?.id ?? null,
    placeId: p?.placeId ?? null,
    name,
    address: f !== null ? joinAddress(f.address, f.city) ?? p?.address ?? null : p!.address,
    location,
    distanceM: Math.round(distanceM(ctx.center, location)),
    phone: f?.phone ?? normalizePhone(providerPhone, ctx.req.region) ?? providerPhone,
    website: f?.website ?? p?.website ?? null,
    mapsUri: p?.mapsUri ?? null,
    fromProvider: p !== null,
    fromCurated: f !== null,
    businessStatus: p?.businessStatus ?? null,
    emergency,
    open: openView(p ? { openNow: p.openNow, weekdayText: p.weekdayText } : null, emergency),
    intake: f !== null ? effectiveIntake(ctx.intake.get(f.id), ctx.now) : effectiveIntake(null, ctx.now),
    facts: f?.facts ?? [],
    lastCheckedAt: f?.lastCheckedAt ?? null,
    stale: f !== null ? isStale(f.lastCheckedAt, ctx.now) : false,
    reviewStatus: f !== null && (f.reviewStatus === 'approved' || f.reviewStatus === 'needs_review') ? f.reviewStatus : null,
  };
}

export async function runSearch(req: SearchRequest, deps: SearchDeps): Promise<SearchOutcome> {
  const now = deps.now();
  const region = req.region;
  const center: LatLng = { lat: req.lat, lng: req.lng };
  const steps = radiusLadder(
    req.radiusM,
    req.mode === 'emergency' ? region.radii.emergencyCuratedM : region.radii.longTermM,
  );
  const maxRadius = steps[steps.length - 1];

  // 1. Curated records and their live intake.
  let curated: CuratedFacility[] = [];
  let curatedOk = true;
  try {
    curated = (await deps.store.curatedNear(region.code, center, maxRadius)).filter(
      (f) => f.countryCode === region.code && f.lat !== null && f.lng !== null,
    );
  } catch (_e) {
    curatedOk = false;
  }
  const intake = new Map<string, IntakeRow>();
  if (curated.length > 0) {
    try {
      for (const row of await deps.store.intakeFor(curated.map((f) => f.id))) intake.set(row.facilityId, row);
    } catch (_e) {
      // Live intake unknown is the safe default; the search goes on.
    }
  }
  const ctx = { center, lang: req.lang, now, intake, req };

  // 2. Radius (emergency) and provider radius.
  let radiusM: number | null = null;
  let providerRadius: number;
  if (req.mode === 'emergency') {
    const strong = curated.map((f) => buildResult(f, null, ctx)).filter(isStrongEmergency);
    radiusM = chooseRadius(steps, (r) => strong.filter((s) => s.distanceM <= r).length >= EMERGENCY_MIN_STRONG);
    providerRadius = Math.min(radiusM, PROVIDER_MAX_RADIUS_M);
  } else {
    providerRadius = Math.min(maxRadius, PROVIDER_MAX_RADIUS_M);
  }

  // 3. Provider.
  let status: ProviderStatus;
  let places: ProviderPlace[] = [];
  if (!deps.provider.enabled) {
    status = 'disabled';
  } else {
    let gate: 'ok' | 'quota' | 'error';
    try {
      gate = await deps.allowProviderCall();
    } catch (_e) {
      // Without the counter there is no cost cap: do not call the provider.
      gate = 'error';
    }
    if (gate !== 'ok') {
      status = gate;
    } else {
      const outcome = await deps.provider.nearbyVets({
        lat: req.lat,
        lng: req.lng,
        radiusM: providerRadius,
        lang: req.lang,
        maxResults: PROVIDER_MAX_RESULTS,
        region,
      });
      status = outcome.status;
      if (outcome.status === 'ok') {
        places = outcome.value.filter((p) => distanceM(center, { lat: p.lat, lng: p.lng }) <= providerRadius);
      }
    }
  }
  if (!curatedOk && status !== 'ok') throw new SearchUnavailable();

  // 4. Match and merge. Nearest places first, so when two provider listings
  //    are linked to one facility the nearer one carries it.
  places.sort((a, b) => distanceM(center, a) - distanceM(center, b));
  const matches = matchPlaces(places, curated, region);
  const byId = new Map(curated.map((f) => [f.id, f]));
  const used = new Set<string>();
  const linkCandidates: LinkCandidate[] = [];
  let all: VetResult[] = [];
  for (const p of places) {
    const m = matches.get(p.placeId);
    if (m === undefined) {
      all.push(buildResult(null, p, ctx));
      continue;
    }
    if (used.has(m.facilityId)) continue; // a duplicate listing of a facility already shown
    used.add(m.facilityId);
    all.push(buildResult(byId.get(m.facilityId)!, p, ctx));
    if (m.via === 'heuristic' && m.matchedOn !== 'place_id') {
      linkCandidates.push({ facilityId: m.facilityId, placeId: p.placeId, matchedOn: m.matchedOn });
    }
  }
  for (const f of curated) if (!used.has(f.id)) all.push(buildResult(f, null, ctx));

  // 5. Filter, choose the radius (long term), rank.
  let results: VetResult[];
  if (req.mode === 'emergency') {
    const r = radiusM!;
    if (status === 'ok') {
      all = all.filter(
        (x) =>
          // Curated records without any emergency or intake signal only
          // appear as listings when the provider found them too.
          (x.fromProvider || x.emergency.state !== 'not_listed' || x.intake.state !== 'unknown') &&
          // A permanently closed listing is no help in an emergency.
          !(x.businessStatus === 'closed_permanently' && x.emergency.state === 'not_listed'),
      );
    } else {
      // Provider down: the emergency-advertised curated records (or ones
      // reporting live intake), labelled with their check dates.
      all = all.filter((x) => isStrongEmergency(x) || x.emergency.state === 'advertised');
    }
    results = rankEmergency(all.filter((x) => x.distanceM <= r));
  } else {
    const ranked = rankLongTerm(all);
    radiusM = chooseRadius(steps, (r) => ranked.filter((x) => x.distanceM <= r).length >= LONG_TERM_MIN_RESULTS);
    const r = radiusM;
    results = ranked.filter((x) => x.distanceM <= r);
  }

  const expanded = radiusM! > req.radiusM;
  const notices: Notice[] = [];
  if (expanded) notices.push('radius_expanded');
  if (status !== 'ok') notices.push('provider_unavailable');
  if (!curatedOk) notices.push('curated_unavailable');
  if (results.length === 0) notices.push('no_results');

  return {
    response: {
      region: region.code,
      searchedAt: now.toISOString(),
      mode: req.mode,
      center,
      radiusM: radiusM!,
      expanded,
      provider: {
        name: deps.provider.name,
        status,
        // Shown (as plain, untranslated text) only when provider content is in the response.
        attribution: status === 'ok' ? deps.provider.attribution : null,
      },
      results,
      notices,
    },
    linkCandidates,
  };
}

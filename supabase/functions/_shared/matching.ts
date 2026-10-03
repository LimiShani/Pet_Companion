// Matching live provider results to curated records (docs/find_a_vet.md,
// "Matching live results to curated records"):
//
// 1. A stored (provider, place_id) link is a match.
// 2. Otherwise, a careful heuristic that needs ALL of: distance under 120 m,
//    normalized-name similarity >= 0.6 (generic words removed), and the same
//    phone number OR the same street + house number.
// 3. Branches of a chain share a name but not a location or phone, so rule 2
//    fails and they stay separate results.
//
// A heuristic match is used for one response and reported as a link
// candidate for an admin; it never becomes a permanent link by itself.

import { distanceM } from './geo.ts';
import { samePhone } from './phone.ts';
import type { ProviderPlace } from './providers/types.ts';
import type { RegionConfig } from './regions/types.ts';
import type { CuratedFacility } from './types.ts';

export const MATCH_MAX_DISTANCE_M = 120;
export const MATCH_MIN_NAME_SIMILARITY = 0.6;

export interface PlaceMatch {
  facilityId: string;
  via: 'place_id' | 'heuristic';
  /** For heuristic matches: which second rule held. */
  matchedOn: 'place_id' | 'phone' | 'address';
}

/** Lower case, no niqqud, no quote marks (ד"ר -> דר), punctuation to spaces. */
function tokens(text: string): string[] {
  return text
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[֑-ׇ]/g, '') // Hebrew points and cantillation
    .replace(/["'`׳״‘’“”]/g, '') // quotes, geresh, gershayim
    .split(/[^\p{L}\p{N}]+/u)
    .filter((t) => t !== '');
}

function isStopWord(token: string, region: RegionConfig, stop: Set<string>): boolean {
  if (stop.has(token)) return true;
  // "המרפאה" = "ה" + "מרפאה": a one-letter prefix glued to a stop word.
  return (
    token.length > 2 && region.nameStopWordPrefixes.includes(token[0]) && stop.has(token.slice(1))
  );
}

/**
 * The name reduced to its distinctive words. If every word is generic
 * ("Vet Center"), the full name is kept so it can still be compared.
 */
export function normalizeName(name: string, region: RegionConfig): string {
  const all = tokens(name);
  const stop = new Set(region.nameStopWords.map((w) => tokens(w).join('')));
  const kept = all.filter((t) => !isStopWord(t, region, stop));
  return (kept.length > 0 ? kept : all).join(' ');
}

function bigrams(s: string): Map<string, number> {
  const m = new Map<string, number>();
  for (let i = 0; i < s.length - 1; i++) {
    const g = s.slice(i, i + 2);
    m.set(g, (m.get(g) ?? 0) + 1);
  }
  return m;
}

/**
 * Similarity of two names in [0, 1]: the Dice coefficient of the character
 * bigrams of their normalized forms (spaces removed, so word splits such as
 * "VetCenter" / "Vet Center" do not matter).
 */
export function nameSimilarity(a: string, b: string, region: RegionConfig): number {
  const x = normalizeName(a, region).replace(/ /g, '');
  const y = normalizeName(b, region).replace(/ /g, '');
  if (x === '' || y === '') return 0;
  if (x === y) return 1;
  if (x.length < 2 || y.length < 2) return 0;
  const bx = bigrams(x);
  const by = bigrams(y);
  let overlap = 0;
  for (const [g, n] of bx) overlap += Math.min(n, by.get(g) ?? 0);
  return (2 * overlap) / (x.length - 1 + (y.length - 1));
}

/**
 * Street and house number from the first comma-separated part of an address
 * ("דרך המכבים 70, ראשון לציון" -> street "המכבים", number "70"). Null when
 * either part is missing: an address without a house number never matches.
 */
export function streetAndNumber(
  address: string | null | undefined,
  region: RegionConfig,
): { street: string; number: string } | null {
  if (typeof address !== 'string') return null;
  const first = address.split(',')[0];
  const words = new Set(region.streetWords.map((w) => tokens(w).join('')));
  let number: string | null = null;
  const street: string[] = [];
  for (const t of tokens(first)) {
    const num = /^(\d+)\p{L}?$/u.exec(t);
    if (num) {
      if (number === null) number = num[1];
      continue;
    }
    if (/\d/.test(t) || words.has(t)) continue;
    street.push(t);
  }
  if (number === null || street.length === 0) return null;
  return { street: street.join(' '), number };
}

function sameStreetAndNumber(a: string | null, b: string | null, region: RegionConfig): boolean {
  const x = streetAndNumber(a, region);
  const y = streetAndNumber(b, region);
  return x !== null && y !== null && x.number === y.number && x.street === y.street;
}

/** Why a heuristic pair matched, or null. Exported for tests. */
export function heuristicMatch(
  place: ProviderPlace,
  facility: CuratedFacility,
  region: RegionConfig,
): { distanceM: number; matchedOn: 'phone' | 'address' } | null {
  if (facility.lat === null || facility.lng === null) return null;
  const d = distanceM({ lat: place.lat, lng: place.lng }, { lat: facility.lat, lng: facility.lng });
  if (!(d < MATCH_MAX_DISTANCE_M)) return null;
  const sim = Math.max(
    nameSimilarity(place.name, facility.name, region),
    facility.nameHe ? nameSimilarity(place.name, facility.nameHe, region) : 0,
  );
  if (sim < MATCH_MIN_NAME_SIMILARITY) return null;
  if (
    samePhone(place.internationalPhone, facility.phone, region) ||
    samePhone(place.nationalPhone, facility.phone, region)
  ) {
    return { distanceM: d, matchedOn: 'phone' };
  }
  if (sameStreetAndNumber(place.address, facility.address, region)) return { distanceM: d, matchedOn: 'address' };
  return null;
}

/**
 * Matches provider places to curated facilities. Place-ID links first; then,
 * for places still unmatched, the heuristic against facilities not yet
 * matched (nearest passing facility wins). Returns placeId -> match.
 */
export function matchPlaces(
  places: ProviderPlace[],
  curated: CuratedFacility[],
  region: RegionConfig,
): Map<string, PlaceMatch> {
  const matches = new Map<string, PlaceMatch>();
  const linked = new Map<string, string>();
  for (const f of curated) for (const pid of f.placeIds) linked.set(pid, f.id);

  const taken = new Set<string>();
  for (const p of places) {
    const fid = linked.get(p.placeId);
    if (fid !== undefined) {
      matches.set(p.placeId, { facilityId: fid, via: 'place_id', matchedOn: 'place_id' });
      taken.add(fid);
    }
  }

  for (const p of places) {
    if (matches.has(p.placeId)) continue;
    let best: { facility: CuratedFacility; distanceM: number; matchedOn: 'phone' | 'address' } | null = null;
    for (const f of curated) {
      // A facility already linked to a place by ID, or already matched, is not reused.
      if (taken.has(f.id) || f.placeIds.length > 0) continue;
      const m = heuristicMatch(p, f, region);
      if (m && (best === null || m.distanceM < best.distanceM)) best = { facility: f, ...m };
    }
    if (best) {
      matches.set(p.placeId, { facilityId: best.facility.id, via: 'heuristic', matchedOn: best.matchedOn });
      taken.add(best.facility.id);
    }
  }
  return matches;
}

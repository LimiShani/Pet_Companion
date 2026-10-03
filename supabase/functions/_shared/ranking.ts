// Ranking and radius expansion (docs/find_a_vet.md, "Ranking").
//
// Emergency: fresh accepting/limited intake first, then emergency
// advertised, then advertised-but-diverting, then unverified, then plain
// listings; distance within each tier. The radius widens along the region's
// curated ladder while fewer than two "strong" results (tiers 0-1) are in
// range.
//
// Long term: distance only, permanently closed places dropped; the radius
// widens along the long-term ladder while fewer than three results are in
// range.

import type { VetResult } from './types.ts';

export const EMERGENCY_MIN_STRONG = 2;
export const LONG_TERM_MIN_RESULTS = 3;

/** Emergency tier of a result: lower sorts first. */
export function emergencyTier(r: VetResult): number {
  const intake = r.intake.state;
  if (intake === 'accepting' || intake === 'limited') return 0;
  if (r.emergency.state === 'advertised') return intake === 'diverting' ? 2 : 1;
  if (r.emergency.state === 'unverified') return 3;
  return 4;
}

/** Counts towards "enough emergency options in range" (tiers 0 and 1). */
export function isStrongEmergency(r: VetResult): boolean {
  return emergencyTier(r) <= 1;
}

const byDistance = (a: VetResult, b: VetResult): number => a.distanceM - b.distanceM || a.key.localeCompare(b.key);

export function rankEmergency(results: VetResult[]): VetResult[] {
  return [...results].sort((a, b) => emergencyTier(a) - emergencyTier(b) || byDistance(a, b));
}

export function rankLongTerm(results: VetResult[]): VetResult[] {
  return results.filter((r) => r.businessStatus !== 'closed_permanently').sort(byDistance);
}

/**
 * The radii to try: the requested one, then every ladder step above it.
 * A request already beyond the ladder is used as is.
 */
export function radiusLadder(requestedM: number, steps: number[]): number[] {
  return [requestedM, ...steps.filter((s) => s > requestedM)];
}

/** The first radius in the ladder that satisfies `enough`, else the last one. */
export function chooseRadius(ladder: number[], enough: (radiusM: number) => boolean): number {
  for (const r of ladder) if (enough(r)) return r;
  return ladder[ladder.length - 1];
}

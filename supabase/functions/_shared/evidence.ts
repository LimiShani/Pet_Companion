// Evidence levels: what each piece of a result may and may not claim.
// The rule (docs/find_a_vet.md): nothing says a facility is available now
// because a directory, Google or its own site says it is open or 24/7.
// Emergency service is "advertised" only from a curated claim with a source;
// a provider listing, a Google type or a name like "Emergency Vet Hospital"
// never establishes it.

import type {
  CuratedEmergency,
  EmergencyView,
  IntakeRow,
  IntakeView,
  OpenView,
  VetResult,
} from './types.ts';

export const EvidenceLevel = {
  listedNearby: 'listed_nearby',
  emergencyAdvertised: 'emergency_advertised',
  publishedOpen: 'published_open',
  acceptingNow: 'accepting_now',
} as const;

export type EvidenceLevelCode = (typeof EvidenceLevel)[keyof typeof EvidenceLevel];

/** A curated fact without a successful check for longer than this is stale. */
export const STALE_AFTER_DAYS = 30;
const DAY_MS = 86_400_000;

/** Stale: never checked, or last checked more than 30 days ago. */
export function isStale(lastCheckedAt: string | null, now: Date): boolean {
  if (lastCheckedAt === null) return true;
  const t = Date.parse(lastCheckedAt);
  if (Number.isNaN(t)) return true;
  return now.getTime() - t > STALE_AFTER_DAYS * DAY_MS;
}

const UNKNOWN_INTAKE: IntakeView = { state: 'unknown', species: [], updatedAt: null, expiresAt: null };

/**
 * The intake a result may show. A status sent by the facility counts only
 * while expiresAt is in the future: at or after expiry it is 'unknown' (and
 * its species/time are not shown, so an expired status cannot leak through).
 */
export function effectiveIntake(row: IntakeRow | null | undefined, now: Date): IntakeView {
  if (!row) return UNKNOWN_INTAKE;
  const expires = Date.parse(row.expiresAt);
  if (Number.isNaN(expires) || expires <= now.getTime()) return UNKNOWN_INTAKE;
  return { state: row.status, species: [...row.species], updatedAt: row.updatedAt, expiresAt: row.expiresAt };
}

const NOT_LISTED: EmergencyView = {
  state: 'not_listed',
  schedule: null,
  sourceUrl: null,
  checkedAt: null,
  confirmedAt: null,
};

/**
 * The emergency state of a result. Only a curated claim can make it
 * 'advertised', and only with an https source and a check or confirmation
 * time; anything less is 'unverified'. A result without a curated claim
 * (every provider-only result, whatever its name says) is 'not_listed'.
 */
export function emergencyView(claim: CuratedEmergency | null | undefined): EmergencyView {
  if (!claim) return NOT_LISTED;
  const sourced = typeof claim.sourceUrl === 'string' && /^https:\/\//i.test(claim.sourceUrl);
  const checked = claim.checkedAt !== null || claim.confirmedAt !== null;
  const state = claim.state === 'advertised' && sourced && checked ? 'advertised' : 'unverified';
  return {
    state,
    schedule: claim.schedule,
    sourceUrl: claim.sourceUrl,
    checkedAt: claim.checkedAt,
    confirmedAt: claim.confirmedAt,
  };
}

/** True for schedule text meaning round the clock ("24/7", "24 שעות"). */
export function isRoundTheClock(schedule: string | null): boolean {
  if (schedule === null) return false;
  const s = schedule.replace(/\s+/g, '').toLowerCase();
  return s === '24/7' || s === '24שעות' || s === '24h' || s === '24/7/365';
}

/**
 * Published opening state. The provider's live hours win; otherwise a
 * curated, advertised round-the-clock schedule counts as published open
 * (published, not "available": the card still says call to confirm).
 */
export function openView(
  provider: { openNow: boolean | null; weekdayText: string[] } | null,
  emergency: EmergencyView,
): OpenView {
  if (provider && provider.openNow !== null) {
    return { state: provider.openNow ? 'open' : 'closed', basis: 'provider_hours', weekdayText: provider.weekdayText };
  }
  if (emergency.state === 'advertised' && isRoundTheClock(emergency.schedule)) {
    return { state: 'open', basis: 'curated_schedule', weekdayText: [] };
  }
  return { state: 'unknown', basis: 'none', weekdayText: provider?.weekdayText ?? [] };
}

/** The evidence levels a finished result carries (used by ranking and tests). */
export function evidenceLevels(r: VetResult): EvidenceLevelCode[] {
  const levels: EvidenceLevelCode[] = [];
  if (r.fromProvider) levels.push(EvidenceLevel.listedNearby);
  if (r.fromCurated && r.emergency.state === 'advertised') levels.push(EvidenceLevel.emergencyAdvertised);
  if (r.open.state === 'open') levels.push(EvidenceLevel.publishedOpen);
  if (r.intake.state === 'accepting' || r.intake.state === 'limited') levels.push(EvidenceLevel.acceptingNow);
  return levels;
}

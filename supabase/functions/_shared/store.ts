// The directory store: everything the search and the weekly job read from
// or write to the database, behind one interface. The real implementation
// talks to PostgREST with plain fetch and the service role key (no client
// library, so the same code runs on Deno and Node); the in-memory one backs
// the tests.

import { boxAround, distanceM } from './geo.ts';
import type { LatLng } from './geo.ts';
import type { CuratedFacility, IntakeRow, LinkCandidate, ReviewStatus } from './types.ts';

export type ClaimStatus = 'current' | 'unverified' | 'conflict' | 'withdrawn';
export type SourceKind = 'facility_site' | 'partner' | 'manual';
export type Severity = 'high' | 'medium' | 'low';

export interface WeeklyClaim {
  id: string;
  key: string;
  value: unknown;
  sourceUrl: string | null;
  sourceKind: SourceKind;
  status: ClaimStatus;
  evidencePatterns: string[];
  checkedAt: string | null;
  confirmedAt: string | null;
  createdAt: string;
}

export interface WeeklyFacility {
  id: string;
  countryCode: string;
  name: string;
  phone: string | null;
  website: string | null;
  reviewStatus: ReviewStatus;
  lastCheckedAt: string | null;
  claims: WeeklyClaim[];
}

export interface ReviewItemInput {
  facilityId: string | null;
  kind: string;
  severity: Severity;
  details: Record<string, unknown>;
  dedupeKey: string;
}

export interface JobRun {
  job: string;
  periodKey: string;
  status: 'running' | 'succeeded' | 'failed';
  startedAt: string;
  finishedAt: string | null;
  stats: Record<string, unknown>;
  errors: unknown[];
}

export interface DirectoryStore {
  // --- search -------------------------------------------------------------
  /** Visible curated facilities of a country within radiusM of center. */
  curatedNear(countryCode: string, center: LatLng, radiusM: number): Promise<CuratedFacility[]>;
  /** Live (unexpired) intake rows for these facilities. */
  intakeFor(facilityIds: string[]): Promise<IntakeRow[]>;
  /** Records a heuristic match for an admin (place ID only). */
  recordLinkCandidate(c: LinkCandidate): Promise<void>;
  /** vet_search_take: false when a limit is reached. */
  takeQuota(bucket: string, bucketLimit: number | null, windowMinutes: number, dailyLimit: number | null): Promise<boolean>;

  // --- weekly job ---------------------------------------------------------
  getJobRun(job: string, periodKey: string): Promise<JobRun | null>;
  /** Inserts or replaces the run row of (job, periodKey). */
  saveJobRun(run: JobRun): Promise<void>;
  /** Facilities the job checks (approved + needs_review) with their claims. */
  facilitiesForCheck(): Promise<WeeklyFacility[]>;
  updateClaim(id: string, patch: { status?: ClaimStatus; checkedAt?: string }): Promise<void>;
  updateFacility(id: string, patch: { reviewStatus?: ReviewStatus; lastCheckedAt?: string }): Promise<void>;
  /** Opens a review item, or refreshes the open one with the same dedupe key. True when newly opened. */
  upsertReviewItem(item: ReviewItemInput): Promise<boolean>;
}

/** A failed store call. The message names the table and status, never query values. */
export class StoreError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.name = 'StoreError';
    this.status = status;
  }
}

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

// ---------------------------------------------------------------------------
// PostgREST implementation
// ---------------------------------------------------------------------------

export interface PostgrestStoreOptions {
  /** SUPABASE_URL, e.g. https://abc.supabase.co */
  url: string;
  /** SUPABASE_SERVICE_ROLE_KEY: bypasses RLS, so it never leaves the function. */
  serviceKey: string;
  fetch?: FetchLike;
}

const num = (v: unknown): number | null => (typeof v === 'number' ? v : v === null ? null : Number(v));

/** Maps a vet_directory_public row (snake_case) to CuratedFacility. */
export function curatedFromRow(row: Record<string, any>, placeIds: string[]): CuratedFacility {
  return {
    id: row.id,
    countryCode: row.country_code,
    name: row.name,
    nameHe: row.name_he ?? null,
    address: row.address ?? null,
    city: row.city ?? null,
    lat: num(row.lat),
    lng: num(row.lng),
    phone: row.phone ?? null,
    website: row.website ?? null,
    facilityType: row.facility_type,
    reviewStatus: row.review_status,
    lastCheckedAt: row.last_checked_at ?? null,
    lastConfirmedAt: row.last_confirmed_at ?? null,
    emergency: row.emergency ?? null,
    facts: Array.isArray(row.facts) ? row.facts : [],
    placeIds,
  };
}

export function createPostgrestStore(opts: PostgrestStoreOptions): DirectoryStore {
  const base = opts.url.replace(/\/+$/, '') + '/rest/v1';
  const doFetch: FetchLike = opts.fetch ?? ((input, init) => fetch(input, init));

  async function call(
    method: string,
    path: string,
    params: Record<string, string | string[]> | null,
    body?: unknown,
    prefer?: string,
  ): Promise<any> {
    const u = new URL(base + '/' + path);
    if (params) {
      for (const [k, v] of Object.entries(params)) {
        for (const one of Array.isArray(v) ? v : [v]) u.searchParams.append(k, one);
      }
    }
    const headers: Record<string, string> = {
      apikey: opts.serviceKey,
      Authorization: `Bearer ${opts.serviceKey}`,
      Accept: 'application/json',
    };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (prefer) headers.Prefer = prefer;
    const res = await doFetch(u.toString(), {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!res.ok) {
      // Drain the body so the connection is released; do not echo it.
      await res.text().catch(() => '');
      throw new StoreError(`${method} ${path.split('?')[0]} failed`, res.status);
    }
    const text = await res.text();
    return text === '' ? null : JSON.parse(text);
  }

  const inList = (ids: string[]): string => `in.(${ids.join(',')})`;

  return {
    async curatedNear(countryCode, center, radiusM) {
      const box = boxAround(center, radiusM);
      const rows: Record<string, any>[] = await call('GET', 'vet_directory_public', {
        select: '*',
        country_code: `eq.${countryCode}`,
        lat: [`gte.${box.minLat}`, `lte.${box.maxLat}`],
        lng: [`gte.${box.minLng}`, `lte.${box.maxLng}`],
      });
      const inRange = (rows ?? []).filter(
        (r) => r.lat !== null && r.lng !== null && distanceM(center, { lat: num(r.lat)!, lng: num(r.lng)! }) <= radiusM,
      );
      if (inRange.length === 0) return [];
      const links: { facility_id: string; place_id: string }[] = await call('GET', 'vet_facility_provider_ids', {
        select: 'facility_id,place_id',
        provider: 'eq.google',
        facility_id: inList(inRange.map((r) => r.id)),
      });
      const byFacility = new Map<string, string[]>();
      for (const l of links ?? []) byFacility.set(l.facility_id, [...(byFacility.get(l.facility_id) ?? []), l.place_id]);
      return inRange.map((r) => curatedFromRow(r, byFacility.get(r.id) ?? []));
    },

    async intakeFor(facilityIds) {
      if (facilityIds.length === 0) return [];
      const rows: Record<string, any>[] = await call('GET', 'vet_intake_current', {
        select: 'facility_id,status,species,updated_at,expires_at',
        facility_id: inList(facilityIds),
      });
      return (rows ?? []).map((r) => ({
        facilityId: r.facility_id,
        status: r.status,
        species: r.species ?? [],
        updatedAt: r.updated_at,
        expiresAt: r.expires_at,
      }));
    },

    async recordLinkCandidate(c) {
      await call('POST', 'rpc/vet_record_link_candidate', null, {
        p_facility: c.facilityId,
        p_place_id: c.placeId,
        p_matched_on: c.matchedOn,
      });
    },

    async takeQuota(bucket, bucketLimit, windowMinutes, dailyLimit) {
      const ok = await call('POST', 'rpc/vet_search_take', null, {
        p_bucket: bucket,
        p_bucket_limit: bucketLimit,
        p_window_minutes: windowMinutes,
        p_global_limit: dailyLimit,
      });
      return ok === true;
    },

    async getJobRun(job, periodKey) {
      const rows: Record<string, any>[] = await call('GET', 'vet_job_runs', {
        select: '*',
        job: `eq.${job}`,
        period_key: `eq.${periodKey}`,
      });
      const r = rows?.[0];
      if (!r) return null;
      return {
        job: r.job,
        periodKey: r.period_key,
        status: r.status,
        startedAt: r.started_at,
        finishedAt: r.finished_at,
        stats: r.stats ?? {},
        errors: r.errors ?? [],
      };
    },

    async saveJobRun(run) {
      await call(
        'POST',
        'vet_job_runs',
        { on_conflict: 'job,period_key' },
        {
          job: run.job,
          period_key: run.periodKey,
          status: run.status,
          started_at: run.startedAt,
          finished_at: run.finishedAt,
          stats: run.stats,
          errors: run.errors,
        },
        'resolution=merge-duplicates,return=minimal',
      );
    },

    async facilitiesForCheck() {
      const rows: Record<string, any>[] = await call('GET', 'vet_facilities', {
        select:
          'id,country_code,name,phone,website,review_status,last_checked_at,' +
          'vet_facility_claims(id,claim_key,value,source_url,source_kind,status,evidence_patterns,checked_at,confirmed_at,created_at)',
        review_status: 'in.(approved,needs_review)',
        order: 'id',
      });
      return (rows ?? []).map((r) => ({
        id: r.id,
        countryCode: r.country_code,
        name: r.name,
        phone: r.phone ?? null,
        website: r.website ?? null,
        reviewStatus: r.review_status,
        lastCheckedAt: r.last_checked_at ?? null,
        claims: (r.vet_facility_claims ?? []).map((c: Record<string, any>) => ({
          id: c.id,
          key: c.claim_key,
          value: c.value,
          sourceUrl: c.source_url ?? null,
          sourceKind: c.source_kind,
          status: c.status,
          evidencePatterns: c.evidence_patterns ?? [],
          checkedAt: c.checked_at ?? null,
          confirmedAt: c.confirmed_at ?? null,
          createdAt: c.created_at,
        })),
      }));
    },

    async updateClaim(id, patch) {
      const body: Record<string, unknown> = {};
      if (patch.status !== undefined) body.status = patch.status;
      if (patch.checkedAt !== undefined) body.checked_at = patch.checkedAt;
      await call('PATCH', 'vet_facility_claims', { id: `eq.${id}` }, body, 'return=minimal');
    },

    async updateFacility(id, patch) {
      const body: Record<string, unknown> = {};
      if (patch.reviewStatus !== undefined) body.review_status = patch.reviewStatus;
      if (patch.lastCheckedAt !== undefined) body.last_checked_at = patch.lastCheckedAt;
      await call('PATCH', 'vet_facilities', { id: `eq.${id}` }, body, 'return=minimal');
    },

    async upsertReviewItem(item) {
      const opened = await call('POST', 'rpc/vet_upsert_review_item', null, {
        p_facility: item.facilityId,
        p_kind: item.kind,
        p_severity: item.severity,
        p_details: item.details,
        p_dedupe_key: item.dedupeKey,
      });
      return opened === true;
    },
  };
}

// ---------------------------------------------------------------------------
// In-memory implementation (tests)
// ---------------------------------------------------------------------------

export interface MemoryReviewItem extends ReviewItemInput {
  id: string;
  status: 'open' | 'resolved' | 'dismissed';
  createdAt: string;
  updatedAt: string;
}

export interface MemoryStoreSeed {
  curated?: CuratedFacility[];
  intake?: IntakeRow[];
  facilities?: WeeklyFacility[];
  now?: () => Date;
}

/**
 * Mirrors the SQL semantics the code relies on: open review items are
 * unique per dedupe key, (job, period_key) is unique, quota windows count
 * like vet_search_take. `fail` makes chosen methods throw, to test fallbacks.
 */
export class MemoryStore implements DirectoryStore {
  curated: CuratedFacility[];
  intake: IntakeRow[];
  facilities: WeeklyFacility[];
  reviewItems: MemoryReviewItem[] = [];
  jobRuns: JobRun[] = [];
  linkCandidates: LinkCandidate[] = [];
  quota = new Map<string, number>();
  fail = new Set<keyof DirectoryStore>();
  now: () => Date;
  private nextId = 1;

  constructor(seed: MemoryStoreSeed = {}) {
    this.curated = seed.curated ?? [];
    this.intake = seed.intake ?? [];
    this.facilities = seed.facilities ?? [];
    this.now = seed.now ?? (() => new Date());
  }

  private check(name: keyof DirectoryStore): void {
    if (this.fail.has(name)) throw new StoreError(`${String(name)} failed`, 503);
  }

  curatedNear(countryCode: string, center: LatLng, radiusM: number): Promise<CuratedFacility[]> {
    this.check('curatedNear');
    return Promise.resolve(
      this.curated.filter(
        (f) =>
          f.countryCode === countryCode &&
          (f.reviewStatus === 'approved' || f.reviewStatus === 'needs_review') &&
          f.lat !== null &&
          f.lng !== null &&
          distanceM(center, { lat: f.lat, lng: f.lng }) <= radiusM,
      ),
    );
  }

  intakeFor(facilityIds: string[]): Promise<IntakeRow[]> {
    this.check('intakeFor');
    return Promise.resolve(this.intake.filter((r) => facilityIds.includes(r.facilityId)));
  }

  recordLinkCandidate(c: LinkCandidate): Promise<void> {
    this.check('recordLinkCandidate');
    if (!this.linkCandidates.some((x) => x.facilityId === c.facilityId && x.placeId === c.placeId)) {
      this.linkCandidates.push(c);
    }
    return Promise.resolve();
  }

  takeQuota(bucket: string, bucketLimit: number | null, windowMinutes: number, dailyLimit: number | null): Promise<boolean> {
    this.check('takeQuota');
    const t = this.now().getTime();
    const windowKey = `${bucket}@${Math.floor(t / (windowMinutes * 60_000))}`;
    const dayKey = `${bucket}#day@${Math.floor(t / 86_400_000)}`;
    const day = this.quota.get(dayKey) ?? 0;
    const win = this.quota.get(windowKey) ?? 0;
    if (dailyLimit !== null && day >= dailyLimit) return Promise.resolve(false);
    if (bucketLimit !== null && win >= bucketLimit) return Promise.resolve(false);
    if (dailyLimit !== null) this.quota.set(dayKey, day + 1);
    if (bucketLimit !== null) this.quota.set(windowKey, win + 1);
    return Promise.resolve(true);
  }

  getJobRun(job: string, periodKey: string): Promise<JobRun | null> {
    this.check('getJobRun');
    const r = this.jobRuns.find((x) => x.job === job && x.periodKey === periodKey);
    return Promise.resolve(r ? structuredClone(r) : null);
  }

  saveJobRun(run: JobRun): Promise<void> {
    this.check('saveJobRun');
    const i = this.jobRuns.findIndex((x) => x.job === run.job && x.periodKey === run.periodKey);
    if (i >= 0) this.jobRuns[i] = structuredClone(run);
    else this.jobRuns.push(structuredClone(run));
    return Promise.resolve();
  }

  facilitiesForCheck(): Promise<WeeklyFacility[]> {
    this.check('facilitiesForCheck');
    return Promise.resolve(
      structuredClone(this.facilities.filter((f) => f.reviewStatus === 'approved' || f.reviewStatus === 'needs_review')),
    );
  }

  updateClaim(id: string, patch: { status?: ClaimStatus; checkedAt?: string }): Promise<void> {
    this.check('updateClaim');
    for (const f of this.facilities) {
      for (const c of f.claims) {
        if (c.id !== id) continue;
        if (patch.status !== undefined) c.status = patch.status;
        if (patch.checkedAt !== undefined) c.checkedAt = patch.checkedAt;
      }
    }
    return Promise.resolve();
  }

  updateFacility(id: string, patch: { reviewStatus?: ReviewStatus; lastCheckedAt?: string }): Promise<void> {
    this.check('updateFacility');
    const f = this.facilities.find((x) => x.id === id);
    if (f) {
      if (patch.reviewStatus !== undefined) f.reviewStatus = patch.reviewStatus;
      if (patch.lastCheckedAt !== undefined) f.lastCheckedAt = patch.lastCheckedAt;
    }
    return Promise.resolve();
  }

  upsertReviewItem(item: ReviewItemInput): Promise<boolean> {
    this.check('upsertReviewItem');
    const at = this.now().toISOString();
    const open = this.reviewItems.find((x) => x.status === 'open' && x.dedupeKey === item.dedupeKey);
    if (open) {
      open.details = structuredClone(item.details);
      open.severity = item.severity;
      open.updatedAt = at;
      return Promise.resolve(false);
    }
    this.reviewItems.push({
      ...structuredClone(item),
      id: `item-${this.nextId++}`,
      status: 'open',
      createdAt: at,
      updatedAt: at,
    });
    return Promise.resolve(true);
  }
}

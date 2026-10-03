// The weekly directory check (docs/find_a_vet.md, "Weekly job").
//
// For every approved / needs_review facility, in every region, it re-reads
// the pages our curated claims cite and compares them with what we hold:
//   - evidence found        -> claim stays current, checked_at = now
//   - evidence gone/404/410 -> claim 'unverified' at once + review item
//   - page unreachable      -> 'source_unreachable' item; an emergency claim
//                              with no successful check for 14 days is
//                              downgraded too
//   - our phone missing from pages that list other numbers -> phone_conflict
//   - closure wording       -> 'closure' item, facility to needs_review
//   - emergency wording on a facility without an emergency claim -> low item
// The job only ever DOWNGRADES. Re-upgrading is an admin action with a
// source (vet_admin_set_claim). It never calls Google and stores no provider
// content. Each facility uses its own country's RegionConfig for evidence
// patterns, phone formats and closure words.
//
// Idempotent: one vet_job_runs row per ISO week (UTC). A finished week's
// rerun returns the stored stats unless forced; review items are upserted
// by dedupe_key, so even a forced rerun never duplicates them.
//
// Fetching rules: an honest user agent, robots.txt respected, 10 s timeout,
// and only URLs on the facility's own website host (or a subdomain of it),
// or claims whose source_kind is 'partner'.

import { errorResponse, json, preflight, readJson } from './http.ts';
import { findPhones, normalizePhone } from './phone.ts';
import type { RegionLookup } from './regions/index.ts';
import type { RegionConfig } from './regions/types.ts';
import type { DirectoryStore, ReviewItemInput, SourceKind, WeeklyClaim, WeeklyFacility } from './store.ts';

export const WEEKLY_JOB = 'vet-directory-weekly';
export const ROBOTS_TOKEN = 'PetLoopDirectoryCheck';
export const USER_AGENT = `${ROBOTS_TOKEN}/1.0 (PetLoop weekly check of published veterinary emergency information)`;
export const FETCH_TIMEOUT_MS = 10_000;
/** An emergency claim with no successful check for this long is downgraded when its page is unreachable. */
export const UNREACHABLE_GRACE_DAYS = 14;
const MAX_PAGE_CHARS = 2_000_000;
const DAY_MS = 86_400_000;

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

// ---------------------------------------------------------------------------
// Small pure helpers (exported for tests)
// ---------------------------------------------------------------------------

/** ISO 8601 week of a date in UTC, e.g. '2026-W40'. */
export function isoWeekKey(d: Date): string {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const day = t.getUTCDay() || 7; // Monday = 1 ... Sunday = 7
  t.setUTCDate(t.getUTCDate() + 4 - day); // the Thursday of this week decides the year
  const yearStart = Date.UTC(t.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((t.getTime() - yearStart) / DAY_MS + 1) / 7);
  return `${t.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

/** Equal strings, compared in time independent of where they differ. */
export function constantTimeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  const n = Math.max(x.length, y.length);
  for (let i = 0; i < n; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

const stripWww = (h: string): string => h.toLowerCase().replace(/^www\./, '');

/**
 * May the job fetch this URL for this claim? Facility-site claims: only the
 * facility's own website host or a subdomain of it. Partner claims: any
 * https URL (the partner registered it with us).
 */
export function urlAllowed(url: string, facilityWebsite: string | null, kind: SourceKind): boolean {
  let u: URL;
  try {
    u = new URL(url);
  } catch (_e) {
    return false;
  }
  if (u.protocol !== 'https:' && u.protocol !== 'http:') return false;
  if (kind === 'partner') return u.protocol === 'https:';
  if (kind !== 'facility_site' || !facilityWebsite) return false;
  let w: URL;
  try {
    w = new URL(facilityWebsite);
  } catch (_e) {
    return false;
  }
  const uh = stripWww(u.hostname);
  const wh = stripWww(w.hostname);
  return uh === wh || uh.endsWith(`.${wh}`);
}

interface RobotsRule {
  allow: boolean;
  path: string;
}

/**
 * The rules of robots.txt that apply to us: the groups naming our token,
 * else the '*' groups. Allow/Disallow paths with '*' and '$' wildcards.
 */
export function parseRobots(text: string, token = ROBOTS_TOKEN): RobotsRule[] {
  const groups: { agents: string[]; rules: RobotsRule[] }[] = [];
  let current: { agents: string[]; rules: RobotsRule[] } | null = null;
  let lastWasAgent = false;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, '').trim();
    const i = line.indexOf(':');
    if (i < 0) continue;
    const key = line.slice(0, i).trim().toLowerCase();
    const value = line.slice(i + 1).trim();
    if (key === 'user-agent') {
      if (!lastWasAgent || current === null) {
        current = { agents: [], rules: [] };
        groups.push(current);
      }
      current.agents.push(value.toLowerCase());
      lastWasAgent = true;
    } else if (key === 'allow' || key === 'disallow') {
      lastWasAgent = false;
      if (current === null) continue;
      if (value === '') continue; // "Disallow:" with nothing = no rule
      current.rules.push({ allow: key === 'allow', path: value });
    } else {
      lastWasAgent = false;
    }
  }
  const t = token.toLowerCase();
  const ours = groups.filter((g) => g.agents.some((a) => a !== '*' && a !== '' && t.includes(a)));
  const chosen = ours.length > 0 ? ours : groups.filter((g) => g.agents.includes('*'));
  return chosen.flatMap((g) => g.rules);
}

function ruleRegex(path: string): RegExp {
  const anchored = path.endsWith('$');
  const body = (anchored ? path.slice(0, -1) : path)
    .split('*')
    .map((s) => s.replace(/[.+?^${}()|[\]\\]/g, '\\$&'))
    .join('.*');
  return new RegExp(`^${body}${anchored ? '$' : ''}`);
}

/** Longest matching rule wins; a tie goes to Allow; no match = allowed. */
export function robotsAllows(rules: RobotsRule[], pathAndQuery: string): boolean {
  let best: RobotsRule | null = null;
  for (const r of rules) {
    if (!ruleRegex(r.path).test(pathAndQuery)) continue;
    if (best === null || r.path.length > best.path.length || (r.path.length === best.path.length && r.allow)) best = r;
  }
  return best === null || best.allow;
}

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };

/** Visible text of an HTML page (scripts, styles and comments removed). */
export function htmlToText(html: string): string {
  return html
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/<(script|style|noscript)\b[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) => {
      if (e[0] === '#') {
        const code = e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
        return Number.isFinite(code) && code > 0 && code < 0x110000 ? String.fromCodePoint(code) : ' ';
      }
      return ENTITIES[e.toLowerCase()] ?? m;
    })
    .replace(/\s+/g, ' ')
    .trim();
}

/** Numbers in tel: links (often the only machine-readable copy). */
function telLinks(html: string): string[] {
  return [...html.matchAll(/href\s*=\s*["']tel:([^"']+)["']/gi)].map((m) => {
    try {
      return decodeURIComponent(m[1]);
    } catch (_e) {
      return m[1];
    }
  });
}

const fold = (s: string): string => s.toLowerCase().replace(/\s+/g, ' ');

/** Case-insensitive substring match (whitespace runs count as one space). */
export function containsPattern(text: string, pattern: string): boolean {
  const p = fold(pattern).trim();
  return p !== '' && fold(text).includes(p);
}

/**
 * Closure wording: a case-insensitive match NOT followed by another letter,
 * so "נסגר" does not fire on "נסגרת בשעה 20:00" (closes at 20:00).
 */
export function containsClosureWord(text: string, word: string): boolean {
  const t = fold(text);
  const w = fold(word).trim();
  if (w === '') return false;
  for (let i = t.indexOf(w); i >= 0; i = t.indexOf(w, i + 1)) {
    const next = t.slice(i + w.length, i + w.length + 2);
    if (!/^\p{L}/u.test(next)) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Fetching
// ---------------------------------------------------------------------------

type PageResult =
  | { kind: 'ok'; text: string; tels: string[] }
  | { kind: 'gone'; status: number }
  | { kind: 'unreachable'; reason: string }
  | { kind: 'refused'; reason: string }
  | { kind: 'robots' };

async function timedFetch(doFetch: FetchLike, url: string, timeoutMs: number): Promise<Response | 'timeout' | 'network'> {
  const ctrl = new AbortController();
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    ctrl.abort();
  }, timeoutMs);
  try {
    return await doFetch(url, {
      method: 'GET',
      headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,text/plain;q=0.9,*/*;q=0.5' },
      redirect: 'follow',
      signal: ctrl.signal,
    });
  } catch (_e) {
    return timedOut ? 'timeout' : 'network';
  } finally {
    clearTimeout(timer);
  }
}

/** One run's fetcher: robots.txt cached per origin, pages cached per URL. */
function createFetcher(doFetch: FetchLike, timeoutMs: number) {
  const robots = new Map<string, Promise<RobotsRule[] | 'all_disallowed'>>();
  const pages = new Map<string, Promise<PageResult>>();

  function robotsFor(origin: string): Promise<RobotsRule[] | 'all_disallowed'> {
    let p = robots.get(origin);
    if (!p) {
      p = (async () => {
        const res = await timedFetch(doFetch, `${origin}/robots.txt`, timeoutMs);
        // RFC 9309: unreachable or 5xx = everything disallowed; 4xx = no rules.
        if (typeof res === 'string' || res.status >= 500) return 'all_disallowed' as const;
        if (res.status >= 400) return [];
        return parseRobots((await res.text()).slice(0, 500_000));
      })();
      robots.set(origin, p);
    }
    return p;
  }

  async function load(url: string, website: string | null, kind: SourceKind): Promise<PageResult> {
    const u = new URL(url);
    const rules = await robotsFor(u.origin);
    if (rules === 'all_disallowed' || !robotsAllows(rules, u.pathname + u.search)) return { kind: 'robots' };
    const res = await timedFetch(doFetch, url, timeoutMs);
    if (res === 'timeout') return { kind: 'unreachable', reason: 'timeout' };
    if (res === 'network') return { kind: 'unreachable', reason: 'network' };
    if (res.url && res.url !== url && !urlAllowed(res.url, website, kind)) {
      await res.text().catch(() => '');
      return { kind: 'refused', reason: 'redirect_off_domain' };
    }
    if (res.status === 404 || res.status === 410) {
      await res.text().catch(() => '');
      return { kind: 'gone', status: res.status };
    }
    if (!res.ok) {
      await res.text().catch(() => '');
      return { kind: 'unreachable', reason: `http_${res.status}` };
    }
    const html = (await res.text()).slice(0, MAX_PAGE_CHARS);
    return { kind: 'ok', text: htmlToText(html), tels: telLinks(html) };
  }

  return function page(url: string, website: string | null, kind: SourceKind): Promise<PageResult> {
    if (!urlAllowed(url, website, kind)) return Promise.resolve({ kind: 'refused', reason: 'off_domain' });
    const key = `${kind}|${url}`;
    let p = pages.get(key);
    if (!p) {
      p = load(url, website, kind).catch(() => ({ kind: 'unreachable', reason: 'error' }) as PageResult);
      pages.set(key, p);
    }
    return p;
  };
}

// ---------------------------------------------------------------------------
// The run
// ---------------------------------------------------------------------------

export interface WeeklyStats {
  periodKey: string;
  facilities: number;
  claimsChecked: number;
  pagesOk: number;
  confirmed: number;
  downgraded: number;
  unreachable: number;
  skipped: number;
  closures: number;
  reviewItemsOpened: number;
  reviewItemsRefreshed: number;
  errors: number;
}

export interface WeeklyDeps {
  store: DirectoryStore;
  fetch: FetchLike;
  now: () => Date;
  regions: RegionLookup;
  timeoutMs?: number;
  log?: (line: string) => void;
}

export interface WeeklyResult {
  periodKey: string;
  reused: boolean;
  status: 'succeeded' | 'failed';
  stats: Record<string, unknown>;
}

function localTime(d: Date, timeZone: string): string {
  try {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).format(d);
  } catch (_e) {
    return d.toISOString();
  }
}

export async function runWeekly(deps: WeeklyDeps, opts: { force?: boolean } = {}): Promise<WeeklyResult> {
  const started = deps.now();
  const periodKey = isoWeekKey(started);
  const log = deps.log ?? ((line: string) => console.log(line));

  const existing = await deps.store.getJobRun(WEEKLY_JOB, periodKey);
  if (existing && existing.status === 'succeeded' && !opts.force) {
    return { periodKey, reused: true, status: 'succeeded', stats: existing.stats };
  }

  await deps.store.saveJobRun({
    job: WEEKLY_JOB,
    periodKey,
    status: 'running',
    startedAt: started.toISOString(),
    finishedAt: null,
    stats: {},
    errors: [],
  });

  const stats: WeeklyStats = {
    periodKey,
    facilities: 0,
    claimsChecked: 0,
    pagesOk: 0,
    confirmed: 0,
    downgraded: 0,
    unreachable: 0,
    skipped: 0,
    closures: 0,
    reviewItemsOpened: 0,
    reviewItemsRefreshed: 0,
    errors: 0,
  };
  const errors: { facilityId: string; error: string }[] = [];
  const page = createFetcher(deps.fetch, deps.timeoutMs ?? FETCH_TIMEOUT_MS);

  try {
    const facilities = await deps.store.facilitiesForCheck();
    for (const f of facilities) {
      stats.facilities++;
      const region = deps.regions.get(f.countryCode);
      if (region === undefined) {
        stats.errors++;
        errors.push({ facilityId: f.id, error: 'unsupported_region' });
        log(JSON.stringify({ job: WEEKLY_JOB, periodKey, facilityId: f.id, error: 'unsupported_region' }));
        continue;
      }
      try {
        const line = await checkFacility(f, region, deps, page, stats);
        log(JSON.stringify({ job: WEEKLY_JOB, periodKey, facilityId: f.id, region: region.code, ...line }));
      } catch (e) {
        stats.errors++;
        const error = e instanceof Error ? e.message.slice(0, 200) : 'unknown';
        errors.push({ facilityId: f.id, error });
        log(JSON.stringify({ job: WEEKLY_JOB, periodKey, facilityId: f.id, region: region.code, error }));
      }
    }
  } catch (e) {
    const error = e instanceof Error ? e.message.slice(0, 200) : 'unknown';
    await deps.store.saveJobRun({
      job: WEEKLY_JOB,
      periodKey,
      status: 'failed',
      startedAt: started.toISOString(),
      finishedAt: deps.now().toISOString(),
      stats: { ...stats },
      errors: [...errors, { facilityId: null, error }],
    });
    return { periodKey, reused: false, status: 'failed', stats: { ...stats } };
  }

  await deps.store.saveJobRun({
    job: WEEKLY_JOB,
    periodKey,
    status: 'succeeded',
    startedAt: started.toISOString(),
    finishedAt: deps.now().toISOString(),
    stats: { ...stats },
    errors,
  });
  return { periodKey, reused: false, status: 'succeeded', stats: { ...stats } };
}

/** Checks one facility; returns the counters for its log line. */
async function checkFacility(
  f: WeeklyFacility,
  region: RegionConfig,
  deps: WeeklyDeps,
  page: ReturnType<typeof createFetcher>,
  stats: WeeklyStats,
): Promise<Record<string, number>> {
  const now = deps.now();
  const nowIso = now.toISOString();
  const when = { checkedAt: nowIso, checkedAtLocal: localTime(now, region.timeZone) };
  const line = { claims: 0, pagesOk: 0, confirmed: 0, downgraded: 0, items: 0, skipped: 0 };

  const item = async (it: ReviewItemInput): Promise<void> => {
    const opened = await deps.store.upsertReviewItem(it);
    if (opened) stats.reviewItemsOpened++;
    else stats.reviewItemsRefreshed++;
    line.items++;
  };

  const downgrade = async (c: WeeklyClaim, reason: string, extra: Record<string, unknown> = {}): Promise<void> => {
    await deps.store.updateClaim(c.id, { status: 'unverified' });
    stats.downgraded++;
    line.downgraded++;
    const emergency = c.key === 'emergency';
    const kind = emergency ? 'emergency_evidence_missing' : 'claim_evidence_missing';
    await item({
      facilityId: f.id,
      kind,
      severity: emergency ? 'high' : 'medium',
      details: { claimKey: c.key, sourceUrl: c.sourceUrl, reason, ...extra, ...when },
      dedupeKey: `${kind}:${c.id}`,
    });
  };

  const texts: string[] = [];
  const phones = new Set<string>();
  const fetchedUrls = new Set<string>();
  const addPage = (p: { text: string; tels: string[] }): void => {
    texts.push(p.text);
    for (const n of findPhones(p.text, region)) phones.add(n);
    for (const t of p.tels) {
      const n = normalizePhone(t, region);
      if (n !== null) phones.add(n);
    }
  };

  const checkable = f.claims.filter(
    (c) =>
      c.status !== 'withdrawn' &&
      typeof c.sourceUrl === 'string' &&
      c.sourceUrl !== '' &&
      (c.sourceKind === 'facility_site' || c.sourceKind === 'partner'),
  );

  for (const c of checkable) {
    stats.claimsChecked++;
    line.claims++;
    const url = c.sourceUrl!;
    const res = await page(url, f.website, c.sourceKind);
    if (res.kind === 'refused' || res.kind === 'robots') {
      stats.skipped++;
      line.skipped++;
      const kind = res.kind === 'robots' ? 'robots_disallowed' : 'source_refused';
      await item({
        facilityId: f.id,
        kind,
        severity: 'medium',
        details: { claimKey: c.key, sourceUrl: url, ...(res.kind === 'refused' ? { reason: res.reason } : {}), ...when },
        dedupeKey: `${kind}:${c.id}`,
      });
      continue;
    }
    if (res.kind === 'gone') {
      if (c.status === 'current') await downgrade(c, `http_${res.status}`);
      continue;
    }
    if (res.kind === 'unreachable') {
      stats.unreachable++;
      const lastSuccess = c.checkedAt ?? c.confirmedAt ?? c.createdAt;
      const age = now.getTime() - Date.parse(lastSuccess);
      const overGrace = !(age <= UNREACHABLE_GRACE_DAYS * DAY_MS);
      const willDowngrade = c.key === 'emergency' && c.status === 'current' && overGrace;
      if (willDowngrade) {
        await deps.store.updateClaim(c.id, { status: 'unverified' });
        stats.downgraded++;
        line.downgraded++;
      }
      await item({
        facilityId: f.id,
        kind: 'source_unreachable',
        severity: willDowngrade ? 'high' : 'medium',
        details: { claimKey: c.key, sourceUrl: url, reason: res.reason, lastSuccessAt: lastSuccess, downgraded: willDowngrade, ...when },
        dedupeKey: `source_unreachable:${c.id}`,
      });
      continue;
    }

    // Page read.
    if (!fetchedUrls.has(url)) {
      fetchedUrls.add(url);
      stats.pagesOk++;
      line.pagesOk++;
      addPage(res);
    }
    const patterns = c.evidencePatterns.length > 0 ? c.evidencePatterns : region.evidencePatterns[c.key] ?? [];
    if (patterns.length === 0) continue; // nothing to verify against: left alone (it goes stale)
    const found = patterns.filter((p) => containsPattern(res.text, p));
    if (found.length > 0) {
      if (c.status === 'current') {
        await deps.store.updateClaim(c.id, { checkedAt: nowIso });
        stats.confirmed++;
        line.confirmed++;
      } else {
        // The job never re-upgrades: tell an admin the evidence is back.
        await item({
          facilityId: f.id,
          kind: 'evidence_restored',
          severity: 'low',
          details: { claimKey: c.key, sourceUrl: url, found, ...when },
          dedupeKey: `evidence_restored:${c.id}`,
        });
      }
    } else if (c.status === 'current') {
      await downgrade(c, 'pattern_missing', { patterns });
    }
  }

  // The facility's own home page too (phones, closure, new emergency wording).
  if (f.website && ![...fetchedUrls].some((u) => sameUrl(u, f.website!))) {
    const res = await page(f.website, f.website, 'facility_site');
    if (res.kind === 'ok') {
      stats.pagesOk++;
      line.pagesOk++;
      addPage(res);
    }
  }

  if (texts.length === 0) return line;
  await deps.store.updateFacility(f.id, { lastCheckedAt: nowIso });

  // Phone: ours appears on none of the pages, which do list other numbers.
  const ours = normalizePhone(f.phone, region);
  if (ours !== null && phones.size > 0 && !phones.has(ours)) {
    await item({
      facilityId: f.id,
      kind: 'phone_conflict',
      severity: 'medium',
      details: { ours, found: [...phones].slice(0, 10), ...when },
      dedupeKey: `phone_conflict:${f.id}`,
    });
  }

  // Closure wording.
  const closure = region.closureWords.filter((w) => texts.some((t) => containsClosureWord(t, w)));
  if (closure.length > 0) {
    stats.closures++;
    await item({
      facilityId: f.id,
      kind: 'closure',
      severity: 'high',
      details: { words: closure, ...when },
      dedupeKey: `closure:${f.id}`,
    });
    if (f.reviewStatus === 'approved') await deps.store.updateFacility(f.id, { reviewStatus: 'needs_review' });
  }

  // Emergency wording on a facility we hold no emergency claim for.
  const hasEmergency = f.claims.some((c) => c.key === 'emergency' && c.status !== 'withdrawn');
  if (!hasEmergency) {
    const found = (region.evidencePatterns.emergency ?? []).filter((p) => texts.some((t) => containsPattern(t, p)));
    if (found.length > 0) {
      await item({
        facilityId: f.id,
        kind: 'new_emergency_evidence',
        severity: 'low',
        details: { found, ...when },
        dedupeKey: `new_emergency_evidence:${f.id}`,
      });
    }
  }
  return line;
}

function sameUrl(a: string, b: string): boolean {
  try {
    const x = new URL(a);
    const y = new URL(b);
    const path = (u: URL): string => u.pathname.replace(/\/+$/, '') + u.search;
    return stripWww(x.hostname) === stripWww(y.hostname) && path(x) === path(y);
  } catch (_e) {
    return a === b;
  }
}

// ---------------------------------------------------------------------------
// HTTP entry
// ---------------------------------------------------------------------------

export interface WeeklyHandlerDeps extends WeeklyDeps {
  /** VET_JOB_SECRET; when empty the job refuses to run. */
  jobSecret: string;
}

export function createWeeklyHandler(deps: WeeklyHandlerDeps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return preflight();
    if (req.method !== 'POST') return errorResponse('method_not_allowed');
    if (deps.jobSecret === '') return errorResponse('unavailable');
    const given = req.headers.get('x-job-secret') ?? '';
    if (!constantTimeEqual(given, deps.jobSecret)) return errorResponse('unauthorized');
    const body = await readJson(req);
    const force = typeof body === 'object' && body !== null && (body as Record<string, unknown>).force === true;
    try {
      const result = await runWeekly(deps, { force });
      return json(result.status === 'succeeded' ? 200 : 500, result);
    } catch (e) {
      (deps.log ?? console.error)(
        JSON.stringify({ job: WEEKLY_JOB, error: e instanceof Error ? e.message.slice(0, 200) : 'unknown' }),
      );
      return json(500, { error: 'job_failed' });
    }
  };
}


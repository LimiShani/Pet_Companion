import { test } from 'node:test';
import assert from 'node:assert/strict';

import { registryLookup } from '../_shared/regions/index.ts';
import { MemoryStore } from '../_shared/store.ts';
import type { WeeklyFacility } from '../_shared/store.ts';
import {
  constantTimeEqual,
  containsClosureWord,
  createWeeklyHandler,
  htmlToText,
  isoWeekKey,
  parseRobots,
  robotsAllows,
  runWeekly,
  urlAllowed,
  USER_AGENT,
  WEEKLY_JOB,
} from '../_shared/weekly.ts';
import type { WeeklyDeps } from '../_shared/weekly.ts';
import { claim, fakeFetch, html, lookupWith, NOW, weeklyFacility, ZZ } from './helpers.ts';
import type { Route } from './helpers.ts';

const SITE = 'https://vet.example.co.il';
const EMERGENCY_URL = `${SITE}/emergency`;
const GOOD_PAGE = html('מיון פתוח 24 שעות ביממה. טלפון 03-9688588, מוקד *8818');

function setup(facilities: WeeklyFacility[], routes: Record<string, Route>, now: () => Date = () => NOW) {
  const store = new MemoryStore({ facilities, now });
  const f = fakeFetch(routes);
  const logs: string[] = [];
  const deps: WeeklyDeps = { store, fetch: f.fetch, now, regions: registryLookup, timeoutMs: 30, log: (l) => logs.push(l) };
  return { store, deps, requested: f.requested, logs };
}

const emergencyFacility = (over: Partial<WeeklyFacility> = {}) =>
  weeklyFacility({ id: 'f1', claims: [claim({ id: 'c1' })], ...over });

test('ISO week key (UTC)', () => {
  assert.equal(isoWeekKey(NOW), '2026-W41');
  assert.equal(isoWeekKey(new Date('2026-10-04T23:59:59Z')), '2026-W40'); // Sunday
  assert.equal(isoWeekKey(new Date('2021-01-03T12:00:00Z')), '2020-W53');
  assert.equal(isoWeekKey(new Date('2024-12-30T00:00:00Z')), '2025-W01');
});

test('evidence found: claim stays current, checked_at updated, no review item', async () => {
  const { store, deps, logs } = setup([emergencyFacility()], { [EMERGENCY_URL]: { status: 200, body: GOOD_PAGE } });
  const r = await runWeekly(deps);
  assert.equal(r.status, 'succeeded');
  assert.equal(r.reused, false);
  const c = store.facilities[0].claims[0];
  assert.equal(c.status, 'current');
  assert.equal(c.checkedAt, NOW.toISOString());
  assert.equal(store.facilities[0].lastCheckedAt, NOW.toISOString());
  assert.equal(store.reviewItems.length, 0);
  assert.equal(r.stats.confirmed, 1);
  // One structured log line per facility, no page content.
  const line = JSON.parse(logs.find((l) => l.includes('"facilityId":"f1"'))!);
  assert.equal(line.job, WEEKLY_JOB);
  assert.equal(line.confirmed, 1);
});

test('evidence gone: claim unverified at once + exactly one high review item', async () => {
  const { store, deps } = setup([emergencyFacility()], {
    [EMERGENCY_URL]: { status: 200, body: html('שעות פעילות: א-ה 08:00-20:00. טלפון 03-9688588') },
  });
  const r = await runWeekly(deps);
  assert.equal(store.facilities[0].claims[0].status, 'unverified');
  assert.equal(store.reviewItems.length, 1);
  assert.equal(store.reviewItems[0].kind, 'emergency_evidence_missing');
  assert.equal(store.reviewItems[0].severity, 'high');
  assert.equal(store.reviewItems[0].dedupeKey, 'emergency_evidence_missing:c1');
  assert.equal(r.stats.downgraded, 1);
});

test('rerun in the same week: stored stats returned, nothing fetched or duplicated', async () => {
  const { store, deps, requested } = setup([emergencyFacility()], {
    [EMERGENCY_URL]: { status: 200, body: html('אין כאן כלום') },
  });
  const first = await runWeekly(deps);
  const fetchedBefore = requested.length;
  const itemsBefore = store.reviewItems.length;
  const second = await runWeekly(deps);
  assert.equal(second.reused, true);
  assert.deepEqual(second.stats, first.stats);
  assert.equal(requested.length, fetchedBefore);
  assert.equal(store.reviewItems.length, itemsBefore);
  assert.equal(store.jobRuns.length, 1);
  assert.equal(store.jobRuns[0].periodKey, '2026-W41');
});

test('forced rerun: runs again but never duplicates review items', async () => {
  const facilities = [
    emergencyFacility(),
    weeklyFacility({ id: 'f2', website: 'https://down.example.co.il/', claims: [claim({ id: 'c2', sourceUrl: 'https://down.example.co.il/er' })] }),
  ];
  const { store, deps } = setup(facilities, {
    [EMERGENCY_URL]: { status: 200, body: html('אין כאן כלום') },
    'https://down.example.co.il/er': { status: 503 },
  });
  await runWeekly(deps);
  assert.equal(store.reviewItems.length, 2);
  const forced = await runWeekly(deps, { force: true });
  assert.equal(forced.reused, false);
  assert.equal(store.reviewItems.length, 2);
  assert.equal(store.reviewItems.filter((i) => i.dedupeKey === 'source_unreachable:c2').length, 1);
  assert.equal(store.jobRuns.length, 1);
});

test('404 / 410: evidence gone -> unverified', async () => {
  for (const status of [404, 410]) {
    const { store, deps } = setup([emergencyFacility()], { [EMERGENCY_URL]: { status } });
    await runWeekly(deps);
    assert.equal(store.facilities[0].claims[0].status, 'unverified', String(status));
    assert.equal(store.reviewItems[0].kind, 'emergency_evidence_missing');
    assert.equal(store.reviewItems[0].details.reason, `http_${status}`);
  }
});

test('5xx / timeout: source_unreachable, no downgrade while the last success is recent', async () => {
  for (const route of [{ status: 502 }, 'timeout', 'network'] as Route[]) {
    const recent = emergencyFacility({ claims: [claim({ id: 'c1', checkedAt: '2026-10-01T00:00:00Z' })] });
    const { store, deps } = setup([recent], { [EMERGENCY_URL]: route });
    const r = await runWeekly(deps);
    assert.equal(store.facilities[0].claims[0].status, 'current', JSON.stringify(route));
    assert.equal(store.reviewItems.length, 1);
    assert.equal(store.reviewItems[0].kind, 'source_unreachable');
    assert.equal(store.reviewItems[0].severity, 'medium');
    assert.equal(r.stats.unreachable, 1);
  }
});

test('5xx with the last success over 14 days ago: emergency claim downgraded', async () => {
  const old = emergencyFacility({ claims: [claim({ id: 'c1', checkedAt: '2026-09-20T00:00:00Z' })] });
  const { store, deps } = setup([old], { [EMERGENCY_URL]: { status: 500 } });
  await runWeekly(deps);
  assert.equal(store.facilities[0].claims[0].status, 'unverified');
  assert.equal(store.reviewItems.length, 1);
  assert.equal(store.reviewItems[0].kind, 'source_unreachable');
  assert.equal(store.reviewItems[0].severity, 'high');
  assert.equal(store.reviewItems[0].details.downgraded, true);
});

test('downgrade only: an unverified claim whose evidence is back is not re-upgraded', async () => {
  const f = emergencyFacility({ claims: [claim({ id: 'c1', status: 'unverified' })] });
  const { store, deps } = setup([f], { [EMERGENCY_URL]: { status: 200, body: GOOD_PAGE } });
  await runWeekly(deps);
  assert.equal(store.facilities[0].claims[0].status, 'unverified');
  assert.equal(store.facilities[0].claims[0].checkedAt, '2026-10-01T00:00:00Z');
  assert.equal(store.reviewItems[0].kind, 'evidence_restored');
  assert.equal(store.reviewItems[0].severity, 'low');
});

test('phone conflict: our number missing from pages that list others', async () => {
  const { store, deps } = setup([emergencyFacility()], {
    [EMERGENCY_URL]: { status: 200, body: html('חירום 24 שעות ביממה - התקשרו 09-1234567') },
  });
  await runWeekly(deps);
  const item = store.reviewItems.find((i) => i.kind === 'phone_conflict');
  assert.ok(item);
  assert.equal(item.severity, 'medium');
  assert.equal(item.details.ours, '+97239688588');
  assert.deepEqual(item.details.found, ['+97291234567']);
  // Our number found (even only in a tel: link) -> no conflict.
  const { store: s2, deps: d2 } = setup([emergencyFacility()], {
    [EMERGENCY_URL]: { status: 200, body: html('24 שעות ביממה 09-1234567 <a href="tel:+97239688588">התקשרו</a>') },
  });
  await runWeekly(d2);
  assert.ok(!s2.reviewItems.some((i) => i.kind === 'phone_conflict'));
});

test('closure wording: high item, facility to needs_review; "closes at 20:00" is not closure', async () => {
  const { store, deps } = setup([emergencyFacility()], {
    [EMERGENCY_URL]: { status: 200, body: html('המרפאה נסגרה לצמיתות. תודה. 24 שעות ביממה 03-9688588') },
  });
  await runWeekly(deps);
  const item = store.reviewItems.find((i) => i.kind === 'closure');
  assert.ok(item);
  assert.equal(item.severity, 'high');
  assert.equal(store.facilities[0].reviewStatus, 'needs_review');

  assert.equal(containsClosureWord('המרפאה נסגרת בשעה 20:00', 'נסגר'), false);
  assert.equal(containsClosureWord('הסניף נסגר.', 'נסגר'), true);
  assert.equal(containsClosureWord('We are PERMANENTLY CLOSED', 'permanently closed'), true);
});

test('robots.txt disallow: claim skipped with an item, page never fetched', async () => {
  const { store, deps, requested } = setup([emergencyFacility({ website: null })], {
    [`${SITE}/robots.txt`]: { status: 200, body: 'User-agent: *\nDisallow: /emergency\n' },
    [EMERGENCY_URL]: { status: 200, body: GOOD_PAGE },
  });
  // website null -> facility_site claims cannot be verified as first party: refused.
  await runWeekly(deps);
  assert.equal(store.reviewItems[0].kind, 'source_refused');

  const s = setup([emergencyFacility()], {
    [`${SITE}/robots.txt`]: { status: 200, body: 'User-agent: *\nDisallow: /emergency\n' },
    [EMERGENCY_URL]: { status: 200, body: GOOD_PAGE },
  });
  const r = await runWeekly(s.deps);
  assert.ok(!s.requested.includes(EMERGENCY_URL));
  const item = s.store.reviewItems.find((i) => i.kind === 'robots_disallowed');
  assert.ok(item);
  assert.equal(s.store.facilities[0].claims[0].status, 'current'); // not downgraded
  assert.equal(r.stats.skipped, 1);
  assert.ok(!requested.includes(EMERGENCY_URL)); // the refused one was not fetched either
});

test('robots.txt parsing: our group beats *, Allow beats a shorter Disallow, 5xx = all disallowed', async () => {
  const txt = 'User-agent: *\nDisallow: /\n\nUser-agent: PetLoopDirectoryCheck\nDisallow: /private\nAllow: /private/er$\n';
  const rules = parseRobots(txt);
  assert.equal(robotsAllows(rules, '/emergency'), true);
  assert.equal(robotsAllows(rules, '/private/x'), false);
  assert.equal(robotsAllows(rules, '/private/er'), true);
  assert.equal(robotsAllows(parseRobots('User-agent: *\nDisallow:\n'), '/x'), true);
  assert.equal(robotsAllows(parseRobots('User-agent: *\nDisallow: /*.pdf$\n'), '/a/b.pdf'), false);

  const { store, deps, requested } = setup([emergencyFacility()], {
    [`${SITE}/robots.txt`]: { status: 503 },
    [EMERGENCY_URL]: { status: 200, body: GOOD_PAGE },
  });
  await runWeekly(deps);
  assert.ok(!requested.includes(EMERGENCY_URL));
  assert.equal(store.reviewItems[0].kind, 'robots_disallowed');
});

test('off-domain source URL is refused; a partner source may be elsewhere', async () => {
  const f = emergencyFacility({
    claims: [
      claim({ id: 'c1', sourceUrl: 'https://directory.example.com/vet-center' }),
      claim({ id: 'c2', key: 'species', value: ['dog'], sourceUrl: 'https://partner.example.org/feed', sourceKind: 'partner', evidencePatterns: ['dog'] }),
    ],
  });
  const { store, deps, requested } = setup([f], {
    'https://partner.example.org/feed': { status: 200, body: 'dog cat' },
  });
  await runWeekly(deps);
  assert.ok(!requested.includes('https://directory.example.com/vet-center'));
  assert.ok(requested.includes('https://partner.example.org/feed'));
  const refused = store.reviewItems.find((i) => i.kind === 'source_refused');
  assert.ok(refused);
  assert.equal(refused.dedupeKey, 'source_refused:c1');
  assert.equal(store.facilities[0].claims.find((c) => c.id === 'c2')!.checkedAt, NOW.toISOString());

  assert.equal(urlAllowed('https://www.vet.example.co.il/x', 'https://vet.example.co.il/', 'facility_site'), true);
  assert.equal(urlAllowed('https://er.vet.example.co.il/x', 'https://www.vet.example.co.il/', 'facility_site'), true);
  assert.equal(urlAllowed('https://evilvet.example.co.il/x', 'https://vet.example.co.il/', 'facility_site'), false);
  assert.equal(urlAllowed('https://vet.example.co.il.evil.com/', 'https://vet.example.co.il/', 'facility_site'), false);
  assert.equal(urlAllowed('ftp://vet.example.co.il/', 'https://vet.example.co.il/', 'facility_site'), false);
  assert.equal(urlAllowed('http://partner.example.org/', null, 'partner'), false);
  assert.equal(urlAllowed('https://vet.example.co.il/x', 'https://vet.example.co.il/', 'manual'), false);
});

test('new emergency wording on a facility without an emergency claim: low item', async () => {
  const f = weeklyFacility({ id: 'f3', claims: [] });
  const { store, deps } = setup([f], { [`${SITE}/`]: { status: 200, body: html('מוקד חירום פתוח 24/7. 03-9688588') } });
  await runWeekly(deps);
  const item = store.reviewItems.find((i) => i.kind === 'new_emergency_evidence');
  assert.ok(item);
  assert.equal(item.severity, 'low');
});

test('the honest user agent is sent and script text is ignored', async () => {
  const seen: string[] = [];
  const store = new MemoryStore({ facilities: [emergencyFacility()], now: () => NOW });
  await runWeekly({
    store,
    now: () => NOW,
    regions: registryLookup,
    log: () => {},
    fetch: (url, init) => {
      seen.push((init?.headers as Record<string, string>)['User-Agent']);
      // The pattern only appears inside <script>: not evidence.
      return Promise.resolve(new Response(url.endsWith('robots.txt') ? '' : html('nothing visible'), { status: url.endsWith('robots.txt') ? 404 : 200 }));
    },
  });
  assert.ok(seen.every((ua) => ua === USER_AGENT));
  assert.equal(store.facilities[0].claims[0].status, 'unverified');
  assert.equal(htmlToText('<p>a&nbsp;b &amp; &#x5D0;</p><!-- x -->'), 'a b & א');
});

test('each facility uses its own region: a ZZ facility gets ZZ words and phones', async () => {
  const zz = weeklyFacility({
    id: 'z1',
    countryCode: 'ZZ',
    phone: '+991234567',
    website: 'https://veto.example.zz/',
    claims: [claim({ id: 'cz', sourceUrl: 'https://veto.example.zz/urgences', evidencePatterns: [] })],
  });
  const store = new MemoryStore({ facilities: [zz], now: () => NOW });
  const f = fakeFetch({
    'https://veto.example.zz/urgences': { status: 200, body: html('Urgences 24h. Tel 8 765 4321. Fermé définitivement.') },
  });
  await runWeekly({ store, fetch: f.fetch, now: () => NOW, regions: lookupWith(ZZ), log: () => {} });
  // ZZ default evidence ('urgences 24h') confirmed the claim.
  assert.equal(store.facilities[0].claims[0].checkedAt, NOW.toISOString());
  const kinds = store.reviewItems.map((i) => i.kind).sort();
  assert.deepEqual(kinds, ['closure', 'phone_conflict']);
  assert.deepEqual(store.reviewItems.find((i) => i.kind === 'phone_conflict')!.details.found, ['+997654321']);
  // With only the registered regions, ZZ facilities are reported, not guessed.
  const store2 = new MemoryStore({ facilities: [zz], now: () => NOW });
  const r = await runWeekly({ store: store2, fetch: f.fetch, now: () => NOW, regions: registryLookup, log: () => {} });
  assert.equal(r.stats.errors, 1);
  assert.equal(store2.jobRuns[0].errors.length, 1);
});

test('handler: x-job-secret checked (constant-time), force flag passed', async () => {
  const store = new MemoryStore({ facilities: [], now: () => NOW });
  const h = createWeeklyHandler({ store, fetch: fakeFetch({}).fetch, now: () => NOW, regions: registryLookup, jobSecret: 's3cret', log: () => {} });
  const call = (secret: string | null, body = '{}') =>
    h(new Request('https://example.test/', { method: 'POST', headers: secret === null ? {} : { 'x-job-secret': secret }, body }));
  assert.equal((await call(null)).status, 401);
  assert.equal((await call('wrong')).status, 401);
  assert.equal((await call('s3cret!')).status, 401);
  const ok = await call('s3cret');
  assert.equal(ok.status, 200);
  assert.equal((await ok.json()).periodKey, '2026-W41');
  assert.equal((await (await call('s3cret')).json()).reused, true);
  assert.equal((await (await call('s3cret', '{"force": true}')).json()).reused, false);

  const off = createWeeklyHandler({ store, fetch: fakeFetch({}).fetch, now: () => NOW, regions: registryLookup, jobSecret: '' });
  assert.equal((await off(new Request('https://example.test/', { method: 'POST', headers: { 'x-job-secret': '' } }))).status, 503);

  assert.equal(constantTimeEqual('abc', 'abc'), true);
  assert.equal(constantTimeEqual('abc', 'abd'), false);
  assert.equal(constantTimeEqual('abc', 'abcd'), false);
  assert.equal(constantTimeEqual('', ''), true);
});

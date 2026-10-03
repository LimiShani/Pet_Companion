import { test } from 'node:test';
import assert from 'node:assert/strict';

import { effectiveIntake, emergencyView, EvidenceLevel, evidenceLevels, isStale, openView } from '../_shared/evidence.ts';
import { ADVERTISED, NOW, result } from './helpers.ts';

const intake = (expiresAt: string) => ({
  facilityId: 'f1',
  status: 'accepting' as const,
  species: ['dog'],
  updatedAt: '2026-10-05T08:00:00Z',
  expiresAt,
});

test('EvidenceLevel codes', () => {
  assert.deepEqual(Object.values(EvidenceLevel), ['listed_nearby', 'emergency_advertised', 'published_open', 'accepting_now']);
});

test('intake: fresh counts, expired and exactly-at-expiry are unknown', () => {
  const fresh = effectiveIntake(intake('2026-10-05T09:00:01Z'), NOW);
  assert.equal(fresh.state, 'accepting');
  assert.deepEqual(fresh.species, ['dog']);

  const atExpiry = effectiveIntake(intake(NOW.toISOString()), NOW);
  assert.equal(atExpiry.state, 'unknown');
  assert.equal(atExpiry.expiresAt, null); // nothing of an expired status leaks out

  const expired = effectiveIntake(intake('2026-10-05T08:59:59Z'), NOW);
  assert.equal(expired.state, 'unknown');
  assert.deepEqual(expired.species, []);

  assert.equal(effectiveIntake(null, NOW).state, 'unknown');
  assert.equal(effectiveIntake(intake('not a date'), NOW).state, 'unknown');
});

test('stale: never checked, or more than 30 days ago', () => {
  assert.equal(isStale(null, NOW), true);
  assert.equal(isStale('2026-10-01T00:00:00Z', NOW), false);
  assert.equal(isStale('2026-09-05T09:00:00Z', NOW), false); // exactly 30 days
  assert.equal(isStale('2026-09-05T08:59:59Z', NOW), true); // 30 days + 1 s
  assert.equal(isStale('garbage', NOW), true);
});

test('emergency: advertised only from a sourced, checked curated claim', () => {
  assert.equal(emergencyView(ADVERTISED).state, 'advertised');
  assert.equal(emergencyView({ ...ADVERTISED, state: 'unverified' }).state, 'unverified');
  // No https source, or never checked nor confirmed: not advertised.
  assert.equal(emergencyView({ ...ADVERTISED, sourceUrl: null }).state, 'unverified');
  assert.equal(emergencyView({ ...ADVERTISED, sourceUrl: 'http://vet.example/x' }).state, 'unverified');
  assert.equal(emergencyView({ ...ADVERTISED, checkedAt: null, confirmedAt: null }).state, 'unverified');
  assert.equal(emergencyView(null).state, 'not_listed');
});

test('a provider-only "Emergency Vet Hospital 24/7" is NOT emergency advertised', () => {
  const r = result({
    key: 'g:x',
    name: 'Emergency Vet Hospital 24/7 - בית חולים חירום',
    fromProvider: true,
    fromCurated: false,
    emergency: emergencyView(null),
    open: openView({ openNow: true, weekdayText: ['Monday: Open 24 hours'] }, emergencyView(null)),
  });
  assert.equal(r.emergency.state, 'not_listed');
  const levels = evidenceLevels(r);
  assert.ok(levels.includes(EvidenceLevel.listedNearby));
  assert.ok(levels.includes(EvidenceLevel.publishedOpen));
  assert.ok(!levels.includes(EvidenceLevel.emergencyAdvertised));
  assert.ok(!levels.includes(EvidenceLevel.acceptingNow));
});

test('open: provider hours first, then an advertised 24/7 schedule, else unknown', () => {
  const adv = emergencyView(ADVERTISED);
  assert.deepEqual(openView({ openNow: false, weekdayText: ['a'] }, adv), {
    state: 'closed',
    basis: 'provider_hours',
    weekdayText: ['a'],
  });
  assert.deepEqual(openView(null, adv), { state: 'open', basis: 'curated_schedule', weekdayText: [] });
  assert.equal(openView(null, emergencyView({ ...ADVERTISED, state: 'unverified' })).state, 'unknown');
  assert.equal(openView({ openNow: null, weekdayText: [] }, emergencyView(null)).basis, 'none');
});

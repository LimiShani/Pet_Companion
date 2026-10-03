import { test } from 'node:test';
import assert from 'node:assert/strict';

import { chooseRadius, emergencyTier, radiusLadder, rankEmergency, rankLongTerm } from '../_shared/ranking.ts';
import { ADVERTISED, result, UNVERIFIED } from './helpers.ts';

const intake = (state: 'accepting' | 'limited' | 'diverting') => ({
  state,
  species: [],
  updatedAt: '2026-10-05T08:00:00Z',
  expiresAt: '2026-10-05T10:00:00Z',
});

test('emergency tiers: intake > advertised > diverting > unverified > listing; distance within a tier', () => {
  const rs = [
    result({ key: 'listing-near', distanceM: 100 }),
    result({ key: 'unverified', distanceM: 200, fromCurated: true, emergency: UNVERIFIED }),
    result({ key: 'adv-far', distanceM: 9_000, fromCurated: true, emergency: ADVERTISED }),
    result({ key: 'adv-near', distanceM: 3_000, fromCurated: true, emergency: ADVERTISED }),
    result({ key: 'diverting', distanceM: 500, fromCurated: true, emergency: ADVERTISED, intake: intake('diverting') }),
    result({ key: 'limited', distanceM: 8_000, fromCurated: true, intake: intake('limited') }),
    result({ key: 'accepting', distanceM: 7_000, fromCurated: true, emergency: ADVERTISED, intake: intake('accepting') }),
  ];
  assert.deepEqual(
    rankEmergency(rs).map((r) => r.key),
    ['accepting', 'limited', 'adv-near', 'adv-far', 'diverting', 'unverified', 'listing-near'],
  );
  assert.equal(emergencyTier(rs[0]), 4);
});

test('long term: distance only, permanently closed dropped', () => {
  const rs = [
    result({ key: 'b', distanceM: 2_000 }),
    result({ key: 'closed', distanceM: 100, businessStatus: 'closed_permanently' }),
    result({ key: 'a', distanceM: 1_000, businessStatus: 'closed_temporarily' }),
  ];
  assert.deepEqual(rankLongTerm(rs).map((r) => r.key), ['a', 'b']);
});

test('radius ladder and choice', () => {
  assert.deepEqual(radiusLadder(10_000, [10_000, 25_000, 50_000, 120_000]), [10_000, 25_000, 50_000, 120_000]);
  assert.deepEqual(radiusLadder(7_000, [10_000, 25_000]), [7_000, 10_000, 25_000]);
  assert.deepEqual(radiusLadder(30_000, [5_000, 10_000, 20_000]), [30_000]);
  assert.equal(chooseRadius([10, 25, 50], (r) => r >= 25), 25);
  assert.equal(chooseRadius([10, 25, 50], () => false), 50);
});

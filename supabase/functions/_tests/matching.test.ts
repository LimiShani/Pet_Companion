import { test } from 'node:test';
import assert from 'node:assert/strict';

import { heuristicMatch, matchPlaces, nameSimilarity, normalizeName, streetAndNumber } from '../_shared/matching.ts';
import { findPhones, normalizePhone, samePhone } from '../_shared/phone.ts';
import { IL } from '../_shared/regions/il.ts';
import { facility, JERUSALEM, offset, place, ZZ } from './helpers.ts';

test('phone normalization: +972 and leading 0 unify to E.164', () => {
  for (const raw of ['03-9688588', '+972 3-968-8588', '+972-3-9688588', '972 3 968 8588', '00972 3 968 8588', '+972 (0)3 968 8588', '(03) 968-8588']) {
    assert.equal(normalizePhone(raw, IL), '+97239688588', raw);
  }
  assert.equal(normalizePhone('052-123-4567', IL), '+972521234567');
  assert.equal(normalizePhone('*8818', IL), '*8818');
  assert.equal(normalizePhone('+44 20 7946 0000', IL), '+442079460000');
  assert.equal(normalizePhone('12', IL), null);
  assert.equal(samePhone('+972 3-968-8588', '03-9688588', IL), true);
  assert.equal(samePhone('03-9688588', '03-9688589', IL), false);
});

test('phone scanning finds Israeli forms in page text', () => {
  const text = 'טלפון: 03-9688588, נייד 052 123 4567, מוקד *8818, international +972-9-966-8133. Year 2026-10-05.';
  assert.deepEqual(findPhones(text, IL).sort(), ['*8818', '+97239688588', '+972521234567', '+97299668133'].sort());
});

test('phone normalization and scanning come from the region (ZZ: code 99, trunk 8)', () => {
  assert.equal(normalizePhone('8 123 4567', ZZ), '+991234567');
  assert.equal(normalizePhone('+99 123 4567', ZZ), '+991234567');
  assert.equal(samePhone('8-1234567', '+99 1234567', ZZ), true);
  // The same digits read as Israeli give a different number.
  assert.notEqual(normalizePhone('8 123 4567', IL), '+991234567');
  assert.deepEqual(findPhones('Tel 8 123 4567', ZZ), ['+991234567']);
  assert.deepEqual(findPhones('Tel 8 123 4567', IL), []);
});

test('name normalization removes the region\'s generic words', () => {
  assert.equal(normalizeName('Hebrew University Veterinary Teaching Hospital', IL), 'hebrew university teaching');
  assert.equal(normalizeName('המרפאה הווטרינרית של ד"ר כהן', IL), 'כהן');
  // All generic: the full name is kept so it can still be compared.
  assert.equal(normalizeName('Vet Center', IL), 'vet center');
  // ZZ's stop words, not Israel's.
  assert.equal(normalizeName('Clinique Vétérinaire Dupont', ZZ), 'vétérinaire dupont');
  assert.equal(normalizeName('Clinique de la Gare', ZZ), 'gare');
  assert.equal(normalizeName('Clinique de la Gare', IL), 'clinique de la gare');
  assert.equal(normalizeName('Gare Vet Clinic', ZZ), 'gare vet clinic');
});

test('name similarity', () => {
  assert.equal(nameSimilarity('Vet Center', 'VetCenter', IL), 1);
  assert.ok(nameSimilarity('Dr Cohen Veterinary Clinic', 'מרפאה וטרינרית - Cohen', IL) >= 0.6);
  assert.ok(nameSimilarity('Vet Center', 'Animal Planet', IL) < 0.6);
});

test('street + house number', () => {
  assert.deepEqual(streetAndNumber('דרך המכבים 70, ראשון לציון, ישראל', IL), { street: 'המכבים', number: '70' });
  assert.deepEqual(streetAndNumber('רחוב המרץ 7', IL), { street: 'המרץ', number: '7' });
  assert.equal(streetAndNumber('ראש העין', IL), null);
});

const A = facility({
  id: 'A',
  name: 'Vet Center',
  phone: '+97299668133',
  address: 'המרץ 7',
  lat: JERUSALEM.lat,
  lng: JERUSALEM.lng,
});

test('place-ID link matches whatever the distance or name', () => {
  const linked = { ...A, placeIds: ['pA'] };
  const far = offset(JERUSALEM, 5_000, 0);
  const m = matchPlaces([place({ placeId: 'pA', name: 'Something else', ...far })], [linked], IL);
  assert.deepEqual(m.get('pA'), { facilityId: 'A', via: 'place_id', matchedOn: 'place_id' });
});

test('heuristic match: close, similar name, same phone (+972 vs 0)', () => {
  const p = place({ placeId: 'p1', name: 'VET CENTER', nationalPhone: '09-966-8133', ...offset(JERUSALEM, 40, 30) });
  const m = matchPlaces([p], [A], IL);
  assert.deepEqual(m.get('p1'), { facilityId: 'A', via: 'heuristic', matchedOn: 'phone' });
});

test('heuristic match: same street + house number when phones differ', () => {
  const p = place({ placeId: 'p2', name: 'Vet Center', address: 'המרץ 7, ראש העין, ישראל', nationalPhone: '03-0000000', ...offset(JERUSALEM, 50, 0) });
  assert.equal(heuristicMatch(p, A, IL)?.matchedOn, 'address');
});

test('same chain, different branch: NOT matched', () => {
  const branch = place({
    placeId: 'p3',
    name: 'Vet Center',
    nationalPhone: '03-5555555',
    address: 'הרצל 10, רחובות',
    ...offset(JERUSALEM, 60, 0),
  });
  assert.equal(matchPlaces([branch], [A], IL).size, 0);
});

test('same name and phone but 300 m away: NOT matched', () => {
  const p = place({ placeId: 'p4', name: 'Vet Center', nationalPhone: '09-9668133', ...offset(JERUSALEM, 300, 0) });
  assert.equal(matchPlaces([p], [A], IL).size, 0);
});

test('a facility is matched at most once; the nearer place wins', () => {
  const near = place({ placeId: 'near', name: 'Vet Center', nationalPhone: '09-9668133', ...offset(JERUSALEM, 20, 0) });
  const less = place({ placeId: 'less', name: 'Vet Center', nationalPhone: '09-9668133', ...offset(JERUSALEM, 90, 0) });
  const m = matchPlaces([near, less], [A], IL);
  assert.equal(m.size, 1);
  assert.equal(m.get('near')?.facilityId, 'A');
});

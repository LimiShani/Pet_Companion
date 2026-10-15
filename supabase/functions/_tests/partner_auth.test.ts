import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readBodyWithin, signPostback, verifyPartnerPostback } from '../_shared/partner_auth.ts';

const secret = 'partner-secret-of-at-least-32-characters!';
const now = 1_790_000_000;
const body = '{"code":"PL-1A2B-3C4D-5E6F-7A8B","order":"77"}';

async function signed(overrides: { body?: string; timestamp?: number; signWith?: string; signature?: string } = {}) {
  const sentBody = overrides.body ?? body;
  const timestamp = String(overrides.timestamp ?? now);
  const signature = overrides.signature ??
    await signPostback(overrides.signWith ?? secret, timestamp, overrides.body ?? body);
  return new Request('https://example.test/partner-postback', {
    method: 'POST', body: sentBody,
    headers: { 'x-petloop-timestamp': timestamp, 'x-petloop-signature': signature },
  });
}

test('a correctly signed, fresh postback passes and returns the raw body', async () => {
  const verdict = await verifyPartnerPostback(await signed(), { secret, nowSeconds: now + 30 });
  assert.deepEqual(verdict, { ok: true, body });
});

test('the signature is case-insensitive hex', async () => {
  const signature = (await signPostback(secret, String(now), body)).toUpperCase();
  const verdict = await verifyPartnerPostback(await signed({ signature }), { secret, nowSeconds: now });
  assert.equal(verdict.ok, true);
});

test('a missing or short secret fails closed', async () => {
  for (const s of ['', 'short']) {
    assert.deepEqual(await verifyPartnerPostback(await signed(), { secret: s, nowSeconds: now }),
      { ok: false, reason: 'no_secret' });
  }
});

test('another partner\'s secret, a changed body or a forged signature fail', async () => {
  const other = await signed({ signWith: 'another-partner-secret-32-characters-long' });
  assert.deepEqual(await verifyPartnerPostback(other, { secret, nowSeconds: now }), { ok: false, reason: 'bad_signature' });
  const signature = await signPostback(secret, String(now), body);
  const tampered = await signed({ body: body.replace('77', '78'), signature });
  assert.deepEqual(await verifyPartnerPostback(tampered, { secret, nowSeconds: now }), { ok: false, reason: 'bad_signature' });
  const zeros = await signed({ signature: '0'.repeat(64) });
  assert.deepEqual(await verifyPartnerPostback(zeros, { secret, nowSeconds: now }), { ok: false, reason: 'bad_signature' });
});

test('an old or future-dated request is refused (replay window)', async () => {
  for (const timestamp of [now - 301, now + 301]) {
    assert.deepEqual(await verifyPartnerPostback(await signed({ timestamp }), { secret, nowSeconds: now }),
      { ok: false, reason: 'stale' });
  }
});

test('missing or malformed headers are refused before any work', async () => {
  const bare = new Request('https://example.test/partner-postback', { method: 'POST', body });
  assert.deepEqual(await verifyPartnerPostback(bare, { secret, nowSeconds: now }), { ok: false, reason: 'missing_headers' });
  const wrongLength = await signed({ signature: 'abc' });
  assert.deepEqual(await verifyPartnerPostback(wrongLength, { secret, nowSeconds: now }), { ok: false, reason: 'missing_headers' });
});

test('a body over the limit is refused without being read in full', async () => {
  let pulled = 0;
  const endless = new ReadableStream<Uint8Array>({
    pull(controller) { pulled++; controller.enqueue(new Uint8Array(4096)); },
  });
  const request = new Request('https://example.test/partner-postback', {
    method: 'POST', body: endless, duplex: 'half',
    headers: { 'x-petloop-timestamp': String(now), 'x-petloop-signature': '0'.repeat(64) },
  } as RequestInit);
  assert.deepEqual(await verifyPartnerPostback(request, { secret, nowSeconds: now }), { ok: false, reason: 'too_large' });
  assert.ok(pulled <= 4, `stopped after ${pulled} chunks`);
});

test('a declared Content-Length over the limit is refused at once', async () => {
  const request = new Request('https://example.test/x', { method: 'POST', body: 'x', headers: { 'content-length': '999999' } });
  assert.equal(await readBodyWithin(request, 8192), undefined);
});

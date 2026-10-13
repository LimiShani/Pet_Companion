// Partner postbacks (rewards, gamification Phase 3): a partner tells us a
// PetLoop coupon code was redeemed. The request is open to the internet
// (verify_jwt = false), so it is trusted only when it carries a valid
// HMAC-SHA256 signature made with that partner's own secret:
//
//   X-PetLoop-Timestamp: <unix seconds>
//   X-PetLoop-Signature: <hex of HMAC-SHA256(secret, "<timestamp>.<raw body>")>
//
// Checks run cheapest first and before anything is parsed: a missing or
// short secret fails closed, the body is read up to a size limit (a larger
// body is never read in full), the timestamp must be within five minutes
// (replays of an old request fail), and the signature is compared in
// constant time. Replays inside the window are stopped by the database:
// one postback per partner and external id (rewards_partner_postback).
//
// Secrets live in the function's environment (one per partner), never in
// a table, a migration or the app.

import { constantTimeEqual } from './weekly.ts';

export const POSTBACK_MAX_BYTES = 8_192;
export const POSTBACK_WINDOW_SECONDS = 300;
const MIN_SECRET_LENGTH = 32;

export type PostbackVerdict =
  | { ok: true; body: string }
  | { ok: false; reason: 'no_secret' | 'too_large' | 'missing_headers' | 'stale' | 'bad_signature' };

/** Reads at most [limit] bytes of the body; undefined when it is larger. */
export async function readBodyWithin(request: Request, limit: number): Promise<string | undefined> {
  const declared = Number(request.headers.get('content-length') ?? 'NaN');
  if (Number.isFinite(declared) && declared > limit) return undefined;
  if (!request.body) return '';
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      await reader.cancel();
      return undefined;
    }
    chunks.push(value);
  }
  const all = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    all.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(all);
}

/** Lower-case hex HMAC-SHA256 of "<timestamp>.<body>" (what partners sign). */
export async function signPostback(secret: string, timestamp: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${body}`));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export async function verifyPartnerPostback(
  request: Request,
  options: { secret: string; nowSeconds?: number; windowSeconds?: number; maxBytes?: number },
): Promise<PostbackVerdict> {
  if (options.secret.length < MIN_SECRET_LENGTH) return { ok: false, reason: 'no_secret' };
  const body = await readBodyWithin(request, options.maxBytes ?? POSTBACK_MAX_BYTES);
  if (body === undefined) return { ok: false, reason: 'too_large' };
  const timestamp = request.headers.get('x-petloop-timestamp') ?? '';
  const signature = (request.headers.get('x-petloop-signature') ?? '').toLowerCase();
  if (!/^\d{9,11}$/.test(timestamp) || !/^[0-9a-f]{64}$/.test(signature)) {
    return { ok: false, reason: 'missing_headers' };
  }
  const now = options.nowSeconds ?? Math.floor(Date.now() / 1000);
  if (Math.abs(now - Number(timestamp)) > (options.windowSeconds ?? POSTBACK_WINDOW_SECONDS)) {
    return { ok: false, reason: 'stale' };
  }
  const expected = await signPostback(options.secret, timestamp, body);
  if (!constantTimeEqual(expected, signature)) return { ok: false, reason: 'bad_signature' };
  return { ok: true, body };
}

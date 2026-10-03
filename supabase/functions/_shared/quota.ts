// Rate-limit keys and limits. A caller is identified only by a SHA-256 of
// (UTC day, server secret, IP): the key changes every day, cannot be turned
// back into the IP without the secret, and the raw IP is never stored or
// logged.

/** Per-client limit: this many searches/geocodes per window. */
export const CLIENT_LIMIT = 30;
export const CLIENT_WINDOW_MINUTES = 10;

/** Default daily provider caps (see docs/find_a_vet.md, "Backend setup", for the arithmetic). */
export const DEFAULT_DAILY_PLACES_CAP = 30;
export const DEFAULT_DAILY_GEOCODE_CAP = 300;

/** Quota bucket names for the provider caps (counted per UTC day). */
export const PLACES_BUCKET = 'provider:places';
export const GEOCODE_BUCKET = 'provider:geocode';

/**
 * The caller's IP as the edge reports it: the first x-forwarded-for entry,
 * else cf-connecting-ip, else 'unknown' (all unknown callers then share one
 * bucket, which fails safe).
 */
export function clientIp(headers: Headers): string {
  const xff = headers.get('x-forwarded-for');
  if (xff) {
    const first = xff.split(',')[0].trim();
    if (first !== '') return first;
  }
  const cf = headers.get('cf-connecting-ip');
  if (cf && cf.trim() !== '') return cf.trim();
  return 'unknown';
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * The quota bucket for a caller: 'client:' + 32 hex characters of
 * SHA-256(day | secret | ip). `secret` should be a server-only value
 * (VET_QUOTA_SALT, else the service role key): without it an attacker
 * could hash all IPv4 addresses for a day and reverse the key.
 */
export async function clientBucket(headers: Headers, now: Date, secret: string): Promise<string> {
  const day = now.toISOString().slice(0, 10);
  const hash = await sha256Hex(`${day}|${secret}|${clientIp(headers)}`);
  return `client:${hash.slice(0, 32)}`;
}

/** Parses a positive integer env value, else the default. */
export function positiveIntOr(value: string | undefined | null, fallback: number): number {
  if (value === undefined || value === null || value.trim() === '') return fallback;
  const n = Number(value);
  return Number.isInteger(n) && n >= 0 ? n : fallback;
}

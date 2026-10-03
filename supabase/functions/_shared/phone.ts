// Phone numbers: normalize to E.164 with the region's calling code and trunk
// prefix, and find numbers in page text with the region's pattern.

import type { RegionConfig } from './regions/types.ts';

/**
 * E.164 ('+97239688588') for a number written any common way in the region
 * ('03-9688588', '+972 3 968 8588', '+972 (0)3...', '00972...'), the star
 * form for short service numbers ('*8818'), or null when it is not a phone
 * number. A number with another country's '+' code is kept as given (digits
 * only) so it never collides with a local one.
 */
export function normalizePhone(raw: string | null | undefined, region: RegionConfig): string | null {
  if (typeof raw !== 'string') return null;
  const s = raw.trim();
  if (s === '') return null;
  const star = /^\*\s*(\d{3,5})$/.exec(s);
  if (star) return `*${star[1]}`;

  const cc = region.phone.countryCallingCode;
  const trunk = region.phone.trunkPrefix;
  let digits = s.replace(/\D/g, '');
  if (s.startsWith('+')) {
    if (!digits.startsWith(cc)) return digits.length >= 7 && digits.length <= 15 ? `+${digits}` : null;
    digits = digits.slice(cc.length);
  } else if (digits.startsWith(`00${cc}`)) {
    digits = digits.slice(2 + cc.length);
  } else if (trunk !== '' && digits.startsWith(trunk)) {
    digits = digits.slice(trunk.length);
  } else if (digits.startsWith(cc) && digits.length > cc.length + 6) {
    // Written without '+' ("972 3 968 8588").
    digits = digits.slice(cc.length);
  }
  // "+972 (0)3 ..." leaves the trunk prefix after the calling code.
  if (trunk !== '' && digits.startsWith(trunk)) digits = digits.slice(trunk.length);
  if (digits.length < 6 || digits.length > 13) return null;
  return `+${cc}${digits}`;
}

/** True when both normalize to the same number. */
export function samePhone(
  a: string | null | undefined,
  b: string | null | undefined,
  region: RegionConfig,
): boolean {
  const na = normalizePhone(a, region);
  return na !== null && na === normalizePhone(b, region);
}

/** Every distinct phone number (normalized) found in a text. */
export function findPhones(text: string, region: RegionConfig): string[] {
  const re = new RegExp(region.phone.scanPattern, 'gu');
  const found = new Set<string>();
  for (const m of text.matchAll(re)) {
    const n = normalizePhone(m[0], region);
    if (n !== null) found.add(n);
  }
  return [...found];
}

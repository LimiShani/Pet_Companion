// The region registry. Adding a country: create regions/<code>.ts exporting a
// RegionConfig and add it to REGIONS below (see docs/find_a_vet.md,
// "Backend setup" > "Adding a country").

import type { RegionConfig } from './types.ts';
import { IL } from './il.ts';

export type { RegionConfig, BoundingBox } from './types.ts';

/** Every region the backend serves, by ISO alpha-2 code. */
export const REGIONS: Readonly<Record<string, RegionConfig>> = Object.freeze({
  IL,
});

/** Used when a request does not name a region. */
export const DEFAULT_REGION_CODE = 'IL';

/** The region for an ISO alpha-2 code (any case), or undefined if not served. */
export function getRegion(code: string): RegionConfig | undefined {
  if (typeof code !== 'string') return undefined;
  const key = code.trim().toUpperCase();
  return Object.prototype.hasOwnProperty.call(REGIONS, key) ? REGIONS[key] : undefined;
}

/** The lookup the handlers take, so tests can pass their own regions. */
export interface RegionLookup {
  get(code: string): RegionConfig | undefined;
  list(): RegionConfig[];
  defaultCode: string;
}

export const registryLookup: RegionLookup = {
  get: getRegion,
  list: () => Object.values(REGIONS),
  defaultCode: DEFAULT_REGION_CODE,
};

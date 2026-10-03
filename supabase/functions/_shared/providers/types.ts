// The places-provider adapter. The search pipeline talks only to this
// interface, so the provider (Google today) can be swapped or disabled
// without touching it. ProviderPlace is provider-neutral and lives only in
// memory for one response: apart from the place ID, nothing in it is ever
// stored (Google Maps Platform terms).

import type { RegionConfig } from '../regions/types.ts';
import type { BusinessStatus } from '../types.ts';

export interface ProviderPlace {
  placeId: string;
  name: string;
  address: string | null;
  lat: number;
  lng: number;
  nationalPhone: string | null;
  internationalPhone: string | null;
  website: string | null;
  /** Link to the place on the provider's map; kept on every provider result. */
  mapsUri: string | null;
  businessStatus: BusinessStatus | null;
  /** null when the provider has no live hours for the place. */
  openNow: boolean | null;
  weekdayText: string[];
}

export interface GeocodeResult {
  label: string;
  lat: number;
  lng: number;
}

export interface NearbyQuery {
  lat: number;
  lng: number;
  radiusM: number;
  lang: string;
  maxResults: number;
  region: RegionConfig;
}

/** Outcome of one provider call; `status` maps 1:1 to the response's provider.status. */
export type ProviderOutcome<T> =
  | { status: 'ok'; value: T }
  | { status: 'error' | 'timeout' | 'disabled' | 'quota'; detail?: string };

export interface PlacesProvider {
  /** Short provider name for the response ("google", "none"). */
  readonly name: string;
  /** False for the disabled provider: the search skips it without spending quota. */
  readonly enabled: boolean;
  /** Plain-text attribution the app must show next to provider content. */
  readonly attribution: string | null;
  nearbyVets(q: NearbyQuery): Promise<ProviderOutcome<ProviderPlace[]>>;
  geocode(query: string, lang: string, region: RegionConfig): Promise<ProviderOutcome<GeocodeResult[]>>;
}

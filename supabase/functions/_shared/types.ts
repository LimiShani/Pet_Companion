// Data shapes shared by the search pipeline, the store and the handlers.
// The response shapes (VetResult, SearchResponse) are the API contract in
// docs/find_a_vet.md; keep every field name in step with it.

import type { LatLng } from './geo.ts';

export type Mode = 'emergency' | 'long_term';

export type ProviderStatus = 'ok' | 'error' | 'disabled' | 'quota' | 'timeout';

export type IntakeStatus = 'accepting' | 'limited' | 'diverting';

export type ReviewStatus = 'pending' | 'approved' | 'needs_review' | 'withdrawn';

/** The `emergency` object of a vet_directory_public row (null when no claim). */
export interface CuratedEmergency {
  state: 'advertised' | 'unverified';
  schedule: string | null;
  sourceUrl: string | null;
  checkedAt: string | null;
  confirmedAt: string | null;
}

/** One element of a vet_directory_public row's `facts` array. */
export interface CuratedFact {
  key: string;
  value: unknown;
  sourceUrl: string | null;
  checkedAt: string | null;
}

/** A curated facility as the search sees it (the public view + its place IDs). */
export interface CuratedFacility {
  id: string;
  countryCode: string;
  name: string;
  nameHe: string | null;
  address: string | null;
  city: string | null;
  lat: number | null;
  lng: number | null;
  phone: string | null;
  website: string | null;
  facilityType: string;
  reviewStatus: ReviewStatus;
  lastCheckedAt: string | null;
  lastConfirmedAt: string | null;
  emergency: CuratedEmergency | null;
  facts: CuratedFact[];
  /** Linked provider place IDs (vet_facility_provider_ids, provider 'google'). */
  placeIds: string[];
}

/** A vet_intake_current row. */
export interface IntakeRow {
  facilityId: string;
  status: IntakeStatus;
  species: string[];
  updatedAt: string;
  expiresAt: string;
}

/** A heuristic match waiting for an admin (place ID only, never provider content). */
export interface LinkCandidate {
  facilityId: string;
  placeId: string;
  matchedOn: 'phone' | 'address';
}

export interface EmergencyView {
  state: 'advertised' | 'unverified' | 'not_listed';
  schedule: string | null;
  sourceUrl: string | null;
  checkedAt: string | null;
  confirmedAt: string | null;
}

export interface OpenView {
  state: 'open' | 'closed' | 'unknown';
  basis: 'provider_hours' | 'curated_schedule' | 'none';
  weekdayText: string[];
}

export interface IntakeView {
  state: IntakeStatus | 'unknown';
  species: string[];
  updatedAt: string | null;
  expiresAt: string | null;
}

export type BusinessStatus = 'operational' | 'closed_temporarily' | 'closed_permanently';

export interface VetResult {
  key: string;
  facilityId: string | null;
  placeId: string | null;
  name: string;
  address: string | null;
  location: LatLng;
  distanceM: number;
  phone: string | null;
  website: string | null;
  mapsUri: string | null;
  fromProvider: boolean;
  fromCurated: boolean;
  businessStatus: BusinessStatus | null;
  emergency: EmergencyView;
  open: OpenView;
  intake: IntakeView;
  facts: CuratedFact[];
  lastCheckedAt: string | null;
  stale: boolean;
  reviewStatus: 'approved' | 'needs_review' | null;
}

export type Notice = 'radius_expanded' | 'provider_unavailable' | 'no_results' | 'curated_unavailable';

export interface SearchResponse {
  region: string;
  searchedAt: string;
  mode: Mode;
  center: LatLng;
  radiusM: number;
  expanded: boolean;
  provider: { name: string; status: ProviderStatus; attribution: string | null };
  results: VetResult[];
  notices: Notice[];
}

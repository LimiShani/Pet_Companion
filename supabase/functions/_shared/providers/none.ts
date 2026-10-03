// The provider used when no API key is configured: every call answers
// 'disabled', and the search falls back to curated records only.

import type { PlacesProvider } from './types.ts';

export const noneProvider: PlacesProvider = {
  name: 'none',
  enabled: false,
  attribution: null,
  nearbyVets: () => Promise.resolve({ status: 'disabled' }),
  geocode: () => Promise.resolve({ status: 'disabled' }),
};

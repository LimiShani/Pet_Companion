// Edge Function `find-vet`: emergency and long-term vet search, geocoding,
// and the list of served regions. Contract: docs/find_a_vet.md ("API").
//
// Environment (Supabase function secrets):
//   GOOGLE_PLACES_API_KEY    optional; without it the provider is disabled and
//                            only curated records are returned
//   VET_DAILY_PROVIDER_CAP   Nearby Search calls per UTC day (default 30)
//   VET_DAILY_GEOCODE_CAP    Geocoding calls per UTC day (default 300)
//   VET_QUOTA_SALT           optional secret for the client hash (default:
//                            the service role key)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   provided by Supabase
//
// Deployed with verify_jwt = false (supabase/config.toml): the search works
// without sign-in; abuse is held back by the per-client and daily limits.

import { createFindVetHandler } from '../_shared/find_vet_handler.ts';
import { createFeatureAuthorizer } from '../_shared/access.ts';
import { createGoogleProvider } from '../_shared/providers/google.ts';
import { noneProvider } from '../_shared/providers/none.ts';
import { DEFAULT_DAILY_GEOCODE_CAP, DEFAULT_DAILY_PLACES_CAP, positiveIntOr } from '../_shared/quota.ts';
import { registryLookup } from '../_shared/regions/index.ts';
import { createPostgrestStore } from '../_shared/store.ts';

const env = (name: string): string | undefined => Deno.env.get(name) ?? undefined;

const supabaseUrl = env('SUPABASE_URL') ?? '';
const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const googleKey = env('GOOGLE_PLACES_API_KEY');

const handler = createFindVetHandler({
  authorize: (request) => createFeatureAuthorizer({ url: supabaseUrl, serviceKey })(request, 'findvet.search'),
  provider: googleKey ? createGoogleProvider({ apiKey: googleKey }) : noneProvider,
  store: createPostgrestStore({ url: supabaseUrl, serviceKey }),
  regions: registryLookup,
  now: () => new Date(),
  quotaSecret: env('VET_QUOTA_SALT') || serviceKey,
  dailyPlacesCap: positiveIntOr(env('VET_DAILY_PROVIDER_CAP'), DEFAULT_DAILY_PLACES_CAP),
  dailyGeocodeCap: positiveIntOr(env('VET_DAILY_GEOCODE_CAP'), DEFAULT_DAILY_GEOCODE_CAP),
});

Deno.serve(handler);

// Edge Function `parks-import`: the monthly OpenStreetMap import of dog
// parks (logic in ../_shared/parks_import.ts, schedule in
// supabase/scheduling/parks_import.sql, design in docs/dog_parks.md).
//
// Call: POST with header `x-job-secret: <PARKS_JOB_SECRET>`, body `{}` or
// `{"force": true}` (redo a month that already finished, or accept a
// download with less than half of the parks we know).
//
// Environment (Supabase function secrets):
//   PARKS_JOB_SECRET   required; without it the function refuses to run
//   OVERPASS_URL       optional; another Overpass instance
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   provided by Supabase

import { createParksImportHandler, createPostgrestParksStore, OVERPASS_URL } from '../_shared/parks_import.ts';
import { IL_LOCALITIES } from '../_shared/regions/il_localities.ts';

const env = (name: string): string => Deno.env.get(name) ?? '';

const handler = createParksImportHandler({
  store: createPostgrestParksStore({ url: env('SUPABASE_URL'), serviceKey: env('SUPABASE_SERVICE_ROLE_KEY') }),
  fetch: (input, init) => fetch(input, init),
  now: () => new Date(),
  localities: IL_LOCALITIES,
  overpassUrl: env('OVERPASS_URL') || OVERPASS_URL,
  jobSecret: env('PARKS_JOB_SECRET'),
});

Deno.serve(handler);

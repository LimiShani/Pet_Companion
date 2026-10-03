// Edge Function `vet-directory-weekly`: the weekly re-check of curated
// directory claims (logic in ../_shared/weekly.ts, schedule in
// supabase/scheduling/vet_directory_weekly.sql).
//
// Call: POST with header `x-job-secret: <VET_JOB_SECRET>`, body `{}` or
// `{"force": true}` to redo a week that already finished.
//
// Environment (Supabase function secrets):
//   VET_JOB_SECRET   required; without it the function refuses to run
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   provided by Supabase
//
// The job never calls Google and never needs the places key.

import { registryLookup } from '../_shared/regions/index.ts';
import { createPostgrestStore } from '../_shared/store.ts';
import { createWeeklyHandler } from '../_shared/weekly.ts';

const env = (name: string): string => Deno.env.get(name) ?? '';

const handler = createWeeklyHandler({
  store: createPostgrestStore({ url: env('SUPABASE_URL'), serviceKey: env('SUPABASE_SERVICE_ROLE_KEY') }),
  fetch: (input, init) => fetch(input, init),
  now: () => new Date(),
  regions: registryLookup,
  jobSecret: env('VET_JOB_SECRET'),
});

Deno.serve(handler);

// Edge Function `community-push`: community push notifications (logic in
// ../_shared/push_handler.ts, schedule in
// supabase/scheduling/community_push.sql).
//
// Call: POST with header `x-job-secret: <PUSH_JOB_SECRET>`, body `{}`.
//
// Environment (Supabase function secrets):
//   PUSH_JOB_SECRET       required; without it every call is refused
//   FCM_SERVICE_ACCOUNT   the Firebase service account JSON key; without it
//                         the function answers 503 and rows wait
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   provided by Supabase

import { parseServiceAccount } from '../_shared/fcm.ts';
import { createPushHandler } from '../_shared/push_handler.ts';

const env = (name: string): string => Deno.env.get(name) ?? '';

Deno.serve(createPushHandler({
  url: env('SUPABASE_URL'),
  serviceKey: env('SUPABASE_SERVICE_ROLE_KEY'),
  jobSecret: env('PUSH_JOB_SECRET'),
  account: parseServiceAccount(env('FCM_SERVICE_ACCOUNT')),
}));

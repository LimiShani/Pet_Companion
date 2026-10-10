-- PetLoop: schedule the monthly dog parks import (Edge Function
-- `parks-import`) with pg_cron + pg_net. Both extensions are available on
-- the Supabase free plan.
--
-- Run in the Supabase SQL editor AFTER:
--   1. 0027_dog_parks.sql is applied,
--   2. the function is deployed (supabase functions deploy parks-import), and
--   3. the function secret PARKS_JOB_SECRET is set
--      (supabase secrets set PARKS_JOB_SECRET=<a long random string>).
--
-- Before running, replace the two placeholders below:
--   <project-ref>                 your project's ref (Dashboard > Project Settings > General)
--   <same as PARKS_JOB_SECRET>    the exact value of the function secret
-- Safe to run more than once: secrets are created only if missing and the
-- job is unscheduled before it is scheduled again.
--
-- When: '0 1 3 * *' = 01:00 UTC on the 3rd of every month (03:00/04:00 in
-- Israel). One Overpass query a month, as the OpenStreetMap usage policy
-- asks; the run is recorded per UTC month in public.dog_park_import_runs.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'parks_project_url') then
    perform vault.create_secret('https://<project-ref>.supabase.co', 'parks_project_url',
                                'PetLoop: project URL for the parks-import cron job');
  end if;
  if not exists (select 1 from vault.secrets where name = 'parks_job_secret') then
    perform vault.create_secret('<same as PARKS_JOB_SECRET>', 'parks_job_secret',
                                'PetLoop: x-job-secret header for parks-import');
  end if;
end;
$$;

select cron.unschedule(jobid) from cron.job where jobname = 'parks-import';

select cron.schedule(
  'parks-import',
  '0 1 3 * *',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'parks_project_url')
           || '/functions/v1/parks-import',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-job-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'parks_job_secret')
    ),
    body := '{}'::jsonb,
    -- Edge Functions may run up to 150 s on the free plan; wait that long.
    timeout_milliseconds := 150000
  );
  $job$
);

-- ---------------------------------------------------------------------------
-- The FIRST import: run it once by hand, right after scheduling (same call
-- as the schedule):
--
--   select net.http_post(
--     url := (select decrypted_secret from vault.decrypted_secrets where name = 'parks_project_url')
--            || '/functions/v1/parks-import',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'x-job-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'parks_job_secret')),
--     body := '{}'::jsonb,
--     timeout_milliseconds := 150000);
--
-- Add "force" (body := '{"force": true}'::jsonb) to redo a month that
-- already finished, or to accept a download with less than half of the
-- parks we know (the import refuses one otherwise, so a broken download
-- never sends every park to review).
--
-- The answer arrives asynchronously; read it a minute later with
--   select id, status_code, content from net._http_response order by id desc limit 5;
-- and the run's bookkeeping with
--   select period_key, status, stats, error from public.dog_park_import_runs order by started_at desc limit 5;
-- Parks waiting for a reviewer:
--   select count(*) from public.dog_parks where status = 'pending_review';
--
-- Check the schedule / last runs:
--   select jobid, jobname, schedule from cron.job where jobname = 'parks-import';
--   select status, return_message, start_time from cron.job_run_details
--     where jobid = (select jobid from cron.job where jobname = 'parks-import')
--     order by start_time desc limit 5;
--
-- Change a stored secret later:
--   select vault.update_secret((select id from vault.secrets where name = 'parks_job_secret'), '<new value>');
-- Stop the schedule:
--   select cron.unschedule('parks-import');

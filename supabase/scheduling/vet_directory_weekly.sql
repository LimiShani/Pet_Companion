-- PetLoop: schedule the weekly directory check (Edge Function
-- `vet-directory-weekly`) with pg_cron + pg_net. Both extensions are
-- available on the Supabase free plan.
--
-- Run in the Supabase SQL editor AFTER:
--   1. 0012_vet_directory.sql is applied,
--   2. the function is deployed, and
--   3. the function secret VET_JOB_SECRET is set.
--
-- Before running, replace the two placeholders below:
--   <project-ref>       your project's ref (Dashboard > Project Settings > General)
--   <same as VET_JOB_SECRET>  the exact value of the function secret
-- Safe to run more than once: secrets are created only if missing (to change
-- one later, see the vault.update_secret note at the end) and the job is
-- unscheduled before it is scheduled again.
--
-- When: '0 0 * * 1' = every Monday 00:00 UTC = 03:00 Israel summer time
-- (IDT, UTC+3) and 02:00 in winter (IST, UTC+2). pg_cron runs in UTC; the
-- job's period_key is the ISO week in UTC either way.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- Project URL and job secret live in Vault, not in the job text.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'vet_project_url') then
    perform vault.create_secret('https://<project-ref>.supabase.co', 'vet_project_url',
                                'PetLoop: project URL for the vet-directory-weekly cron job');
  end if;
  if not exists (select 1 from vault.secrets where name = 'vet_job_secret') then
    perform vault.create_secret('<same as VET_JOB_SECRET>', 'vet_job_secret',
                                'PetLoop: x-job-secret header for vet-directory-weekly');
  end if;
end;
$$;

-- (Re)schedule.
select cron.unschedule(jobid) from cron.job where jobname = 'vet-directory-weekly';

select cron.schedule(
  'vet-directory-weekly',
  '0 0 * * 1',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'vet_project_url')
           || '/functions/v1/vet-directory-weekly',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-job-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'vet_job_secret')
    ),
    body := '{}'::jsonb,
    -- Edge Functions may run up to 150 s on the free plan; wait that long.
    timeout_milliseconds := 150000
  );
  $job$
);

-- ---------------------------------------------------------------------------
-- Run it once by hand (same call as the schedule). Add "force" to redo a
-- week that already finished: body := '{"force": true}'::jsonb
--
--   select net.http_post(
--     url := (select decrypted_secret from vault.decrypted_secrets where name = 'vet_project_url')
--            || '/functions/v1/vet-directory-weekly',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'x-job-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'vet_job_secret')),
--     body := '{}'::jsonb,
--     timeout_milliseconds := 150000);
--
-- The answer arrives asynchronously; read it a few seconds later with
--   select id, status_code, content from net._http_response order by id desc limit 5;
-- and the run's bookkeeping with
--   select period_key, status, stats, errors from public.vet_job_runs order by started_at desc limit 5;
--
-- Check the schedule / last runs:
--   select jobid, jobname, schedule from cron.job where jobname = 'vet-directory-weekly';
--   select status, return_message, start_time from cron.job_run_details
--     where jobid = (select jobid from cron.job where jobname = 'vet-directory-weekly')
--     order by start_time desc limit 5;
--
-- Change a stored secret later:
--   select vault.update_secret((select id from vault.secrets where name = 'vet_job_secret'), '<new value>');
-- Stop the schedule:
--   select cron.unschedule('vet-directory-weekly');

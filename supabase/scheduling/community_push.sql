-- PetLoop: wire the database to the Edge Function `community-push`.
--
-- Run in the Supabase SQL editor AFTER:
--   1. 0023_community_push.sql is applied,
--   2. the function is deployed, and
--   3. the function secrets PUSH_JOB_SECRET and FCM_SERVICE_ACCOUNT are set.
--
-- Before running, replace the two placeholders below:
--   <project-ref>             your project's ref (Dashboard > Project Settings > General)
--   <same as PUSH_JOB_SECRET> the exact value of the function secret
-- Only edit the quoted placeholders on those two lines; this file holds no
-- other secret.
--
-- What it does: stores the project URL and the job secret in Vault (the
-- comment, like and answer triggers read them to call the function at
-- once), and schedules a run every five minutes for anything a failed
-- call left waiting. Safe to run more than once.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'push_project_url') then
    perform vault.create_secret('https://<project-ref>.supabase.co', 'push_project_url',
                                'PetLoop: project URL for community-push');
  end if;
  if not exists (select 1 from vault.secrets where name = 'push_job_secret') then
    perform vault.create_secret('<same as PUSH_JOB_SECRET>', 'push_job_secret',
                                'PetLoop: x-job-secret header for community-push');
  end if;
end;
$$;

select cron.unschedule(jobid) from cron.job where jobname = 'community-push';

select cron.schedule(
  'community-push',
  '*/5 * * * *',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'push_project_url')
           || '/functions/v1/community-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-job-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_job_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $job$
);

-- ---------------------------------------------------------------------------
-- To change a stored value later (for example after rotating the secret):
--   select vault.update_secret(
--     (select id from vault.secrets where name = 'push_job_secret'),
--     '<new value>');
--
-- To see whether rows are waiting or were sent:
--   select kind, created_at, sent_at, attempts from public.push_outbox
--   order by id desc limit 20;

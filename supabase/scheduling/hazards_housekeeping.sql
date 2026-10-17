-- PetLoop: delete hazard reports 30 days after they expired, with pg_cron.
-- Available on the Supabase free plan. No Edge Function and no secret: the
-- job calls the database function directly.
--
-- Run in the Supabase SQL editor AFTER 0035_neighbourhood.sql.
-- Safe to run more than once: the job is unscheduled before it is
-- scheduled again. Without it nothing breaks: the same clean-up runs on
-- every new report, and expired reports are never shown.
--
-- When: '29 2 * * *' = 02:29 UTC every day.
--
-- Check it: select * from cron.job_run_details
--           where jobid = (select jobid from cron.job where jobname = 'hazards-housekeeping')
--           order by start_time desc limit 5;
-- Run it by hand: select community_private.hazards_housekeeping();

create extension if not exists pg_cron;

select cron.unschedule(jobid) from cron.job where jobname = 'hazards-housekeeping';

select cron.schedule(
  'hazards-housekeeping',
  '29 2 * * *',
  $$set statement_timeout = '60s'; select community_private.hazards_housekeeping();$$
);

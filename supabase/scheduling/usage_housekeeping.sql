-- PetLoop: delete usage counts older than 400 days, with pg_cron. Available
-- on the Supabase free plan. No Edge Function and no secret: the job calls
-- the database function directly.
--
-- Run in the Supabase SQL editor AFTER 0031_usage_counts.sql.
-- Safe to run more than once: the job is unscheduled before it is
-- scheduled again.
--
-- When: '17 2 * * *' = 02:17 UTC every day. One short delete by day (the
-- table is indexed by day); it also forgets the per-day call counters of
-- the rate limit after a week.
--
-- Check it: select * from cron.job_run_details
--           where jobid = (select jobid from cron.job where jobname = 'usage-housekeeping')
--           order by start_time desc limit 5;
-- Run it by hand: select usage_private.housekeeping();

create extension if not exists pg_cron;

select cron.unschedule(jobid) from cron.job where jobname = 'usage-housekeeping';

select cron.schedule(
  'usage-housekeeping',
  '17 2 * * *',
  $$set statement_timeout = '60s'; select usage_private.housekeeping();$$
);

-- PetLoop: schedule the rewards rollup (milestones, care rhythm, community
-- standing, shopper tiers, partner checks) with pg_cron. Available on the
-- Supabase free plan. No Edge Function and no secret: the job calls the
-- database function directly.
--
-- Run in the Supabase SQL editor AFTER 0029_rewards_foundation.sql.
-- Safe to run more than once: the job is unscheduled before it is
-- scheduled again.
--
-- When: every 10 minutes. Each run does at least one batch of 200 pets or
-- members and stops after about 25 seconds; it resumes where it stopped.
-- Once a day's run is complete (UTC) the later runs that day do nothing,
-- so the real work happens shortly after midnight UTC. A run that collides
-- with another is skipped (advisory lock). statement_timeout bounds a
-- runaway run; a timed-out run rolls back and the next one retries.
--
-- Check it: select * from cron.job_run_details
--           where jobid = (select jobid from cron.job where jobname = 'rewards-rollup')
--           order by start_time desc limit 5;
--           select * from rewards_private.rollup_state;

create extension if not exists pg_cron;

select cron.unschedule(jobid) from cron.job where jobname = 'rewards-rollup';

select cron.schedule(
  'rewards-rollup',
  '*/10 * * * *',
  $$set statement_timeout = '60s'; select rewards_private.rollup_step(200, interval '25 seconds');$$
);

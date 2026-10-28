-- schedule_workers.sql
-- Purpose: Activate trusted development workers with pg_cron, pg_net, and Vault.
-- Replace __PROJECT_REF__ only after selecting the target project. Never commit a token.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'team_check_in_scheduler') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'team_check_in_scheduler');
  end if;
end;
$$;

select cron.schedule('team-check-in-open-events', '* * * * *', $job$
  select net.http_post(
    url := 'https://__PROJECT_REF__.supabase.co/functions/v1/process-due-events',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'X-Team-CheckIn-Scheduler', (select decrypted_secret from vault.decrypted_secrets where name = 'team_check_in_scheduler')),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
$job$);

select cron.schedule('team-check-in-orphan-photos', '17 * * * *', $job$
  select net.http_post(
    url := 'https://__PROJECT_REF__.supabase.co/functions/v1/cleanup-orphan-photos',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'X-Team-CheckIn-Scheduler', (select decrypted_secret from vault.decrypted_secrets where name = 'team_check_in_scheduler')),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
$job$);

-- This removes only this app's old operational job logs, never athlete content.
select cron.schedule('team-check-in-job-log-cleanup', '23 3 * * *', $job$
  delete from cron.job_run_details where runid in (
    select r.runid from cron.job_run_details r join cron.job j on j.jobid = r.jobid
    where j.jobname in ('team-check-in-open-events', 'team-check-in-orphan-photos', 'team-check-in-job-log-cleanup')
      and r.end_time < now() - interval '7 days'
    order by r.runid limit 1000
  );
$job$);

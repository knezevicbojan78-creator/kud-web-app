-- FOLKLORAS DEV/V1
-- Automatski obracun clanarine svakog prvog dana u mesecu.
-- Pokrenuti nakon finance-v1-membership-workflows.sql.

create extension if not exists pg_cron with schema pg_catalog;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid from cron.job where jobname = 'folkloras-monthly-membership-fees'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end $$;

select cron.schedule(
  'folkloras-monthly-membership-fees',
  '10 0 1 * *',
  $job$select public.finance_generate_all_membership_fees(current_date);$job$
);

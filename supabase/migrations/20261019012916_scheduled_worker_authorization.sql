-- 20261019012916_scheduled_worker_authorization.sql
-- Purpose: Validate a scoped scheduler secret only through the trusted server role.
-- Activation and the generated secret live in the separate deployment script.
create or replace function public.authorize_scheduled_worker(p_token text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select length(p_token) = 64 and p_token ~ '^[a-f0-9]{64}$' and exists (
    select 1 from vault.decrypted_secrets
    where name = 'team_check_in_scheduler' and decrypted_secret = p_token
  );
$$;
revoke all on function public.authorize_scheduled_worker(text) from public, anon, authenticated;
grant execute on function public.authorize_scheduled_worker(text) to service_role;

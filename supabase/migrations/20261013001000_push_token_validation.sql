-- 20261013001000_push_token_validation.sql
-- Purpose: Validate variable token sizes without exceeding PostgreSQL regex repetition bounds.
alter table private.push_devices drop constraint push_devices_device_token_check;
alter table private.push_devices add constraint push_devices_device_token_check
    check(device_token ~ '^[a-f0-9]+$' and length(device_token) between 32 and 512 and length(device_token) % 2 = 0);
create or replace function public.register_push_device(p_installation uuid,p_token text,p_environment text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_session uuid := (auth.jwt()->>'session_id')::uuid;
begin
    if v_user is null or v_session is null or p_installation is null
        or p_token is null or p_token !~ '^[a-fA-F0-9]+$' or length(p_token) not between 32 and 512 or length(p_token) % 2 <> 0
        or p_environment is null or p_environment not in ('sandbox','production') then
        raise exception 'Valid account, installation, token, and environment are required';
    end if;
    if not exists(select 1 from auth.sessions where id=v_session and user_id=v_user) then
        raise exception 'A live account session is required';
    end if;
    -- Reinstallation can reuse an Apple token. One device must not notify two accounts.
    delete from private.push_devices where environment=p_environment and device_token=lower(p_token)
        and installation_id <> p_installation;
    insert into private.push_devices(installation_id,user_id,session_id,device_token,environment,updated_at,expires_at)
        values(p_installation,v_user,v_session,lower(p_token),p_environment,clock_timestamp(),clock_timestamp()+interval '7 days')
        on conflict(installation_id) do update set user_id=excluded.user_id,session_id=excluded.session_id,
            device_token=excluded.device_token,environment=excluded.environment,
            updated_at=excluded.updated_at,expires_at=excluded.expires_at;
end;
$$;

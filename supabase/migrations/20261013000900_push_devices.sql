-- 20261013000900_push_devices.sql
-- Purpose: Bind private device registrations to authenticated accounts and live sessions.
create table private.push_devices (
    installation_id uuid primary key,
    user_id uuid not null references auth.users on delete cascade,
    session_id uuid not null,
    device_token text not null check(device_token ~ '^[a-f0-9]{32,512}$' and length(device_token) % 2 = 0),
    environment text not null check(environment in ('sandbox','production')),
    updated_at timestamptz not null default now(),
    expires_at timestamptz not null,
    unique(environment,device_token)
);
create index push_devices_user_idx on private.push_devices(user_id);
alter table private.push_devices enable row level security;
revoke all on private.push_devices from public, anon, authenticated;

create function public.register_push_device(p_installation uuid,p_token text,p_environment text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_session uuid := (auth.jwt()->>'session_id')::uuid;
begin
    if v_user is null or v_session is null or p_installation is null
        or p_token is null or p_token !~ '^[a-fA-F0-9]{32,512}$' or length(p_token) % 2 <> 0
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
create function public.revoke_push_device(p_installation uuid) returns void
language sql security definer set search_path = '' as $$
    delete from private.push_devices where installation_id=p_installation and user_id=auth.uid();
$$;
create function public.list_push_devices(p_user uuid) returns jsonb
language sql security definer set search_path = '' as $$
    select coalesce(jsonb_agg(jsonb_build_object('installation_id',d.installation_id,
        'device_token',d.device_token,'environment',d.environment,'updated_at',d.updated_at)), '[]'::jsonb)
    from private.push_devices d join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
    where d.user_id=p_user and d.expires_at > clock_timestamp();
$$;
revoke all on function public.register_push_device(uuid,text,text),public.revoke_push_device(uuid),public.list_push_devices(uuid)
    from public, anon, authenticated;
grant execute on function public.register_push_device(uuid,text,text),public.revoke_push_device(uuid) to authenticated;
grant execute on function public.list_push_devices(uuid) to service_role;

-- 20261013001100_push_delivery_leases.sql
-- Purpose: Lease per-device notification attempts with schedule, account, and token revalidation.
create table private.push_deliveries (
    id uuid primary key default gen_random_uuid(),
    outbox_id uuid not null references private.push_outbox on delete cascade,
    installation_id uuid not null,
    device_token text,
    registered_at timestamptz not null,
    state text not null default 'pending' check(state in ('pending','leased','accepted','failed','canceled')),
    next_attempt_at timestamptz not null default now(),
    attempts integer not null default 0,
    lease_id uuid,
    lease_until timestamptz,
    unique(outbox_id,installation_id)
);
create index push_deliveries_due_idx on private.push_deliveries(next_attempt_at) where state in ('pending','leased');
alter table private.push_deliveries enable row level security;
revoke all on private.push_deliveries from public, anon, authenticated;

create function public.claim_push_deliveries(p_limit integer default 20) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_delivery private.push_deliveries; v_lease uuid; v_result jsonb := '[]';
begin
    -- Bound materialization independently of the claim count, preserving immutable retry identifiers.
    insert into private.push_deliveries(outbox_id,installation_id,device_token,registered_at)
        select o.id,d.installation_id,d.device_token,d.updated_at from private.push_outbox o
        join public.games g on g.id=o.game_id join private.push_devices d on d.user_id=o.user_id
        join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
        where o.state='pending' and o.revision=g.schedule_revision and not g.is_canceled
            and g.starts_at > clock_timestamp() and g.starts_at-interval '1 hour' <= clock_timestamp()
            and d.expires_at > clock_timestamp()
            and exists(select 1 from public.assignment_members a where a.game_id=g.id and a.user_id=o.user_id)
            and exists(select 1 from public.team_members m where m.team_id=g.team_id and m.user_id=o.user_id)
            and not exists(select 1 from private.push_deliveries p where p.outbox_id=o.id and p.installation_id=d.installation_id)
        order by o.created_at,o.id,d.installation_id limit 100 on conflict do nothing;
    for v_delivery in select p.* from private.push_deliveries p
        where p.attempts < 5 and p.next_attempt_at <= clock_timestamp()
            and (p.state='pending' or (p.state='leased' and p.lease_until <= clock_timestamp()))
        order by p.next_attempt_at,p.id limit greatest(1,least(coalesce(p_limit,20),20)) for update skip locked loop
        v_lease := gen_random_uuid();
        update private.push_deliveries set state='leased',lease_id=v_lease,
            lease_until=clock_timestamp()+interval '2 minutes',attempts=attempts+1 where id=v_delivery.id;
        v_result := v_result || jsonb_build_array(jsonb_build_object('delivery_id',v_delivery.id,'lease_id',v_lease));
    end loop;
    return v_result;
end;
$$;

create function public.push_delivery_context(p_delivery uuid,p_lease uuid) returns jsonb
language sql security definer set search_path = '' as $$
    select jsonb_build_object('game_id',g.id,'starts_at',g.starts_at,'notification_id',p.id,
        'device_token',d.device_token,'environment',d.environment)
    from private.push_deliveries p join private.push_outbox o on o.id=p.outbox_id
    join public.games g on g.id=o.game_id
    join private.push_devices d on d.installation_id=p.installation_id and d.user_id=o.user_id
    join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
    where p.id=p_delivery and p.lease_id=p_lease and p.state='leased' and p.lease_until > clock_timestamp()
        and p.device_token=d.device_token and p.registered_at=d.updated_at and d.expires_at > clock_timestamp()
        and o.state='pending' and o.revision=g.schedule_revision and not g.is_canceled
        and g.starts_at > clock_timestamp() and g.starts_at-interval '1 hour' <= clock_timestamp()
        and exists(select 1 from public.assignment_members a where a.game_id=g.id and a.user_id=o.user_id)
        and exists(select 1 from public.team_members m where m.team_id=g.team_id and m.user_id=o.user_id);
$$;

create function public.finish_push_delivery(p_delivery uuid,p_lease uuid,p_outcome text,p_invalidated_at bigint default null)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_delivery private.push_deliveries; v_user uuid; v_game uuid; v_state text;
begin
    if p_outcome is null or p_outcome not in ('accepted','retry','invalidToken','configuration','expired','canceled') then
        raise exception 'Valid delivery outcome is required'; end if;
    select o.game_id,o.user_id into v_game,v_user from private.push_outbox o
        join private.push_deliveries p on p.outbox_id=o.id where p.id=p_delivery;
    -- Match the game-first lock order used by schedule updates.
    perform 1 from public.games where id=v_game for share;
    select * into v_delivery from private.push_deliveries where id=p_delivery for update;
    if not found or v_delivery.state <> 'leased' or v_delivery.lease_id is distinct from p_lease
        or v_delivery.lease_until <= clock_timestamp() then return false; end if;
    if public.push_delivery_context(p_delivery,p_lease) is null then v_state := 'canceled';
    elsif p_outcome='accepted' then v_state := 'accepted';
    elsif p_outcome='retry' and v_delivery.attempts < 5 then v_state := 'pending';
    elsif p_outcome in ('expired','canceled') then v_state := 'canceled';
    else v_state := 'failed'; end if;
    if v_state='failed' and p_outcome='invalidToken' then
        -- Never remove a token refreshed or reassigned after this request was prepared.
        delete from private.push_devices where installation_id=v_delivery.installation_id and user_id=v_user
            and device_token=v_delivery.device_token and updated_at=v_delivery.registered_at
            and (p_invalidated_at is null or updated_at <= to_timestamp(p_invalidated_at/1000.0));
    end if;
    update private.push_deliveries set state=v_state,lease_id=null,lease_until=null,
        next_attempt_at=clock_timestamp()+make_interval(secs=>least(900,30*(2^least(attempts,5))::integer)),
        device_token=case when v_state='pending' then device_token else null end where id=p_delivery;
    return true;
end;
$$;
revoke all on function public.claim_push_deliveries(integer),public.push_delivery_context(uuid,uuid),
    public.finish_push_delivery(uuid,uuid,text,bigint) from public,anon,authenticated;
grant execute on function public.claim_push_deliveries(integer),public.push_delivery_context(uuid,uuid),
    public.finish_push_delivery(uuid,uuid,text,bigint) to service_role;

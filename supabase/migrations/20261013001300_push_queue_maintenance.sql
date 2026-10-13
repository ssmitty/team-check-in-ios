-- 20261013001300_push_queue_maintenance.sql
-- Purpose: Bound device snapshot refresh and remove expired operational notification state.
create function public.cleanup_push_state() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_devices integer; v_deliveries integer;
begin
    with candidates as (select installation_id from private.push_devices where expires_at <= clock_timestamp()
        order by expires_at,installation_id limit 100 for update skip locked)
    delete from private.push_devices d using candidates c where d.installation_id=c.installation_id;
    get diagnostics v_devices = row_count;
    with candidates as (select p.id from private.push_deliveries p join private.push_outbox o on o.id=p.outbox_id
        join public.games g on g.id=o.game_id where g.starts_at <= clock_timestamp()-interval '24 hours'
        order by g.starts_at,p.id limit 200 for update of p skip locked)
    delete from private.push_deliveries p using candidates c where p.id=c.id;
    get diagnostics v_deliveries = row_count;
    return jsonb_build_object('expired_devices',v_devices,'old_attempts',v_deliveries);
end;
$$;
revoke all on function public.cleanup_push_state() from public,anon,authenticated;
grant execute on function public.cleanup_push_state() to service_role;

create or replace function public.claim_push_deliveries(p_limit integer default 20) returns jsonb
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
    -- Renew pending device snapshots, and recover interrupted attempts without resending accepted rows.
    with candidates as (
        select p.id,d.device_token,d.updated_at from private.push_deliveries p
        join private.push_outbox o on o.id=p.outbox_id join public.games g on g.id=o.game_id
        join private.push_devices d on d.installation_id=p.installation_id and d.user_id=o.user_id
        where d.expires_at > clock_timestamp() and o.state='pending' and o.revision=g.schedule_revision
            and not g.is_canceled and g.starts_at > clock_timestamp() and p.attempts < 5
            and (p.state in ('pending','canceled') or (p.state='leased' and p.lease_until <= clock_timestamp()))
        order by p.next_attempt_at,p.id limit 100 for update of p skip locked
    )
    update private.push_deliveries p set device_token=c.device_token,registered_at=c.updated_at,
        state='pending',lease_id=null,lease_until=null from candidates c where p.id=c.id;
    update private.push_deliveries set state='failed',device_token=null,lease_id=null,lease_until=null
        where attempts >= 5 and state='leased' and lease_until <= clock_timestamp();
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

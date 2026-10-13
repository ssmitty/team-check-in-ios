-- 20261012000700_check_in_jobs.sql
-- Purpose: Queue authoritative event-opening work with leased retries and private notification outbox records.
alter table public.games add column schedule_revision bigint not null default 1;
create table private.check_in_jobs (
    game_id uuid primary key references public.games on delete cascade,
    revision bigint not null,
    due_at timestamptz not null,
    state text not null check(state in ('pending','leased','done','canceled')),
    lease_id uuid,
    lease_until timestamptz,
    attempts integer not null default 0
);
create index check_in_jobs_due_idx on private.check_in_jobs(due_at) where state in ('pending','leased');
create table private.push_outbox (
    id uuid primary key default gen_random_uuid(),
    game_id uuid not null references public.games on delete cascade,
    user_id uuid not null references auth.users on delete cascade,
    revision bigint not null,
    state text not null default 'pending' check(state in ('pending','sent','canceled')),
    created_at timestamptz not null default now(),
    unique(game_id,user_id,revision)
);
alter table private.check_in_jobs enable row level security;
alter table private.push_outbox enable row level security;
revoke all on private.check_in_jobs, private.push_outbox from public, anon, authenticated;

create function private.revise_game_schedule() returns trigger
language plpgsql set search_path = '' as $$
begin
    if new.starts_at is distinct from old.starts_at or new.is_canceled is distinct from old.is_canceled
        then new.schedule_revision := old.schedule_revision + 1; end if;
    return new;
end;
$$;
create trigger revise_game_schedule before update on public.games
    for each row execute function private.revise_game_schedule();
create function private.queue_check_in_job() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    if tg_op = 'UPDATE' and new.schedule_revision = old.schedule_revision then return new; end if;
    insert into private.check_in_jobs(game_id,revision,due_at,state)
        values(new.id,new.schedule_revision,new.starts_at - interval '1 hour',case when new.is_canceled then 'canceled' else 'pending' end)
        on conflict(game_id) do update set revision=excluded.revision,due_at=excluded.due_at,state=excluded.state,
            lease_id=null,lease_until=null,attempts=0;
    update private.push_outbox set state='canceled'
        where game_id=new.id and state='pending';
    return new;
end;
$$;
create trigger queue_check_in_job after insert or update on public.games
    for each row execute function private.queue_check_in_job();
insert into private.check_in_jobs(game_id,revision,due_at,state)
    select id,schedule_revision,starts_at - interval '1 hour',
        case when is_canceled then 'canceled' when assignments_generated_at is not null then 'done' else 'pending' end
    from public.games;

create function public.claim_check_in_jobs(p_limit integer default 20) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_job private.check_in_jobs; v_result jsonb := '[]'; v_lease uuid; v_user uuid;
begin
    -- Never claim an expired game, and serialize competing workers without waiting on one another.
    for v_job in select j.* from private.check_in_jobs j join public.games g on g.id=j.game_id
        where j.due_at <= clock_timestamp() and not g.is_canceled and g.starts_at > clock_timestamp()
        and (j.state='pending' or (j.state='leased' and j.lease_until <= clock_timestamp()))
        order by j.due_at,j.game_id limit greatest(1,least(coalesce(p_limit,20),20)) for update of j skip locked loop
        v_lease := gen_random_uuid();
        update private.check_in_jobs set state='leased',lease_id=v_lease,
            lease_until=clock_timestamp() + interval '2 minutes',attempts=attempts+1 where game_id=v_job.game_id;
        select m.user_id into v_user from public.team_members m join public.games g on g.team_id=m.team_id
            where g.id=v_job.game_id order by m.user_id limit 1;
        v_result := v_result || jsonb_build_array(jsonb_build_object('game_id',v_job.game_id,
            'revision',v_job.revision,'lease_id',v_lease,'acting_user',v_user));
    end loop;
    return v_result;
end;
$$;
create function public.complete_check_in_job(p_game uuid,p_revision bigint,p_lease uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_game public.games;
begin
    -- Game lock order agrees with schedule changes. Completion never opens a canceled/revised event.
    select * into v_game from public.games where id=p_game for share;
    if not found or v_game.is_canceled or v_game.starts_at <= clock_timestamp()
        or v_game.schedule_revision <> p_revision or v_game.assignments_generated_at is null then return false; end if;
    update private.check_in_jobs set state='done',lease_id=null,lease_until=null
        where game_id=p_game and revision=p_revision and lease_id=p_lease and state='leased'
            and lease_until > clock_timestamp();
    if not found then return false; end if;
    insert into private.push_outbox(game_id,user_id,revision)
        select p_game,user_id,p_revision from public.assignment_members where game_id=p_game on conflict do nothing;
    return true;
end;
$$;
revoke all on function private.revise_game_schedule(), private.queue_check_in_job() from public, anon, authenticated;
revoke all on function public.claim_check_in_jobs(integer), public.complete_check_in_job(uuid,bigint,uuid) from public, anon, authenticated;
grant execute on function public.claim_check_in_jobs(integer), public.complete_check_in_job(uuid,bigint,uuid) to service_role;

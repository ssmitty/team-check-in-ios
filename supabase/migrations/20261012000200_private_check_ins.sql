-- 20261012000200_private_check_ins.sql
-- Purpose: Persist immutable pair/trio assignments and private retryable responses.
create table public.game_opt_outs (
    game_id uuid not null references public.games on delete cascade,
    user_id uuid not null references auth.users on delete cascade,
    primary key(game_id, user_id)
);
create table public.assignments (
    id uuid primary key default gen_random_uuid(),
    game_id uuid not null references public.games on delete cascade,
    created_at timestamptz not null default now(),
    unique(id, game_id)
);
create index assignments_game_idx on public.assignments(game_id);
create table public.assignment_members (
    assignment_id uuid not null,
    game_id uuid not null,
    user_id uuid not null references auth.users on delete cascade,
    primary key(assignment_id, user_id),
    unique(game_id, user_id),
    foreign key(assignment_id, game_id) references public.assignments(id, game_id) on delete cascade
);
create index assignment_members_user_idx on public.assignment_members(user_id, assignment_id);
create table public.check_ins (
    assignment_id uuid not null,
    user_id uuid not null,
    feeling text not null check (feeling in ('Calm', 'Energized', 'Nervous', 'Low energy', 'Having a tough day')),
    support text not null check (support in ('Encouragement', 'A quick conversation', 'A distraction', 'Just knowing you''re there')),
    note text not null default '' check(length(note) <= 280),
    updated_at timestamptz not null default now(),
    primary key(assignment_id, user_id),
    foreign key(assignment_id, user_id) references public.assignment_members on delete cascade
);
create table public.encouragements (
    assignment_id uuid not null,
    sender_id uuid not null,
    recipient_id uuid not null,
    message text not null check (message in ('I''ve got you', 'Let''s talk at warmups', 'We''re in this together')),
    updated_at timestamptz not null default now(),
    primary key(assignment_id, sender_id, recipient_id),
    check(sender_id <> recipient_id),
    foreign key(assignment_id, sender_id) references public.assignment_members on delete cascade,
    foreign key(assignment_id, recipient_id) references public.assignment_members on delete cascade
);
create function private.in_assignment(p_assignment uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists(select 1 from public.assignment_members am join public.games g on g.id = am.game_id
        where am.assignment_id = p_assignment and am.user_id = (select auth.uid())
        and private.is_member(g.team_id));
$$;
revoke all on function private.in_assignment(uuid) from public, anon;
grant execute on function private.in_assignment(uuid) to authenticated;
alter table public.game_opt_outs enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_members enable row level security;
alter table public.check_ins enable row level security;
alter table public.encouragements enable row level security;
revoke all on public.game_opt_outs, public.assignments, public.assignment_members, public.check_ins, public.encouragements from anon, authenticated;
grant select on public.game_opt_outs, public.assignments, public.assignment_members, public.check_ins, public.encouragements to authenticated;
create policy own_opt_out_read on public.game_opt_outs for select to authenticated using(user_id = (select auth.uid()));
create policy own_assignment_read on public.assignments for select to authenticated using(private.in_assignment(id));
create policy own_connection_read on public.assignment_members for select to authenticated using(private.in_assignment(assignment_id));
create policy private_response_read on public.check_ins for select to authenticated using(private.in_assignment(assignment_id));
create policy private_encouragement_read on public.encouragements for select to authenticated using(private.in_assignment(assignment_id));

create function public.set_game_opt_out(p_game uuid, p_opt_out boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare v_game public.games;
begin
    select * into v_game from public.games where id = p_game for update;
    if not found or not private.is_member(v_game.team_id) or v_game.assignments_generated_at is not null
        or v_game.starts_at - interval '1 hour' <= clock_timestamp() then raise exception 'Eligibility is frozen'; end if;
    if p_opt_out then insert into public.game_opt_outs values(p_game, auth.uid()) on conflict do nothing;
    else delete from public.game_opt_outs where game_id = p_game and user_id = auth.uid(); end if;
end;
$$;
create function private.require_open_assignment(p_assignment uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_game public.games;
begin
    select g.* into v_game from public.games g join public.assignments a on a.game_id = g.id
        where a.id = p_assignment for share of g;
    if not found or not private.in_assignment(p_assignment) or v_game.is_canceled
        or clock_timestamp() < v_game.starts_at - interval '1 hour' or clock_timestamp() >= v_game.starts_at
        then raise exception 'Check-in unavailable'; end if;
end;
$$;
revoke all on function private.require_open_assignment(uuid) from public, anon, authenticated;
create function public.submit_check_in(p_assignment uuid, p_feeling text, p_support text, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
begin
    perform private.require_open_assignment(p_assignment);
    insert into public.check_ins(assignment_id, user_id, feeling, support, note)
        values(p_assignment, auth.uid(), p_feeling, p_support, p_note)
        on conflict(assignment_id,user_id) do update set feeling = excluded.feeling,
            support = excluded.support, note = excluded.note, updated_at = clock_timestamp();
end;
$$;
create function public.send_encouragement(p_assignment uuid, p_recipient uuid, p_message text) returns void
language plpgsql security definer set search_path = '' as $$
begin
    perform private.require_open_assignment(p_assignment);
    insert into public.encouragements(assignment_id,sender_id,recipient_id,message)
        values(p_assignment,auth.uid(),p_recipient,p_message)
        on conflict(assignment_id,sender_id,recipient_id) do update
            set message = excluded.message, updated_at = clock_timestamp();
end;
$$;
revoke all on function public.set_game_opt_out(uuid,boolean), public.submit_check_in(uuid,text,text,text),
    public.send_encouragement(uuid,uuid,text) from public, anon;
grant execute on function public.set_game_opt_out(uuid,boolean), public.submit_check_in(uuid,text,text,text),
    public.send_encouragement(uuid,uuid,text) to authenticated;

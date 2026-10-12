-- 20261012000100_teams_and_schedules.sql
-- Purpose: Protect team membership, captain schedules, and retryable invitations.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.teams (
    id uuid primary key default gen_random_uuid(),
    name text not null check (length(trim(name)) between 1 and 80),
    created_at timestamptz not null default now()
);
create table public.team_members (
    team_id uuid not null references public.teams on delete cascade,
    user_id uuid not null references auth.users on delete cascade,
    display_name text not null check (length(trim(display_name)) between 1 and 60),
    role text not null default 'member' check (role in ('member', 'captain')),
    created_at timestamptz not null default now(),
    primary key (team_id, user_id)
);
create index team_members_user_idx on public.team_members(user_id, team_id);
create table public.team_invites (
    id uuid primary key default gen_random_uuid(),
    team_id uuid not null references public.teams on delete cascade,
    token text unique not null default encode(extensions.gen_random_bytes(24), 'hex'),
    expires_at timestamptz not null default now() + interval '7 days',
    revoked_at timestamptz,
    created_at timestamptz not null default now()
);
create index team_invites_team_idx on public.team_invites(team_id);
create table public.games (
    id uuid primary key default gen_random_uuid(),
    team_id uuid not null references public.teams on delete cascade,
    title text not null check (length(trim(title)) between 1 and 100),
    starts_at timestamptz not null,
    location text not null default '' check (length(location) <= 200),
    time_zone_identifier text not null,
    is_canceled boolean not null default false,
    assignments_generated_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index games_team_start_idx on public.games(team_id, starts_at);
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.team_invites enable row level security;
alter table public.games enable row level security;
revoke all on public.teams, public.team_members, public.team_invites, public.games from anon, authenticated;
grant select on public.teams, public.team_members, public.team_invites, public.games to authenticated;

-- Definer helpers avoid recursive membership policies; caller identity is always derived.
create function private.is_member(p_team uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists(select 1 from public.team_members where team_id = p_team and user_id = (select auth.uid()));
$$;
create function private.is_captain(p_team uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists(select 1 from public.team_members where team_id = p_team and user_id = (select auth.uid()) and role = 'captain');
$$;
revoke all on function private.is_member(uuid), private.is_captain(uuid) from public, anon;
grant execute on function private.is_member(uuid), private.is_captain(uuid) to authenticated;
create policy member_team_read on public.teams for select to authenticated using (private.is_member(id));
create policy member_roster_read on public.team_members for select to authenticated using (private.is_member(team_id));
create policy captain_invite_read on public.team_invites for select to authenticated using (private.is_captain(team_id));
create policy member_schedule_read on public.games for select to authenticated using (private.is_member(team_id));

create function public.create_team(p_name text, p_display_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_team uuid;
begin
    if auth.uid() is null then raise exception 'Sign in first'; end if;
    insert into public.teams(name) values(trim(p_name)) returning id into v_team;
    insert into public.team_members(team_id, user_id, display_name, role)
        values(v_team, auth.uid(), trim(p_display_name), 'captain');
    return v_team;
end;
$$;
create function public.create_invite(p_team uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare v_token text;
begin
    if not private.is_captain(p_team) then raise exception 'Captain required'; end if;
    insert into public.team_invites(team_id) values(p_team) returning token into v_token;
    return v_token;
end;
$$;
create function public.revoke_invite(p_token text) returns void
language plpgsql security definer set search_path = '' as $$
begin
    update public.team_invites set revoked_at = clock_timestamp()
        where token = p_token and private.is_captain(team_id);
    if not found then raise exception 'Invite unavailable'; end if;
end;
$$;
create or replace function public.redeem_invite(p_token text, p_display_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_invite public.team_invites;
begin
    if auth.uid() is null then raise exception 'Sign in first'; end if;
    select * into v_invite from public.team_invites where token = p_token for update;
    if not found or v_invite.revoked_at is not null or v_invite.expires_at <= clock_timestamp()
        then raise exception 'Invite unavailable'; end if;
    perform 1 from public.teams where id = v_invite.team_id for update;
    insert into public.team_members(team_id, user_id, display_name)
        values(v_invite.team_id, auth.uid(), trim(p_display_name)) on conflict do nothing;
    return v_invite.team_id;
end;
$$;
create function public.save_game(p_id uuid, p_team uuid, p_title text, p_starts_at timestamptz,
    p_location text, p_time_zone_identifier text, p_is_canceled boolean default false) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_game public.games;
begin
    -- Team lock also serializes membership snapshots with pairing generation.
    perform 1 from public.teams where id = p_team for update;
    if not private.is_captain(p_team) then raise exception 'Captain required'; end if;
    select * into v_game from public.games where id = p_id for update;
    if found and (v_game.team_id <> p_team or
        (v_game.assignments_generated_at is not null and not p_is_canceled))
        then raise exception 'Game cannot be rescheduled after pairing'; end if;
    if not p_is_canceled and p_starts_at <= clock_timestamp() then raise exception 'Future time required'; end if;
    insert into public.games(id, team_id, title, starts_at, location, time_zone_identifier, is_canceled)
        values(p_id, p_team, trim(p_title), p_starts_at, p_location, p_time_zone_identifier, p_is_canceled)
        on conflict(id) do update set title = excluded.title, starts_at = excluded.starts_at,
            location = excluded.location, time_zone_identifier = excluded.time_zone_identifier,
            is_canceled = excluded.is_canceled, updated_at = clock_timestamp();
    return p_id;
end;
$$;
revoke all on function public.create_team(text,text), public.create_invite(uuid), public.revoke_invite(text),
    public.redeem_invite(text,text), public.save_game(uuid,uuid,text,timestamptz,text,text,boolean) from public, anon;
grant execute on function public.create_team(text,text), public.create_invite(uuid), public.revoke_invite(text),
    public.redeem_invite(text,text), public.save_game(uuid,uuid,text,timestamptz,text,text,boolean) to authenticated;

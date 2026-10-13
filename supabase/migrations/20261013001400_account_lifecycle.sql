-- 20261013001400_account_lifecycle.sql
-- Purpose: Transfer captain duties and freeze membership/photo uploads before verified account deletion.
create table private.account_deletions (
    user_id uuid primary key references auth.users on delete cascade,
    started_at timestamptz not null default now()
);
alter table private.account_deletions enable row level security;
revoke all on private.account_deletions from public,anon,authenticated;

create function private.guard_membership_account() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    perform 1 from auth.users where id=new.user_id for share;
    if not found or exists(select 1 from private.account_deletions where user_id=new.user_id) then
        raise exception 'Account deletion is in progress'; end if;
    return new;
end;
$$;
create trigger guard_membership_account before insert or update on public.team_members
    for each row execute function private.guard_membership_account();

create function public.transfer_captain(p_team uuid,p_recipient uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    perform 1 from public.teams where id=p_team for update;
    if not private.is_captain(p_team) or p_recipient is null or p_recipient=auth.uid() then
        raise exception 'Choose another teammate as captain'; end if;
    if not exists(select 1 from public.team_members where team_id=p_team and user_id=p_recipient)
        or exists(select 1 from private.account_deletions where user_id=p_recipient) then
        raise exception 'Choose a current teammate'; end if;
    update public.team_members set role='captain' where team_id=p_team and user_id=p_recipient;
    update public.team_members set role='member' where team_id=p_team and user_id=auth.uid();
end;
$$;

create function public.begin_account_deletion(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    -- Team-first ordering agrees with invite redemption and captain transfer.
    perform 1 from public.teams t join public.team_members m on m.team_id=t.id
        where m.user_id=p_user order by t.id for update of t;
    perform 1 from auth.users where id=p_user for update;
    if not found then raise exception 'Account unavailable'; end if;
    if exists(select 1 from public.team_members mine where mine.user_id=p_user and mine.role='captain'
        and exists(select 1 from public.team_members other where other.team_id=mine.team_id and other.user_id<>p_user)
        and not exists(select 1 from public.team_members other where other.team_id=mine.team_id
            and other.user_id<>p_user and other.role='captain')) then
        raise sqlstate 'PT409' using message='Transfer captain duties before deleting your account'; end if;
    insert into private.account_deletions(user_id) values(p_user) on conflict do nothing;
    delete from private.push_devices where user_id=p_user;
    -- Empty sole-member teams cannot admit new members after deletion starts.
    delete from public.teams t where exists(select 1 from public.team_members m where m.team_id=t.id and m.user_id=p_user)
        and not exists(select 1 from public.team_members m where m.team_id=t.id and m.user_id<>p_user);
    delete from public.team_members where user_id=p_user;
end;
$$;
create function public.account_deletion_photos(p_user uuid) returns jsonb
language sql security definer set search_path = '' as $$
    select coalesce(jsonb_agg(name),'[]'::jsonb) from (
        select o.name from storage.objects o where o.bucket_id='check-in-photos'
            and (o.owner_id=p_user::text or split_part(o.name,'/',2)=p_user::text)
            and exists(select 1 from private.account_deletions where user_id=p_user)
        order by o.name limit 100
    ) photos;
$$;
-- Upload authorization takes a user lock so deletion waits for prior metadata writes.
create or replace function private.can_upload_photo(p_name text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
    perform 1 from auth.users where id=auth.uid() for share;
    if not found or exists(select 1 from private.account_deletions where user_id=auth.uid()) then return false; end if;
    return exists(select 1 from public.check_in_photos p join public.assignments a on a.id=p.assignment_id
        join public.games g on g.id=a.game_id where p.user_id=auth.uid() and not p.is_ready
        and p_name=p.assignment_id::text||'/'||p.user_id::text||'/'||p.photo_id::text||'.jpg'
        and private.in_assignment(p.assignment_id) and not g.is_canceled
        and clock_timestamp() >= g.starts_at-interval '1 hour' and clock_timestamp() < g.starts_at);
end;
$$;
revoke all on function private.guard_membership_account(),public.transfer_captain(uuid,uuid),
    public.begin_account_deletion(uuid),public.account_deletion_photos(uuid) from public,anon,authenticated;
grant execute on function public.transfer_captain(uuid,uuid) to authenticated;
grant execute on function public.begin_account_deletion(uuid),public.account_deletion_photos(uuid) to service_role;

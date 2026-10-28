-- 20261013001500_finalize_empty_teams.sql
-- Purpose: Remove actual objects before deleting empty-team photo metadata during account cleanup.
alter table private.account_deletions add column empty_team_ids uuid[] not null default '{}';
create or replace function public.begin_account_deletion(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    -- Invitations lock before teams, matching redemption of an existing link.
    perform 1 from public.team_invites i join public.team_members m on m.team_id=i.team_id
        where m.user_id=p_user order by i.id for update of i;
    perform 1 from public.teams t join public.team_members m on m.team_id=t.id
        where m.user_id=p_user order by t.id for update of t;
    perform 1 from auth.users where id=p_user for update;
    if not found then raise exception 'Account unavailable'; end if;
    if exists(select 1 from public.team_members mine where mine.user_id=p_user and mine.role='captain'
        and exists(select 1 from public.team_members other where other.team_id=mine.team_id and other.user_id<>p_user)
        and not exists(select 1 from public.team_members other where other.team_id=mine.team_id
            and other.user_id<>p_user and other.role='captain')) then
        raise sqlstate 'PT409' using message='Transfer captain duties before deleting your account'; end if;
    insert into private.account_deletions(user_id,empty_team_ids)
        select p_user,coalesce(array_agg(t.id),'{}'::uuid[]) from public.teams t
        where exists(select 1 from public.team_members m where m.team_id=t.id and m.user_id=p_user)
            and not exists(select 1 from public.team_members m where m.team_id=t.id and m.user_id<>p_user)
        on conflict(user_id) do nothing;
    delete from private.push_devices where user_id=p_user;
    -- Keep response/photo metadata until Storage confirms physical removal.
    update public.team_invites set revoked_at=clock_timestamp() where team_id=any(
        select unnest(empty_team_ids) from private.account_deletions where user_id=p_user);
    delete from public.team_members where user_id=p_user;
end;
$$;

create function public.finish_account_data_deletion(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    if not exists(select 1 from private.account_deletions where user_id=p_user) then
        raise exception 'Deletion must start first'; end if;
    if exists(select 1 from storage.objects where bucket_id='check-in-photos'
        and (owner_id=p_user::text or split_part(name,'/',2)=p_user::text)) then
        raise exception 'Photo removal must finish first'; end if;
    delete from public.teams t where t.id=any(select unnest(empty_team_ids) from private.account_deletions where user_id=p_user)
        and not exists(select 1 from public.team_members m where m.team_id=t.id);
end;
$$;
revoke all on function public.finish_account_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.finish_account_data_deletion(uuid) to service_role;

-- 20261012000600_private_photos.sql
-- Purpose: Reserve private photo paths and publish only uploaded objects within an assigned connection.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
    values('check-in-photos','check-in-photos',false,5000000,array['image/jpeg','image/png']);
create table public.check_in_photos (
    assignment_id uuid not null,
    user_id uuid not null,
    photo_id uuid not null,
    is_ready boolean not null default false,
    updated_at timestamptz not null default now(),
    primary key(assignment_id,user_id),
    foreign key(assignment_id,user_id) references public.assignment_members on delete cascade
);
create index check_in_photos_user_idx on public.check_in_photos(user_id, assignment_id);
alter table public.check_in_photos enable row level security;
revoke all on public.check_in_photos from anon, authenticated;
grant select on public.check_in_photos to authenticated;
create policy connection_photo_metadata on public.check_in_photos for select to authenticated
    using(private.in_assignment(assignment_id) and (user_id = (select auth.uid()) or
        (is_ready and exists(select 1 from public.check_ins c where c.assignment_id = check_in_photos.assignment_id and c.user_id = check_in_photos.user_id))));

create function private.can_read_photo(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists(select 1 from public.check_in_photos p where
        p.assignment_id::text || '/' || p.user_id::text || '/' || p.photo_id::text || '.jpg' = p_name
        and private.in_assignment(p.assignment_id) and (p.user_id = (select auth.uid()) or
            (p.is_ready and exists(select 1 from public.check_ins c where c.assignment_id=p.assignment_id and c.user_id=p.user_id))));
$$;
create function private.can_upload_photo(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists(select 1 from public.check_in_photos p join public.assignments a on a.id=p.assignment_id
        join public.games g on g.id=a.game_id where p.user_id = (select auth.uid()) and not p.is_ready
        and p.assignment_id::text || '/' || p.user_id::text || '/' || p.photo_id::text || '.jpg' = p_name
        and private.in_assignment(p.assignment_id) and not g.is_canceled
        and clock_timestamp() >= g.starts_at - interval '1 hour' and clock_timestamp() < g.starts_at);
$$;
create function private.owns_photo_path(p_name text) returns boolean
language sql stable set search_path = '' as $$
    select split_part(p_name,'/',2) = (select auth.uid())::text;
$$;
revoke all on function private.can_read_photo(text), private.can_upload_photo(text), private.owns_photo_path(text) from public, anon;
grant execute on function private.can_read_photo(text), private.can_upload_photo(text), private.owns_photo_path(text) to authenticated;
create policy connection_photo_download on storage.objects for select to authenticated
    using(bucket_id = 'check-in-photos' and private.can_read_photo(name));
create policy reserved_photo_upload on storage.objects for insert to authenticated
    with check(bucket_id = 'check-in-photos' and private.can_upload_photo(name));
create policy own_photo_delete on storage.objects for delete to authenticated
    using(bucket_id = 'check-in-photos' and private.owns_photo_path(name));

create function public.prepare_photo(p_assignment uuid, p_photo uuid) returns text
language plpgsql security definer set search_path = '' as $$
begin
    perform private.require_open_assignment(p_assignment);
    insert into public.check_in_photos(assignment_id,user_id,photo_id) values(p_assignment,auth.uid(),p_photo)
        on conflict(assignment_id,user_id) do update set photo_id=excluded.photo_id,
            is_ready=case when check_in_photos.photo_id=excluded.photo_id then check_in_photos.is_ready else false end,
            updated_at=clock_timestamp();
    return p_assignment::text || '/' || auth.uid()::text || '/' || p_photo::text || '.jpg';
end;
$$;
create function public.publish_photo(p_assignment uuid, p_photo uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_name text;
begin
    perform private.require_open_assignment(p_assignment);
    v_name := p_assignment::text || '/' || auth.uid()::text || '/' || p_photo::text || '.jpg';
    if not exists(select 1 from storage.objects where bucket_id='check-in-photos' and name=v_name)
        then raise exception 'Upload the photo first'; end if;
    update public.check_in_photos set is_ready=true, updated_at=clock_timestamp()
        where assignment_id=p_assignment and user_id=auth.uid() and photo_id=p_photo;
    if not found then raise exception 'Photo changed. Try again'; end if;
end;
$$;
create function public.remove_photo(p_assignment uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    if not private.in_assignment(p_assignment) then raise exception 'Connection required'; end if;
    delete from public.check_in_photos where assignment_id=p_assignment and user_id=auth.uid();
end;
$$;
revoke all on function public.prepare_photo(uuid,uuid), public.publish_photo(uuid,uuid), public.remove_photo(uuid) from public, anon;
grant execute on function public.prepare_photo(uuid,uuid), public.publish_photo(uuid,uuid), public.remove_photo(uuid) to authenticated;

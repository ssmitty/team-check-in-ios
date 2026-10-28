-- 20261012000800_orphan_photo_cleanup.sql
-- Purpose: List old unreferenced photo objects for trusted deletion through the Storage API.
create function public.list_orphan_photos(p_limit integer default 100) returns jsonb
language sql security definer set search_path = '' as $$
    select coalesce(jsonb_agg(name), '[]'::jsonb) from (
        select o.name from storage.objects o where o.bucket_id='check-in-photos'
            and o.created_at < clock_timestamp() - interval '24 hours'
            and not exists(select 1 from public.check_in_photos p where
                p.assignment_id::text || '/' || p.user_id::text || '/' || p.photo_id::text || '.jpg' = o.name)
        order by o.created_at,o.name limit greatest(1,least(coalesce(p_limit,100),100))
    ) orphaned;
$$;
revoke all on function public.list_orphan_photos(integer) from public, anon, authenticated;
grant execute on function public.list_orphan_photos(integer) to service_role;

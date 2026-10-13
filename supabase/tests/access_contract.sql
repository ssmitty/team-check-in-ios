-- access_contract.sql
-- Purpose: Check table isolation and privileged RPC grants independently of application code.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(20);
select extensions.is((select count(*)::integer from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ('teams','team_members','team_invites','games',
        'game_opt_outs','assignments','assignment_members','check_ins','encouragements',
        'warmup_requests','warmup_acknowledgments','check_in_photos') and c.relrowsecurity), 12,
    'Every application table enables RLS');
select extensions.ok(not has_table_privilege('anon', 'public.check_ins', 'select'), 'Anon cannot read responses');
select extensions.ok(not has_table_privilege('authenticated', 'public.team_members', 'update'), 'Members cannot promote themselves');
select extensions.ok(not has_table_privilege('authenticated', 'public.games', 'insert'), 'Schedules require captain RPC');
select extensions.ok(not has_table_privilege('authenticated', 'public.assignment_members', 'insert'), 'Clients cannot invent assignments');
select extensions.ok(not has_function_privilege('authenticated', 'public.commit_pairings(uuid,uuid,jsonb,jsonb)', 'execute'), 'Only worker can commit pairs');
select extensions.ok(not has_function_privilege('anon', 'public.create_team(text,text)', 'execute'), 'Team creation requires auth');
select extensions.ok(has_function_privilege('authenticated', 'public.submit_check_in(uuid,text,text,text)', 'execute'), 'Players may call protected submission');
select extensions.ok(not has_function_privilege('authenticated', 'public.claim_check_in_jobs(integer)', 'execute'), 'Players cannot claim server jobs');
select extensions.ok(not has_table_privilege('authenticated', 'private.push_outbox', 'select'), 'Push outbox is server-only');
select extensions.ok((select relrowsecurity from pg_class where oid='private.push_devices'::regclass), 'Device registrations enable RLS');
select extensions.ok(not has_table_privilege('authenticated', 'private.push_devices', 'select'), 'Players cannot read raw device tokens');
select extensions.ok(not has_function_privilege('authenticated', 'public.list_push_devices(uuid)', 'execute'), 'Device recipient lookup is server-only');
select extensions.ok((select relrowsecurity from pg_class where oid='private.push_deliveries'::regclass), 'Delivery attempts enable RLS');
select extensions.ok(not has_table_privilege('authenticated', 'private.push_deliveries', 'select'), 'Delivery attempts are private');
select extensions.ok(not has_function_privilege('authenticated', 'public.claim_push_deliveries(integer)', 'execute'), 'Delivery claims are server-only');
select extensions.ok(not has_function_privilege('authenticated', 'public.cleanup_push_state()', 'execute'), 'Push cleanup is server-only');
select extensions.ok((select relrowsecurity from pg_class where oid='private.account_deletions'::regclass), 'Deletion state enables RLS');
select extensions.ok(not has_function_privilege('authenticated', 'public.begin_account_deletion(uuid)', 'execute'), 'Clients cannot delete another account');
select extensions.ok(not has_function_privilege('authenticated', 'public.account_deletion_photos(uuid)', 'execute'), 'Deletion object listing is server-only');
select * from extensions.finish();
rollback;

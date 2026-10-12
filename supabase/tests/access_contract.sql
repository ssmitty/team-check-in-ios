-- access_contract.sql
-- Purpose: Check table isolation and privileged RPC grants independently of application code.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(8);
select extensions.is((select count(*)::integer from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ('teams','team_members','team_invites','games',
        'game_opt_outs','assignments','assignment_members','check_ins','encouragements') and c.relrowsecurity), 9,
    'Every application table enables RLS');
select extensions.ok(not has_table_privilege('anon', 'public.check_ins', 'select'), 'Anon cannot read responses');
select extensions.ok(not has_table_privilege('authenticated', 'public.team_members', 'update'), 'Members cannot promote themselves');
select extensions.ok(not has_table_privilege('authenticated', 'public.games', 'insert'), 'Schedules require captain RPC');
select extensions.ok(not has_table_privilege('authenticated', 'public.assignment_members', 'insert'), 'Clients cannot invent assignments');
select extensions.ok(not has_function_privilege('authenticated', 'public.commit_pairings(uuid,uuid,jsonb,jsonb)', 'execute'), 'Only worker can commit pairs');
select extensions.ok(not has_function_privilege('anon', 'public.create_team(text,text)', 'execute'), 'Team creation requires auth');
select extensions.ok(has_function_privilege('authenticated', 'public.submit_check_in(uuid,text,text,text)', 'execute'), 'Players may call protected submission');
select * from extensions.finish();
rollback;

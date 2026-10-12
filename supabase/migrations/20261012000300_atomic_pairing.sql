-- 20261012000300_atomic_pairing.sql
-- Purpose: Give the trusted worker a validated snapshot and atomic commit boundary.
create or replace function public.pairing_context(p_game uuid, p_user uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_game public.games; v_players jsonb; v_previous jsonb;
begin
    select * into v_game from public.games where id = p_game;
    if not found or not exists(select 1 from public.team_members where team_id = v_game.team_id and user_id = p_user)
        or v_game.is_canceled or clock_timestamp() < v_game.starts_at - interval '1 hour'
        or clock_timestamp() >= v_game.starts_at then raise exception 'Check-in unavailable'; end if;
    select coalesce(jsonb_agg(user_id order by user_id), '[]') into v_players
        from public.team_members m where team_id = v_game.team_id
        and not exists(select 1 from public.game_opt_outs o where o.game_id = p_game and o.user_id = m.user_id);
    select coalesce(jsonb_agg(members order by assignment_id), '[]') into v_previous from (
        select am.assignment_id, jsonb_agg(am.user_id order by am.user_id) members
        from public.assignment_members am where am.game_id = (
            select id from public.games where team_id = v_game.team_id and starts_at < v_game.starts_at
                and assignments_generated_at is not null and not is_canceled order by starts_at desc, id limit 1)
        group by am.assignment_id) previous;
    return jsonb_build_object('players', v_players, 'previous', v_previous,
        'generated', v_game.assignments_generated_at is not null);
end;
$$;
create or replace function public.commit_pairings(p_game uuid, p_user uuid, p_context jsonb, p_groups jsonb) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_team uuid; v_context jsonb; v_flat jsonb; v_group jsonb; v_assignment uuid; v_player text; v_count integer;
begin
    select team_id into v_team from public.games where id = p_game;
    perform 1 from public.teams where id = v_team for update;
    perform 1 from public.games where id = p_game for update;
    v_context := public.pairing_context(p_game, p_user);
    if (v_context->>'generated')::boolean then return false; end if;
    if v_context is distinct from p_context then raise exception 'Pairing snapshot changed' using errcode = '40001'; end if;
    if p_groups is null or jsonb_typeof(p_groups) <> 'array' then raise exception 'Invalid assignments'; end if;
    v_count := jsonb_array_length(v_context->'players');
    if v_count < 2 then
        if jsonb_array_length(p_groups) <> 0 then raise exception 'Invalid small roster'; end if;
    else
        if exists(select 1 from jsonb_array_elements(p_groups) g where jsonb_typeof(g) <> 'array'
            or jsonb_array_length(g) not in (2,3)) then raise exception 'Invalid group size'; end if;
        if (select count(*) from jsonb_array_elements(p_groups) g where jsonb_array_length(g) = 3) <> v_count % 2
            then raise exception 'Invalid trio count'; end if;
        select jsonb_agg(member.value order by member.value) into v_flat from jsonb_array_elements(p_groups) g,
            lateral jsonb_array_elements(g) member;
        if v_flat is distinct from v_context->'players' then raise exception 'Roster coverage mismatch'; end if;
    end if;
    for v_group in select value from jsonb_array_elements(p_groups) loop
        insert into public.assignments(game_id) values(p_game) returning id into v_assignment;
        for v_player in select jsonb_array_elements_text(v_group) loop
            insert into public.assignment_members(assignment_id,game_id,user_id) values(v_assignment,p_game,v_player::uuid);
        end loop;
    end loop;
    update public.games set assignments_generated_at = clock_timestamp() where id = p_game;
    return true;
end;
$$;
revoke all on function public.pairing_context(uuid,uuid), public.commit_pairings(uuid,uuid,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.pairing_context(uuid,uuid), public.commit_pairings(uuid,uuid,jsonb,jsonb) to service_role;

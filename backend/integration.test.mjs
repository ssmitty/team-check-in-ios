/**
 * integration.test.mjs
 * Purpose: Exercise real local Auth, PostgREST, RLS, invites, and atomic pair persistence.
 * Notes: Uses synthetic example.test accounts in this project's local Supabase only.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { makeAssignments } from './pairing.mjs';

const config = JSON.parse(execFileSync('supabase', ['status', '-o', 'json'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 15000 }));
const base = config.API_URL;
assert.ok(new URL(base).hostname === '127.0.0.1', 'Tests must target the local stack');
const stamp = randomUUID();

async function request(path, token, body, method = 'POST') {
  const response = await fetch(base + path, {
    method, signal: AbortSignal.timeout(20000), headers: { apikey: config.ANON_KEY, Authorization: `Bearer ${token ?? config.ANON_KEY}`, 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  }).catch(error => { throw new Error('Request failed: ' + path.split('?')[0], { cause: error }); });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null };
}
async function rpc(name, token, body) {
  const response = await request('/rest/v1/rpc/' + name, token, body);
  assert.ok(response.status < 300, `${name}: ${JSON.stringify(response.data)}`);
  return response.data;
}
async function rows(table, token, query = '') {
  const response = await request(`/rest/v1/${table}?select=*${query}`, token, undefined, 'GET');
  assert.equal(response.status, 200);
  return response.data;
}
async function account(index) {
  const result = await request('/auth/v1/signup', null, { email: `player-${stamp}-${index}@example.test`, password: randomUUID() + 'Aa9!' });
  assert.ok(result.status < 300, 'Local signup succeeds');
  assert.ok(result.data.access_token);
  return { id: result.data.user.id, token: result.data.access_token, refresh: result.data.refresh_token };
}

test('local accounts, captain enforcement, retry safety, and pair privacy', async () => {
  const users = [];
  for (let index = 0; index < 7; index += 1) users.push(await account(index));
  const captain = users[0];
  const team = await rpc('create_team', captain.token, { p_name: 'Synthetic test team', p_display_name: 'Captain' });
  const invite = await rpc('create_invite', captain.token, { p_team: team });
  for (const [index, user] of users.slice(1, 6).entries()) {
    const args = { p_token: invite, p_display_name: 'Player ' + index };
    assert.equal(await rpc('redeem_invite', user.token, args), team);
    assert.equal(await rpc('redeem_invite', user.token, args), team);
  }
  assert.equal((await rows('team_members', captain.token)).length, 6);
  const game = randomUUID();
  const gameArgs = { p_id: game, p_team: team, p_title: 'Test game', p_starts_at: new Date(Date.now() + 2400000).toISOString(), p_location: 'Warmups', p_time_zone_identifier: 'America/New_York' };
  await rpc('save_game', captain.token, gameArgs);
  assert.equal((await rows('games', users[1].token)).length, 1);
  assert.equal((await rows('games', users[6].token)).length, 0);
  assert.ok((await request('/rest/v1/rpc/save_game', users[1].token, gameArgs)).status >= 400);
  assert.ok((await request('/rest/v1/team_members', users[1].token, { team_id: team, user_id: users[1].id, role: 'captain', display_name: 'Member' }, 'PATCH')).status >= 400);
  assert.ok((await request('/rest/v1/rpc/create_invite', users[1].token, { p_team: team })).status >= 400);
  assert.ok((await request('/rest/v1/rpc/redeem_invite', users[6].token, { p_token: 'invalid', p_display_name: 'Outsider' })).status >= 400);
  const revocable = await rpc('create_invite', captain.token, { p_team: team });
  await rpc('revoke_invite', captain.token, { p_token: revocable });
  assert.ok((await request('/rest/v1/rpc/redeem_invite', users[6].token, { p_token: revocable, p_display_name: 'Outsider' })).status >= 400);
  assert.ok((await request('/rest/v1/rpc/pairing_context', captain.token, { p_game: game, p_user: captain.id })).status >= 400);
  const context = await rpc('pairing_context', config.SERVICE_ROLE_KEY, { p_game: game, p_user: captain.id });
  assert.ok((await request('/rest/v1/rpc/commit_pairings', config.SERVICE_ROLE_KEY,
    { p_game: game, p_user: captain.id, p_context: null, p_groups: null })).status >= 400);
  const groups = makeAssignments(context.players).groups;
  const args = { p_game: game, p_user: captain.id, p_context: context, p_groups: groups };
  const commits = await Promise.all([rpc('commit_pairings', config.SERVICE_ROLE_KEY, args), rpc('commit_pairings', config.SERVICE_ROLE_KEY, args)]);
  assert.deepEqual(commits.sort(), [false, true]);
  assert.equal((await rows('assignment_members', config.SERVICE_ROLE_KEY, `&game_id=eq.${game}`)).length, 6);
  const privateGroup = groups.find(group => !group.includes(captain.id));
  assert.ok(privateGroup);
  const author = users.find(user => user.id === privateGroup[0]);
  const partner = users.find(user => user.id === privateGroup[1]);
  const assignments = await rows('assignment_members', author.token, `&game_id=eq.${game}`);
  assert.equal(assignments.length, 2);
  const assignment = assignments[0].assignment_id;
  const checkIn = { p_assignment: assignment, p_feeling: 'Nervous', p_support: 'Encouragement', p_note: 'Synthetic note' };
  await rpc('submit_check_in', author.token, checkIn);
  await rpc('submit_check_in', author.token, checkIn);
  assert.equal((await rows('check_ins', partner.token)).length, 1);
  assert.equal((await rows('check_ins', captain.token)).length, 0);
  assert.equal((await rows('check_ins', users[6].token)).length, 0);
  assert.ok((await request('/rest/v1/rpc/submit_check_in', captain.token, checkIn)).status >= 400);
  assert.ok((await request('/rest/v1/rpc/submit_check_in', author.token, { ...checkIn, p_note: 'a'.repeat(281) })).status >= 400);
  await rpc('send_encouragement', partner.token, { p_assignment: assignment, p_recipient: author.id, p_message: "I've got you" });
  assert.equal((await rows('encouragements', author.token)).length, 1);
  assert.equal((await rows('encouragements', captain.token)).length, 0);
  assert.ok((await request('/rest/v1/rpc/save_game', captain.token, gameArgs)).status >= 400);
  const refreshed = await request('/auth/v1/token?grant_type=refresh_token', null, { refresh_token: author.refresh });
  assert.equal(refreshed.status, 200);
  assert.equal((await rows('check_ins', refreshed.data.access_token)).length, 1);
  const endpointGame = randomUUID();
  await rpc('save_game', captain.token, { ...gameArgs, p_id: endpointGame, p_starts_at: new Date(Date.now() + 2500000).toISOString() });
  const generated = await Promise.all([request('/functions/v1/generate-pairings', author.token, { game_id: endpointGame }),
    request('/functions/v1/generate-pairings', partner.token, { game_id: endpointGame })]);
  assert.ok(generated.every(result => result.status === 200), JSON.stringify(generated));
  const persisted = await rows('assignment_members', config.SERVICE_ROLE_KEY, `&game_id=eq.${endpointGame}`);
  assert.equal(persisted.length, 6);
  const newGroups = Object.values(persisted.reduce((map, member) => { (map[member.assignment_id] ??= []).push(member); return map; }, {})).map(group => group.map(member => member.user_id));
  for (const group of newGroups) assert.ok(!groups.some(previous => group.every(id => previous.includes(id))), 'Previous partner avoided');
  assert.ok((await request('/functions/v1/generate-pairings', users[6].token, { game_id: endpointGame })).status >= 400);
  const future = randomUUID();
  await rpc('save_game', captain.token, { ...gameArgs, p_id: future, p_starts_at: new Date(Date.now() + 7200000).toISOString() });
  await rpc('set_game_opt_out', users[5].token, { p_game: future, p_opt_out: true });
  assert.ok((await request('/functions/v1/generate-pairings', captain.token, { game_id: future })).status >= 400);
  // Only the test admin advances this synthetic event into its open window.
  execFileSync('psql', ['postgresql://postgres:postgres@127.0.0.1:54322/postgres', '-v', 'ON_ERROR_STOP=1', '-c',
    `update public.games set starts_at = now() + interval '30 minutes' where id = '${future}'`], { stdio: 'ignore' });
  assert.equal((await request('/functions/v1/generate-pairings', captain.token, { game_id: future })).status, 200);
  const trioMembers = await rows('assignment_members', config.SERVICE_ROLE_KEY, `&game_id=eq.${future}`);
  assert.equal(trioMembers.length, 5);
  const sizes = Object.values(trioMembers.reduce((map, member) => { (map[member.assignment_id] ??= []).push(member); return map; }, {})).map(group => group.length).sort();
  assert.deepEqual(sizes, [2, 3]);
  assert.ok((await request('/rest/v1/rpc/set_game_opt_out', author.token, { p_game: future, p_opt_out: true })).status >= 400);
  await rpc('save_game', captain.token, { ...gameArgs, p_is_canceled: true });
  assert.ok((await request('/rest/v1/rpc/submit_check_in', author.token, checkIn)).status >= 400);
});

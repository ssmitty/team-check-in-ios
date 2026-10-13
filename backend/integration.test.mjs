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
async function storage(path, token, body, method = 'GET', contentType = 'image/png') {
  const response = await fetch(base + '/storage/v1/' + path, {
    method, signal: AbortSignal.timeout(20000), headers: {
      apikey: config.ANON_KEY, Authorization: `Bearer ${token}`, 'Content-Type': contentType,
    }, ...(body === undefined ? {} : { body }),
  });
  return { status: response.status, data: Buffer.from(await response.arrayBuffer()) };
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
  const malformed = await request('/rest/v1/rpc/commit_pairings', config.SERVICE_ROLE_KEY,
    { p_game: game, p_user: captain.id, p_context: null, p_groups: null });
  assert.equal(malformed.status, 400);
  const stale = await request('/rest/v1/rpc/commit_pairings', config.SERVICE_ROLE_KEY,
    { p_game: game, p_user: captain.id, p_context: { ...context, players: [] }, p_groups: [] });
  assert.equal(stale.status, 409);
  assert.equal(stale.data.code, 'PT409');
  assert.equal((await rows('assignment_members', config.SERVICE_ROLE_KEY, `&game_id=eq.${game}`)).length, 0);
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
  const photoID = randomUUID();
  const photoArgs = { p_assignment: assignment, p_photo: photoID };
  const photoPath = await rpc('prepare_photo', author.token, photoArgs);
  assert.ok((await request('/rest/v1/rpc/prepare_photo', captain.token, photoArgs)).status >= 400);
  assert.ok((await request('/rest/v1/rpc/publish_photo', author.token, photoArgs)).status >= 400);
  const pixel = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZB0AAAAASUVORK5CYII=', 'base64');
  const objectPath = 'object/check-in-photos/' + photoPath;
  const downloadPath = 'object/authenticated/check-in-photos/' + photoPath;
  assert.ok((await storage(objectPath, partner.token, pixel, 'POST')).status >= 400);
  assert.ok((await storage(objectPath, author.token, Buffer.from('text'), 'POST', 'text/plain')).status >= 400);
  assert.ok((await storage(objectPath, author.token, Buffer.alloc(5_000_001), 'POST')).status >= 400);
  assert.ok((await storage(objectPath, author.token, pixel, 'POST')).status < 300);
  assert.ok((await storage(downloadPath, partner.token)).status >= 400);
  await rpc('publish_photo', author.token, photoArgs);
  await rpc('publish_photo', author.token, photoArgs);
  const image = await storage(downloadPath, partner.token);
  assert.equal(image.status, 200);
  assert.deepEqual(image.data, pixel);
  assert.ok((await storage(downloadPath, captain.token)).status >= 400);
  assert.ok((await storage(downloadPath, users[6].token)).status >= 400);
  assert.ok((await storage('object/public/check-in-photos/' + photoPath, partner.token)).status >= 400);
  assert.equal((await rows('check_in_photos', captain.token)).length, 0);
  const removed = await storage('object/check-in-photos', author.token,
    JSON.stringify({ prefixes: [photoPath] }), 'DELETE', 'application/json');
  assert.ok(removed.status < 300);
  await rpc('remove_photo', author.token, { p_assignment: assignment });
  await rpc('remove_photo', author.token, { p_assignment: assignment });
  assert.ok((await storage(downloadPath, partner.token)).status >= 400);
  assert.equal((await rows('check_in_photos', partner.token)).length, 0);
  // Abandoned reservations can be cleaned without deleting a currently referenced photo.
  const orphanID = randomUUID();
  const orphanPath = await rpc('prepare_photo', author.token, { p_assignment: assignment, p_photo: orphanID });
  assert.ok((await storage('object/check-in-photos/' + orphanPath, author.token, pixel, 'POST')).status < 300);
  await rpc('remove_photo', author.token, { p_assignment: assignment });
  const activeID = randomUUID();
  const activePath = await rpc('prepare_photo', author.token, { p_assignment: assignment, p_photo: activeID });
  assert.ok((await storage('object/check-in-photos/' + activePath, author.token, pixel, 'POST')).status < 300);
  await rpc('publish_photo', author.token, { p_assignment: assignment, p_photo: activeID });
  execFileSync('psql', ['postgresql://postgres:postgres@127.0.0.1:54322/postgres', '-v', 'ON_ERROR_STOP=1', '-c',
    `update storage.objects set created_at = now() - interval '2 days' where bucket_id='check-in-photos' and name in ('${orphanPath}','${activePath}')`], { stdio: 'ignore', timeout: 10000 });
  assert.ok((await request('/rest/v1/rpc/list_orphan_photos', author.token, { p_limit: 100 })).status >= 400);
  const orphans = await rpc('list_orphan_photos', config.SERVICE_ROLE_KEY, { p_limit: 100 });
  assert.ok(orphans.includes(orphanPath) && !orphans.includes(activePath));
  assert.equal((await request('/functions/v1/cleanup-orphan-photos', author.token, {})).status, 403);
  const cleanup = await request('/functions/v1/cleanup-orphan-photos', config.SERVICE_ROLE_KEY, {});
  assert.equal(cleanup.status, 200, JSON.stringify(cleanup.data));
  assert.ok((await storage('object/authenticated/check-in-photos/' + orphanPath, config.SERVICE_ROLE_KEY)).status >= 400);
  assert.equal((await storage('object/authenticated/check-in-photos/' + activePath, partner.token)).status, 200);
  assert.ok((await storage('object/check-in-photos', author.token,
    JSON.stringify({ prefixes: [activePath] }), 'DELETE', 'application/json')).status < 300);
  await rpc('remove_photo', author.token, { p_assignment: assignment });

  await rpc('request_warmup', author.token, { p_assignment: assignment });
  await rpc('request_warmup', author.token, { p_assignment: assignment });
  await rpc('acknowledge_warmup', partner.token, { p_assignment: assignment, p_requester: author.id });
  await rpc('acknowledge_warmup', partner.token, { p_assignment: assignment, p_requester: author.id });
  assert.equal((await rows('warmup_requests', partner.token)).length, 1);
  assert.equal((await rows('warmup_acknowledgments', author.token)).length, 1);
  assert.equal((await rows('warmup_requests', captain.token)).length, 0);
  assert.equal((await rows('warmup_requests', users[6].token)).length, 0);
  assert.ok((await request('/rest/v1/rpc/request_warmup', captain.token, { p_assignment: assignment })).status >= 400);
  assert.ok((await request('/rest/v1/rpc/acknowledge_warmup', author.token,
    { p_assignment: assignment, p_requester: author.id })).status >= 400);
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
  const trio = Object.values(trioMembers.reduce((map, member) => {
    (map[member.assignment_id] ??= []).push(member); return map;
  }, {})).find(group => group.length === 3);
  const trioRequester = users.find(user => user.id === trio[0].user_id);
  const trioRecipient = users.find(user => user.id === trio[1].user_id);
  const otherRecipient = users.find(user => user.id === trio[2].user_id);
  await rpc('request_warmup', trioRequester.token, { p_assignment: trio[0].assignment_id });
  await rpc('acknowledge_warmup', trioRecipient.token,
    { p_assignment: trio[0].assignment_id, p_requester: trioRequester.id });
  const trioAcks = await rows('warmup_acknowledgments', otherRecipient.token,
    `&assignment_id=eq.${trio[0].assignment_id}`);
  assert.equal(trioAcks.length, 1);
  assert.ok(!trioAcks.some(ack => ack.recipient_id === otherRecipient.id));
  assert.ok((await request('/rest/v1/rpc/set_game_opt_out', author.token, { p_game: future, p_opt_out: true })).status >= 400);
  await rpc('save_game', captain.token, { ...gameArgs, p_is_canceled: true });
  assert.ok((await request('/rest/v1/rpc/submit_check_in', author.token, checkIn)).status >= 400);
  assert.ok((await request('/rest/v1/rpc/request_warmup', author.token, { p_assignment: assignment })).status >= 400);
  assert.ok((await request('/rest/v1/rpc/acknowledge_warmup', partner.token,
    { p_assignment: assignment, p_requester: author.id })).status >= 400);
  // A trusted timer can open connections without an app calling the pairing endpoint.
  const scheduledGame = randomUUID();
  const scheduledArgs = { ...gameArgs, p_id: scheduledGame, p_starts_at: new Date(Date.now() + 7200000).toISOString() };
  await rpc('save_game', captain.token, scheduledArgs);
  assert.ok((await request('/rest/v1/rpc/claim_check_in_jobs', captain.token, { p_limit: 20 })).status >= 400);
  let earlyClaims = await rpc('claim_check_in_jobs', config.SERVICE_ROLE_KEY, { p_limit: 20 });
  assert.ok(!earlyClaims.some(job => job.game_id === scheduledGame));
  execFileSync('psql', ['postgresql://postgres:postgres@127.0.0.1:54322/postgres', '-v', 'ON_ERROR_STOP=1', '-c',
    `update public.games set starts_at = now() + interval '10 minutes' where id = '${scheduledGame}'`], { stdio: 'ignore', timeout: 10000 });
  const claims = (await Promise.all([
    rpc('claim_check_in_jobs', config.SERVICE_ROLE_KEY, { p_limit: 20 }),
    rpc('claim_check_in_jobs', config.SERVICE_ROLE_KEY, { p_limit: 20 }),
  ])).flat().filter(job => job.game_id === scheduledGame);
  assert.equal(claims.length, 1);
  const leased = claims[0];
  assert.equal(await rpc('complete_check_in_job', config.SERVICE_ROLE_KEY,
    { p_game: scheduledGame, p_revision: leased.revision, p_lease: leased.lease_id }), false);
  execFileSync('psql', ['postgresql://postgres:postgres@127.0.0.1:54322/postgres', '-v', 'ON_ERROR_STOP=1', '-c',
    `update private.check_in_jobs set lease_until = now() - interval '1 second' where game_id = '${scheduledGame}'`], { stdio: 'ignore', timeout: 10000 });
  const timer = await request('/functions/v1/process-due-events', config.SERVICE_ROLE_KEY, {});
  assert.equal(timer.status, 200, JSON.stringify(timer.data));
  assert.equal((await rows('assignment_members', config.SERVICE_ROLE_KEY, `&game_id=eq.${scheduledGame}`)).length, 6);
  assert.equal(await rpc('complete_check_in_job', config.SERVICE_ROLE_KEY,
    { p_game: scheduledGame, p_revision: leased.revision, p_lease: leased.lease_id }), false);
  assert.equal((await request('/functions/v1/process-due-events', captain.token, {})).status, 403);
  const retryTimer = await request('/functions/v1/process-due-events', config.SERVICE_ROLE_KEY, {});
  assert.equal(retryTimer.status, 200);
  assert.equal((await rows('assignment_members', config.SERVICE_ROLE_KEY, `&game_id=eq.${scheduledGame}`)).length, 6);
  const outboxCount = execFileSync('psql', ['postgresql://postgres:postgres@127.0.0.1:54322/postgres', '-Atc',
    `select count(*) from private.push_outbox where game_id = '${scheduledGame}'`], { encoding: 'utf8', timeout: 10000 }).trim();
  assert.equal(outboxCount, '6');
  await rpc('save_game', captain.token, { ...scheduledArgs, p_is_canceled: true });
  const pendingPushes = execFileSync('psql', ['postgresql://postgres:postgres@127.0.0.1:54322/postgres', '-Atc',
    `select count(*) from private.push_outbox where game_id = '${scheduledGame}' and state = 'pending'`], { encoding: 'utf8', timeout: 10000 }).trim();
  assert.equal(pendingPushes, '0');

});

/**
 * accountLifecycle.integration.test.mjs
 * Purpose: Verify real local password-confirmed deletion, captain transfer, photo removal, and stale-token denial.
 * Notes: Deletes only newly created synthetic accounts and photo fixtures in the isolated local stack.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
const config = JSON.parse(execFileSync('supabase', ['status', '-o', 'json'], {
  encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 15000,
}));
assert.equal(new URL(config.API_URL).hostname, '127.0.0.1');
async function request(path, token, body, method = 'POST') {
  const response = await fetch(config.API_URL + path, { method, signal: AbortSignal.timeout(30000),
    headers: { apikey: config.ANON_KEY, Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null };
}
async function rpc(name, user, body) {
  const response = await request('/rest/v1/rpc/' + name, user.token, body);
  assert.ok(response.status < 300, `${name}: ${response.status}, ${response.data?.code ?? 'unknown'}`);
  return response.data;
}
async function account() {
  const password = randomUUID() + 'Aa9!';
  const response = await request('/auth/v1/signup', config.ANON_KEY, { email: 'delete-' + randomUUID() + '@example.test', password });
  assert.ok(response.status < 300);
  return { id: response.data.user.id, token: response.data.access_token, password };
}
function sql(command) {
  return execFileSync('psql', [config.DB_URL, '-v', 'ON_ERROR_STOP=1', '-Atc', command], { encoding: 'utf8', timeout: 10000 }).trim();
}
async function deletion(user, extra = {}) {
  const response = await request('/functions/v1/delete-account', user.token, { password: user.password, confirmation: 'DELETE', ...extra });
  if (response.status >= 500) throw new Error(`Deletion returned ${response.status}: ${response.data.error}`);
  return response;
}
async function rows(table, user, query = '') {
  const response = await request('/rest/v1/' + table + '?select=*' + query, user.token, undefined, 'GET');
  assert.equal(response.status, 200);
  return response.data;
}
async function storage(path, user, body, method = 'GET') {
  return fetch(config.API_URL + '/storage/v1/object/' + path, { method, signal: AbortSignal.timeout(20000),
    headers: { apikey: config.ANON_KEY, Authorization: 'Bearer ' + user.token, 'Content-Type': 'image/png' },
    ...(body === undefined ? {} : { body }) });
}
async function photo(user, assignment) {
  const photoID = randomUUID();
  const path = await rpc('prepare_photo', user, { p_assignment: assignment, p_photo: photoID });
  const pixel = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jN1sAAAAASUVORK5CYII=', 'base64');
  assert.equal((await storage('check-in-photos/' + path, user, pixel, 'POST')).status, 200);
  await rpc('publish_photo', user, { p_assignment: assignment, p_photo: photoID });
  return { path, pixel };
}

async function fixture() {
  const [captain, member, outsider] = await Promise.all([account(), account(), account()]);
  const team = await rpc('create_team', captain, { p_name: 'Deletion fixture', p_display_name: 'Captain' });
  const invite = await rpc('create_invite', captain, { p_team: team });
  await rpc('redeem_invite', member, { p_token: invite, p_display_name: 'Member' });
  const game = randomUUID();
  await rpc('save_game', captain, { p_id: game, p_team: team, p_title: 'Fixture',
    p_starts_at: new Date(Date.now() + 1800000).toISOString(), p_location: '', p_time_zone_identifier: 'America/New_York', p_is_canceled: false });
  assert.equal((await request('/functions/v1/generate-pairings', captain.token, { game_id: game })).status, 200);
  const assignment = (await rows('assignment_members', captain, '&game_id=eq.' + game))[0].assignment_id;
  for (const user of [captain, member]) {
    await rpc('submit_check_in', user, { p_assignment: assignment, p_feeling: 'Nervous', p_support: 'Encouragement', p_note: 'Synthetic response' });
  }
  return { captain, member, outsider, team, invite, assignment };
}

test('password confirmation and captain transfer precede deleting actual owned data', async () => {
  const value = await fixture();
  const { captain, member, outsider, team, assignment } = value;
  const ownPhoto = await photo(captain, assignment), partnerPhoto = await photo(member, assignment);
  assert.equal((await deletion(captain, { password: 'wrong-password' })).status, 403);
  assert.equal((await deletion(captain, { user_id: member.id })).status, 400, 'Target IDs are rejected');
  assert.equal((await deletion(captain)).status, 409, 'Last captain must transfer first');
  assert.equal((await rows('team_members', captain, '&team_id=eq.' + team)).length, 2);
  assert.equal((await request('/rest/v1/rpc/transfer_captain', outsider.token, { p_team: team, p_recipient: member.id })).status, 400);
  assert.equal((await request('/rest/v1/rpc/transfer_captain', member.token, { p_team: team, p_recipient: member.id })).status, 400);
  await rpc('transfer_captain', captain, { p_team: team, p_recipient: member.id });
  assert.equal((await rows('team_members', member)).find(row => row.user_id === member.id).role, 'captain');
  assert.equal((await deletion(captain)).data.deleted, true);
  assert.equal(sql(`select count(*) from auth.users where id='${captain.id}'`), '0');
  assert.equal(sql(`select count(*) from storage.objects where bucket_id='check-in-photos' and name='${ownPhoto.path}'`), '0');
  assert.equal((await rows('check_ins', member)).length, 1, 'Partner independent response remains');
  assert.equal((await storage('authenticated/check-in-photos/' + partnerPhoto.path, member)).status, 200);
  assert.equal((await rows('check_ins', captain)).length, 0, 'Old JWT cannot read its previous connection');
  assert.ok((await request('/rest/v1/rpc/create_team', captain.token, { p_name: 'Stale account', p_display_name: 'Stale' })).status >= 400);
  assert.equal(sql("select count(*) from public.teams where name='Stale account'"), '0', 'Stale JWT cannot leave an orphan team');
  assert.ok((await request('/auth/v1/user', captain.token, undefined, 'GET')).status >= 400);
});

test('interrupted cleanup freezes access and can be resumed with password confirmation', async () => {
  const { captain, member, team, invite, assignment } = await fixture();
  await rpc('transfer_captain', captain, { p_team: team, p_recipient: member.id });
  const reserved = await rpc('prepare_photo', captain, { p_assignment: assignment, p_photo: randomUUID() });
  assert.ok((await request('/rest/v1/rpc/begin_account_deletion', captain.token, { p_user: member.id })).status >= 400);
  await rpc('begin_account_deletion', { token: config.SERVICE_ROLE_KEY }, { p_user: captain.id });
  assert.equal((await rows('check_ins', captain)).length, 0);
  assert.ok((await request('/rest/v1/rpc/redeem_invite', captain.token, { p_token: invite, p_display_name: 'Retry' })).status >= 400);
  assert.ok((await storage('check-in-photos/' + reserved, captain, Buffer.from('fixture'), 'POST')).status >= 400);
  assert.equal((await deletion(captain)).data.deleted, true);
  assert.equal((await rows('check_ins', member)).length, 1);
});

test('sole-member deletion removes its empty team and anonymous deletion is denied', async () => {
  const solo = await account();
  const team = await rpc('create_team', solo, { p_name: 'Sole fixture', p_display_name: 'Solo' });
  assert.ok((await request('/functions/v1/delete-account', config.ANON_KEY, { password: solo.password, confirmation: 'DELETE' })).status >= 400);
  assert.equal((await deletion(solo)).data.deleted, true);
  assert.equal(sql(`select count(*) from public.teams where id='${team}'`), '0');
});

test('concurrent captain transfer and deletion never leave remaining players without a captain', async () => {
  const { captain, member, team } = await fixture();
  const [transfer, cleanup] = await Promise.all([
    request('/rest/v1/rpc/transfer_captain', captain.token, { p_team: team, p_recipient: member.id }),
    deletion(captain),
  ]);
  assert.ok(transfer.status < 300 || transfer.status === 400);
  assert.ok(cleanup.status === 200 || cleanup.status === 409);
  const remaining = await rows('team_members', member, '&team_id=eq.' + team);
  assert.ok(remaining.some(row => row.role === 'captain'));
  if (cleanup.data.deleted) assert.equal(remaining.length, 1);
});

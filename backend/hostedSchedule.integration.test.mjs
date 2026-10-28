/**
 * hostedSchedule.integration.test.mjs
 * Purpose: Verify real hosted cron opening, schedule changes, and cancellation with synthetic accounts.
 * Notes: Explicit opt-in, approved development host only, public client key only, no APNs delivery.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { setTimeout as pause } from 'node:timers/promises';

const fixturePath = process.env.TEAM_CHECK_IN_HOSTED_FIXTURE;

test('hosted cron opens a real game and respects edited or canceled schedules', {
  skip: !fixturePath, timeout: 300000,
}, async context => {
  assert.equal(statSync(fixturePath).mode & 0o077, 0, 'Fixture credentials require private file permissions');
  const fixture = JSON.parse(readFileSync(fixturePath, 'utf8'));
  assert.equal(fixture.url, 'https://jdwrtscsjilmnurmhrez.supabase.co');
  assert.ok(fixture.marker.startsWith('hosted-review-'));
  assert.equal(fixture.accounts.length, 7);
  const key = process.env.TEAM_CHECK_IN_HOSTED_PUBLIC_KEY;
  assert.ok(key?.startsWith('sb_publishable_'), 'Only a publishable client key is accepted');

  /** Return decoded data without ever logging credentials or response bodies. */
  async function request(path, token, body, method = 'POST') {
    const response = await fetch(fixture.url + path, {
      method, signal: AbortSignal.timeout(20000),
      headers: { apikey: key, Authorization: `Bearer ${token ?? key}`, 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    }).catch(error => {
      throw new Error('Hosted request failed: ' + method + ' ' + path.split('?')[0], { cause: error });
    });
    assert.ok(response.ok, `${path.split('?')[0]} returned HTTP ${response.status}`);
    return response.json();
  }
  const players = [];
  // The native lifecycle suite deletes fixture index 5; the remaining five teammates form a pair and trio.
  for (const account of fixture.accounts.slice(0, 5)) {
    assert.ok(account.email.startsWith('hosted-review-') && account.email.endsWith('@example.test'));
    const session = await request('/auth/v1/token?grant_type=password', null,
      { email: account.email, password: account.password });
    assert.equal(session.user.id, account.id);
    players.push({ id: account.id, token: session.access_token });
  }
  const captain = players[0];
  const teams = await request('/rest/v1/team_members?select=team_id&role=eq.captain', captain.token, undefined, 'GET');
  assert.equal(teams.length, 1, 'Run only against the isolated native fixture team');
  const game = randomUUID(), edited = randomUUID(), canceled = randomUUID();
  const args = { p_team: teams[0].team_id, p_title: 'Synthetic hosted timer review',
    p_starts_at: new Date(Date.now() + 3670000).toISOString(), p_location: 'Synthetic warmups',
    p_time_zone_identifier: 'America/New_York' };
  const saved = new Map();
  async function save(id, changes = {}) {
    const body = { ...args, p_id: id, ...changes };
    const result = await request('/rest/v1/rpc/save_game', captain.token, body);
    saved.set(id, body);
    return result;
  }
  context.after(async () => {
    for (const body of saved.values()) {
      await request('/rest/v1/rpc/save_game', captain.token, { ...body, p_is_canceled: true });
    }
  });
  const members = (id, token) => request('/rest/v1/assignment_members?select=assignment_id,user_id&game_id=eq.' + id,
    token, undefined, 'GET');
  await save(game);
  await save(edited);
  await save(edited, { p_starts_at: new Date(Date.now() + 7200000).toISOString() });
  await save(canceled);
  await save(canceled, { p_is_canceled: true });
  console.log('Scheduled fixture game: ' + game);
  assert.equal((await members(game, captain.token)).length, 0, 'No early pairing');

  // Never call generate-pairings for this game. Only the deployed timer may open it.
  const deadline = Date.now() + 170000;
  while ((await members(game, captain.token)).length === 0 && Date.now() < deadline) await pause(5000);
  const all = (await Promise.all(players.map(player => members(game, player.token)))).flat();
  const unique = [...new Map(all.map(member => [member.user_id, member])).values()];
  assert.deepEqual(unique.map(member => member.user_id).sort(), players.map(player => player.id).sort());
  const sizes = new Map();
  for (const member of unique) sizes.set(member.assignment_id, (sizes.get(member.assignment_id) ?? 0) + 1);
  assert.deepEqual([...sizes.values()].sort(), [2, 3]);
  for (const player of players) {
    assert.equal((await members(edited, player.token)).length, 0, 'Moved game must remain closed');
    assert.equal((await members(canceled, player.token)).length, 0, 'Canceled game must remain closed');
  }
  // A later timer tick must not create another assignment or change the original group.
  const initial = await members(game, captain.token);
  await pause(65000);
  const byUser = (a, b) => a.user_id.localeCompare(b.user_id);
  assert.deepEqual((await members(game, captain.token)).sort(byUser), initial.sort(byUser));
});

/**
 * pushDelivery.integration.test.mjs
 * Purpose: Exercise real local delivery leases with injected APNs responses and no Apple network calls.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { processPushBatch } from './pushWorker.mjs';

const config = JSON.parse(execFileSync('supabase', ['status', '-o', 'json'], {
  encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 15000,
}));
assert.equal(new URL(config.API_URL).hostname, '127.0.0.1');
async function request(path, token, body) {
  const response = await fetch(config.API_URL + path, { method: 'POST', signal: AbortSignal.timeout(20000),
    headers: { apikey: config.ANON_KEY, Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
    body: JSON.stringify(body) });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null };
}
async function rpc(name, body, token = config.SERVICE_ROLE_KEY) {
  const response = await request('/rest/v1/rpc/' + name, token, body);
  assert.ok(response.status < 300, `${name}: ${response.status}, ${response.data?.code ?? 'unknown'}`);
  return response.data;
}
function sql(command) {
  return execFileSync('psql', [config.DB_URL, '-v', 'ON_ERROR_STOP=1', '-Atc', command],
    { encoding: 'utf8', timeout: 10000 }).trim();
}
async function account() {
  const response = await request('/auth/v1/signup', config.ANON_KEY, {
    email: 'delivery-' + randomUUID() + '@example.test', password: randomUUID() + 'Aa9!',
  });
  assert.ok(response.status < 300);
  return { id: response.data.user.id, token: response.data.access_token, installation: randomUUID(),
    deviceToken: randomUUID().replaceAll('-', '') + randomUUID().replaceAll('-', '') };
}
async function register(user, token = user.deviceToken) {
  await rpc('register_push_device', { p_installation: user.installation, p_token: token, p_environment: 'sandbox' }, user.token);
}
async function dueGame(team, captain) {
  const game = randomUUID();
  await rpc('save_game', { p_id: game, p_team: team, p_title: 'Synthetic delivery fixture',
    p_starts_at: new Date(Date.now() + 1800000).toISOString(), p_location: 'Fixture',
    p_time_zone_identifier: 'America/New_York', p_is_canceled: false }, captain.token);
  assert.equal((await request('/functions/v1/process-due-events', config.SERVICE_ROLE_KEY, {})).status, 200);
  return game;
}
const ids = claim => ({ p_delivery: claim.delivery_id, p_lease: claim.lease_id });
const finish = (claim, outcome, invalidated = null) => rpc('finish_push_delivery', {
  ...ids(claim), p_outcome: outcome, p_invalidated_at: invalidated,
});

// This suite owns the local delivery queue while asserting concurrent claims internally.
test('delivery leasing, current access, bounded retries, and stale invalidation', async (t) => {
  const users = await Promise.all([account(), account()]);
  const [captain, member] = users;
  const team = await rpc('create_team', { p_name: 'Delivery fixture', p_display_name: 'Captain' }, captain.token);
  t.after(async () => {
    sql(`delete from public.teams where id='${team}'`);
    for (const user of users) await rpc('revoke_push_device', { p_installation: user.installation }, user.token);
  });
  const invite = await rpc('create_invite', { p_team: team }, captain.token);
  await rpc('redeem_invite', { p_token: invite, p_display_name: 'Member' }, member.token);
  for (const user of users) await register(user);
  const game = await dueGame(team, captain);
  await verifyPrivacyAndRetry(game, captain, member);
  await verifyInterruptedLease(team, captain);
  await verifyTokenRotation(team, captain);
  await verifyStaleInvalidation(team, captain, member);
  await verifyCancellation(team, captain);
  await verifyRetryLimit(team, captain);
  await verifyMaintenance(game, captain, member);
});

async function verifyPrivacyAndRetry(game, captain, member) {
  const concurrent = await Promise.all([rpc('claim_push_deliveries', { p_limit: 1 }), rpc('claim_push_deliveries', { p_limit: 1 })]);
  const claims = concurrent.flat();
  assert.equal(claims.length, 2);
  assert.notEqual(claims[0].delivery_id, claims[1].delivery_id);
  const contexts = await Promise.all(claims.map(claim => rpc('push_delivery_context', ids(claim))));
  assert.ok(contexts.every(context => context.game_id === game));
  assert.ok((await request('/rest/v1/rpc/claim_push_deliveries', captain.token, { p_limit: 1 })).status >= 400);
  assert.ok((await request('/rest/v1/rpc/push_delivery_context', member.token, ids(claims[0]))).status >= 400);
  assert.ok((await request('/rest/v1/rpc/finish_push_delivery', member.token, { ...ids(claims[0]), p_outcome: 'accepted' })).status >= 400);
  assert.equal(await finish(claims[0], 'accepted'), true);
  assert.equal(await finish(claims[0], 'accepted'), false);
  assert.equal(await finish(claims[1], 'retry'), true);
  assert.equal((await rpc('claim_push_deliveries', { p_limit: 4 })).length, 0, 'Backoff excludes an immediate repeat');
  sql(`update private.push_deliveries set next_attempt_at=clock_timestamp()-interval '1 second' where id='${claims[1].delivery_id}'`);
  let sends = 0, sentID;
  const result = await processPushBatch({ rpc, bundleID: 'dev.ssmitty.TeamCheckIn', providerToken: 'offline.fixture.only',
    send: async value => { sends++; sentID = value.request.headers['apns-id']; return { outcome: 'accepted' }; } });
  assert.equal(result.accepted, 1);
  assert.equal(sends, 1);
  assert.equal(sentID, claims[1].delivery_id, 'Retries keep the original APNs identity');
  assert.equal((await rpc('claim_push_deliveries', { p_limit: 4 })).length, 0, 'Accepted attempts are never claimed again');

}

async function verifyInterruptedLease(team, captain) {
  await dueGame(team, captain);
  const interrupted = await rpc('claim_push_deliveries', { p_limit: 4 });
  assert.equal(interrupted.length, 2);
  for (const claim of interrupted) {
    sql(`update private.push_deliveries set lease_until=clock_timestamp()-interval '1 second' where id='${claim.delivery_id}'`);
  }
  const recovered = await rpc('claim_push_deliveries', { p_limit: 4 });
  assert.deepEqual(recovered.map(c => c.delivery_id).sort(), interrupted.map(c => c.delivery_id).sort());
  for (const claim of recovered) {
    const old = interrupted.find(c => c.delivery_id === claim.delivery_id);
    assert.notEqual(claim.lease_id, old.lease_id);
    assert.equal(await finish(old, 'accepted'), false);
    assert.equal(await finish(claim, 'accepted'), true);
  }

}

async function verifyTokenRotation(team, captain) {
  await dueGame(team, captain);
  const rotating = await rpc('claim_push_deliveries', { p_limit: 4 });
  const rotatingContexts = await Promise.all(rotating.map(c => rpc('push_delivery_context', ids(c))));
  const rotatedIndex = rotatingContexts.findIndex(c => c.device_token === captain.deviceToken);
  const rotated = rotating[rotatedIndex];
  captain.deviceToken = randomUUID().replaceAll('-', '') + randomUUID().replaceAll('-', '');
  await register(captain);
  assert.equal(await rpc('push_delivery_context', ids(rotated)), null, 'Old token cannot receive the current send');
  assert.equal(await finish(rotated, 'canceled'), true);
  assert.equal(await finish(rotating[1 - rotatedIndex], 'accepted'), true);
  assert.equal((await rpc('claim_push_deliveries', { p_limit: 4 })).length, 0, 'Token rotation still respects backoff');
  sql(`update private.push_deliveries set next_attempt_at=clock_timestamp()-interval '1 second' where id='${rotated.delivery_id}'`);
  const replacement = await rpc('claim_push_deliveries', { p_limit: 4 });
  assert.equal(replacement.length, 1);
  assert.equal(replacement[0].delivery_id, rotated.delivery_id);
  assert.equal((await rpc('push_delivery_context', ids(replacement[0]))).device_token, captain.deviceToken);
  assert.equal(await finish(replacement[0], 'accepted'), true);

}

async function verifyStaleInvalidation(team, captain, member) {
  const secondGame = await dueGame(team, captain);
  const secondClaims = await rpc('claim_push_deliveries', { p_limit: 4 });
  assert.equal(secondClaims.length, 2);
  const secondContexts = await Promise.all(secondClaims.map(claim => rpc('push_delivery_context', ids(claim))));
  const refreshedIndex = secondContexts.findIndex(context => context.device_token === member.deviceToken);
  const refreshed = secondClaims[refreshedIndex], other = secondClaims[1 - refreshedIndex];
  await register(member);
  assert.equal((await rpc('push_delivery_context', ids(refreshed))).game_id, secondGame, 'Same-token refresh preserves the queued alert');
  assert.equal(await finish(refreshed, 'invalidToken', Date.now() - 60000), true);
  assert.equal((await rpc('list_push_devices', { p_user: member.id })).length, 1, 'Old invalidation cannot delete refreshed registration');
  await rpc('revoke_push_device', { p_installation: captain.installation }, captain.token);
  assert.equal(await rpc('push_delivery_context', ids(other)), null, 'Sign-out revocation excludes an already claimed send');
  assert.equal(await finish(other, 'canceled'), true);
  // Cancel before another claim so revoked fixtures cannot recover a notification in a later run.
  sql(`update public.games set is_canceled=true where id='${secondGame}'`);

}

async function verifyCancellation(team, captain) {
  await register(captain);
  const canceledGame = await dueGame(team, captain);
  const canceled = await rpc('claim_push_deliveries', { p_limit: 4 });
  sql(`update public.games set is_canceled=true where id='${canceledGame}'`);
  for (const claim of canceled) {
    assert.equal(await rpc('push_delivery_context', ids(claim)), null);
    assert.equal(await finish(claim, 'accepted'), true);
    assert.equal(sql(`select state from private.push_deliveries where id='${claim.delivery_id}'`), 'canceled');
  }

}

async function verifyRetryLimit(team, captain) {
  const exhaustedGame = await dueGame(team, captain);
  const exhausted = await rpc('claim_push_deliveries', { p_limit: 4 });
  assert.equal(exhausted.length, 2);
  for (let attempt = 1; attempt <= 5; attempt++) {
    const attempts = attempt === 1 ? exhausted : await rpc('claim_push_deliveries', { p_limit: 4 });
    assert.equal(attempts.length, 2);
    for (const claim of attempts) assert.equal(await finish(claim, 'retry'), true);
    sql(`update private.push_deliveries p set next_attempt_at=clock_timestamp()-interval '1 second'
      from private.push_outbox o where o.id=p.outbox_id and o.game_id='${exhaustedGame}'`);
  }
  assert.equal((await rpc('claim_push_deliveries', { p_limit: 4 })).length, 0);
  assert.equal(sql(`select count(*) from private.push_deliveries p join private.push_outbox o on o.id=p.outbox_id
    where o.game_id='${exhaustedGame}' and p.state='failed'`), '2');
}

async function verifyMaintenance(game, captain, member) {
  assert.ok((await request('/rest/v1/rpc/cleanup_push_state', member.token, {})).status >= 400);
  sql(`update private.push_devices set expires_at=clock_timestamp()-interval '1 second' where installation_id='${member.installation}'`);
  sql(`update public.games set starts_at=clock_timestamp()-interval '2 days' where id='${game}'`);
  const cleaned = await rpc('cleanup_push_state', {});
  assert.ok(cleaned.expired_devices >= 1);
  assert.ok(cleaned.old_attempts >= 2);
  assert.equal((await rpc('list_push_devices', { p_user: captain.id })).length, 1, 'Cleanup preserves current registrations');
}

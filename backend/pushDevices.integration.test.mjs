/**
 * pushDevices.integration.test.mjs
 * Purpose: Verify private device registration, account reassignment, revocation, and session expiry locally.
 * Notes: Uses synthetic credentials and tokens; never targets a hosted project.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const config = JSON.parse(execFileSync('supabase', ['status', '-o', 'json'], {
  encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 15000,
}));
assert.equal(new URL(config.API_URL).hostname, '127.0.0.1');
async function call(path, token, body, method = 'POST') {
  const response = await fetch(config.API_URL + path, { method, signal: AbortSignal.timeout(20000),
    headers: { apikey: config.ANON_KEY, Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null };
}
async function rpc(name, token, args) {
  const result = await call('/rest/v1/rpc/' + name, token, args);
  assert.ok(result.status < 300, `${name}: ${result.status}, ${result.data?.code ?? 'unknown'}`);
  return result.data;
}
async function account() {
  const result = await call('/auth/v1/signup', config.ANON_KEY,
    { email: 'push-' + randomUUID() + '@example.test', password: randomUUID() + 'Aa9!' });
  assert.ok(result.status < 300);
  return { id: result.data.user.id, token: result.data.access_token };
}
function sql(command) {
  return execFileSync('psql', [config.DB_URL, '-v', 'ON_ERROR_STOP=1', '-Atc', command],
    { encoding: 'utf8', timeout: 10000 }).trim();
}

test('device associations remain server-only and follow the current account and live session', async () => {
  const [first, second] = await Promise.all([account(), account()]);
  const installation = randomUUID(), replacement = randomUUID();
  const deviceToken = randomUUID().replaceAll('-', '') + randomUUID().replaceAll('-', '');
  const args = { p_installation: installation, p_token: deviceToken.toUpperCase(), p_environment: 'sandbox' };
  assert.ok((await call('/rest/v1/rpc/register_push_device', config.ANON_KEY, args)).status >= 400);
  await rpc('register_push_device', first.token, args);
  await rpc('register_push_device', first.token, args);
  const list = () => rpc('list_push_devices', config.SERVICE_ROLE_KEY, { p_user: first.id });
  assert.equal((await list()).length, 1);
  assert.equal((await list())[0].device_token, deviceToken);
  assert.ok((await call('/rest/v1/rpc/list_push_devices', second.token, { p_user: first.id })).status >= 400);
  assert.ok((await call('/rest/v1/push_devices?select=*', first.token, undefined, 'GET')).status >= 400);
  for (const invalid of [{ p_token: 'not-hex' }, { p_token: 'a'.repeat(33) }, { p_token: 'a'.repeat(514) }, { p_environment: 'arbitrary' }]) {
    assert.ok((await call('/rest/v1/rpc/register_push_device', first.token, { ...args, ...invalid })).status >= 400);
  }
  await rpc('register_push_device', first.token, { ...args, p_token: 'a'.repeat(512) });
  await rpc('register_push_device', first.token, args);
  await rpc('revoke_push_device', second.token, { p_installation: installation });
  assert.equal((await list()).length, 1, 'Another account cannot revoke the current association');
  await rpc('register_push_device', second.token, args);
  assert.equal((await list()).length, 0, 'Shared device no longer belongs to its previous account');
  await rpc('register_push_device', second.token, { ...args, p_installation: replacement });
  const secondDevices = () => rpc('list_push_devices', config.SERVICE_ROLE_KEY, { p_user: second.id });
  assert.equal((await secondDevices()).length, 1, 'Reinstallation cannot duplicate a token');
  assert.equal((await secondDevices())[0].installation_id, replacement);
  sql(`update private.push_devices set expires_at=clock_timestamp()-interval '1 second' where installation_id='${replacement}'`);
  assert.equal((await secondDevices()).length, 0, 'Expired registrations cannot receive sends');
  await rpc('register_push_device', second.token, { ...args, p_installation: replacement });
  await rpc('revoke_push_device', second.token, { p_installation: replacement });
  await rpc('revoke_push_device', second.token, { p_installation: replacement });
  assert.equal((await secondDevices()).length, 0);
  await rpc('register_push_device', first.token, args);
  assert.equal((await list()).length, 1);
  assert.ok((await call('/auth/v1/logout', first.token, {})).status < 300);
  assert.equal((await list()).length, 0, 'Revoked Auth sessions cannot receive sends');
  assert.ok((await call('/rest/v1/rpc/register_push_device', first.token, args)).status >= 400,
    'An unexpired JWT from a deleted session cannot re-register');
});

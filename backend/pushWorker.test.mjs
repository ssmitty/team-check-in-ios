/**
 * pushWorker.test.mjs
 * Purpose: Verify current-access cancellation, private payloads, retries, and lease loss offline.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { processPushBatch } from './pushWorker.mjs';
import { makePushRPC } from './pushRpc.mjs';

const claim = { delivery_id: '00000000-0000-0000-0000-000000000001', lease_id: '00000000-0000-0000-0000-000000000002' };
const context = { game_id: '00000000-0000-0000-0000-000000000003', starts_at: '2026-10-13T02:00:00Z',
  notification_id: claim.delivery_id, device_token: 'a'.repeat(64), environment: 'sandbox' };
function fixture(value = context, recorded = true) {
  const calls = [];
  return { calls, async rpc(name, args) {
    calls.push({ name, args });
    if (name === 'claim_push_deliveries') return [claim];
    if (name === 'push_delivery_context') return value;
    return recorded;
  } };
}
test('worker revalidates immediately before sending and records only provider acceptance', async () => {
  const fake = fixture(); let sent;
  const result = await processPushBatch({ rpc: fake.rpc, bundleID: 'dev.ssmitty.TeamCheckIn',
    providerToken: 'offline.fixture.only', send: async request => { sent = request; return { outcome: 'accepted' }; } });
  assert.deepEqual(result, { claimed: 1, accepted: 1 });
  assert.deepEqual(fake.calls.map(call => call.name), ['claim_push_deliveries', 'push_delivery_context', 'finish_push_delivery']);
  assert.deepEqual(fake.calls[0].args, { p_limit: 4 });
  assert.deepEqual(Object.keys(sent.request.payload).sort(), ['aps', 'game_id']);
  assert.equal(sent.request.headers['apns-id'], claim.delivery_id);
});
test('revoked or changed context never calls APNs', async () => {
  const fake = fixture(null); let sends = 0;
  assert.deepEqual(await processPushBatch({ rpc: fake.rpc, send: async () => { sends++; } }), { claimed: 1, canceled: 1 });
  assert.equal(sends, 0);
});
test('network ambiguity requests retry without inventing acceptance', async () => {
  const fake = fixture();
  assert.deepEqual(await processPushBatch({ rpc: fake.rpc, bundleID: 'app',
    send: async () => { throw new Error('sensitive diagnostic'); } }), { claimed: 1, retry: 1 });
  assert.equal(fake.calls.at(-1).args.p_outcome, 'retry');
});
test('lost completion lease is reported separately from accepted delivery', async () => {
  const fake = fixture(context, false);
  assert.deepEqual(await processPushBatch({ rpc: fake.rpc, bundleID: 'app',
    send: async () => ({ outcome: 'accepted' }) }), { claimed: 1, leaseLost: 1 });
});
test('RPC transport requires HTTPS and does not expose server error content', async () => {
  assert.throws(() => makePushRPC({ baseURL: 'http://example.test', serviceKey: 'x'.repeat(40) }));
  const rpc = makePushRPC({ baseURL: 'https://example.test', serviceKey: 'x'.repeat(40),
    fetchRequest: async () => ({ ok: false, text: async () => 'private details' }) });
  await assert.rejects(rpc('claim_push_deliveries', {}), /Push persistence request failed/);
  await assert.rejects(rpc('../secrets', {}), /valid RPC/);
});

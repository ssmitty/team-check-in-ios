/**
 * apnsDelivery.test.mjs
 * Purpose: Verify HTTP/2 request shaping, safe outcomes, expiration, and bounded failures offline.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { deliverNotification } from './apnsDelivery.mjs';
import { makePregameRequest } from './apns.mjs';

const base = {
  deviceToken: 'a'.repeat(64), providerToken: 'offline.fixture.only', environment: 'sandbox',
  now: new Date('2026-10-13T00:00:00Z'),
  request: makePregameRequest({ gameID: '00000000-0000-0000-0000-000000000001',
    notificationID: '00000000-0000-0000-0000-000000000002',
    startsAt: '2026-10-13T01:00:00Z', bundleID: 'dev.ssmitty.TeamCheckIn' }),
};
function fixture(status, body = '', { hang = false, fail = false } = {}) {
  const captured = {};
  return { captured, connectSession(host) {
    captured.host = host;
    const session = new EventEmitter();
    session.destroy = () => { captured.closed = true; };
    session.request = (headers) => {
      captured.headers = headers;
      const stream = new EventEmitter();
      stream.close = () => {};
      stream.end = (payload) => {
        captured.payload = JSON.parse(payload);
        queueMicrotask(() => {
          if (fail) { stream.emit('error', new Error('sensitive transport details')); return; }
          if (hang) return;
          stream.emit('response', { ':status': status });
          if (body) stream.emit('data', Buffer.from(body));
          stream.emit('end');
        });
      };
      return stream;
    };
    return session;
  } };
}
test('HTTP/2 uses the exact APNs endpoint and neutral stable request', async () => {
  const fake = fixture(200);
  assert.deepEqual(await deliverNotification({ ...base, connectSession: fake.connectSession }),
    { outcome: 'accepted', status: 200 });
  assert.equal(fake.captured.host, 'https://api.sandbox.push.apple.com');
  assert.equal(fake.captured.headers[':path'], '/3/device/' + base.deviceToken);
  assert.equal(fake.captured.headers[':method'], 'POST');
  assert.equal(fake.captured.headers['apns-id'], base.request.headers['apns-id']);
  assert.deepEqual(fake.captured.payload, base.request.payload);
  assert.equal(fake.captured.closed, true);
});
test('expired events do not open a connection', async () => {
  const fake = fixture(200);
  assert.deepEqual(await deliverNotification({ ...base, now: new Date('2026-10-13T01:00:00Z'),
    connectSession: fake.connectSession }), { outcome: 'expired' });
  assert.equal(fake.captured.host, undefined);
});
test('temporary, token, and provider failures have distinct safe outcomes', async () => {
  for (const [status, body, expected] of [
    [429, '{}', 'retry'], [503, '{}', 'retry'],
    [410, '{"reason":"Unregistered","timestamp":1791849600000}', 'invalidToken'],
    [400, '{"reason":"BadDeviceToken"}', 'invalidToken'],
    [403, '{"reason":"InvalidProviderToken"}', 'configuration'],
    [400, '{"reason":"BadTopic"}', 'configuration'], [400, 'private diagnostic', 'configuration'],
  ]) {
    const fake = fixture(status, body);
    const result = await deliverNotification({ ...base, connectSession: fake.connectSession });
    assert.equal(result.outcome, expected);
    assert.equal(JSON.stringify(result).includes('private'), false);
    if (status === 410) assert.equal(result.invalidatedAt, 1791849600000);
  }
});
test('transport failures and hanging responses end within the configured deadline', async () => {
  for (const options of [{ fail: true }, { hang: true }]) {
    const fake = fixture(200, '', options);
    const result = await deliverNotification({ ...base, timeoutMs: 10, connectSession: fake.connectSession });
    assert.deepEqual(result, { outcome: 'retry' });
    assert.equal(fake.captured.closed, true);
  }
});
test('invalid endpoints and oversized responses cannot expose transport details', async () => {
  await assert.rejects(deliverNotification({ ...base, environment: 'https://attacker.test' }));
  await assert.rejects(deliverNotification({ ...base, deviceToken: '../secret' }));
  const fake = fixture(403, 'x'.repeat(4097));
  assert.deepEqual(await deliverNotification({ ...base, connectSession: fake.connectSession }), { outcome: 'retry' });
});

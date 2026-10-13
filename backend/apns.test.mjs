/**
 * apns.test.mjs
 * Purpose: Verify notification privacy, expiration, retry identity, and provider token signing offline.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { createProviderToken, makePregameRequest } from './apns.mjs';

const gameID = '00000000-0000-0000-0000-000000000001';
const notificationID = '00000000-0000-0000-0000-000000000002';
test('notification carries only neutral text and event navigation, with stable retry IDs', () => {
  const input = { gameID, notificationID, startsAt: '2026-10-13T00:00:00Z', bundleID: 'dev.ssmitty.TeamCheckIn' };
  const first = makePregameRequest(input);
  assert.deepEqual(first, makePregameRequest(input));
  assert.deepEqual(Object.keys(first.payload).sort(), ['aps', 'game_id']);
  assert.equal(first.payload.aps.alert.body, 'Time for a teammate check-in.');
  assert.equal(first.headers['apns-expiration'], '1791849600');
  assert.equal(first.headers['apns-collapse-id'], gameID);
  assert.equal(first.headers['apns-id'], notificationID);
  assert.equal(first.headers['apns-push-type'], 'alert');
});
test('invalid navigation identifiers and dates are rejected', () => {
  assert.throws(() => makePregameRequest({ gameID: 'bad', notificationID, startsAt: 'bad', bundleID: 'app' }));
  assert.throws(() => makePregameRequest({ gameID, notificationID, startsAt: 'bad', bundleID: 'app' }));
});
test('provider JWT has verifiable ES256 signature and injected issue time', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const pem = privateKey.export({ type: 'pkcs8', format: 'pem' });
  const token = createProviderToken({ teamID: 'TESTTEAM01', keyID: 'TESTKEY001', privateKey: pem,
    now: new Date('2026-10-13T00:00:00Z') });
  const [header, claims, signature] = token.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url')), { alg: 'ES256', kid: 'TESTKEY001' });
  assert.deepEqual(JSON.parse(Buffer.from(claims, 'base64url')), { iss: 'TESTTEAM01', iat: 1791849600 });
  assert.ok(verify('sha256', Buffer.from(header + '.' + claims), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(signature, 'base64url')));
});
test('incorrect signing curves cannot be used for provider authorization', () => {
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'secp384r1' });
  assert.throws(() => createProviderToken({ teamID: 'TESTTEAM01', keyID: 'TESTKEY001',
    privateKey: privateKey.export({ type: 'pkcs8', format: 'pem' }) }));
});

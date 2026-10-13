/**
 * apns.mjs
 * Purpose: Prepare neutral pregame payloads and short-lived APNs provider authorization.
 * Exports: makePregameRequest, createProviderToken
 * Notes: This module performs no network delivery and requires server-only credentials.
 */
import { createPrivateKey, sign } from 'node:crypto';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function base64url(value) { return Buffer.from(value).toString('base64url'); }

/** Build a privacy-preserving request that expires when the game starts. */
export function makePregameRequest({ gameID, startsAt, bundleID, notificationID }) {
  if (!UUID_PATTERN.test(gameID) || !UUID_PATTERN.test(notificationID)) {
    throw new Error('Valid event and notification identifiers are required.');
  }
  if (typeof bundleID !== 'string' || !/^[a-z0-9.-]+$/i.test(bundleID)) {
    throw new Error('An app bundle identifier is required.');
  }
  const expiry = Math.floor(new Date(startsAt).getTime() / 1000);
  if (!Number.isFinite(expiry)) throw new Error('A valid absolute start time is required.');
  return {
    headers: {
      'apns-topic': bundleID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'apns-expiration': String(expiry),
      'apns-id': notificationID,
      'apns-collapse-id': gameID,
    },
    payload: {
      aps: { alert: { title: 'Team Check-in', body: 'Time for a teammate check-in.' }, 'thread-id': 'team-check-in' },
      game_id: gameID,
    },
  };
}

/** Sign an ES256 provider JWT. Never place the key or resulting token in the iPhone app or logs. */
export function createProviderToken({ teamID, keyID, privateKey, now = new Date() }) {
  if (!/^[a-z0-9]{10}$/i.test(teamID) || !/^[a-z0-9]{10}$/i.test(keyID)) {
    throw new Error('Valid Apple team and key identifiers are required.');
  }
  const issuedAt = Math.floor(now.getTime() / 1000);
  if (!Number.isFinite(issuedAt)) throw new Error('A valid token issue time is required.');
  const key = createPrivateKey(privateKey);
  if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
    throw new Error('An Apple-compatible P-256 signing key is required.');
  }
  const input = base64url(JSON.stringify({ alg: 'ES256', kid: keyID })) + '.'
    + base64url(JSON.stringify({ iss: teamID, iat: issuedAt }));
  const signature = sign('sha256', Buffer.from(input), { key, dsaEncoding: 'ieee-p1363' });
  return input + '.' + base64url(signature);
}

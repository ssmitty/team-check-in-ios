/**
 * apnsDelivery.mjs
 * Purpose: Send one bounded HTTP/2 request to APNs and classify provider acceptance safely.
 * Exports: deliverNotification
 * Notes: Server-only adapter. Acceptance does not establish delivery to a device.
 */
import { connect } from 'node:http2';

const HOSTS = { sandbox: 'https://api.sandbox.push.apple.com', production: 'https://api.push.apple.com' };

/** Send once with an injected connection factory and clock. Queue retry policy belongs to the caller. */
export async function deliverNotification({ deviceToken, providerToken, request, environment,
  connectSession = connect, now = new Date(), timeoutMs = 15_000 }) {
  if (typeof deviceToken !== 'string' || !/^[a-f0-9]{32,512}$/i.test(deviceToken) || deviceToken.length % 2 !== 0) {
    throw new Error('A valid hexadecimal device token is required.');
  }
  if (typeof providerToken !== 'string' || !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(providerToken)) {
    throw new Error('A server provider token is required.');
  }
  if (!Object.hasOwn(HOSTS, environment) || !Number.isFinite(now.getTime())
    || !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 30_000) {
    throw new Error('Valid delivery environment, time, and bounded timeout are required.');
  }
  const expiry = Number(request?.headers?.['apns-expiration']);
  if (!Number.isFinite(expiry) || expiry <= Math.floor(now.getTime() / 1000)) return { outcome: 'expired' };
  return sendRequest({ deviceToken, providerToken, request, host: HOSTS[environment], connectSession, timeoutMs });
}

function sendRequest({ deviceToken, providerToken, request, host, connectSession, timeoutMs }) {
  return new Promise((resolve) => {
    let session, stream, timer, finished = false, status = 0, body = '';
    const finish = (result) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      stream?.close();
      session?.destroy();
      resolve(result);
    };
    const retry = () => finish({ outcome: 'retry' });
    try {
      timer = setTimeout(retry, timeoutMs);
      session = connectSession(host);
      session.on('error', retry);
      stream = session.request({ ...request.headers, ':method': 'POST', ':path': '/3/device/' + deviceToken,
        authorization: 'bearer ' + providerToken });
      stream.on('error', retry);
      stream.on('aborted', retry);
      stream.on('close', () => { if (!finished) retry(); });
      stream.on('response', (headers) => { status = Number(headers[':status']); });
      stream.on('data', (chunk) => {
        if (Buffer.byteLength(body) + chunk.length > 4096) { retry(); return; }
        body += chunk.toString('utf8');
      });
      stream.on('end', () => finish(classify(status, body)));
      stream.end(JSON.stringify(request.payload));
    } catch { retry(); }
  });
}

function classify(status, body) {
  if (status === 200) return { outcome: 'accepted', status };
  if (status === 429 || status >= 500 || status === 0) return { outcome: 'retry', status };
  let error;
  try { error = JSON.parse(body); } catch { return { outcome: 'configuration', status }; }
  if (status === 410 && error.reason === 'Unregistered') {
    const timestamp = Number(error.timestamp);
    return Number.isFinite(timestamp) && timestamp > 0
      ? { outcome: 'invalidToken', status, invalidatedAt: timestamp }
      : { outcome: 'invalidToken', status };
  }
  if (status === 400 && ['BadDeviceToken', 'DeviceTokenNotForTopic'].includes(error.reason)) {
    return { outcome: 'invalidToken', status };
  }
  return { outcome: 'configuration', status };
}

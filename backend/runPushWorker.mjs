/**
 * runPushWorker.mjs
 * Purpose: Compose one server push batch from environment-only credentials.
 * Notes: Requires a Node HTTP/2 runtime, configured APNs credentials, and an external timer.
 */
import { createProviderToken } from './apns.mjs';
import { deliverNotification } from './apnsDelivery.mjs';
import { processPushBatch } from './pushWorker.mjs';
import { makePushRPC } from './pushRpc.mjs';

try {
  const environment = process.env;
  if (typeof environment.APNS_BUNDLE_ID !== 'string' || !/^[a-z0-9.-]+$/i.test(environment.APNS_BUNDLE_ID)) {
    throw new Error('App topic configuration is required.');
  }
  const providerToken = createProviderToken({ teamID: environment.APNS_TEAM_ID,
    keyID: environment.APNS_KEY_ID, privateKey: environment.APNS_PRIVATE_KEY });
  const rpc = makePushRPC({ baseURL: environment.SUPABASE_URL, serviceKey: environment.SUPABASE_SERVICE_ROLE_KEY });
  await rpc('cleanup_push_state', {});
  const result = await processPushBatch({ providerToken, bundleID: environment.APNS_BUNDLE_ID,
    rpc,
    send: deliverNotification });
  console.log(JSON.stringify(result));
  if (result.error || result.configuration || result.leaseLost) process.exitCode = 1;
} catch {
  console.error('Push worker failed. Check server configuration and connectivity.');
  process.exitCode = 1;
}

/**
 * pushWorker.mjs
 * Purpose: Process a small leased batch with current access checks and injected APNs delivery.
 * Exports: processPushBatch
 * Notes: Does not claim device delivery from APNs acceptance. Credentials stay in server composition.
 */
import { makePregameRequest } from './apns.mjs';

/** Process at most four concurrent attempts so the bounded RPC/network calls fit inside a lease. */
export async function processPushBatch({ rpc, send, providerToken, bundleID, now = () => new Date() }) {
  const claims = await rpc('claim_push_deliveries', { p_limit: 4 });
  if (!Array.isArray(claims) || claims.length > 4) throw new Error('Invalid delivery claim response.');
  const results = await Promise.all(claims.map(claim => processClaim(claim, { rpc, send, providerToken, bundleID, now })));
  return results.reduce((counts, outcome) => ({ ...counts, [outcome]: (counts[outcome] ?? 0) + 1 }), { claimed: claims.length });
}

async function processClaim(claim, { rpc, send, providerToken, bundleID, now }) {
  const identifiers = { p_delivery: claim.delivery_id, p_lease: claim.lease_id };
  try {
    const context = await rpc('push_delivery_context', identifiers);
    let result = { outcome: 'canceled' };
    if (context) {
      const request = makePregameRequest({ gameID: context.game_id, startsAt: context.starts_at,
        notificationID: context.notification_id, bundleID });
      try {
        result = await send({ deviceToken: context.device_token, environment: context.environment,
          providerToken, request, now: now() });
      } catch { result = { outcome: 'retry' }; }
    }
    const recorded = await rpc('finish_push_delivery', { ...identifiers, p_outcome: result.outcome,
      p_invalidated_at: result.invalidatedAt ?? null });
    return recorded ? result.outcome : 'leaseLost';
  } catch { return 'error'; }
}

/**
 * workerAuthorization.mjs
 * Purpose: Authorize trusted jobs with the server key or a scoped, Vault-backed scheduler token.
 * Exports: authorizeWorker
 */

/** Validate the bounded scheduler credential without exposing the service key to cron. */
export async function authorizeWorker(request, serverKey, rpc) {
  if (!serverKey) return false;
  if (request.headers.get('Authorization') === `Bearer ${serverKey}`) return true;
  const token = request.headers.get('X-Team-CheckIn-Scheduler');
  if (!token || !/^[a-f0-9]{64}$/.test(token)) return false;
  try {
    return await rpc('authorize_scheduled_worker', { p_token: token }) === true;
  } catch {
    return false;
  }
}

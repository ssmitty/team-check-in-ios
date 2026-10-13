/**
 * pushRpc.mjs
 * Purpose: Provide bounded server-only RPC transport for the Node push worker.
 * Exports: makePushRPC
 */
/** Construct a trusted HTTPS transport; tests inject local transport separately. */
export function makePushRPC({ baseURL, serviceKey, fetchRequest = fetch }) {
  const url = new URL(baseURL);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
    throw new Error('A trusted HTTPS backend URL is required.');
  }
  if (typeof serviceKey !== 'string' || serviceKey.length < 30) throw new Error('Server credentials are required.');
  return async (name, body) => {
    if (!/^[a-z_]+$/.test(name)) throw new Error('A valid RPC name is required.');
    const response = await fetchRequest(new URL('/rest/v1/rpc/' + name, url), {
      method: 'POST', signal: AbortSignal.timeout(15000),
      headers: { apikey: serviceKey, Authorization: 'Bearer ' + serviceKey, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!response.ok) throw new Error('Push persistence request failed.');
    return response.json();
  };
}

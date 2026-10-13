/**
 * serverRpc.ts
 * Purpose: Bound trusted database calls without logging credentials or private responses.
 */
export async function serverRpc(baseURL: string, key: string, name: string, body: unknown) {
  const response = await fetch(`${baseURL}/rest/v1/rpc/${name}`, {
    method: 'POST', signal: AbortSignal.timeout(15000),
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const value = await response.json();
  if (!response.ok) throw Object.assign(new Error('Server operation failed'), { code: value.code });
  return value;
}

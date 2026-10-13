/**
 * index.ts
 * Purpose: Delete old unreferenced private photos through Storage, including their actual object data.
 * Notes: Requires the exact server credential. Current reservations and recent uploads are preserved.
 */
import { serverRpc } from '../_shared/serverRpc.ts';
const baseURL = Deno.env.get('SUPABASE_URL');
const serverKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response(null, { status: 405 });
  if (!baseURL || !serverKey) return Response.json({ error: 'Service unavailable' }, { status: 503 });
  if (request.headers.get('Authorization') !== `Bearer ${serverKey}`) {
    return Response.json({ error: 'Server authorization required' }, { status: 403 });
  }
  try {
    const paths = await serverRpc(baseURL, serverKey, 'list_orphan_photos', { p_limit: 100 });
    if (paths.length === 0) return Response.json({ removed: 0 });
    const response = await fetch(`${baseURL}/storage/v1/object/check-in-photos`, {
      method: 'DELETE', signal: AbortSignal.timeout(20000),
      headers: { apikey: serverKey, Authorization: `Bearer ${serverKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ prefixes: paths }),
    });
    if (!response.ok) return Response.json({ error: 'Cleanup failed. Retry later.' }, { status: 503 });
    const objects = await response.json();
    return Response.json({ removed: objects.length });
  } catch { return Response.json({ error: 'Cleanup unavailable' }, { status: 503 }); }
});

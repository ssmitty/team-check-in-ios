/**
 * index.ts
 * Purpose: Authenticate a player and atomically persist server-generated assignments.
 * Notes: Service credentials stay in this function. Clients receive no other assignments.
 */
import { serverRpc } from '../_shared/serverRpc.ts';
import { makeAssignments } from '../_shared/pairing.mjs';

const baseURL = Deno.env.get('SUPABASE_URL');
const serverKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

async function rpc(name: string, body: unknown) {
  if (!baseURL || !serverKey) throw new Error('Service unavailable');
  return await serverRpc(baseURL, serverKey, name, body);
}

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response(null, { status: 405 });
  if (!baseURL || !serverKey) return Response.json({ error: 'Service unavailable' }, { status: 503 });
  const authorization = request.headers.get('Authorization');
  if (!authorization) return Response.json({ error: 'Sign in first' }, { status: 401 });
  try {
    const userResponse = await fetch(`${baseURL}/auth/v1/user`, {
      headers: { apikey: serverKey, Authorization: authorization },
    });
    if (!userResponse.ok) return Response.json({ error: 'Sign in first' }, { status: 401 });
    const user = await userResponse.json();
    const { game_id } = await request.json();
    if (typeof game_id !== 'string' || !/^[0-9a-f-]{36}$/i.test(game_id)) {
      return Response.json({ error: 'Invalid game' }, { status: 400 });
    }
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const context = await rpc('pairing_context', { p_game: game_id, p_user: user.id });
      if (context.generated) return Response.json({ ready: true });
      const { groups } = makeAssignments(context.players, context.previous);
      try {
        await rpc('commit_pairings', { p_game: game_id, p_user: user.id, p_context: context, p_groups: groups });
        return Response.json({ ready: true });
      } catch (error) {
        if (!(error instanceof Error) || (error as Error & { code?: string }).code !== 'PT409') throw error;
      }
    }
    return Response.json({ error: 'Roster changed. Try again.' }, { status: 409 });
  } catch {
    return Response.json({ error: 'Check-in unavailable. Refresh and try again.' }, { status: 400 });
  }
});

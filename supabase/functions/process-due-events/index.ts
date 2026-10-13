/**
 * index.ts
 * Purpose: Process leased pregame jobs independently of a player's app being open.
 * Notes: Only the exact server credential can invoke this worker. Push records are queued, not delivered.
 */
import { serverRpc } from '../_shared/serverRpc.ts';
import { makeAssignments } from '../_shared/pairing.mjs';
const baseURL = Deno.env.get('SUPABASE_URL');
const serverKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

async function rpc(name: string, body: unknown) {
  if (!baseURL || !serverKey) throw new Error('Service unavailable');
  return await serverRpc(baseURL, serverKey, name, body);
}

async function process(job: { game_id: string; acting_user: string | null; revision: number; lease_id: string }) {
  if (!job.acting_user) return false;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const context = await rpc('pairing_context', { p_game: job.game_id, p_user: job.acting_user });
    if (!context.generated) {
      const { groups } = makeAssignments(context.players, context.previous);
      try {
        await rpc('commit_pairings', { p_game: job.game_id, p_user: job.acting_user, p_context: context, p_groups: groups });
      } catch (error) {
        if (error instanceof Error && (error as Error & { code?: string }).code === 'PT409') continue;
        throw error;
      }
    }
    return await rpc('complete_check_in_job', { p_game: job.game_id, p_revision: job.revision, p_lease: job.lease_id });
  }
  return false;
}

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response(null, { status: 405 });
  if (!baseURL || !serverKey) return Response.json({ error: 'Service unavailable' }, { status: 503 });
  if (request.headers.get('Authorization') !== `Bearer ${serverKey}`) {
    return Response.json({ error: 'Server authorization required' }, { status: 403 });
  }
  try {
    const jobs = await rpc('claim_check_in_jobs', { p_limit: 20 });
    let completed = 0;
    let failed = 0;
    for (const job of jobs) {
      try { if (await process(job)) completed += 1; else failed += 1; }
      catch { failed += 1; }
    }
    // Failed leases expire for later retries. No secrets or private response content enters logs.
    return Response.json({ claimed: jobs.length, completed, failed });
  } catch { return Response.json({ error: 'Worker unavailable' }, { status: 503 }); }
});

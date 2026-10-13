/**
 * index.ts
 * Purpose: Reauthenticate the caller, remove their real photo objects, and delete their own Auth account.
 * Notes: Never accepts a target user ID. Partial cleanup is retryable and never reported as complete.
 */
import { serverRpc } from '../_shared/serverRpc.ts';
const baseURL = Deno.env.get('SUPABASE_URL');
const serverKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

async function auth(path: string, token: string, method = 'GET', body?: unknown) {
  return await fetch(`${baseURL}/auth/v1/${path}`, {
    method, signal: AbortSignal.timeout(15000),
    headers: { apikey: serverKey!, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}
async function removePhotos(userID: string) {
  for (let batch = 0; batch < 3; batch++) {
    const paths = await serverRpc(baseURL!, serverKey!, 'account_deletion_photos', { p_user: userID });
    if (paths.length === 0) return true;
    const response = await fetch(`${baseURL}/storage/v1/object/check-in-photos`, {
      method: 'DELETE', signal: AbortSignal.timeout(20000),
      headers: { apikey: serverKey!, Authorization: `Bearer ${serverKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ prefixes: paths }),
    });
    if (!response.ok) throw new Error('Photo removal failed');
  }
  return (await serverRpc(baseURL!, serverKey!, 'account_deletion_photos', { p_user: userID })).length === 0;
}

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response(null, { status: 405 });
  if (!baseURL || !serverKey) return Response.json({ error: 'Service unavailable' }, { status: 503 });
  let reauthenticationToken: string | undefined;
  try {
    const authorization = request.headers.get('Authorization') ?? '';
    if (!authorization.startsWith('Bearer ')) return Response.json({ error: 'Sign in first' }, { status: 401 });
    const userResponse = await auth('user', authorization.slice(7));
    if (!userResponse.ok) return Response.json({ error: 'Sign in first' }, { status: 401 });
    const user = await userResponse.json();
    const text = await request.text();
    if (text.length > 4096) return Response.json({ error: 'Invalid request' }, { status: 400 });
    const input = JSON.parse(text);
    if (!input || typeof input !== 'object' || Array.isArray(input) || Object.keys(input).sort().join(',') !== 'confirmation,password' || input.confirmation !== 'DELETE'
      || typeof input.password !== 'string' || input.password.length < 1 || input.password.length > 1024
      || typeof user.email !== 'string') return Response.json({ error: 'Confirm deletion with your password' }, { status: 400 });
    const verifiedResponse = await auth('token?grant_type=password', serverKey, 'POST', { email: user.email, password: input.password });
    if (!verifiedResponse.ok) return Response.json({ error: 'Password verification failed' }, { status: 403 });
    const verified = await verifiedResponse.json();
    if (verified.user?.id !== user.id) return Response.json({ error: 'Password verification failed' }, { status: 403 });
    reauthenticationToken = verified.access_token;
    await serverRpc(baseURL, serverKey, 'begin_account_deletion', { p_user: user.id });
    if (!await removePhotos(user.id)) return Response.json({ deleted: false, needs_retry: true }, { status: 202 });
    await serverRpc(baseURL, serverKey, 'finish_account_data_deletion', { p_user: user.id });
    const deleted = await auth(`admin/users/${user.id}`, serverKey, 'DELETE', { should_soft_delete: false });
    if (!deleted.ok) return Response.json({ error: 'Deletion started. Retry to finish.' }, { status: 503 });
    return Response.json({ deleted: true });
  } catch (error) {
    console.warn('Account deletion step failed', error instanceof Error ? (error as Error & { code?: string }).code ?? error.name : 'unknown');
    if (error instanceof Error && (error as Error & { code?: string }).code === 'PT409') {
      return Response.json({ error: 'Transfer captain duties before deleting your account' }, { status: 409 });
    }
    return Response.json({ error: 'Deletion could not finish. Retry when connected.' }, { status: 503 });
  } finally {
    if (reauthenticationToken) {
      // The temporary password-verification session is independent of the caller's original session.
      try { await auth('logout?scope=local', reauthenticationToken, 'POST'); }
      catch { console.warn('Temporary deletion-verification session cleanup could not be confirmed'); }
    }
  }
});

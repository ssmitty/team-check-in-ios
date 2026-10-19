/**
 * schedulerAuthorization.test.mjs
 * Purpose: Verify job authentication fails closed without leaking server credentials into cron.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { authorizeWorker } from '../supabase/functions/_shared/workerAuthorization.mjs';

test('missing server configuration cannot authorize a request', async () => {
  const request = new Request('https://worker.example.test', {
    headers: { Authorization: 'Bearer undefined' },
  });
  assert.equal(await authorizeWorker(request, undefined, () => true), false);
});

test('server credential retains the existing worker path', async () => {
  const request = new Request('https://worker.example.test', {
    headers: { Authorization: 'Bearer synthetic-server' },
  });
  assert.equal(await authorizeWorker(request, 'synthetic-server', () => {
    throw new Error('Unexpected scheduler lookup');
  }), true);
});

test('missing and malformed credentials never reach the database', async () => {
  for (const token of ['', 'a'.repeat(63), 'Z'.repeat(64), 'a'.repeat(65)]) {
    const request = new Request('https://worker.example.test', {
      headers: { 'X-Team-CheckIn-Scheduler': token },
    });
    assert.equal(await authorizeWorker(request, 'synthetic-server', () => {
      throw new Error('Unexpected scheduler lookup');
    }), false);
  }
});

test('only an exact positive Vault lookup permits scheduler invocation', async () => {
  const token = 'a'.repeat(64);
  const request = new Request('https://worker.example.test', {
    headers: { 'X-Team-CheckIn-Scheduler': token },
  });
  for (const value of [false, null, {}, 'true', true]) {
    const rpc = async (name, body) => {
      assert.equal(name, 'authorize_scheduled_worker');
      assert.deepEqual(body, { p_token: token });
      return value;
    };
    assert.equal(await authorizeWorker(request, 'synthetic-server', rpc), value === true);
  }
  assert.equal(await authorizeWorker(request, 'synthetic-server', async () => {
    throw new Error('Unavailable');
  }), false);
});

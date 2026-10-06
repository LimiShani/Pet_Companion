import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createFeatureAuthorizer } from '../_shared/access.ts';

const request = (authorization?: string) => new Request('https://example.test/search', {
  headers: authorization ? { Authorization: authorization } : {},
});

test('authorization forwards the supplied caller token and only trusts a true RPC result', async () => {
  let received: RequestInit | undefined;
  const authorize = createFeatureAuthorizer({ url: 'https://backend.test', serviceKey: 'server-only',
    fetcher: async (_url, init) => { received = init; return Response.json(true); } });
  assert.equal(await authorize(request('Bearer caller'), 'findvet.search'), true);
  assert.equal((received?.headers as Record<string,string>).Authorization, 'Bearer caller');
  assert.deepEqual(JSON.parse(received?.body as string), { p_capability: 'findvet.search' });
});

for (const result of [false, 'true', null, {}]) {
  test(`RPC result ${JSON.stringify(result)} fails closed`, async () => {
    const authorize = createFeatureAuthorizer({ url: 'https://backend.test', serviceKey: 'server-only',
      fetcher: async () => Response.json(result) });
    assert.equal(await authorize(request(), 'findvet.search'), false);
  });
}

test('invalid caller JWT never falls back to a public request', async () => {
  let calls = 0;
  const authorize = createFeatureAuthorizer({ url: 'https://backend.test', serviceKey: 'server-only',
    fetcher: async (_url, init) => {
      calls++;
      assert.equal((init?.headers as Record<string,string>).Authorization, 'Bearer invalid');
      return new Response('', {status: 401});
    } });
  assert.equal(await authorize(request('Bearer invalid'), 'findvet.search'), false);
  assert.equal(calls, 1);
});

test('network errors fail closed', async () => {
  const authorize = createFeatureAuthorizer({ url: 'https://backend.test', serviceKey: 'server-only',
    fetcher: async () => { throw new Error('offline'); } });
  assert.equal(await authorize(request(), 'findvet.search'), false);
});

test('public access is still evaluated by the caller-bound server policy', async () => {
  const authorize = createFeatureAuthorizer({ url: 'https://backend.test', serviceKey: 'server-only',
    fetcher: async (_url, init) => {
      assert.equal((init?.headers as Record<string,string>).Authorization, 'Bearer server-only');
      return Response.json(false);
    } });
  assert.equal(await authorize(request(), 'findvet.search'), false);
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createStorageCleanupHandler } from '../_shared/storage_cleanup_handler.ts';

const request = (secret = 'maintenance') => new Request('https://worker.test', {
  method: 'POST', headers: {Authorization: `Bearer ${secret}`},
});

function worker(orphan: unknown, removalStatus = 200, checkStatus = 200) {
  const calls: string[] = [];
  const handler = createStorageCleanupHandler({url: 'https://backend.test', key: 'server-only', secret: 'maintenance',
    fetcher: async (url, init) => {
      const path = String(url);
      calls.push(`${init?.method ?? 'GET'} ${path}`);
      if (path.includes('?select=')) return Response.json([{id: 'job', bucket: 'pet-photos', path: 'owner/photo.jpg'}]);
      if (path.includes('/rpc/')) return Response.json(orphan, {status:checkStatus});
      if (path.includes('/storage/v1/')) return new Response('', {status:removalStatus});
      return new Response('', {status:200});
    }});
  return {handler, calls};
}

test('wrong secret cannot read or delete files', async () => {
  const {handler, calls} = worker(true);
  assert.equal((await handler(request('wrong'))).status, 401);
  assert.equal(calls.length, 0);
});
test('live referenced files are preserved and their maintenance job is acknowledged', async () => {
  const {handler, calls} = worker(false);
  assert.deepEqual(await (await handler(request())).json(), {completed:1});
  assert.equal(calls.some(c => c.includes('/storage/v1/')), false);
  assert.equal(calls.some(c => c.includes('?id=eq.job')), true);
});
test('an orphan is removed before its durable job is acknowledged', async () => {
  const {handler, calls} = worker(true);
  assert.deepEqual(await (await handler(request())).json(), {completed:1});
  assert.equal(calls.length, 4);
  assert.match(calls[2], /DELETE .*storage\/v1/);
  assert.match(calls[3], /DELETE .*id=eq.job/);
});
for (const orphan of [null, 'true']) {
  test(`ambiguous orphan status ${String(orphan)} preserves the job and file`, async () => {
    const {handler, calls} = worker(orphan);
    assert.deepEqual(await (await handler(request())).json(), {completed:0});
    assert.equal(calls.length, 2);
  });
}
test('failed file removal preserves the job for a later run', async () => {
  const {handler, calls} = worker(true, 503);
  assert.deepEqual(await (await handler(request())).json(), {completed:0});
  assert.equal(calls.some(c => c.includes('?id=')), false);
});
test('failed reference check preserves the job and does not remove a file', async () => {
  const {handler, calls} = worker(true, 200, 503);
  assert.deepEqual(await (await handler(request())).json(), {completed:0});
  assert.equal(calls.length, 2);
});

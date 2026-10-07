import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseServiceAccount, type ServiceAccount, signedAssertion } from '../_shared/fcm.ts';
import { type ClaimedPush, createPushHandler, wordsFor } from '../_shared/push_handler.ts';

const NOW = new Date('2026-10-07T09:00:00Z');

async function testAccount(): Promise<{ account: ServiceAccount; publicKey: CryptoKey }> {
  const pair = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
  let text = '';
  for (const byte of der) text += String.fromCharCode(byte);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(text).replace(/(.{64})/g, '$1\n')}\n-----END PRIVATE KEY-----\n`;
  return {
    account: {
      project_id: 'petloop-test',
      client_email: 'push@petloop-test.iam.gserviceaccount.com',
      private_key: pem,
      token_uri: 'https://oauth.test/token',
    },
    publicKey: pair.publicKey,
  };
}

const comment: ClaimedPush = {
  id: 1,
  kind: 'comment',
  target: 'post:p1',
  preview: 'Lovely!',
  actor_name: 'Maya',
  devices: [{ token: 'token-he', platform: 'android', language: 'he' }],
};

const request = (secret = 'job-secret') =>
  new Request('https://push.test', { method: 'POST', headers: { 'x-job-secret': secret } });

function backend(claimed: ClaimedPush[], fcm: (body: Record<string, unknown>) => Response) {
  const calls: { url: string; body?: string; auth?: string }[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const url = String(input);
    calls.push({ url, body: init?.body ? String(init.body) : undefined, auth: (init?.headers as Record<string, string>)?.Authorization });
    if (url.endsWith('/rpc/push_claim')) return Response.json(claimed);
    if (url.endsWith('/rpc/push_finish')) return new Response('', { status: 204 });
    if (url === 'https://oauth.test/token') return Response.json({ access_token: 'fcm-access' });
    if (url.includes('fcm.googleapis.com')) return fcm(JSON.parse(String(init?.body)));
    return new Response('', { status: 500 });
  };
  return { calls, fetcher };
}

test('a wrong or missing secret sends nothing', async () => {
  const { account } = await testAccount();
  const { calls, fetcher } = backend([comment], () => Response.json({}));
  const handler = createPushHandler({ url: 'https://db.test', serviceKey: 'service', jobSecret: 'job-secret', account, fetcher });
  assert.equal((await handler(request('wrong'))).status, 401);
  assert.equal((await handler(new Request('https://push.test', { method: 'POST' }))).status, 401);
  assert.equal(calls.length, 0);
});

test('without a service account the function says so and claims nothing', async () => {
  const { calls, fetcher } = backend([comment], () => Response.json({}));
  const handler = createPushHandler({ url: 'https://db.test', serviceKey: 'service', jobSecret: 'job-secret', account: null, fetcher });
  const response = await handler(request());
  assert.equal(response.status, 503);
  assert.equal(calls.length, 0);
});

test('a comment is sent in the phone\'s language, then marked sent', async () => {
  const { account } = await testAccount();
  const sent: Record<string, unknown>[] = [];
  const { calls, fetcher } = backend([comment], (body) => {
    sent.push(body);
    return Response.json({ name: 'projects/x/messages/1' });
  });
  const handler = createPushHandler({ url: 'https://db.test', serviceKey: 'service', jobSecret: 'job-secret', account, fetcher, now: () => NOW });
  assert.deepEqual(await (await handler(request())).json(), { sent: 1, dead: 0 });

  const message = sent[0].message as Record<string, any>;
  assert.equal(message.token, 'token-he');
  assert.equal(message.notification.title, 'תגובה חדשה מ־⁨Maya⁩ לפוסט שלך');
  assert.equal(message.notification.body, 'Lovely!');
  assert.deepEqual(message.data, { target: 'post:p1', kind: 'comment' });
  assert.equal(message.android.notification.channel_id, 'community');
  assert.equal(message.android.notification.tag, 'post:p1');
  const fcmCall = calls.find((c) => c.url.includes('fcm.googleapis.com'))!;
  assert.equal(fcmCall.auth, 'Bearer fcm-access');
  assert.match(fcmCall.url, /projects\/petloop-test\/messages:send$/);
  const finish = calls.find((c) => c.url.endsWith('/rpc/push_finish'))!;
  assert.deepEqual(JSON.parse(finish.body!), { p_sent: [1], p_dead_tokens: [] });
});

test('a token FCM no longer knows is forgotten and the row closed', async () => {
  const { account } = await testAccount();
  const { calls, fetcher } = backend([comment], () =>
    Response.json({ error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }, { status: 404 })
  );
  const handler = createPushHandler({ url: 'https://db.test', serviceKey: 'service', jobSecret: 'job-secret', account, fetcher, now: () => NOW });
  assert.deepEqual(await (await handler(request())).json(), { sent: 1, dead: 1 });
  const finish = calls.find((c) => c.url.endsWith('/rpc/push_finish'))!;
  assert.deepEqual(JSON.parse(finish.body!), { p_sent: [1], p_dead_tokens: ['token-he'] });
});

test('a failed send leaves the row open for the next run', async () => {
  const { account } = await testAccount();
  const { calls, fetcher } = backend([comment], () => new Response('', { status: 503 }));
  const handler = createPushHandler({ url: 'https://db.test', serviceKey: 'service', jobSecret: 'job-secret', account, fetcher, now: () => NOW });
  assert.deepEqual(await (await handler(request())).json(), { sent: 0, dead: 0 });
  const finish = calls.find((c) => c.url.endsWith('/rpc/push_finish'))!;
  assert.deepEqual(JSON.parse(finish.body!), { p_sent: [], p_dead_tokens: [] });
});

test('nothing waiting: no call to Google', async () => {
  const { account } = await testAccount();
  const { calls, fetcher } = backend([], () => Response.json({}));
  const handler = createPushHandler({ url: 'https://db.test', serviceKey: 'service', jobSecret: 'job-secret', account, fetcher });
  assert.deepEqual(await (await handler(request())).json(), { sent: 0, dead: 0 });
  assert.equal(calls.length, 1);
});

test('words: English, the fallback name, a photo answer', () => {
  assert.deepEqual(wordsFor({ ...comment, kind: 'like', preview: 'My first post' }, 'en'), {
    title: 'Maya liked your post',
    body: 'My first post',
  });
  assert.deepEqual(wordsFor({ ...comment, kind: 'reply', actor_name: '', preview: '' }, 'en'), {
    title: 'Pet lover answered your message',
    body: 'Photo',
  });
  assert.equal(wordsFor({ ...comment, kind: 'reply', preview: '' }, 'he').body, 'תמונה');
});

test('the JWT is signed with the account\'s key and asks for FCM', async () => {
  const { account, publicKey } = await testAccount();
  const jwt = await signedAssertion(account, NOW);
  const [header, claims, signature] = jwt.split('.');
  const decode = (part: string) => Uint8Array.from(atob(part.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    publicKey,
    decode(signature),
    new TextEncoder().encode(`${header}.${claims}`),
  );
  assert.equal(valid, true);
  const body = JSON.parse(new TextDecoder().decode(decode(claims)));
  assert.equal(body.scope, 'https://www.googleapis.com/auth/firebase.messaging');
  assert.equal(body.aud, 'https://oauth.test/token');
  assert.equal(body.exp - body.iat, 3600);
});

test('a service account secret must look like one', () => {
  assert.equal(parseServiceAccount(''), null);
  assert.equal(parseServiceAccount('not json'), null);
  assert.equal(parseServiceAccount('{"project_id":"x"}'), null);
  assert.notEqual(
    parseServiceAccount(JSON.stringify({ project_id: 'x', client_email: 'a@b', private_key: '-----BEGIN PRIVATE KEY-----\nAA\n-----END PRIVATE KEY-----' })),
    null,
  );
});

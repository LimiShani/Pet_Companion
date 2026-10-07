// Firebase Cloud Messaging (HTTP v1) for the community push notifications.
//
// The function holds a Google service account (the JSON key Firebase gives
// under Project settings > Service accounts) in the secret
// FCM_SERVICE_ACCOUNT. It signs a short-lived JWT with the account's key,
// trades it for an OAuth access token, and sends one message per phone.

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

/** The service account in the secret, or `null` when it is missing or not one. */
export function parseServiceAccount(raw: string): ServiceAccount | null {
  if (!raw) return null;
  try {
    const value = JSON.parse(raw) as Partial<ServiceAccount>;
    if (
      typeof value.project_id !== 'string' || !value.project_id ||
      typeof value.client_email !== 'string' || !value.client_email ||
      typeof value.private_key !== 'string' || !value.private_key.includes('PRIVATE KEY')
    ) {
      return null;
    }
    return value as ServiceAccount;
  } catch (_) {
    return null;
  }
}

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const DEFAULT_TOKEN_URI = 'https://oauth2.googleapis.com/token';

function base64url(bytes: Uint8Array): string {
  let text = '';
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const utf8 = (text: string) => new TextEncoder().encode(text);

async function importKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/** A signed JWT asking Google for an FCM access token. */
export async function signedAssertion(account: ServiceAccount, now: Date): Promise<string> {
  const issued = Math.floor(now.getTime() / 1000);
  const header = base64url(utf8(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64url(utf8(JSON.stringify({
    iss: account.client_email,
    scope: SCOPE,
    aud: account.token_uri ?? DEFAULT_TOKEN_URI,
    iat: issued,
    exp: issued + 3600,
  })));
  const key = await importKey(account.private_key);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, utf8(`${header}.${claims}`));
  return `${header}.${claims}.${base64url(new Uint8Array(signature))}`;
}

/** An OAuth access token for FCM, or `null` when Google refuses. */
export async function accessToken(
  account: ServiceAccount,
  fetcher: typeof fetch,
  now: Date,
): Promise<string | null> {
  const assertion = await signedAssertion(account, now);
  const response = await fetcher(account.token_uri ?? DEFAULT_TOKEN_URI, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }).toString(),
  });
  if (!response.ok) return null;
  const value = await response.json() as { access_token?: unknown };
  return typeof value.access_token === 'string' ? value.access_token : null;
}

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  /** Where a tap leads: 'post:<id>' or 'room:<id>'. */
  target: string;
  kind: string;
}

/** What FCM said about one message. */
export type SendOutcome = 'sent' | 'dead_token' | 'failed';

/** Sends one message. A token FCM no longer knows comes back as `dead_token`. */
export async function sendMessage(
  account: ServiceAccount,
  token: string,
  message: PushMessage,
  fetcher: typeof fetch,
): Promise<SendOutcome> {
  const response = await fetcher(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: message.token,
          notification: { title: message.title, body: message.body },
          data: { target: message.target, kind: message.kind },
          android: {
            priority: 'HIGH',
            // One notification per post or room: a newer one replaces it.
            notification: { channel_id: 'community', tag: message.target },
          },
          apns: { payload: { aps: { 'thread-id': message.target } } },
        },
      }),
    },
  );
  if (response.ok) return 'sent';
  if (response.status === 404) return 'dead_token';
  if (response.status === 400) {
    try {
      const detail = JSON.stringify(await response.json());
      if (detail.includes('UNREGISTERED') || detail.includes('registration token')) return 'dead_token';
    } catch (_) { /* Not JSON: a plain failure. */ }
  }
  return 'failed';
}

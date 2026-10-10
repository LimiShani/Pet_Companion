// Edge Function `community-push`: sends what the database queued in
// `push_outbox` (comments on a member's posts, likes, answers to their
// chat messages, messages in their private chats, invitations to a chat,
// new partner ads at a saved park and the end of a member's own ad)
// to their phones through FCM, in each phone's language.
//
// Called by the database (a trigger pokes it through pg_net) and by a
// schedule, both with the header `x-job-secret`. Rows are claimed with
// `push_claim()` and closed with `push_finish()`; a row whose phones all
// failed stays open and is tried again (five attempts at most).
// Never logs tokens, names or texts.

import { accessToken, type SendOutcome, sendMessage, type ServiceAccount } from './fcm.ts';

export interface PushHandlerOptions {
  url: string;
  serviceKey: string;
  jobSecret: string;
  account: ServiceAccount | null;
  fetcher?: typeof fetch;
  now?: () => Date;
}

export interface ClaimedDevice { token: string; platform: string; language: string }
export interface ClaimedPush {
  id: number;
  kind: 'comment' | 'like' | 'reply' | 'message' | 'invite' | 'meetup' | 'meetup_renew';
  target: string;
  preview: string;
  actor_name: string;
  devices: ClaimedDevice[];
  /** How many unread messages a 'message' stands for (0026). */
  count?: number;
  /** The private chat's name; empty for a chat of two (0026). */
  chat_name?: string;
  /** A private chat of two (0026). */
  direct?: boolean;
  /** A partner ad's kind, 'walk' or 'play' (0028). */
  meetup_kind?: string | null;
  /** The ad's park: names and nearest street in each language (0028). */
  park_name_he?: string | null;
  park_name_en?: string | null;
  park_street_he?: string | null;
  park_street_en?: string | null;
  /** The ad's place when it is not at a park (0028). */
  place?: string | null;
}

const WORDS = {
  en: {
    fallbackName: 'Pet lover',
    photo: 'Photo',
    privateChat: 'Private chat',
    comment: (name: string) => `${name} commented on your post`,
    like: (name: string) => `${name} liked your post`,
    reply: (name: string) => `${name} answered your message`,
    newMessages: (count: number) => `${count} new messages`,
    fromIn: (name: string, text: string) => `${name}: ${text}`,
    inviteDirect: (name: string) => `${name} wants to chat with you`,
    inviteGroup: (name: string, chat: string) => `${name} invited you to ${chat}`,
    inviteBody: 'Open PetLoop to join or say no thanks',
    dogPark: 'Dog park',
    parkOnStreet: (street: string) => `Dog park · ${street}`,
    newWalk: (place: string) => `A new walk at ${place}`,
    newPlay: (place: string) => `A new playdate at ${place}`,
    postedBy: (name: string) => `Posted by ${name}`,
    renewTitle: 'Your partner ad has ended',
    renewBody: 'Renew it in PetLoop to show it for 30 more days',
  },
  he: {
    fallbackName: 'אוהבי חיות',
    photo: 'תמונה',
    privateChat: 'שיחה פרטית',
    // A name in Latin letters is kept as one unit inside the Hebrew line.
    comment: (name: string) => `תגובה חדשה מ־⁨${name}⁩ לפוסט שלך`,
    like: (name: string) => `לייק מ־⁨${name}⁩ לפוסט שלך`,
    reply: (name: string) => `תשובה מ־⁨${name}⁩ להודעה שלך`,
    newMessages: (count: number) => `${count} הודעות חדשות`,
    fromIn: (name: string, text: string) => `⁨${name}⁩: ⁨${text}⁩`,
    inviteDirect: (name: string) => `⁨${name}⁩ רוצה לדבר איתך`,
    inviteGroup: (name: string, chat: string) => `הזמנה מ־⁨${name}⁩ לשיחה ״⁨${chat}⁩״`,
    inviteBody: 'אפשר להצטרף או לוותר באפליקציה',
    dogPark: 'גינת כלבים',
    parkOnStreet: (street: string) => `גינת כלבים · ⁨${street}⁩`,
    newWalk: (place: string) => `טיול חדש ב־⁨${place}⁩`,
    newPlay: (place: string) => `מפגש משחק חדש ב־⁨${place}⁩`,
    postedBy: (name: string) => `פורסם על ידי ⁨${name}⁩`,
    renewTitle: 'מודעת השותפים שלך הסתיימה',
    renewBody: 'אפשר לחדש אותה באפליקציה לעוד 30 יום',
  },
};

/** The notification's title and text in [language] (Hebrew unless English). */
export function wordsFor(item: ClaimedPush, language: string): { title: string; body: string } {
  const words = language === 'en' ? WORDS.en : WORDS.he;
  const name = item.actor_name.trim() || words.fallbackName;
  const preview = item.preview.trim();
  if (item.kind === 'message') {
    // One notification a chat: several unread messages are counted, one is
    // shown. A chat of two is titled with the other person.
    const count = item.count ?? 1;
    const text = preview || words.photo;
    if (item.direct) {
      return { title: name, body: count > 1 ? words.newMessages(count) : text };
    }
    const chat = (item.chat_name ?? '').trim() || words.privateChat;
    return { title: chat, body: count > 1 ? words.newMessages(count) : words.fromIn(name, text) };
  }
  if (item.kind === 'meetup') {
    // "A new walk at Dog park · Ahuza": the park in the phone's language
    // (else the other one, else its street), then who posted and their note.
    const he = language !== 'en';
    const own = (he ? item.park_name_he : item.park_name_en)?.trim();
    const other = (he ? item.park_name_en : item.park_name_he)?.trim();
    const street = ((he ? item.park_street_he : item.park_street_en) ?? (he ? item.park_street_en : item.park_street_he))?.trim();
    const park = own || other || (street ? words.parkOnStreet(street) : words.dogPark);
    return {
      title: item.meetup_kind === 'play' ? words.newPlay(park) : words.newWalk(park),
      body: preview ? words.fromIn(name, preview) : words.postedBy(name),
    };
  }
  if (item.kind === 'meetup_renew') {
    return { title: words.renewTitle, body: words.renewBody };
  }
  if (item.kind === 'invite') {
    const chat = (item.chat_name ?? '').trim();
    return {
      title: item.direct || !chat ? words.inviteDirect(name) : words.inviteGroup(name, chat),
      body: words.inviteBody,
    };
  }
  const title = words[item.kind](name);
  const body = preview || (item.kind === 'reply' ? words.photo : '');
  return { title, body };
}

const digest = async (value: string) =>
  new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)));

async function sameSecret(expected: string, provided: string): Promise<boolean> {
  if (!expected || !provided) return false;
  const [a, b] = await Promise.all([digest(expected), digest(provided)]);
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) mismatch |= a[i] ^ b[i];
  return mismatch === 0;
}

export function createPushHandler(options: PushHandlerOptions) {
  const fetcher = options.fetcher ?? fetch;
  const now = options.now ?? (() => new Date());
  const headers = {
    apikey: options.serviceKey,
    Authorization: `Bearer ${options.serviceKey}`,
    'Content-Type': 'application/json',
  };
  const rpc = (name: string, body: unknown) =>
    fetcher(`${options.url}/rest/v1/rpc/${name}`, { method: 'POST', headers, body: JSON.stringify(body) });

  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return new Response('', { status: 405 });
    if (!(await sameSecret(options.jobSecret, request.headers.get('x-job-secret') ?? ''))) {
      return new Response('', { status: 401 });
    }
    const account = options.account;
    if (!account) return Response.json({ error: 'not_configured' }, { status: 503 });

    let claimed: ClaimedPush[];
    try {
      const response = await rpc('push_claim', { p_limit: 100 });
      if (!response.ok) return new Response('', { status: 503 });
      const value: unknown = await response.json();
      if (!Array.isArray(value)) return new Response('', { status: 503 });
      claimed = value as ClaimedPush[];
    } catch (_) {
      return new Response('', { status: 503 });
    }
    if (claimed.length === 0) return Response.json({ sent: 0, dead: 0 });

    let token: string | null;
    try {
      token = await accessToken(account, fetcher, now());
    } catch (_) {
      token = null;
    }
    // The rows were claimed: they open again for the next run.
    if (!token) return Response.json({ error: 'fcm_auth' }, { status: 503 });

    const done: number[] = [];
    const dead = new Set<string>();
    for (const item of claimed) {
      const outcomes: SendOutcome[] = [];
      for (const device of item.devices ?? []) {
        const { title, body } = wordsFor(item, device.language);
        try {
          const outcome = await sendMessage(account, token, {
            token: device.token,
            title,
            body,
            target: item.target,
            kind: item.kind,
          }, fetcher);
          outcomes.push(outcome);
          if (outcome === 'dead_token') dead.add(device.token);
        } catch (_) {
          outcomes.push('failed');
        }
      }
      // Done when no phone is left to try: sent, or every token is dead.
      if (!outcomes.includes('failed')) done.push(item.id);
    }

    try {
      await rpc('push_finish', { p_sent: done, p_dead_tokens: [...dead] });
    } catch (_) {
      // The rows reopen after their claim lapses; a resend is harmless
      // (the phone shows one notification per post or room).
    }
    return Response.json({ sent: done.length, dead: dead.size });
  };
}

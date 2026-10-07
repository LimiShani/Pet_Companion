# Push notifications (community)

PetLoop tells a member's phones when someone comments on their post, likes
it (if they switched that on), or answers their chat message. Firebase
Cloud Messaging (FCM, free) carries the notifications; a Supabase Edge
Function sends them.

```
comment / like / chat answer
  └─ trigger (0023) ─ checks: not one's own, not blocked, switched on,
     │                has access, has a phone; likes once an hour per post
     ├─ push_outbox row
     └─ pg_net poke ──> Edge Function community-push ──> FCM ──> phone
                         (also every 5 minutes, for retries)
```

## Setup (owner, once)

Nothing here costs money: Firebase's Spark plan includes FCM, pg_net and
pg_cron are on the Supabase free plan.

1. **Firebase project.** In the [Firebase console](https://console.firebase.google.com)
   choose *Add project* and pick the existing Google Cloud project
   `petloop-510512` (the one Find a vet uses). Analytics is not needed.
2. **Android app.** Project settings → *Your apps* → Android. Package name
   `com.limi.pet_companion`. Download `google-services.json` and keep it
   outside the repository (for example in
   `C:/Work/Flutter_projects/petloop_secrets/`). Copy four values from it
   into `env.json` (not committed):

   | env.json key | google-services.json |
   |---|---|
   | `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
   | `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |
   | `FIREBASE_SENDER_ID` | `project_info.project_number` |

   These are client identifiers, not secrets; the app is not built with the
   Google Services Gradle plugin, so the file itself is not needed in the
   build.
3. **Service account for sending.** Project settings → *Service accounts* →
   *Generate new private key*. Keep the JSON file private (never in the
   repository or in chat).
4. **Function secrets** (Supabase dashboard → Edge Functions → Secrets):
   - `FCM_SERVICE_ACCOUNT`: the whole content of that JSON file;
   - `PUSH_JOB_SECRET`: a long random string you make up.
5. **Database.** Run `supabase/migrations/0023_community_push.sql` in the
   SQL editor (backup first).
6. **Deploy the function:**
   ```bash
   npx supabase@2.119.0 functions deploy community-push --project-ref rogmiiusncgmxjqpwgsn --use-api
   ```
7. **Connect the database to the function.** Open
   `supabase/scheduling/community_push.sql`, replace `<project-ref>` and
   `<same as PUSH_JOB_SECRET>` on their two lines only, and run it in the SQL
   editor. Do not save the filled-in copy anywhere.
8. **Build the app** with the new `env.json`:
   ```bash
   flutter build apk --debug --dart-define-from-file=env.json
   ```

Without the Firebase values in `env.json` the app simply runs without push;
without the function secrets the outbox fills and waits.

## Checking it works

- Settings → Notifications shows a **Community** card with three switches.
- From a second account, comment on a post of the first one: within a few
  seconds the first phone shows "{name} commented on your post". Tapping it
  opens the post.
- In the SQL editor:
  ```sql
  select kind, created_at, sent_at, attempts from public.push_outbox order by id desc limit 20;
  ```
  `sent_at` filled means FCM accepted it. Rows with `attempts` 5 and no
  `sent_at` failed five times: check the function's logs in the dashboard
  (they never contain tokens, names or texts).

## How it behaves

- **Who gets what.** Comments on one's posts and answers to one's chat
  messages are on by default; likes are off and, when on, come at most once
  an hour per post. Nothing comes from a member one blocked, or about one's
  own doings.
- **Language.** Each phone registers with the app's language; texts are
  written in it (English or Hebrew).
- **One per post or room.** A newer notification about the same post or
  room replaces the older one on the phone.
- **While the app is open** the phone shows nothing; the Activity bell and
  the room list refresh instead.
- **Signing out** removes the phone from the account first. A session that
  ended elsewhere forgets the phone's token; the server's next send to it
  fails and the server removes it.
- **Privacy.** The notification text (who, and up to 140 characters of the
  comment or message) passes through Google's FCM. The legal document lists
  it.
- **iPhone.** Not yet: it needs an Apple developer account and an APNs key
  uploaded to Firebase. The app starts push on Android only.

## Code

| Part | Where |
|---|---|
| Tables, triggers, claim/finish | `supabase/migrations/0023_community_push.sql` |
| Vault secrets and the 5-minute schedule | `supabase/scheduling/community_push.sql` |
| Edge Function | `supabase/functions/community-push/`, `_shared/push_handler.ts`, `_shared/fcm.ts` |
| Phone side | `lib/notifications/push.dart` (`FirebasePushMessaging`, `PushRegistrar`), `notifications_host.dart` (taps, arrivals) |
| Sign-out hook | `beforeSignOutProvider` in `lib/auth/auth_controller.dart` |
| Settings card, preferences | `lib/features/community/members/community_push_card.dart`, `lib/services/community/data/push_preferences_repository.dart` |
| Opening a post or room | community module actions `post` and `room` |
| Tests | `supabase/tests/community_push_test.sql`, `supabase/functions/_tests/push.test.ts`, `test/notifications/push_test.dart` |

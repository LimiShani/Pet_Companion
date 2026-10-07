# Community: feed, chat, members, safety and moderation

What the Community tab does beyond the feed and the guides, where it lives in
the code, and what the owner has to do on the server.

## Server steps (owner)

1. Take a backup, then run in the Supabase SQL editor, in order:
   - `supabase/migrations/0021_community_chat_safety.sql`
   - `supabase/migrations/0022_community_feed_profiles.sql`
2. Moderators: permission administrators receive `community.moderate` from
   0021. Anyone else: Feature access → Users → the person → *Community feed ·
   Moderate reports* → Allow.
3. Nothing else: no Edge Function, no secret, no paid service. Realtime picks
   up `chat_message_reactions` from the publication change in 0021.

Before 0021 is run the app still works: rooms load, text messages send,
reactions and the room list's unread counts are simply missing. Before 0022
the feed loads and posts are written (as moments for everyone); filtering by
kind or animal, edits, helpful answers, profiles and activity need it.

## Feed

| What | Where |
|---|---|
| Animal / kind / search header, endless list | `lib/features/community/feed/feed_section.dart` |
| Query, paging (30 a page), edit, helpful answer, posts opened from outside the feed | `FeedController`, `feedFilterProvider`, `feedQueryProvider`, `outsidePostsProvider` in `feed/feed_controller.dart` |
| Card: tags, Edited, menu (edit, delete, share, report, block), double tap on the photo | `feed/post_card.dart`, `feed/post_actions.dart` (`communityShareProvider`) |
| Composer: kinds, hints, edit mode, the pet's animal | `feed/post_composer_screen.dart` |
| Helpful answer on the post page | `feed/post_detail_screen.dart` |
| Backend | `FeedRepository` (`fetchPosts(query, before)`, `fetchPost`, `updatePost`, `setHelpful`) |

- A post's animal comes from the tagged pet (`audienceOfSpecies`); posts
  without a pet are for everyone and show under every chip.
- Paging uses `created_at` of the last post shown (`before`).
- Double tap likes only on a photo: on the whole card it would make every
  button wait for a possible second tap.

## Members and activity

| What | Where |
|---|---|
| Member page, own profile form | `members/member_screen.dart` (route `/community/member/:id`) |
| Activity page, the bell's dot | `members/activity_screen.dart` (route `/community/activity`), `activityProvider`, `activitySeenProvider`, `hasNewActivityProvider` |
| Muted rooms | `mutedRoomsProvider` (kept on the phone under `community.muted.<user id>`) |
| Backend | `lib/services/community/data/members_repository.dart` (+ fake that reads the fake feed and chat, + Supabase on `community_members`, `profiles`, `community_activity`) |

Member, post and room pages opened from Activity or a profile are pushed,
so Back returns to where the member was.

## Chat

| What | Where |
|---|---|
| Room list: latest message, time, unread badge, liveliest first | `lib/features/community/chat/chat_section.dart`, `chatRoomSummariesProvider` |
| A room: runs of messages, replies, photos, reactions, long-press menu, jump to latest | `chat/chat_screen.dart`, `chat/chat_message_tile.dart` |
| Optimistic sending, retry, older history, read markers, delete, report | `ChatRoomController` and `chatConversationProvider` in `chat/chat_providers.dart` |
| Backend | `lib/services/community/data/chat_repository.dart` (+ fake, + Supabase) |

- The live list is the newest 200 messages (`chatLiveWindow`); scrolling up
  loads 50 at a time with `fetchOlder`.
- A message is shown from `ChatRoomState.pending` at once, then from
  `ChatRoomState.sent` until the live stream brings it; a failure marks it
  ("Not sent. Tap to try again.") and is also said in a snack bar.
- Reading: `mark_chat_read()` stamps `chat_reads` with the server clock each
  time the newest message changes while the room is open.
- The advice note can be hidden per room (kept in `SettingsStore` under
  `community.notice.<room>`), except in `health`; the ⓘ sheet always shows it.
- `CommunityKeeper` keeps the tab's lists (and an open room's conversation)
  active while another route covers them. Without it Riverpod 3 pauses the
  covered subscriptions and flushes them in the middle of a build when the
  route comes back ("setState() called during build").

## Safety

| What | Where |
|---|---|
| Rules shown before a first post, comment or message | `ensureCommunityRules` in `safety/safety_flows.dart`; kept per account and phone under `community.rules.<user id>` |
| Block / unblock | `blockMemberFlow`, `BlockedMembersController`, `blockedIdsProvider` |
| Report a comment or message | `askReportReason`; `CommentsController.report`, `ChatRoomController.report` |
| Community safety page | `safety/community_safety_screen.dart` (route `/community/safety`) |
| Moderators' review | `safety/moderation_screen.dart` (route `/community/safety/review`), `ModerationQueueController` |
| Backend | `lib/services/community/data/safety_repository.dart` (+ fake with two queued items, + Supabase) |

Server rules (0021):

- Restrictive `community_safety_read` policies on posts, comments and chat
  messages hide blocked members' content, what the reader reported, and
  content hidden by reports (except from its author and moderators). The
  feed view, the room summaries and Realtime all follow them.
- Three reports since the last decision set `hidden_at`. *Keep* clears it
  and sets `moderated_at` (a fresh count); *Remove* deletes the row (its
  photo is queued for the storage clean-up). Decisions go to
  `community_private.moderation_log`.
- Rate limits: 6 posts per 10 minutes, 20 comments per 5 minutes, 15
  messages per minute (`rate_limited` → "That was quick!").
- Menus offer only what the account may do: reporting a message needs
  `community.chat.send`, reporting a comment `community.feed.post`.

## Push notifications

Comments, likes and chat answers can reach a member's phone: see
[push_notifications.md](push_notifications.md) (migration 0023, the
`community-push` Edge Function, Firebase setup). The Settings card and the
`post` / `room` actions that open a tapped notification live in this
feature.

## Tests

- `test/community/community_feed_members_test.dart`: kinds, search, the
  animal chips, paging, composing a question, editing, the helpful answer,
  sharing, double tap, member pages, own profile, chat names, activity,
  muting, Hebrew at 320 px.
- `test/community/community_chat_safety_test.dart`: room list, runs,
  replies, reactions, copy and delete, failed sends, photos, paging, the jump
  button, the advice note, rules, reports, blocking, the safety page,
  moderation, Hebrew at 320 px.
- `supabase/tests/community_chat_safety_test.sql` and
  `supabase/tests/community_feed_profiles_test.sql`, run by
  `tool/test_database.ps1`.

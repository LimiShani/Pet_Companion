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

Private chats (after 0023, 0024 and 0025 are in):

4. Backup, then run `supabase/migrations/0026_private_chats.sql` in the SQL
   editor. It adds the capability `community.chat.private` to the Standard
   owners group, so every account has private chats at once; to switch
   them off for one account: Feature access → Users → the person →
   *Community chat · Private chats* → Deny.
5. Deploy the push function again (it words the new kinds):
   ```bash
   npx supabase@2.119.0 functions deploy community-push --project-ref rogmiiusncgmxjqpwgsn --use-api
   ```
   Nothing to change in its secrets or schedule.

Before 0026 the app still works: the server does not grant
`community.chat.private` yet, so nothing of private chats shows (no My
chats, no New chat, no Private message, no new push switches); the topic
rooms, their pushes and the push card are as before.

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

## Private chats

Chats between a member and people they invite, like a group in WhatsApp; a
chat with one other person and no name is a chat of two.

| What | Where |
|---|---|
| Invitations and "My chats" above the topic rooms, the "New chat" button | `chat/chat_section.dart` (`_PrivateChats`), `community_screen.dart` (the button) |
| Lists, actions, the way in for other features | `chat/private_chat_providers.dart`: `privateChatsProvider`, `chatInvitationsProvider`, `chatPeopleProvider`, `PrivateChatController`, `openDirectChat`, `openGroupChat` |
| Choosing people, naming a group, adding people | `chat/new_chat_screen.dart` (`openNewChat`, `openAddParticipants`) |
| A conversation: the people line, system lines, the invitation before joining, the closed bar | `chat/chat_screen.dart`, `chat/private_chat_widgets.dart` (`ChatInvitationCard`, `ChatSystemLineTile`, `PrivateChatAvatar`) |
| Chat details: rename, members, admins, remove, mute, leave | `chat/chat_details_screen.dart` (route `/community/chat/:id/details`) |
| Private message on a member page | `members/member_screen.dart` |
| Invitations on the Activity page and the bell's dot | `members/activity_screen.dart`, `hasNewActivityProvider` |
| Words of system lines and chat names | `CommunityWords.systemLine`, `privateChatName` in `community_words.dart` |
| Backend | `ChatRepository` (`fetchPrivateChats`, `fetchInvitations`, `fetchPeople`, `createPrivateChat`, `inviteToPrivateChat`, `answerInvitation`, `leavePrivateChat`, `removeFromPrivateChat`, `makePrivateChatAdmin`, `renamePrivateChat`, `setPrivateChatMuted`); the fake keeps the same rules and seeds a chat with Maya, a group walk and Dana's invitation for the demo account |

Rules (enforced by 0026; the fake follows them):

- **Joining.** An invitee accepts first; until then they see only the
  invitation card (name, inviter, how many people) and members see them as
  *Invited*. *No thanks* drops the invitation.
- **Admins.** The creator is the first admin. Only admins invite, rename,
  remove (or take back an invitation) and make another joined member
  admin. Anyone can leave. The last admin leaving makes the
  earliest-joined member admin; the last member leaving deletes the chat
  with its messages.
- **History.** A member reads the chat from the moment they were brought in
  (invited), once they joined: so the first message of a chat of two,
  written before the other person accepted, reaches them. Whoever leaves
  or is removed loses the whole chat.
- **Size and limits.** Up to 30 people (invited and joined); 10 new chats
  and 30 invitations per account per day ("That was quick!"); messages keep
  the 15 a minute of the rooms. System lines do not count.
- **Chats of two.** Starting a chat with someone one already has a chat of
  two with reopens it (`direct_key`; whoever left is brought back, the
  other person is invited again). It has no name, no more people, no
  system lines.
- **Blocking.** Nobody invites, or finds in *New chat*, someone they
  blocked or who blocked them. In a group a blocked member's messages are
  hidden (the rule of the rooms). A chat of two with a block between the
  two is closed: no new messages from either side; the blocker no longer
  sees it in My chats until they unblock.
- **Reports.** Reporting a message sends that message only to the
  moderators' queue (it reads "In a private chat"); moderators cannot read
  private chats.
- **Photos.** A private chat's photos are stored in the community-photos
  bucket under `<author>/private/<chat id>/<file>`
  (`CommunityPhotos.pathFor`). Storage rules let only the members who may
  read the message carrying a photo read the file (joined, from their
  invitation on; whoever left or was removed cannot), plus its author and,
  for a reported message, the moderators; only joined members of an open
  chat upload there. A private message must use its chat's folder and a
  room message must not. Room photos are unchanged. The app reads them
  through the usual short-lived signed links, which storage refuses to
  anyone else. Because the author's folder comes first, the clean-up of
  0015/0021 removes them as before: a deleted message, a chat deleted with
  its last member, a deleted account.
- **Mute.** The details switch mutes the chat on the server (no pushes) and
  on this phone (no unread count). Topic rooms keep the phone-only mute.
- **Capability.** `community.chat.private` ("Private chats", needs
  `community.chat.view`); without it nothing of private chats shows and the
  server refuses every call.

System lines are `chat_messages` rows with `system` set
(`{"event": "added", "users": [...]}`; events created, added, joined, left,
removed, admin, renamed), written only by the server functions; the app
words them in its language (`systemLine`). They follow the same read rule
as messages, are never unread, and cannot be answered, reacted to or
deleted from the app.

### Opening a chat from another feature

```dart
import '../community/chat/private_chat_providers.dart';

// The chat of two with the ad's author, the message field pre-filled.
await openDirectChat(context, ref, userId: ad.authorId, draft: 'Hi, I saw your ad...');

// One group for everyone who answered.
await openGroupChat(context, ref, userIds: answered, name: 'Saturday walk');
```

Both find or create the chat through `PrivateChatController.start`, push
`/community/chat/<id>` (with a `ChatDraft` as the route's `extra`), say a
failure in a snack bar and return the chat's id (`null` on failure). The
other people see the chat once they accept their invitation.

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

## Outside: dog parks

The fourth section, Outside (Feed · Chat · Outside · Guides), comes from
the `outdoors` module through the `community-outside` slot: a Partners |
Parks switch, dog parks from OpenStreetMap with members' suggestions and
a review queue, and the seams the meetups feature (Partners) plugs into.
Design, owner steps (migration 0027, the `parks-import` Edge Function, its
secret and schedule, the first import, appointing reviewers) and tests:
[dog_parks.md](dog_parks.md).

## Push notifications

Comments, likes, chat answers, private messages and chat invitations can
reach a member's phone: see
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
- `test/community/private_chats_test.dart`: My chats, invitations (chat
  section and Activity), joining and declining, a group's system lines and
  details, an admin's new group (rename, add, make admin, remove), chats of
  two (New chat, Private message, a draft from another feature, blocks),
  the push switches, the capability switched off, Hebrew at 320 px.
- `test/community/private_chats_repository_test.dart`: the fake's rules.
- `supabase/tests/community_chat_safety_test.sql`,
  `supabase/tests/community_feed_profiles_test.sql` and
  `supabase/tests/private_chats_test.sql`, run by
  `tool/test_database.ps1`.

# Walk and play partners (Community > Outside > Partners)

A small board of ads: "looking for a morning walk partner in Ra'anana",
"a puppy playdate on Saturday at the City Garden dog park". Members answer
an ad in a private chat with its author; an ad can be at one of the dog
parks. The approved proposal is section 3 of
`tools/agent_board/state/proposals/community/proposal.md` in the main
checkout (with the parks integration of section 2).

This file is the design record and the contract between the app
(`lib/features/meetups/`, `lib/services/meetups/`), the database
(`supabase/migrations/0028_meetups.sql`) and the push function
(`supabase/functions/community-push`).

## Owner steps (server)

Nothing here costs money.

1. **Database.** Take a backup, then run
   `supabase/migrations/0028_meetups.sql` in the SQL editor (after 0026
   and 0027; it refuses to run before them). It is additive and safe to
   run twice. It creates the tables, the view, the functions, the push
   kinds and the two capabilities, and gives `community.meetups.view` and
   `community.meetups.post` to the Standard owners group, so every account
   has partners at once. To switch them off for one account: Feature
   access → Users → the person → *Walk and play partners · View* (or
   *· Post*) → Deny.
2. **Push function.** Deploy it again (it words the two new kinds):
   ```bash
   npx supabase@2.119.0 functions deploy community-push --project-ref rogmiiusncgmxjqpwgsn --use-api
   ```
   Nothing to change in its secrets or schedule. The clean-up and the
   renewal reminder run inside `push_claim()`, i.e. on every run of the
   existing five-minute schedule (`supabase/scheduling/community_push.sql`):
   no new schedule.

Before 0028 is run the app still works: the server does not grant
`community.meetups.view`, so Outside opens on Parks and Partners shows the
"coming soon" card, as before.

## The app

- **Where:** Community > Outside, the **Partners | Parks** switch; Partners
  now shows first (it falls back to Parks when the account may not see
  partners, and an account with partners but no parks sees the board
  alone).
- **The area.** The city of the member's community profile by default
  (the free-text city is matched to the bundled localities: "Tel Aviv" is
  Tel Aviv-Yafo). Without one the board asks once: **Near me** (the phone
  is asked for one fix only on the tap, after saying why, and only to pick
  the nearest city; the position is forgotten at once) or a city from the
  list. The choice is kept on the phone (`meetups.area.<user id>` =
  `raanana|km10`), never the position. Radius **City only / Up to 10 km /
  Up to 25 km** (10 km by default). The server is sent only the locality
  codes in range (`MeetupsArea.codes`: the cities whose centres are within
  the radius of the chosen city's centre).
- **The board:** the fixed line "Meet in a public place and don't share a
  home address", **New ad**, **My ads (n)**, the filters, then the open ads,
  the soonest first, then the nearest:
  - kind: All / Walk / Play;
  - animal: Dogs / Cats / Everything, the Community's shared chips
    (`communityScopeProvider`, starting on the selected pet's kind); an ad
    without a pet shows under every chip, as posts do;
  - when: Today / This week (the next seven days) / Regular;
  - **At my parks** (one of the saved parks).
  - Empty: "No ads around here yet", or "No ads match these filters" with
    **Clear filters**, and **Look up to 25 km**. Demo data says "Sample
    ads".
- **The card:** the pet (avatar from its icon, or the real photo on one's
  own ad; name; "Dog · Mixed · about 3 years · medium-sized"), Walk/Play,
  the place (a park with its city and its tags; a tap opens the park page,
  `openFeature(context, 'park', '', {'parkId': id})`), when ("Today
  18:00–19:00", "Sun–Thu · Morning"), about how far (between the city
  centre and the park or the ad's city centre), the sizes it suits, the
  note, the author, how long ago and how many answered. The menu reports
  the ad or blocks its author. One's own ad says "Your ad" and offers
  **Manage**.
- **I want to join:** "Message to <author>" with **who is coming** (one of
  my pets, the selected one first when it is the ad's kind of animal, or
  **Just me**) and an editable first message ("Hi Noa, I saw your walk ad
  (Yarkon Park, by the Seven Mills). I'd love to join with Kelly."), then
  `openDirectChat(context, ref, userId: author, draft: ...)`: the chat of
  two opens with the message in its field. Once the chat is open the
  answer is recorded (`meetup_answer`): the count, and the author's group.
  The card then says "You answered" and **Open the chat**. The author is
  told by the private-chat message push when the message is sent; nothing
  else is sent for an answer.
- **New ad / edit / post again** (`MeetupFormScreen`, full screen): a pet or
  **No pet**; Walk / Play; **A park** (`openFeature<PickedPark>(context,
  'pick-park', '')`: My parks first, then nearest) or **Other place** (the
  board's city by default, a city search, and "Where exactly?", a public
  place of up to 80 characters, "No home addresses"); **Once** (date, from,
  to; up to 12 hours, up to 60 days ahead) or **Every week** (the days in
  the order of the member's week setting, and Morning / Noon / Evening);
  **Suits…** (any size, or small / medium / large); a note of up to 200
  characters. Opened from a park page the park is chosen. The community
  rules are shown first if the member has not agreed yet. The server's
  refusals are said in words (three a day, five open, the park or the time
  no longer fits).
- **My ads:** Open (edit, "Found someone, close it", renew when fewer than
  seven days are left), Ended (a regular ad: **Renew for 30 days**; a
  one-off: **Post again**, the form filled in), Closed (a regular ad can be
  renewed). **Group for everyone who answered (n)** (from two answers):
  `openGroupChat` with the responders still reachable, named "Walk ·
  <place>". "Up to 3 new ads a day and 5 open at once."
- **An ad's own page** (`MeetupScreen`): from a push (`meetup:<id>`, the
  `meetup` action), a park page or a member page; its author gets the
  tools of My ads there.
- **Park page** (outdoors slots): **Post a meetup here** beside Navigate,
  and **Meetups at this park** (the open ads; a row opens the ad). For a
  saved park, the switch **Tell me about new meetups here**
  (`dog_park_favorites.notify_meetups`, off by default); for an unsaved
  one, a line saying to save it first.
- **Park cards** (parks list and picker): "Meetup today" or "N meetups this
  week".
- **Member page:** "Walk and play ads": the member's open ads.
- **Strings:** `lib/l10n/features/meetups/` (`MeetupsL10n`,
  `context.meetupsL10n`), 139 strings, Hebrew gender-neutral per
  `lib/l10n/GLOSSARY.md` (rows use "שותפים", the kinds "טיול" and "משחק";
  messages in the first person: "אשמח להצטרף"). The generic words of the
  area picker (Near me, Change, the radii, the location problems) come
  from the outdoors strings. The moderation tag "Partner ad" is in the
  community strings (`kindMeetup`).

### Code map

| Path | What |
|---|---|
| `lib/services/meetups/data/meetup_models.dart` | `Meetup`, `MeetupPet` (with sizes from the weight), `MeetupTime` (`OneOffTime`, `RecurringTime`), `MeetupDraft`, `draftProblems`, `MeetupLimits`, `MeetupException` |
| `lib/services/meetups/data/meetups_repository.dart` | the interface; `fake_meetups_repository.dart` (the server's rules; sample ads by the fake chat's people around Ra'anana, Kfar Saba and Tel Aviv-Yafo, two of the demo's own), `supabase_meetups_repository.dart` |
| `lib/services/meetups/state/meetups_providers.dart` | repository, clock, `MeetupsArea` and `MeetupsAreaController`, filters (`passesFilters`), the lists (area, mine, a park, parks, a member, one ad, responders), the notify switches, `MeetupsController` (each change bumps `meetupsRevisionProvider`, so every list reloads) |
| `lib/features/meetups/module.dart` | slots `outside-partners`, `park-meetups`, `park-meetup-post`, `park-card-meetups`, `member-meetups`; actions `meetup` (an ad's page, a push's target) and `new-meetup` |
| `lib/features/meetups/meetups.dart` | the public import |
| `lib/features/meetups/meetups_state.dart` | the board's listing (`buildMeetupListing`: blocks, filters, chips, order), the park cards' summaries, `MeetupsKeeper` |
| `lib/features/meetups/meetups_words.dart` | `MeetupsWords`, `MeetupText` (pet line, place, when, days, distance, the first message, the group's name) |
| `lib/features/meetups/meetup_actions.dart` | open the form, an ad, My ads; join (`JoinMeetupSheet`), group, close, renew, report, block |
| `lib/features/meetups/board/` | `PartnersView`, `MeetupCard`, `MeetupsAreaPicker` |
| `lib/features/meetups/form/meetup_form_screen.dart` | the form |
| `lib/features/meetups/mine/` | `MyMeetupsScreen`, `MeetupScreen` |
| `lib/features/meetups/slots/meetup_slots.dart` | `PostMeetupHereButton`, `ParkMeetupsSection`, `MeetupRow`, `ParkCardMeetups`, `MemberMeetupsSection` |

The module needs the `community` and `outdoors` modules in the build
(`python tool/configure_features.py --modules ...,community,outdoors,meetups`):
it lives in their slots and opens their chats and park pages.

`MeetupsKeeper` keeps the board's providers (or, with `board: false`, a
slot's own) listened to while a form, an ad's page or a chat covers them,
for the reason given on `CommunityKeeper` in [community.md](community.md).
The park cards' summaries are worked out from the parks controller's own
state, never from the derived listing (which is computed while the list
builds; depending on it would refresh a provider in the middle of a
build).

## Database (`0028_meetups.sql`)

| Object | What |
|---|---|
| `community_meetups` | `author_id`; `kind` (`walk`, `play`); the pet as saved: `pet_id` (only its author reads it back), `pet_name`, `pet_species`, `pet_breed`, `pet_born_on`, `pet_born_approx`, `pet_size` (dogs: under 10 kg small, under 25 kg medium, else large), `pet_icon`; `audience` (`all`, `dog`, `cat`, `other`); `park_id` or a `place_text` (80); `locality_code`; one-off `starts_at`/`ends_at` or recurring `weekdays` (ISO, 1 = Monday) + `day_part` (`morning`, `noon`, `evening`); `suits` (sizes, empty = all); `note` (200); `status` (`open`, `closed`); `answer_count`; `expires_at`; `renew_notified_at`; `hidden_at`/`moderated_at`; timestamps |
| `community_meetup_answers` | who answered which ad (once each) |
| `community_meetup_reports` | reports (spam, abusive, inappropriate, other), one per member and ad |
| `community_meetup_board` (view, the reader's rights) | an ad with its author's name, its park's names, place and tags (when the reader may see the park) and whether the reader answered |

Rules (row level security with the `(select auth.uid())` /
`(select public.can_use(...))` once-per-statement form, and
security-definer functions with `search_path = ''`):

- **Reading.** Members with `community.meetups.view` read open ads that
  have not ended and are not hidden; authors read all their own ads;
  moderators read hidden ones. Never an ad of someone the reader blocked,
  nor one they reported. Members cannot read pets rows: the public facts
  are copied by the server from the author's own pet when the ad is saved.
- **Writing.** Clients never write the ads or answers tables. Every change
  goes through a function:
  - `meetup_save(id, p)` (`community.meetups.post`): a new ad (`id` null)
    or the new text of the author's open ad. Checks the kind, the pet (the
    author's own, not archived), the place (an active park, whose city it
    takes, or a city code and a place), the time (one-off: ends after it
    starts, within 12 hours, not over, up to 60 days ahead; recurring: 1–7
    weekdays and a part of the day), the sizes and the note. A one-off ad
    ends with its time; a recurring ad is up for 30 days (an edit keeps
    them). **3 new ads a day** (`rate_limited`), **5 open at once**
    (`too_many_open`); editing a closed or ended ad is `not_open`.
  - `meetup_close(id)`, `meetup_renew(id)` (recurring ads only, another 30
    days from now, counted against the five open), `meetup_answer(id)`
    (an open ad of someone else, no block either way: `blocked`; answers
    the count), `meetup_responders(id)` (the author's, without anyone
    blocked either way).
  - Reports are inserted by the reporter (`community_meetup_reports`);
    three since the last moderator decision set `hidden_at`.
- **Moderation.** The queue (`community_moderation_queue`, 0021) also lists
  reported ads (`kind` `meetup`, the note as the text, the city code as the
  context); `community_moderate('meetup', id, 'keep' | 'remove')`.
- **Push** (`push_outbox`, kinds `meetup` and `meetup_renew`):
  - a new ad at a park reaches everyone who saved the park and switched on
    "Tell me about new meetups here" (not the author, nobody across a
    block either way, members with `community.meetups.view` and a phone),
    three a day at most per member; the private-chat message push covers
    the answers;
  - `push_claim()` first runs `community_private.meetups_housekeeping()`
    (failures never stop the claim): an author with a phone hears once
    that their recurring ad has ended (within the week after); ads that
    ended, or were closed, more than **90 days** ago are deleted. The
    housekeeping also runs on every new ad.
  - The claim carries `meetup_kind`, the park's names and street and the
    place for the words: "A new walk at <park>" / "טיול חדש ב־<park>",
    then "<name>: <note>"; "Your partner ad has ended" / "מודעת השותפים שלך
    הסתיימה". A tap opens the ad (`meetup:<id>`).
- **Capabilities:** `community.meetups.view` and `community.meetups.post`
  ("Walk and play partners · View / Post"), both for the Standard owners
  group. Disabling the `community` feature disables partners too. The
  Outside section shows for `community.parks.view|community.meetups.view`.
- **Accounts.** Deleting an account deletes its ads, answers and reports
  (cascades).

## Tests

- `test/meetups/meetups_logic_test.dart`: sizes, times, the form's checks,
  areas and their codes, the profile city, filters, the fake's rules
  (limits, parks, editing, closing, renewing, answers, blocks, reports),
  the Supabase rows and refusals, the moderation word.
- `test/meetups/partners_board_test.dart`: Partners first, the profile
  city, the order, the card, radii, filters and chips, empty areas, asking
  once and remembering, Near me (only the city is kept), refused location,
  joining (the sheet, the chat of two with the draft, the answer), report
  and block, member pages, the push action, the capabilities switched off.
- `test/meetups/meetup_ads_test.dart`: a new ad at a park and at another
  place, the daily limit, My ads (renew, close, group, edit, post again),
  park cards, the park page's meetups, posting there and the switch,
  Hebrew at 320 px (board, card, join sheet, form, My ads, park page).
- `supabase/tests/meetups_test.sql` (`tool/test_database.ps1`): grants and
  refusals, the pet snapshot, places and times, the limits, reading rules,
  answers and responders, blocks, editing, closing, renewing, reports and
  moderation, the pushes, the housekeeping, account deletion.
- `supabase/functions/_tests/push.test.ts`: the words of `meetup` and
  `meetup_renew` and the tap target.

## Limits and open questions

- Other members see the pet's icon, not its photo: pet photos are private
  to their owner's storage folder. Showing photos would mean copying one
  into a shared folder at posting (a later decision).
- The renewal reminder needs the community-push schedule; without it the
  in-app **Renew** in My ads still works and nothing is deleted until the
  next run.
- Distances are between city centres (or the park), so "about 5 km" is a
  rough guide by design; the phone's position is never used for it.
- The profile city is free text; a city the bundled list does not know is
  asked for once on the board.

# Household: sharing a pet's care between the people of one home

Proposal dated 14 October 2026; phase 1 built the same day (see Status).
A companion page with the screen mockups was published from the session
that produced this file. Follows the shape of [meetups.md](meetups.md) and
the rules in [design_rules.md](design_rules.md).

## Status: phase 1 built (14 October 2026)

Branch `feature/household`. Database `supabase/migrations/0030_household.sql`
(tested by `supabase/tests/household_test.sql`, part of
`tool/test_database.ps1`); app code in `lib/services/household/` and
`lib/features/household/`; strings in `lib/l10n/features/household/`.

**Owner steps.** Back up, run `0030_household.sql` in the SQL editor,
then build the app. If `0028_meetups.sql` or `0015_reliable_operations.sql`
is ever run again, run `0030` again after it (it patches one condition in
a function of each).

**Where phase 1 differs from the plan below**, decided while building:

- A pet's rows keep `owner_id` = **the pet's owner**, set by a trigger
  whoever writes them; `care_logs` and `health_observations` get
  `logged_by`, the account that wrote them. Letting `owner_id` mean
  "created by" would have broken the trigger that checks a log has the
  same owner as its reminder, the clean-up jobs, cascades and rewards.
- No `profiles.default_household_id`. Every account owns exactly one
  household (made at sign-up); a new pet joins the adder's own household
  unless the row names another the adder belongs to. A pet always belongs
  to its household's owner.
- Files stay in their **uploader's folder**. Members read a shared pet's
  photo and documents because a row they can see points at the file; a row
  may only point at a file in its writer's folder; a replaced file's
  clean-up job goes to the uploader. No `pets/<pet id>/` move was needed.
- Roles are only `owner` and `carer` (owner's decision); invitations carry
  no role. Codes are 8 characters; 20 wrong codes an hour per account.
- Server functions that asked "is this the caller's pet?" now ask "is it
  in the caller's household?": `pet_context` (now also returns
  `household_id` and `my_role`), `set_first_days_task`, rewards
  `mark_seen` and `account_trusted`, the care-log rate limit (per person),
  `meetup_save` and `record_basket_purchase`.
- Home shows the people of a shared pet as a **badge of avatars on the
  photo**, not a text line: the hero's name-and-pills column is fitted to
  320 px. By-lines ("Dana" under the row) are on the **Feeding and Activity
  pages' meal and walk rows**; Home's cards show no single meal.
- Carers see no Archive, Delete or Restore for a pet; the server refuses
  them anyway.

**Not in phase 1:** a QR code on the invite sheet; the invitation link
opening the app (needs the domain's link files, Android and iOS link
settings, and keeping the link through sign-in: until then the shared text
carries the code and the Household page has "I have an invitation code");
"Which home?" when adding a pet; everything of phases 2 to 4 (events,
Updates, push, the room, assignments, tasks, hand-over), whose tables go in
later migrations (0031 on).

## The problem

A pet is looked after by several people. Today PetLoop knows exactly one:
`pets.owner_id`, and every one of the 38 row policies says "the signed-in
user sees and edits their own rows, for a pet that belongs to them". A
wife, a daughter or a dog walker cannot see Kelly at all, cannot log the
walk they just took, and the owner's phone keeps ringing for a meal that
was given an hour ago.

What the feature has to do, in the owner's words:

1. Define a group of people who share the responsibility for each animal.
2. Delegate tasks to members.
3. Let every member report and update the animal's state (health,
   activity); the update reaches every member.
4. Give the group a private room.

## Name

**Household** (Hebrew: **הבית**, "הבית של קלי וסויה"). Not *Family*: a dog
walker, a roommate or a neighbour belongs in it too. Not *Partners*: the
Outside tab already uses "Walk and play partners" (meetups) for strangers
one walks with; the same word for the people of one's home would collide
in every string and in the member's mind. "Household" is the owner's
decision to make; everything below works with any name.

## Roles

Two roles (the owner's decision of 14 October 2026: a third, limited tier
was too complicated), named by the kind of access so the Hebrew stays
gender-neutral (nouns, per `lib/l10n/GLOSSARY.md` rule 1):

| Role | Hebrew tag | Who | May |
|---|---|---|---|
| **Owner** | בעלים | The account that created the pet (exactly one per pet; transferable) | Everything a Carer can, plus the structure: archive or remove the pet, move it to another household, rename the household, remove people, hand the household over |
| **Carer** | טיפול | Everyone else in the household: a partner, a child, a dog walker | Everything about the pet's care and health: profile, medicines, routines, records, documents, emergency tools; invite others; assign and claim tasks; log anything; the room |

Everyone invited gets the same access. A child or a dog walker you would
rather limit is a later per-member switch, not a role (see *Limits*).
Membership is per household; every pet in the household is shared with
every member. A member's Home shows all pets of all their households (a
walker who looks after two homes' dogs sees both). Per-pet exclusions are
a later option too.

## Rules

- **One household per person to begin with.** Every existing account gets a
  household of one on migration (named after the account, pets moved into
  it); a new account gets one on sign-up (`handle_new_user`). New pets go to
  `profiles.default_household_id`. Membership in other people's households
  is unlimited; owning several (after a hand-over) is allowed.
- **Joining.** Any member creates an invite and shares
  a link (`https://petloop.app/join/<code>`) or the code itself, usually
  over WhatsApp. The invitee signs in (or up), the app opens the join card
  (household name, the pets, who invited, what joining allows) and they
  accept or decline. One invite, one person, seven days; up to 10
  members per household; 10 invites per account per day ("That was
  quick!", the existing limit wording).
- **Leaving and removing.** Anyone but the Owner may leave; only the Owner
  removes people. Access ends at once (row security). What the person logged stays, with their name as
  it was (`care_logs.logged_by_name` already snapshots it).
- **Hand-over.** The Owner can hand the household (and every pet in it) to a
  joined Carer. Deleting the Owner's account hands over to the
  earliest-joined Carer automatically; alone in the household, the pets go
  with the account, as today.
- **Who did it.** Every care log, observation and record carries
  `logged_by` (the account) beside the name snapshot. Home cards show it
  ("Breakfast 07:40 · Noa").
- **Delegation.** A recurring reminder may have a usual person ("Who usually
  does it": Everyone or a member). Any single occurrence (one reminder on
  one day) can be given to a member or claimed ("I'll do it"). A one-off
  chore ("Pick up Rimadyl", "Vet, Thursday 16:00") is a household task
  with an optional pet and an optional assignee.
- **Reminders ring where they should.** A member's phone rings for
  occurrences that are Everyone's or theirs. An occurrence given to
  somebody else rings on the others' phones only as a backup, 30 minutes
  after the time, if it is still unanswered. Any member's answer silences
  it everywhere (realtime update plus a data-only push, see below).
- **Updates reach everyone.** Every care log, dose, observation, new record,
  assignment and membership change becomes a household event. Members
  read them in the room's *Updates* segment and, per their own settings,
  as a push: medicine given, observations, tasks given to me, missed
  tasks and room messages on by default; routine meals and walks off by
  default (they show in Updates only).
- **The room.** One chat per household, created when the second member
  joins, with the private chats' machinery (`chat_channels.kind =
  'household'`): photos, replies, reactions, mute, system lines. Its
  members are the household's members, always; nobody is invited to it
  or leaves it separately. Owner and Carers are its admins. Reporting a
  message reaches the moderators' queue as for private chats; moderators
  cannot read the room.
- **Rewards.** A pet's milestones and care rhythm count every member's logs
  (it is the pet's rhythm). Community standing is untouched. The "trusted
  account" rule (a pet with a done care log) is met by a Carer's log on a
  shared pet.
- **Capability.** Feature `household` with `household.view`,
  `household.manage` (invite, remove, hand over; needs view) and
  `household.room` (needs view), granted to Standard owners and Beta
  testers like every other feature. Without `household.view` the app shows
  nothing of it and the server refuses every call; the member's own pets
  keep working exactly as today because their household is their own.

## The app

### Where it lives

- **You page:** one row *Household*, subtitle the members' names ("Limi,
  Dana, Noa"), or "Just you" with the invitation sentence. The one door.
- **Home hero:** under the pet's name, the stacked avatars of the people
  who look after this pet (up to three, then "+1"). Status, not a second
  door: tapping opens the same Household page.
- **Care and Health cards and rows:** a by-line ("07:40 · Noa") where a
  thing was done, an assignee chip ("Everyone ▾" / "Dana ▾") on today's
  occurrence rows, "Still waiting · Noa is on it" states.
- **Routine and medicine forms:** one field, "Who usually does it", shown
  (not folded), menu chip, default Everyone.
- **The room:** `/household/room`, `CoralHeader` with the household's name
  and two segments, *Chat* | *Updates* (the segmented control allows
  three; the third is kept free for *Tasks* if phase 3 wants it).
- **Join:** `/join/:code`, a full-screen card like `ChatInvitationCard`.

### Screens

**Household** (`/household`). Header: the household's name (Owner edits it
from the title row's pencil, a short sheet). Sections, as rows:

1. *People*: avatar, name, role tag (`AppTag` yellow Owner, sage Carer;
   "Invited" in neutral with the inviter's name). Tapping a row opens the
   member sheet: remove (Owner), take back an invitation, and for oneself:
   leave. One filled button at the end of the section: **Invite someone**
   (hidden without `household.manage`).
2. *Pets*: the household's pets (name, species icon); the Owner's row
   action "Move to another household" lives in the pet profile, not here.
3. *Room*: one row with the unread count.
4. *Tell me about*: one row that opens the notification sheet with six
   switches (medicine given, observations and notes, tasks given to me,
   missed tasks, room messages, meals and walks).
5. For the Owner: *Hand over the household* (destructive text button at
   the bottom, two-step confirmation naming the Carer).

**Invite** (one sheet). Three lines on what joining allows, then the link
and the code, **Share link** (system share sheet, filled), a Copy icon on
the code, a QR for the phone in front of you, and the sentence "Works for 7
days, for one person." Pending invites appear in *People* as "Invited"
rows the inviter can take back.

**Join** (`/join/:code`). Card: the pets' avatars, "Limi invited you to
Kelly & Soya's household", a three-line explanation of what joining allows,
**Join** (filled) and *No thanks*. Signed out: the router redirects to
sign-in / sign-up and returns here. Expired or used: one sentence and
"Ask Limi for a new link." A code field on the Household page covers
phones where the link does not open the app.

**Room** (`/household/room`). *Chat* is the private chat screen as it is,
plus one composer chip, **Ask for help**: pick one of today's or
tomorrow's open occurrences (or type a chore), and a request card is
posted: "Can someone walk Kelly tonight, 19:00?" with an **I'll do it**
button; the first tap assigns the occurrence to the tapper and the card
turns into "Noa is on it"; a system line "Noa took the evening walk"
follows. *Updates* is the household event timeline grouped by day: avatar,
sentence, optional tag (observation level in peach for "less", "more",
"different"), time; tapping opens the thing (the log sheet, the record,
the task). Empty: "When someone in the house logs a meal, a walk or a note,
it shows here."

**Home with a household.** Feeding card metric block: "Breakfast 07:40 ·
Noa" and the next meal "Dinner 19:00 · Dana ▾" (the chip is the
assignment; Everyone when nobody is set). Activity card: "Evening walk
still waiting · Noa is on it" with the one pill *Did it*. Health card
unchanged apart from the by-line on the last dose. The card contract
holds: one metric block, one pill.

**Add a pet** gets a first step "Which home?" only for members of more than
one household. **Pet profile** gets, for the Owner, *Move to another
household* under More.

### Words

English: Household, Owner / Carer, Invite someone, Join, No
thanks, Everyone (the unassigned state), I'll do it, Ask for help, Still
waiting, is on it, Tell me about.

Hebrew, gender-neutral by construction (nouns and the first person):

| English | Hebrew |
|---|---|
| Household / Kelly & Soya's household | הבית / הבית של קלי וסויה |
| Owner / Carer (role tags) | בעלים / טיפול |
| Invite someone | הזמנה לבית |
| Join / No thanks | הצטרפות / לא תודה |
| Everyone (nobody assigned) | כולם |
| I'll do it / Noa is on it | אני על זה / נועה על זה |
| Ask for help | בקשת עזרה |
| Still waiting | עדיין מחכה |
| Tell me about | על מה לעדכן אותי |
| Updates / Room | עדכונים / החדר |
| Breakfast 07:40 · Noa | ארוחת בוקר 07:40 · נועה |
| Kelly's appetite: less than usual · Dana | תיאבון של קלי: פחות מהרגיל · דנה |

Event sentences use the pattern *thing of pet: state · member*, so no verb
agrees with the pet or the member. Pushes use *member: event* ("נועה: טיול
של קלי, 25 דק׳"). Names in Hebrew strings are wrapped in U+2068/U+2069 as
always.

### Code map (proposed; phase 1 as built: see Status)

```
lib/features/household/
  module.dart                     FeatureModule 'household': You row, hero avatars slot,
                                  actions join / invite / room / assign, routes
  household.dart                  facade
  household_words.dart            role names, event and push sentences
  data/household_models.dart      Household, HouseholdMember, HouseholdInvite,
                                  HouseholdEvent, Assignment, HouseholdTask
  data/household_repository.dart  interface
  data/supabase_household_repository.dart
  data/fake_household_repository.dart   demo: Limi (Owner), Dana and Noa (Carers)
  state/household_providers.dart  myHouseholdsProvider, householdOfPetProvider,
                                  myRoleProvider(petId), householdEventsProvider,
                                  assignmentsProvider, HouseholdController
  household_screen.dart, invite_sheet.dart, join_screen.dart, member_sheet.dart,
  notify_sheet.dart, updates_tab.dart, ask_for_help_sheet.dart
  widgets/member_avatars.dart     stacked avatars, ByLine, AssigneeChip, RequestCard
lib/platform/household_context.dart   contract used by Care and Health without importing
                                  the feature: role for a pet, members for by-lines,
                                  assignment lookups for the planner
lib/l10n/features/household/household_en.arb, household_he.arb
```

Changes in existing code: `care_models.dart` (`loggedBy`, assignee),
`FeedingCard` / `ActivityCard` / `HealthCard` (ByLine, AssigneeChip),
`routine_form_screen.dart` and `medicine_form_screen.dart` (Who usually
does it), `reminder_planner.dart` (filter by assignee, backup reminders),
`notifications/push.dart` (data-only `replan` message cancels and plans
again), `pets_provider` (pets now arrive through membership; `get_my_pet_context`
changes server-side, the client query does not), `you_screen.dart` (the
row), `app_router.dart` (`/join/:code` with sign-in redirect that keeps the
target), the `community` chat screen (kind `household`: no invitation card,
no leave, the Ask for help chip), the deletion flow (hand-over sentence).

## Database (planned shape; phase 1 is `0030_household.sql`, see Status)

Additive and idempotent, after 0029. Back up first, as always.

### Tables

```sql
create table public.households (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'carer')),
  invited_by uuid references auth.users(id) on delete set null,
  joined_at timestamptz not null default now(),
  notify jsonb not null default '{"doses":true,"observations":true,"assigned":true,
                                  "missed":true,"room":true,"routine":false}',
  primary key (household_id, user_id)
);
create index on public.household_members (user_id);

create table public.household_invites (
  code text primary key,                 -- 10 chars, server-made, unambiguous alphabet
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  revoked_at timestamptz
);

alter table public.pets add column household_id uuid references public.households(id);
alter table public.profiles add column default_household_id uuid references public.households(id);
alter table public.care_logs add column logged_by uuid default auth.uid() references auth.users(id) on delete set null;
alter table public.health_observations add column logged_by uuid default auth.uid() references auth.users(id) on delete set null;
alter table public.care_plan_items add column assignee_id uuid references auth.users(id) on delete set null;

create table public.care_assignments (              -- one occurrence, one person
  plan_item_id uuid not null references public.care_plan_items(id) on delete cascade,
  due_on date not null,
  assignee_id uuid not null references auth.users(id) on delete cascade,
  assigned_by uuid not null default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (plan_item_id, due_on)
);

create table public.household_tasks (               -- one-off chores
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  pet_id uuid references public.pets(id) on delete set null,
  title text not null check (char_length(title) between 1 and 120),
  due_at timestamptz,
  assignee_id uuid references auth.users(id) on delete set null,
  created_by uuid not null default auth.uid() references auth.users(id) on delete set null,
  done_at timestamptz,
  done_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.household_events (              -- append-only, written by triggers
  id bigint generated always as identity primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  pet_id uuid references public.pets(id) on delete set null,
  actor_id uuid references auth.users(id) on delete set null,
  kind text not null check (kind in ('care_logged','dose_given','observation','record_added',
    'task_assigned','task_claimed','task_done','member_joined','member_left','role_changed',
    'pet_added','pet_moved','handed_over')),
  ref_table text, ref_id uuid,
  summary jsonb not null default '{}',               -- title, status, level, minutes...
  created_at timestamptz not null default now()
);
create index on public.household_events (household_id, created_at desc);

alter table public.chat_channels add column household_id uuid unique references public.households(id) on delete cascade;
-- kind 'household' joins 'topic' and 'private'.
```

Migration of existing data, in the same file: one household per account
(`name = display_name`, or "My home"), `pets.household_id` set,
`default_household_id` set, then `pets.household_id set not null`.
`care_logs.logged_by` is backfilled from `owner_id` (it was always the
owner).

### One check for every policy

`public.health_owns_pet(pet)` is the choke point every pet-scoped policy
already calls (0002, 0006, 0009, 0010, 0011). It keeps its name and gets
new meaning: *the caller is a joined member of the pet's household*. Two
siblings beside it, one for the lookup and one for the Owner-only cases:

```sql
create or replace function access_private.my_household_ids() returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(household_id), '{}') from public.household_members
  where user_id = (select auth.uid())
$$;

create or replace function public.pet_role(pet uuid) returns text   -- owner | carer | null
language sql stable security definer set search_path = '' as $$
  select m.role from public.pets p join public.household_members m on m.household_id = p.household_id
  where p.id = pet and m.user_id = (select auth.uid())
$$;

create or replace function public.health_owns_pet(pet uuid) returns boolean
language sql stable set search_path = public as $$ select public.pet_role(pet) is not null $$;

create or replace function public.pet_owned(pet uuid) returns boolean   -- the Owner only
language sql stable set search_path = public as $$ select public.pet_role(pet) = 'owner' $$;
```

`security definer` on the two lookups avoids policy recursion (pets →
members → pets) and keeps the plan to one index probe. `pets` itself:
`using (household_id = any (access_private.my_household_ids()))`; writes
through a trigger that lets any member change rows and only the Owner set
`archived_at`, `household_id` or `owner_id`.

The per-row `owner_id = auth.uid()` conditions on the child tables are
what actually locks members out today, so every pet-scoped policy is
rewritten by the matrix below. With two roles the rewrite is mostly
mechanical: wherever a policy says `owner_id = (select auth.uid())` it now
says `public.health_owns_pet(pet_id)`. `owner_id` on child rows is kept and
now means *created by* (comments updated; a rename is a later clean-up).

| Table(s) | Read | Insert | Update / delete |
|---|---|---|---|
| pets | member | default household; member | member; Owner-only columns by trigger |
| pet_care_settings, care_plan_items, medications, health_profiles, health_events/records, health_documents, vets, emergency_kit_items, lost_pet_cards, pet_first_days | member | member | member |
| care_logs, health_observations | member | member, `owner_id = auth.uid()` | member |
| care_assignments, household_tasks | member | member | member |
| pet_milestones, care_rhythm (rewards) | member | server | server |
| budget expenses, basket items | unchanged (the owner's) in phase 1; household-scoped in phase 4 | | |
| household_events | member of the household | triggers only | nobody |
| households, household_members, household_invites | member (the invitee reads an invite through the preview function) | functions only | functions only |

`access_private.pet_context()` (0016) changes its `where` from
`p.owner_id = auth.uid()` to membership, and adds `household_id` and the
caller's `role` to each pet. `rewards_private.compute_pets` and the 0029
care-log counting read `care_logs` by pet, so they already count every
member.

### Storage

Pet photos live at `<owner id>/<pet id>/<file>` and the bucket policies key
off the first folder being the caller (0001); `pets_photo_path_owner_check`
(0005) ties the row to that folder. Both break the moment a Carer uploads
or the Owner changes. New uploads go to `pets/<pet id>/<file>` in both
`pet-photos` and `pet-documents`; policies: read when
`(storage.foldername(name))[1] = 'pets' and public.health_owns_pet([2]::uuid)`,
write the same. Legacy paths stay
readable by their owner as before, plus one read policy for members keyed
on the second folder. The check constraint is dropped. The clean-up worker
(`access_private.file_is_orphan`, 0015/0021) learns the `pets/` prefix.
Room photos use the private chats' `<author>/private/<chat id>/` rule as
they are.

### Functions (the API the app calls)

| Function | Does |
|---|---|
| `create_household_invite(p_household)` → code | `household.manage`; 10 a day; code from an alphabet without 0/O/1/I |
| `preview_household_invite(p_code)` → jsonb | Any signed-in account: household name, pets (name, icon), inviter's display name; nothing else. Expired / used / revoked → a reason code |
| `accept_household_invite(p_code)` | Joins (or, if already a member, raises); marks the invite; mirrors into the room; system line; event `member_joined` |
| `revoke_household_invite(p_code)` | Any member |
| `remove_household_member(p_household, p_user)` / `leave_household(p_household)` | Owner removes; anyone but the Owner leaves; a leaving member's `default_household_id` falls back to their own; room mirror; events |
| `hand_over_household(p_household, p_to)` | Owner → joined Carer: `households.owner_id`, `pets.owner_id`, the two roles swapped; event `handed_over` |
| `rename_household(p_household, p_name)` | Owner |
| `move_pet(p_pet, p_household)` | Owner of the pet and member of the target; the pet's reminders keep their assignees only if still members |
| `assign_occurrence(p_item, p_due_on, p_user)` / `claim_occurrence(p_item, p_due_on)` | Member; `null` user clears; events `task_assigned` / `task_claimed`; the request card, if any, is updated |
| `set_household_notify(p_household, p_notify)` | Own row's `notify` |
| `my_households()` → jsonb | Households with members (id, display name, avatar, role, joined_at), pets, my role, room channel id, unread |
| `household_updates(p_household, p_before, p_limit)` → set | Events page, newest first, with actor display name and avatar |

Display names: `profiles` is readable only by its owner (0001).
`my_households()` and `household_updates()` are `security definer` and
return fellow members' `display_name` and `avatar_path` only, like
`chat_people` (0026) does. Realtime: `household_events` and `care_logs` join
the publication; the app subscribes per household (`household_id=eq.`).
Row security filters the stream.

Triggers write events: after insert on `care_logs` (kind by
`plan_item_id`'s kind or `medication_id`), `health_observations`,
`health_records`, `care_assignments`, `household_tasks` (insert and
`done_at` set), and from the membership functions. `delete_my_account()`
(0025) first calls the hand-over for every household the account owns
that has a joined Carer.

### Push

`community_private.enqueue_push` (0023) gains kinds `dose_given`,
`observation`, `assigned`, `missed`, `household_room`, `routine` and a
data-only `replan`. The access gate for these kinds is `household.view`
on the recipient; the per-kind switch comes from
`household_members.notify` instead of `push_preferences`. One trigger on
`household_events` fans out to every other joined member of the household
(skipping the actor, the blocked, the muted room for `household_room`);
`push_on_reply` gets a sibling: every message in a `kind = 'household'`
channel pushes to members who did not mute it. `push_claim` returns the
pet's name with the row; the Edge Function `community-push` words the new
kinds in the recipient's language (`member: event`) and sends `replan` as
a data message with the occurrence key, no notification. Missed tasks are
the one server-timed push: a pg_cron job every 10 minutes finds
occurrences due 30 to 40 minutes ago with no log and no assignment
claimed, and enqueues `missed` once per occurrence (a small
`care_missed_sent (plan_item_id, due_on)` table keeps it to once).

### Reminders on the phone

`planReminders` keeps its contract and takes two more inputs: the
caller's id and the assignment lookups. Rule: an occurrence rings at its
time when `assignee` (the day's `care_assignments` row, else the item's
`assignee_id`) is null or me; when it is somebody else, it rings at due +
30 minutes with the text "Kelly's evening walk is still waiting · Noa"
(the backup). Answers from any member cancel through the planner the way
own answers do today: a realtime `care_logs` row or a `replan` data push
re-runs the plan (the `NotificationSink` already replaces a pet's group).

## Tests

`supabase/tests/household_test.sql`, in the style of
`private_chats_test.sql`: a Carer reads, edits and logs everything for a
shared pet; a non-member reads nothing; a removed member reads nothing a
second later and their logs remain; an invite is single-use and expires;
a Carer cannot remove anyone and the Owner cannot leave; nobody but the
Owner changes `archived_at` or `household_id`; the room has exactly the
members, and a member cannot leave it directly; `delete_my_account()` with
a Carer hands over and the pets survive; alone they cascade; events are
written and readable to members only; pushes are enqueued for the right
members with the right switches; `missed` fires once; storage: a Carer
uploads to `pets/<id>/`, a non-member reads nothing.

Flutter: the fake repository encodes the same rules for the demo account
(Limi the Owner, Dana and Noa Carers, a pending invite for Yossi); planner tests for the
assignee and backup rules; fit tests at 320 px in Hebrew and English for
Household, Invite, Join, the Room's Updates and the Home cards with
by-lines (recipe: `test/outdoors/outside_header_fit_test.dart`).

## Rollout

| Phase | Ships | Days |
|---|---|---|
| **1 Foundation** | 0030 schema, backfill, `pet_role`, the policy rewrite, storage paths, `pet_context`; capability `household`; Household page, Invite (link + code), Join, member sheet; pets appear for members; by-lines on cards; tests | 4 |
| **2 Shared awareness** | `household_events` + triggers, Updates segment, realtime, push kinds and the notify sheet, `replan` data push, the room (kind `household`, mirrored membership) | 4 |
| **3 Delegation** | "Who usually does it", day assignments, claim, AssigneeChip, backup reminders, Ask for help request card, household tasks, missed-task job | 4 |
| **4 Lifecycle** | Hand-over, move pet, deletion hand-over, multi-household pills grouping, budget and basket per household | 3 |

Phase 1 alone already solves the owner's own case (wife and daughter log
and see everything, nobody is locked out); 2 and 3 are what makes the
shared care feel shared.

## Limits and open questions

- **Children.** The terms draft needs an age line; a child under 13 should
  use a parent's account or the parent decides. The feature does not
  verify age.
- **Links.** `petloop.app/join/<code>` needs the domain's
  `assetlinks.json` (Android) and `apple-app-site-association` (iOS) for
  the link to open the app; until then the share text carries the code and
  the Household page has the code field.
- **Per-pet exclusions** inside one household (the walker who handles one
  of two dogs) are not in scope: a `household_member_pets` allow-list
  would slot into `pet_role` later without touching the policies.
- **A limited member.** Every Carer sees the health records, documents
  and costs. If a dog walker or a young child should see less one day,
  that is a per-member switch on the member sheet ("care only": today's
  tasks, logging, the room) checked inside `pet_role`, not a third role.
- **Budget and basket** stay personal until phase 4.
- **Noise.** Defaults push doses, observations, assignments, missed and
  room; meals and walks only in Updates. A household of five with two
  dogs may still want a daily digest; nothing in the design prevents
  adding one.
- **Owner of several households** after a hand-over is allowed but has no
  UI to merge or dissolve them yet.

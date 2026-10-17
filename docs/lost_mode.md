# Lost mode

The aim: when a pet goes missing, the neighbourhood hears about it within a
minute, and the alert, the sightings and the card to share stay in one
place until the pet is home (improvement plan phase 4b). Lost mode starts
from the Emergency sheet's **Lost mode** row and needs `safety.lost`, which
is for Beta testers for now (`docs/safety.md`).

## The flow

`lib/features/safety/lost_mode_screens.dart`

1. **Step 1 of 2, "Lost mode"**:
   * the pet (photo, name, kind, breed and the lost card's description;
     "Change" when the account has several pets);
   * **Last seen** (now by default; a date and a time, never in the future);
   * **Town**, from the locality list Find a vet and the parks use. It
     starts on Outside's area when one is chosen;
   * **Where exactly?**, a public place and not an address, up to 120
     characters;
   * **Anything people should know?**, optional, up to 300 characters.

   Next is refused until a town is chosen.
2. **Step 2 of 2, "What people will see"**:
   * the post exactly as the feed will show it. The text comes from
     `lostPostBody` in `lib/services/safety/data/lost_post.dart`, which says
     what the server's `safety_private.post_body` writes, in the lost
     card's language (Hebrew by default). It holds the pet's kind, breed,
     description, the time and place, and the note, and never the phone
     number or an address;
   * the switch "Use Kelly's photo" (copied into the community photos when
     the pet has one);
   * who hears about it;
   * a row saying the card to share comes next.

   **Start lost mode** starts it. Back, or the phone's back, returns to step
   1 with everything kept.
3. Starting replaces the flow with **the open alert**, and the lost-pet card
   opens on top, already filled in, ready to share. The usage count
   `post_created` goes up by one.
4. **The open alert, "Kelly is missing"** (also reached from the sheet's row
   "Kelly is missing · 2 sightings"):
   * a peach status card: since when, the town and the place;
   * **Sightings**: the comments on the post written by other people,
     newest first, and "Open the post" to answer there;
   * **Share the card**: the lost-pet card;
   * **Kelly is home**: the one filled button. It closes the alert, thanks
     everyone on the post, and puts the lost card away;
   * **Close the alert**: asks first. If nobody outside the household has
     answered, the post is removed too; otherwise a closing comment stays.

Home is unchanged: no banner and no dot.

## The server (`supabase/migrations/0034_lost_alerts.sql`)

### `lost_alerts`

One row each time a pet goes missing:

* who started it;
* the pet's name and kind, copied when the alert starts (members cannot
  read pets);
* the locality code, the time last seen, the place and the note;
* the language of the post's words;
* the post;
* the status (`active`, `found` or `cancelled`), with `created_at` and
  `closed_at`.

A pet has at most one open alert. The pet's household reads its own
alerts. Nobody writes rows directly: every change goes through the
functions below.

### `lost_start`

Called as `lost_start(pet, locality, place, seen_at, note, language,
photo_path, area_name)`. It checks:

* `safety.lost` and `community.feed.post`;
* that the caller is in the pet's household and the pet is not archived;
* the locality code, the lengths of the texts, and the time last seen (not
  in the future, at most 30 days ago);
* that the photo, if any, is in the caller's folder;
* one open alert per pet, and at most three alerts per account per day
  (`rate_limited`).

Then, in one go, it:

* writes a `lost_found` community post through the normal community rules
  (the post rate limit, reports, blocks). When 0036's
  `community_posts.locality_code` exists, the post gets the alert's
  locality;
* writes the alert;
* updates the lost card's draft (the place, the time, not found);
* queues `lost_nearby` pushes, as described in the next section.

### Pushes

The server knows a member's town only from what they did there, so a push
goes to members who:

* saved a dog park in the town, or
* have an open partner ad there, or
* posted there in the last 60 days (once 0036 adds the post's locality).

The limits:

* one push per member per alert, and at most three Lost mode pushes a day;
* never to the pet's household, never across a block in either direction;
* only to members with a phone registered and `community.feed.view`;
* at most 500 members per alert;
* each member can switch them off with `push_preferences.lost_nearby`
  (on by default).

The push opens the post (`post:<id>`). `community-push` words it "A pet is
missing near you", with the pet and the place. With push not configured
nothing is sent and nothing fails.

### Closing and reading

* **`lost_found` / `lost_cancel`**: any member of the household can close
  an alert, even without the capabilities. Closing removes the alert's
  unsent pushes. "Found" leaves a thank-you comment on the post and marks
  the lost card found. "Cancel" deletes the post when nobody outside the
  household has commented, and leaves a closing comment otherwise.
  Closing an alert that is already closed changes nothing.
* **`lost_alerts_mine()`**: the household's open alerts, each with its
  number of sightings (comments from people outside the household that are
  not hidden).
* **`lost_alerts_near(locality)`**: the open alerts of a town as any member
  may see them (minimal columns, never across a block, never a hidden or
  reported post). It is ready for a banner; no screen uses it yet.

The `lost_nearby` kind is added to `push_outbox_kind_check` by reading the
current list and appending to it. **A later migration that rewrites that
check must keep `lost_nearby`**, and so must 0026 or 0028 if either is ever
run again.

## Owner steps

1. Run `supabase/migrations/0034_lost_alerts.sql` in the SQL editor, after
   0031. It is idempotent. 0036 may run before or after it.
2. Redeploy the Edge Function `community-push`. The old version cannot word
   the new kind.
3. Optional: when Lost mode should reach everyone, grant `safety.view` and
   `safety.lost` to Standard owners (`docs/safety.md`).
4. Check on two phones: start an alert as one account in a town where the
   other saved a park; the other gets one push, comments on the post, and
   the first sees "1 sighting"; "Kelly is home" closes it.

## Tests

* `supabase/tests/lost_alerts_test.sql`, run by `tool/test_database.ps1`:
  the capabilities, what is refused, the post, the alert and the card, who
  is pushed and who is not, sightings, the reads, found and cancel, and the
  rate limit.
* `supabase/functions/_tests/push.test.ts`: the push's words in English and
  Hebrew and its tap target.
* `test/safety/lost_alerts_test.dart`: the repositories, the refusals, the
  post's words, the controller.
* `test/safety/safety_pages_test.dart` and
  `test/safety/safety_pages_fit_test.dart`: the flow, the open alert, found,
  cancel, a refusal, and every page at 320 px.

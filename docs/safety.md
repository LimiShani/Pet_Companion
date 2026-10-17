# The safety hub

The Emergency sheet is the app's one safety door (improvement plan phase
4a). It opens from the Emergency pill (Home, Health) and from "Looks
urgent?" in the Quick log.

## The sheet

From top to bottom (`lib/features/health/emergency/emergency_sheet.dart`):

* "Kelly · Emergency" and one line: "Call first. The rows below help you
  decide and prepare."
* A peach card with the contact to call first: the 24 h clinic if one is
  saved, else the regular vet, else the emergency contact. It shows the
  name, the address when one is saved, "Call to confirm they are open" for
  a clinic or a vet, a round Directions button, and one full-width
  **Call now**. With nothing saved, the add-a-vet prompt takes its place.
* One white card of rows, each with a health disc:
  * the other contacts, with round Message and Call buttons (each contact
    appears once on the sheet);
  * **Is it urgent?** and **Can Kelly eat this?** (`safety.lists`);
  * **Lost mode** (`safety.lost`; see `docs/lost_mode.md`). While an alert
    is open the row reads "Kelly is missing · 2 sightings" and opens the
    alert. Without the capability the row opens the lost-pet card;
  * **Emergency card and kit** ("5 of 6 kit items · share as PDF");
  * **Find a clinic nearby** (Find a vet's emergency path).
* One line of fine print: "Lists and signs are general guidance, not a
  diagnosis. When in doubt, call."

Opening the sheet counts `emergency_opened` (usage counts).

The safety rows come from the `safety` module
(`lib/features/safety/module.dart`), which answers the actions
`safety-urgent`, `safety-food`, `lost-mode` and `lost-alert`. The sheet shows
a row only when an installed module answers its action for the account, so
building without the module (`tool/configure_features.py`) leaves a sheet
with the contacts, Lost mode as the card, the Emergency card and Find a
clinic.

## Is it urgent?

`lib/features/safety/urgent_signs_screen.dart`, content in
`lib/services/safety/data/urgent_signs.dart`.

* The peach Call now card stays pinned above the list (with no number
  saved: "No vet saved? Find a clinic nearby").
* One line: "Any of these means going to a vet now. Call on the way."
* The signs for the pet's kind: 18 in all, general ones for every animal,
  plus a swollen belly with retching and processionary caterpillars for
  dogs, and straining to pee for cats. Birds, rabbits, reptiles and others
  get the general list and a line saying the dog-only and cat-only signs
  are left out.
* No sign has a button of its own. The page always gives the same answer:
  call and go.
* "Where this comes from" (the sources, folded) and the fine print.

## Can they eat this?

`lib/features/safety/food_check_screen.dart`, content in
`lib/services/safety/data/food_safety.dart`.

* The search field sits in the header and is focused when the page opens.
  It searches English and Hebrew names and other common names, ignores
  Hebrew vowel marks and accepts a word typed without its final letter
  ("שו" finds שום).
* One filter row: an animal menu chip (Dog, Cat, Bird, Other animals),
  starting on the pet's kind, then the toggle chips Foods, Plants and
  Around the house.
* There are 83 entries. Each has one answer per animal, shown as a tag:
  **Safe** (sage), **A little** (yellow), **Dangerous** (ink with a warning
  icon, never red), or **Ask your vet** when the list says nothing for that
  animal (rabbits, reptiles, some foods for birds). With an empty search
  everything is listed, the dangerous ones first.
* A row opens a sheet with the answer, the one line, the other animals'
  answers and the food's other names. A dangerous entry gets the one
  filled **Call the vet** and "Eaten already? Call even if all seems fine.";
  any other entry gets an outlined "Not sure? Call the vet".
* No amounts, no calculator. When nothing matches: "Nothing found for
  "lychee"." with a call to the vet.

## Access and review

The capabilities come from migration `0034_lost_alerts.sql`, feature
`safety`:

| Capability | What it opens | Who has it |
|---|---|---|
| `safety.view` | the safety module at all | Beta testers |
| `safety.lists` | Is it urgent?, Can they eat this? | Beta testers |
| `safety.lost` | starting Lost mode | Beta testers |

`safety.lists` and `safety.lost` need `safety.view`.

**Before the lists leave the beta group, a vet must review both content
files.** Each file lists its sources at the top: ASPCA Animal Poison
Control, the MSD Veterinary Manual, Pet Poison Helpline and the AVMA. The
reviewer reads every entry in English and Hebrew; a change is a one-line
edit to the entry. After the review, grant `safety.view` and `safety.lists`
to Standard owners in Feature access (Groups), or by SQL:

```sql
insert into public.group_capability_rules(group_id, capability, allowed)
values ('acc35500-0000-4000-8000-000000000001', 'safety.view', true),
       ('acc35500-0000-4000-8000-000000000001', 'safety.lists', true)
on conflict (group_id, capability) do update set allowed = excluded.allowed;
```

Lost mode needs no vet review. To open it to everyone, also grant
`safety.lost`.

## Owner steps

1. Run `supabase/migrations/0034_lost_alerts.sql` in the SQL editor, after
   0031. It is idempotent.
2. Redeploy the Edge Function `community-push`, which now words the
   `lost_nearby` push.
3. Have a vet review `lib/services/safety/data/urgent_signs.dart` and
   `lib/services/safety/data/food_safety.dart`, then widen access as above.

## Tests

* `test/safety/safety_data_test.dart`: the content (both languages, the
  sources, no amounts, the per-animal answers, search).
* `test/safety/safety_pages_test.dart`: the pages reached from the sheet.
* `test/safety/safety_pages_fit_test.dart`: every page at 320 px in real
  fonts, in English and Hebrew.
* `test/health/emergency_test.dart` and
  `test/health/emergency_sheet_fit_test.dart`: the sheet.

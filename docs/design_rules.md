# PetLoop design rules

The rules the October 2026 streamline applied to every screen (design
review of 11 Oct 2026, phases 0 to 6). Follow them for any new screen or
change; when a rule cannot hold, say why in the change's description.

The identity stays: coral header, cream pages, yellow for "selected",
rounded cards, the illustrated Home icons, Nunito (Latin) with Fredoka
(Hebrew). The rules are about how much sits on one screen.

## Navigation

* **Five tabs:** Home, Health, Community, Outside, Store. A new area gets a
  tab only if it is used daily; otherwise it is a row on the You page or
  inside an existing tab.
* **The You page** (`/you`, the avatar in every tab's header except Health)
  holds the account: My pets, Budget, Settings, Community safety, About,
  Admin tools (administrators only), Sign out, Delete account. There is no
  side menu and no account sheet.
* **One door per destination.** Before adding a second entry point to a
  page, check whether the first one is enough. Today: Emergency = the pill
  (Home, Health) + "Looks urgent?" in the Quick log; Health profile = the
  Health Overview row + the pet profile row.
* **Pet context.** Home keeps its pet pills (owner's decision). Health uses
  the `PetSwitcher` chip. Store and Community filter by animal with a menu
  chip and never change the pet selected app-wide.

## Header

* `CoralHeader` on every screen (no Material `AppBar`).
* One title row and at most ONE segment row (`CoralSegmentedControl`,
  max three segments; the on-page variant `onSurface: true` for a switch
  below the header).
* Search opens from the header (`HeaderSearchButton` /
  `HeaderSearchField`) in place of the segments; no search row on the page.
* Pet pills, filter chips and fields do not go in the header.

## Filters

* One horizontally scrolling filter row per list. A choice with a single
  value (animal, sort, distance, area) is a menu chip with ▾; categories
  are toggle chips; a divider separates the two kinds.
* More than about seven choices, or several groups: a Filters chip that
  opens a sheet.
* No caption line under the chips explaining the filter.
* Selected is yellow everywhere.

## Cards and actions

* `DashboardCard` contract (Home): 64 px illustrated icon, a title that owns
  its line (`CardTitleRow`), one metric block, a trailing chevron; the card
  is the button and opens its page. Since the Today list (October 2026) Home
  cards carry no pill: daily actions are ticks on Today rows, not buttons on
  cards.
* A list row acts by a tick or a chevron, not a pill.
* One filled button per screen: the one thing to do. A floating button
  means no other filled button on that screen.
* Call / Message / Directions appear once per contact, in one place.
* Empty states invite with one sentence and one action, never a zero or a
  dash ("Add Soya's food and meal times to count calories." + Set up).

## One plus per tab

* Health, Community, Outside and Store each have exactly ONE floating "+"
  (`AddFab`: 56 px, round, coral dark, white plus; a screen reader hears
  "Add to Health"), on every segment of the tab. Home has none.
* It opens the tab's **Add sheet** (`AddSheet` in `lib/widgets/`): the
  title ("Add to Health") and 3 to 6 rows, each an `AreaDisc`, a label and
  at most one quieter line. A row opens an existing form, sheet or page.
* Modules contribute the rows (`FeatureModule.add[AddTab.health]`, an
  `AddEntry` with its capability, area, icon, label and `open`); the tab
  never imports another feature. Rows the account lacks the capability
  for are hidden; with no row, no "+".
* Today: Health (Quick log, Record, Appointment or due date, Medicine,
  Care routine), Community (Share a moment, Ask a question, Recommend a
  place or product, Lost or found, New chat), Outside (Plan a walk or play
  date, Suggest a park), Store (Share a deal, Regular product, Expense).
* No other "add" button on a tab's pages: the "+" replaced Quick log /
  Add record on the Overview, the Schedule's Add, the Records' Add record,
  New post, New chat, New ad, Share a deal and the basket's add line. An
  empty state still invites with one action (Health's opens the Add
  sheet); a button that carries context stays (the park page's "Post a
  meetup here", "Log weight", the Budget page's "Add expense").

## Colour by area

* Every part of the app has a colour from the brand palette (`AppArea` in
  `lib/theme/app_area.dart`): **Care** coral tint `#FBD0C3`
  (`AppColors.coralTint`), **Health** peach, **Community and Outside**
  sage, **Store, Budget and the basket** yellow, **You** (the account)
  neutral `#EADFCB` (`AppColors.neutral`).
* The colour sits on **icon discs** (`AreaDisc`: an ink line icon in a
  34 px circle; `MenuEntry(area:)` on the You and Settings pages; the
  Health and Community discs), on **tags** (`AppTag.area`) and on the
  **bottom-bar icons**: the selected tab's icon on a pill of its area's
  fill, in ink, with an ink bold label; the others stroked in the area's
  deep variant (`AppArea.deep`, 3:1 on white), labels brown.
* Text is never coloured by area: ink or brown only. The coral header
  stays coral everywhere; yellow still means "selected" for chips and
  segmented controls; the three illustrated Home cards (Feeding sage,
  Activity yellow, Health peach) keep their colours.
* A new disc goes where a row already shows a round icon, not on every
  row.

## Pages and forms

* Overview pages with small editors: a page that shows a thing lists rows
  (label, value or "Add", chevron) that open short sheets which save on
  their own (pet profile, Settings). No page-level Save.
* Long forms show what most people fill and fold the rest behind
  `MoreDetails`; a required field is never folded; the fold opens by itself
  when editing something that has those details, or when a folded field
  fails validation (`MoreDetails.scrollToOnceOpen`).
* A form with more than about ten fields is split into steps (Share a deal,
  Add a pet), with Back keeping what was typed.

## Words

* Say it once: a disclaimer or safety sentence appears where it matters
  (the top of the feed, the ad form), not on every item.
* Plain, warm, sentence case, gender-neutral Hebrew per
  `lib/l10n/GLOSSARY.md`; placeholders wrapped in U+2068 / U+2069 in Hebrew;
  no ICU `select` (the strings checker rejects it; use separate keys).
* Find strings no code uses with `py -3 tool/find_unused_strings.py`.

## Type, shape, components

* Sizes only from `AppText`: appTitle 23, petName 24, heading 20,
  sectionTitle 18, rowTitle 16, bodyLarge 16, cardTitle 15, body 14,
  secondary 13, label 12, navLabel 11, metric 28/30, button(size).
* One tag (`AppTag` with tones yellow / sage / peach / neutral / ink, or
  an area's colour with `AppTag.area`), one
  segmented control, one menu chip (`CoralMenuChip` on coral).
* Tap targets at least 44 px.

## Checking a change

* Every new or changed screen gets a real-font fit test at 320 px in Hebrew
  and English (recipe: `test/outdoors/outside_header_fit_test.dart`).
* Look at it: the emulator, or a temporary golden probe with real fonts and
  a PIL contact sheet (delete the probe afterwards).

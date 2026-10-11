# Dog parks (Community > Outside > Parks)

Dog park search inside the Community tab: parks near the phone or around a
city, what each one has (fence, water, shade, lighting, small-dog area,
benches), navigation, "My parks", and members' suggestions checked by park
reviewers before anything is published. "Play gardens" in the proposal are
dog parks: public areas for dogs.

This file is the design record and the contract between the app
(`lib/features/outdoors/`, `lib/services/outdoors/`), the database
(`supabase/migrations/0027_dog_parks.sql`) and the monthly import
(`supabase/functions/parks-import`). The approved proposal is section 2 of
`tools/agent_board/state/proposals/community/proposal.md` in the main
checkout.

## Owner steps (server)

Nothing here costs money: the free plan's Edge Functions, `pg_cron` and
`pg_net`, and OpenStreetMap's public Overpass servers.

1. **Database.** Take a backup, then run
   `supabase/migrations/0027_dog_parks.sql` in the SQL editor (after 0025;
   it does not need 0026). It is additive and safe to run twice. It creates
   the tables, the review functions, the import function and the three
   capabilities, and gives `community.parks.review` to the permission
   administrators.
2. **Function.** Deploy it and set its secret (any long random string):
   ```sh
   supabase functions deploy parks-import --no-verify-jwt
   supabase secrets set PARKS_JOB_SECRET=<a long random string>
   ```
   `supabase/config.toml` already says `verify_jwt = false` for it (pg_cron
   calls it without a user); the function refuses any call without the
   right `x-job-secret` header. Every request names a `Referer` as well
   as the User-Agent: overpass-api.de answers 406 to a request with neither,
   and the first live run (2026-10-11) got 406 from the Edge Runtime. When
   overpass-api.de refuses (406/429) or is busy (5xx) the import tries
   `maps.mail.ru`'s public instance once. Optional secret: `OVERPASS_URL`
   (one chosen instance, used alone with no fallback).
3. **Schedule.** Open `supabase/scheduling/parks_import.sql`, replace
   `<project-ref>` and `<same as PARKS_JOB_SECRET>`, run it. It runs the
   import at 01:00 UTC on the 3rd of every month.
4. **First import.** Run the commented "FIRST import" call at the end of the
   same file once, then a minute later check
   `select period_key, status, stats, error from public.dog_park_import_runs;`
   Expected on 2026-10-10 data: about 700 parks added. If the status is
   `failed` with `overpass_http_504` or `overpass_timeout`, the public
   Overpass server was busy: run the call again later (or set
   `OVERPASS_URL`). A month that succeeded is never downloaded again unless
   the body is `{"force": true}`.
   After a change to the query or the localities (the Judea and Samaria
   towns, 2026-10-11): deploy the function again
   (`supabase functions deploy parks-import --no-verify-jwt`) and run the
   same call with the body `{"force": true}`, since the month already
   succeeded. Expected on 2026-10-11 data: about 10 parks added and the
   rest refreshed.
5. **Reviewers.** Permission administrators already review. Anyone else:
   Feature access → Users → the person → *Dog parks · Review suggestions* →
   Allow. Everyone else keeps *Dog parks · View* and *Dog parks · Suggest
   changes* through the Standard owners group.
6. **Legal.** Add the OpenStreetMap credit and the ODbL to the legal page in
   the wiki (the app already shows it, see "Licence").

Before 0027 is run the app shows Outside with an error on the list ("We
could not load the parks"); the rest of Community is unaffected.

## Data source and licence

- **OpenStreetMap**, `leisure=dog_park`, inside OSM's boundary of Israel
  (`area["ISO3166-1"="IL"][admin_level=2]`, the Golan included) and within
  3.5 km of the centre of each Israeli city and local council of Judea and
  Samaria (the 18 in "Localities" below). Probe on 2026-10-10: 704
  parks; 34 have a name, 661 get one from the nearest street, 9 stay "Dog
  park"; fences are known for 72 and lighting for 9, water, shade, benches
  and small-dog areas for none. Tel Aviv-Yafo has 41, fewer than it really
  has: coverage is partial, which is why members can suggest parks.
- **Judea and Samaria** (owner decision 2026-10-11): the Israeli towns
  there are part of the app's list, so their parks are imported too. OSM's
  boundary of Israel leaves them out, so the query adds one "around" per
  town (3.5 km: enough for Ma'ale Adumim and Ariel, about 2.5 km from the
  centre to the edge). Probe on 2026-10-11: 714 parks in all, 10 of them
  new from these areas (Ariel 4, Alfei Menashe 3, Ma'ale Adumim 2,
  Oranit 1; the other 6 parks within 3.5 km of a town were already inside
  OSM's boundary: Mevaseret Zion, Tzur Hadassa, Kfar Bara). Regional
  councils' villages and Palestinian localities are not in the list; a park
  further than 3.5 km from the 18 towns is not imported. Members can still
  suggest one; it is kept if a reviewer approves it.
- **Licence:** OpenStreetMap data is © OpenStreetMap contributors, under the
  Open Database License (ODbL). The app says "Map data © OpenStreetMap
  contributors" at the end of the parks list, on every park page, and in
  Settings > About PetLoop. Our `dog_parks` table is a derivative database:
  if we ever publish it as a whole (an export, an API), it must be offered
  under the ODbL too. Showing parks in the app is a "produced work" and
  needs only the credit.
- **Names:** an unnamed park is "Dog park · <street>" ("גינת כלבים ·
  <רחוב>"), the street being the nearest named street from OSM; with the city
  when the context needs it ("Dog park · Ahuza, Ra'anana"). Google is never
  used.
- **Usage policy:** one Overpass query a month, an honest User-Agent
  (`PetLoopParksImport/1.0 (+https://github.com/LimiShani/Pet_Companion; ...)`),
  a server-side timeout (90 s) and a memory budget (64 MB), no retries in a
  loop.

## Import (Edge Function `parks-import`)

`POST {SUPABASE_URL}/functions/v1/parks-import` with header
`x-job-secret: <PARKS_JOB_SECRET>`, body `{}` or `{"force": true}`. Logic in
`supabase/functions/_shared/parks_import.ts`, node tests in
`supabase/functions/_tests/parks_import.test.ts`.

1. If this UTC month already succeeded (`dog_park_import_runs`), answer its
   stats (unless forced).
2. One Overpass query: the parks with their centres (inside OSM's
   boundary of Israel, plus within 3.5 km of each Israeli town of Judea and
   Samaria: `IL_JUDEA_SAMARIA_CODES`, one `around` each, merged in one set),
   then the named vehicle and pedestrian streets within 100 m of any point
   of a park (node parks and the nodes of park outlines), these parks
   included. "around" over the park polygons themselves, or park by park in
   a `foreach`, is refused by the public servers (HTTP 504, checked
   2026-10-10); around the points answers the whole country in about 36 s
   (3.9 MB), inside the function's 150 s; with the 18 extra areas, 41 s
   (3.8 MB) on 2026-10-11.
3. Each park becomes a row: names (`name:he`, `name:en`, else `name` by its
   script), the nearest street (distance to the street's closest segment,
   from the streets whose box comes within 400 m of the park's centre), the
   centre, the nearest locality code within 15 km (a town of Judea and
   Samaria claims only parks within 3.5 km of its centre, so Jerusalem's
   Pisgat Ze'ev, nearer Ma'ale Adumim's centre than Jerusalem's, stays
   `jerusalem`; `parkLocality`), the six details from the
   usual tags (`fence`/`barrier=fence`, `drinking_water`, `shade`/`covered`,
   `lit`, `small_dog`, `bench`), `opening_hours`.
4. `dog_parks_import(period, rows, force)` (service role only) merges them
   in one transaction:
   - a new OSM id is added (`active`);
   - a known one is refreshed, except the fields in its `locked_fields`;
   - a park back on the map after vanishing leaves review by itself;
   - a park no longer on the map moves to `pending_review`
     (`review_reason = 'osm_vanished'`), unless a reviewer decided its
     status; nothing is ever deleted;
   - an answer with less than half of the active OSM parks we hold (when we
     hold at least 20) is refused (`suspicious_import`) unless forced, so a
     broken download never sends every park to review;
   - the run and its stats (`received`, `accepted`, `added`, `refreshed`,
     `reappeared`, `vanished`) are recorded.
5. Failures (`overpass_http_<status>`, `overpass_timeout`,
   `overpass_bad_answer`, `empty_download`, a database refusal) are recorded
   as a `failed` run and answered with HTTP 502; the parks are untouched.

Verified on 2026-10-10: the real answer, run through the import code and
`dog_parks_import()` in the disposable test database, added 704 parks, and
a second run refreshed 704 and added none.

## Database (`0027_dog_parks.sql`)

| Table | What |
|---|---|
| `dog_parks` | `source` (`osm`, `member`, `admin`) + `source_id` (unique together), `name_he`, `name_en`, `street_he`, `street_en`, `lat`, `lng`, `locality_code`, `fenced`, `water`, `shade`, `lighting`, `small_dogs`, `benches` (`yes`/`no`/`unknown`), `opening_hours`, `status` (`active`, `closed` for renovation, `pending_review`, `removed`), `review_reason`, `locked_fields`, `osm_seen_at`, timestamps. Index on `(lat, lng)` for box queries (no PostGIS) and on `locality_code`. |
| `dog_park_suggestions` | `kind` (`new_park`, `details`), `park_id`, `author_id`, `name`, `lat`/`lng` + `location_kind` (`device`: the phone at the park; `locality`: the city's centre with `place_note`), `locality_code`, `changes` (`{"fenced":"yes", ..., "closed": true}`), `status` (`pending`, `approved`, `rejected`), `reviewer_id`, `decided_at`. |
| `dog_park_favorites` | `user_id`, `park_id`, `notify_meetups` (default false; "Tell me about new meetups here", shown and used by meetups, 0028). |
| `dog_park_import_runs` | one row per UTC month: status, stats, error. Service role only. |

Rules (row level security, every permission check in the
`(select public.can_use(...))` once-per-statement form):

- Members with `community.parks.view` read `active` and `closed` parks
  only. Nobody but the service role writes `dog_parks`; reviewers change it
  through security-definer functions with a fixed `search_path`.
- A suggestion is written by its author (`community.parks.suggest`), read
  only by them, and checked by a trigger: known details with
  yes/no/unknown, `closed` true/false, a park members can see, a location
  inside Israel's box; **ten a day per account** (`rate_limited`).
- Favourites belong to their owner.
- Deleting an account deletes its suggestions and favourites; approved
  parks stay.

Functions: `dog_park_review_queue()`, `dog_park_decide(suggestion, action,
edits)` (`approve` / `reject`; `edits` may correct `name`, `lat`, `lng`,
`locality_code`, `street` and any detail), `dog_park_set_status(park,
status)` (`active` = keep, `closed`, `removed`), all for
`community.parks.review` only; `dog_parks_import(period, parks, force)` for
the service role. Approving a detail change locks those fields (and
`status` when it changed); setting a status locks `status`: the import
keeps them.

Capabilities: `community.parks.view` and `community.parks.suggest` (Standard
owners), `community.parks.review` (permission administrators, then whoever
the owner appoints). Disabling the `community` feature disables parks too.

SQL tests: `supabase/tests/dog_parks_test.sql`, run by
`tool/test_database.ps1`.

## The app

- **Where:** Community has a fourth section, **Outside / בחוץ** (Feed ·
  Chat · Outside · Guides), filled by the `outdoors` module through the
  `community-outside` slot. Inside it, a **Partners | Parks** switch (like
  the Store's Deals | My basket); Partners shows first once the meetups
  module fills it ([meetups.md](meetups.md)), Parks otherwise.
- **Where to look:** **Near me** (the phone is asked for one fix only on
  that tap, after saying why; denied, "never" with Open settings, location
  off, outside Israel each have their message) or a city from the bundled
  list (no server call), then **City only / Up to 10 km / Up to 25 km** (near
  me: 10 or 25 km). The position never leaves the phone and is never stored:
  the server is asked for a box widened to a 0.05° grid (about 5.5 km), so
  many positions send the same box; "City only" asks by locality code.
- **The list:** **My parks** first (all saved parks, wherever they are),
  then the area's parks nearest first (distance shown for Near me), each
  with tags for what it is known to have (unknown details are not shown)
  and "Closed for renovation". Filter chips: fenced, small-dog area,
  lighting, water (a park passes when it is known to have all chosen).
  Empty area: "Look further" (to 25 km). At the end: **Missing a park?
  Suggest a park** and the OpenStreetMap credit. Demo data says "Sample
  parks". Park reviewers see **Park suggestions (n)** at the top.
- **Park page:** name, city, distance, closed tag, **Navigate** (Waze or
  Google Maps, by coordinates), **Update details**, the star for **My
  parks**, "What's there" (yes / no / not known for the six details),
  opening hours, a note asking visitors to fill in unknowns, the credit.
  Park reviewers also get *Mark closed* (or *Open again*) and *Remove*
  (hidden, never deleted; asks first). No map in the app in v1.
- **Update details:** each detail as yes / no / not known, and "Closed for
  renovation"; only what changed is sent; nothing changes until a reviewer
  approves.
- **Suggest a park:** optional name; **I'm at the park now** (the position
  is sent as the park's location, and said so) or the city and "Where in
  the city?"; optional details.
- **Review page:** new parks (name, where the location came from, place,
  details, *Show on the map*), detail changes ("Water tap: Not known → Yes",
  closed / open again), parks gone from OpenStreetMap (Keep, Mark closed,
  Remove). Approve / Reject. All decisions are checked on the server.
- **Settings > About PetLoop:** "Dog parks: map data © OpenStreetMap
  contributors, available under the Open Database License (ODbL)."
- **Strings:** `lib/l10n/features/outdoors/` (`OutdoorsL10n`,
  `context.outdoorsL10n`), 121 strings, Hebrew gender-neutral per
  `lib/l10n/GLOSSARY.md`. "Waze", "Google Maps" and "OpenStreetMap
  contributors" are not translated.

### Code map

| Path | What |
|---|---|
| `lib/services/outdoors/data/park_models.dart` | `DogPark`, `ParkDetail`, `ParkAnswer`, `ParkStatus`, suggestions, review queue |
| `lib/services/outdoors/data/park_area.dart` | `ParkArea` (`NearMeArea`, `CityArea`), `ParkRadius`, `coarseBox`, `ParkQuery` |
| `lib/services/outdoors/data/parks_repository.dart` | the interface; `fake_parks_repository.dart` (made-up parks around Ra'anana, Kfar Saba, Tel Aviv-Yafo, Jerusalem; one pending suggestion), `supabase_parks_repository.dart` |
| `lib/services/outdoors/data/park_launcher.dart` | Waze / Google Maps links |
| `lib/services/outdoors/state/parks_providers.dart` | repository, area and filters (`ParksController`), My parks, the listing, the park, the review queue |
| `lib/features/outdoors/module.dart` | slots `community-outside`, `about-credits`; actions `park`, `pick-park`, `suggest-park`, `parks-review` |
| `lib/features/outdoors/outdoors.dart` | the public import for other features |
| `lib/features/outdoors/outside_section.dart` | Partners \| Parks, `OutdoorsKeeper` |
| `lib/features/outdoors/parks/` | list, area picker, park page, update sheet, suggestion form, park picker |
| `lib/features/outdoors/review/` | the reviewers' page |
| `lib/services/findvet/regions/il_localities.dart` | the shared localities (generated) |

`OutdoorsKeeper` keeps the parks providers listened to while the park page,
the forms or the review page cover the section, for the reason given on
`CommunityKeeper` in [community.md](community.md).

## Localities (shared with Find a vet, and meetups next)

`lib/services/findvet/regions/il_localities.dart` (app) and
`supabase/functions/_shared/regions/il_localities.ts` (server) hold 207
localities: every city and town inside OSM's boundary of Israel plus the
local councils OSM tags as villages (189), and the Israeli cities and local
councils of Judea and Samaria (18, below), each with a **stable lowercase code**
(`raanana`, `tel-aviv-yafo`), Hebrew and English names, the centre and the
other spellings. Both are generated by `python tool/gen_il_localities.py`
from `tool/data/il_localities.json` (the source of truth): a run fetches
OSM once and only **adds** places and aliases; codes, names and
coordinates already there never change. The 60 hand-written cities Find a
vet had kept their names, coordinates and aliases. A node test checks the
two files agree. `VetRegion` gains `localityByCode`, `nearestLocality` and
`localitiesWithin`.

**Judea and Samaria** (owner decision 2026-10-11). OSM's boundary of
Israel (the Golan included) leaves out the Israeli towns there, so the
generator adds them from an explicit list, `EXTRA_ISRAELI_LOCALITIES`, with
the same criterion as the rest (cities and local councils; no regional
councils, no Palestinian localities), checked against the local
authorities of the Judea and Samaria Area on 2026-10-11:

- cities: `ariel`, `maale-adumim`, `modiin-illit`, `beitar-illit`;
- local councils: `alfei-menashe`, `beit-aryeh-ofarim`, `beit-el`,
  `efrat`, `elkana`, `givat-zeev` (on its way to city status), `har-adar`,
  `immanuel`, `karnei-shomron`, `kedumim`, `kiryat-arba`, `maale-efraim`,
  `oranit`, `shaar-shomron` (Sha'arei Tikva and Etz Efraim, a council
  since 2022; both names are aliases).

Their centres are fixed, read from OSM's place nodes that day (Sha'ar
Shomron halfway between its two villages); the usual spellings are aliases
("Maale Adumim", "Modiin Illit", "Kiryat Sefer", "Betar Illit"...). They
are appended (codes never change), their JSON entries say
`"area": "judea-samaria"`, and the server's file exports their codes as
`IL_JUDEA_SAMARIA_CODES` for the parks import. Find a vet's bounds (29.3 to
33.5 N, 34.2 to 35.95 E, `il.ts` and `il.dart`) and the `dog_parks` checks
already cover them. Each of them reaches 3.5 km from its centre (the
generator's `JUDEA_SAMARIA_REACH_M`: `reachM` on the app's entries,
`IL_JUDEA_SAMARIA_REACH_M` on the server's): the import takes the parks
that close, and a point further out gets another locality when one is in
range. The app's `VetRegion.nearestLocality` (parks Near me, Suggest a park,
meetups Near me) and the import's `parkLocality` apply the same rule, so a
phone or a park in Pisgat Ze'ev resolves to Jerusalem.

## Hooks for meetups (Partners)

Filled by the meetups module since 0028: see [meetups.md](meetups.md).
Everything below is in `package:pet_companion/features/outdoors/outdoors.dart`:

- **The Partners side:** register a `FeatureSlot` named `outside-partners`
  (`outsidePartnersSlot`) in the meetups module; Outside shows it instead of
  the "coming soon" card. Default the switch with
  `ref.read(outsideViewProvider.notifier).show(OutsideView.partners)` if
  wanted. When meetups has its own capability, widen the
  `community-outside` slot's capability in `outdoors/module.dart` to
  `community.parks.view|community.meetups.view`.
- **On the park page:** two empty slots, `ParkPageSlots.meetups`
  (`park-meetups`: "Meetups at this park", under the details) and
  `ParkPageSlots.postMeetup` (`park-meetup-post`: a button beside Navigate).
  Each gets `parkId`, `parkName` (with the city) and `parkTags`
  (`List<ParkDetail>`). Empty, they take no room.
- **A park picker:** `pickPark(context)` or `openFeature<PickedPark>(context,
  'pick-park', '')`: "My parks" first, then nearest first, in the same area
  as the list; answers `PickedPark(id, displayName, tags, park)` or `null`.
  `openFeature(context, 'park', '', {'parkId': id})` opens a park's page.
- **Areas and radii:** `ParkArea`, `NearMeArea`, `CityArea`, `ParkRadius`
  (city only / 10 / 25 km), `coarseBox`, and the localities helpers above.
  `dog_parks.locality_code` uses the same codes.
- **Saved parks:** `dog_park_favorites.notify_meetups` is stored (false)
  for "tell me about new meetups here"; the meetups module shows its
  switch on the park page and 0028 sends the push.
- **Park cards:** `ParkCard.meetupsSlot` (`park-card-meetups`, with
  `parkId`) under the tags: "Meetup today" / "N meetups this week".
- **Which side shows first:** `OutsideViewController` opens on Partners
  when a module fills `outside-partners` for the account; an account
  without `community.parks.view` sees Partners alone.

## Tests

- `test/outdoors/parks_logic_test.dart`: localities, coarse boxes, queries,
  the listing rules, models, names and distances.
- `test/outdoors/parks_flow_test.dart`: Outside's place and the Partners
  card, Near me (asked only on the tap, a coarse box only), refused
  location and cities, radii, filters, My parks first, the park page
  (details, Waze / Google Maps, saving and a failed save), Update details,
  the daily limit, Suggest a park both ways, errors, empty areas.
- `test/outdoors/parks_review_hebrew_test.dart`: reviewing detail changes,
  new parks and vanished parks, reviewer tools on a park page, members
  kept out, the park picker and the
  park action, the Settings credit, Hebrew at 320 px.
- `test/outdoors/outside_header_fit_test.dart`: with the app's real fonts,
  the four Community sections and the switch fit at 320 px in Hebrew (and
  360 px in English).
- `supabase/functions/_tests/parks_import.test.ts`,
  `supabase/functions/_tests/localities.test.ts` (node).
- `supabase/tests/dog_parks_test.sql` (`tool/test_database.ps1`).

## Limits and open questions

- Coverage is partial and most details are unknown: members' suggestions
  are the way to fill them; a reviewer must approve each one.
- Some OSM `leisure=dog_park` entries are not dog parks (a dog boarding
  place appears as one): a reviewer removes them from the park page
  (*For park reviewers*: Mark closed / Open again / Remove).
- No map in the app (v1): a tile provider is an open question
  (proposal question 10).
- In English at 320 px, "Outside" is cut short in the Community header by
  a few pixels (Hebrew fits); fixing it needs a change in the shared
  `CoralSegmentedControl` (less side padding for four segments).

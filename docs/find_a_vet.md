# Find a vet

Launched for **Israel**, built to add other countries later: everything
country-specific (bounds, languages, phone formats, search radii, the
words the weekly check looks for, the bundled list of localities, the
places provider's region settings) lives in one **region module** per
country, on the server (`supabase/functions/_shared/regions/<code>.ts`)
and in the app (`lib/features/findvet/regions/<code>.dart`). The rest of
the code takes a region and has no country knowledge. Israel (`IL`) is
the only region registered today; see "Adding a country".

Two paths from one entry point:

- **Emergency care**: the nearest facilities that advertise emergency
  service, with Call and Directions on every card, a second option when one
  exists, and no sign-in, form or pet profile needed.
- **Long term care**: nearby practices with their name, location, phone,
  website, published hours and (only when we can source it) species and
  services; Call, Directions and Save (as the pet's regular vet).

This file is the design record and the contract between the app
(`lib/features/findvet/`), the backend (`supabase/functions/`,
`supabase/migrations/0012_vet_directory.sql`) and the weekly job.

## The rule everything else follows

**Nothing in PetLoop says a facility is "available now" because a
directory, Google or its own website says it is open or works 24/7.**
Opening hours do not establish staffing, species, equipment or intake
capacity. Until a facility reports a live status itself, every emergency
card says **"Call to confirm they can receive your pet"**. Calling never
marks anything confirmed.

Real-time emergency intake **cannot be offered** until hospitals send
direct status updates through the reporter API below. Nothing in the app,
the seed data or the demo simulates one.

## Evidence levels (code: `EvidenceLevel`, both sides)

| Level | Code | Comes from | Never comes from |
|---|---|---|---|
| Listed nearby | `listed_nearby` | the places provider found it in this search | - |
| Emergency service advertised | `emergency_advertised` | the facility's own current publication (its website) or a direct facility submission, recorded in our curated database with a source URL and check time, and still found on the latest weekly check | a business name containing "hospital"/"emergency"/"חירום", a directory listing, Google types |
| Published as open | `published_open` | published opening hours (provider's live hours or our curated schedule) - "unknown" when hours are missing | - |
| Accepting now | `accepting_now` | a fresh (`expiresAt` in the future) status sent directly by the facility, or a case-specific confirmation | hours, 24/7 claims, the user having called |

An emergency claim whose evidence disappears on a weekly check (page gone,
wording gone) is **downgraded immediately** to `unverified` and a
high-severity review item is opened; it is never silently kept.

A curated fact older than 30 days without a successful check is shown as
**stale** ("Last checked 12.08.26"), never hidden and never presented as
current.

## Data sources and what each may support

| Source | Supports | Stored by us |
|---|---|---|
| Google Places (Nearby Search, `veterinary_care`) | listed nearby; name, address, location, phone, website, published hours, business status, at search time | **place IDs only** (permitted indefinitely). Other Places content is shown live and never written to our database or the weekly job. Shown with the plain text "Google Maps" (never translated or wrapped) and a link to the place on Google Maps (`mapsUri`). Stored place IDs older than 12 months should be refreshed (free ID-only Place Details call; not automated yet). |
| Facility's own website (first party) | emergency advertised, schedule, phone, address, species/services as published | yes, as claims with source URL + `checked_at` |
| Direct facility / partner submission | anything the facility states, incl. live intake status | yes, `source_kind = 'partner'` |
| Ministry of Agriculture veterinarian register (data.gov.il dataset 345) | that an individual vet with a given licence number exists | **not ingested.** Its fields are licence type and number, name, licence date and specialities: no address, phone, city or clinic, so it cannot place or qualify a facility; a similar name is never treated as proof a practice is licensed. The dataset states no licence; the portal's terms page could not be read (HTTP 403) when checked on 2026-10-03, so bulk reuse waits for the owner to confirm the terms. |

## Matching live results to curated records

`supabase/functions/_shared/matching.ts`

1. **Provider ID**: a stored `(provider, place_id)` link is a match.
2. **Careful heuristic** (only when no ID link exists): all of
   - distance under 120 m,
   - normalized name similarity at least 0.6 (generic words such as
     "vet", "clinic", "hospital", "מרפאה", "וטרינרית", "בית חולים" removed
     before comparing), and
   - same phone number (digits only, Israeli `+972` / leading `0`
     unified) **or** same street + house number.
   A heuristic match is used for that response and recorded as a
   `vet_provider_link_candidates` row (place ID only) for an admin to
   confirm. It never creates a permanent link by itself.
3. Distinct branches stay separate: two branches of a chain share a name
   but not a location/phone, so rule 2 fails and they remain two results.

## API (Edge Function `find-vet`)

`POST {SUPABASE_URL}/functions/v1/find-vet`, JSON. Works without sign-in
(the publishable key only). Every request may carry `"region"` (ISO 3166-1
alpha-2, default `"IL"`); an unknown one answers 400
`{"error": "unsupported_region"}`, and responses echo `"region"`.
Coordinates are validated against that region's bounding box (Israel: lat
29.3-33.5, lng 34.2-35.95); radius 500-50,000 m (provider) and up to the
region's largest curated ladder step (Israel: 120 km) for emergency
records. `{"action": "regions"}` lists the supported regions and their
languages.

### `search`

`mode` is `"emergency"` or `"long_term"`; `lang` must be one of the
region's languages (Israel: `he`, `en`).

```json
{ "action": "search", "region": "IL", "mode": "emergency", "lat": 31.778,
  "lng": 35.235, "radiusM": 10000, "lang": "he" }
```

Response:

```json
{
  "searchedAt": "2026-10-03T10:00:00Z",
  "mode": "emergency",
  "center": { "lat": 31.778, "lng": 35.235 },
  "radiusM": 25000,
  "expanded": true,
  "provider": { "name": "google", "status": "ok", "attribution": "Google Maps" },
  "results": [ VetResult, ... ],
  "notices": ["radius_expanded"]
}
```

`provider.status`: `ok` | `error` | `disabled` (no key configured) |
`quota` (cost cap reached) | `timeout`. When it is not `ok`, results still
contain the curated records for the area (emergency: emergency-advertised
records only, labelled with their check date).

`notices`: `radius_expanded`, `provider_unavailable`, `no_results`,
`curated_unavailable`.

`VetResult`:

```json
{
  "key": "f:7f1c... | g:ChIJ...",
  "facilityId": "uuid or null",
  "placeId": "ChIJ... or null",
  "name": "...", "address": "...",
  "location": { "lat": 0, "lng": 0 }, "distanceM": 1830,
  "phone": "+97226758...", "website": "https://...", "mapsUri": "https://...",
  "fromProvider": true,
  "fromCurated": true,
  "businessStatus": "operational | closed_temporarily | closed_permanently | null",
  "emergency": {
    "state": "advertised | unverified | not_listed",
    "schedule": "24/7 or free text or null",
    "sourceUrl": "https://...", "checkedAt": "iso or null", "confirmedAt": "iso or null"
  },
  "open": {
    "state": "open | closed | unknown",
    "basis": "provider_hours | curated_schedule | none",
    "weekdayText": ["Sunday: 08:00-20:00", "..."]
  },
  "intake": {
    "state": "accepting | limited | diverting | unknown",
    "species": ["dog", "cat"], "updatedAt": "iso or null", "expiresAt": "iso or null"
  },
  "facts": [
    { "key": "species", "value": ["dog", "cat", "exotic"], "sourceUrl": "...", "checkedAt": "iso" },
    { "key": "services", "value": ["surgery", "imaging"], "sourceUrl": "...", "checkedAt": "iso" }
  ],
  "lastCheckedAt": "iso or null",
  "stale": false,
  "reviewStatus": "approved | needs_review | null"
}
```

`intake.state` is computed by the server from `vet_intake_status` and is
`unknown` whenever `expiresAt` has passed; the app applies the same rule
again with its own clock (a response kept on screen expires too).

Ranking (emergency): fresh `accepting`/`limited` intake first, then
`emergency.state = advertised`, then `unverified`, then provider-only
listings; distance within each tier. `diverting` sorts after advertised.
If fewer than 2 advertised results fall inside the radius, the radius is
expanded (10 → 25 → 50 → 120 km for curated records; the provider is
capped at 50 km) and `expanded` / `radius_expanded` are set.

Ranking (long term): distance; closed-permanently results are dropped.
The radius expands 5 → 10 → 20 km when fewer than 3 results are found.

### `geocode`

```json
{ "action": "geocode", "query": "הרצל 10 רחובות", "lang": "he" }
```

→ `{ "results": [ { "label": "...", "lat": 31.89, "lng": 34.81 } ] }`,
restricted to Israel. City names are matched in the app first against a
bundled list of Israeli localities (our own data), so the common case needs
no provider call.

### Errors

`400 {"error": "invalid_request", "detail": "..."}` for bad coordinates or
radius, `429 {"error": "rate_limited"}`, `503 {"error": "unavailable"}`.

### Abuse and cost controls

- Coordinates and radius validated; `maxResultCount` 20; field mask lists
  only the fields above.
- Per-client limit (30 searches / 10 min, keyed by a daily-salted SHA-256
  of the caller IP; raw IPs are never stored) and a global daily cap
  (`VET_DAILY_PROVIDER_CAP`, default 30 provider calls: Nearby Search with
  phone, website and hours bills as Google's Enterprise SKU, 1,000 free
  calls a month, so 30 a day stays inside it; geocoding has its own
  `VET_DAILY_GEOCODE_CAP`, default 300, against 10,000 free a month) in
  `vet_search_quota`, atomically through `vet_search_take()`.
- When the cap is hit the provider is skipped (`provider.status = quota`),
  curated results still return.
- The Google key lives only in the function's secrets
  (`GOOGLE_PLACES_API_KEY`). Restrict it to Places API (New) + Geocoding
  API, and set per-day quotas and a budget alert in Google Cloud.

## Database (`0012_vet_directory.sql`, hardened by `0013`)

| Table | What |
|---|---|
| `vet_facilities` | our curated facility: `country_code` (ISO alpha-2, default `IL`), name (+ Hebrew name), address, city, lat/lng, phone, website, `facility_type`, `review_status` (`pending`, `approved`, `needs_review`, `withdrawn`), `last_checked_at`, `last_confirmed_at`, timestamps |
| `vet_facility_provider_ids` | `(facility_id, provider, place_id)`, unique per provider + place |
| `vet_provider_link_candidates` | heuristic matches awaiting an admin |
| `vet_facility_claims` | one row per sourced claim: `claim_key` (`emergency`, `schedule`, `phone`, `address`, `website`, `species`, `services`), `value` jsonb, `source_url`, `source_kind` (`facility_site`, `partner`, `manual`), `status` (`current`, `unverified`, `conflict`, `withdrawn`), `checked_at`, `confirmed_at`, `evidence_patterns` (what the weekly check looks for) |
| `vet_intake_status` | live, short-lived: `status` (`accepting`/`limited`/`diverting`), `species`, `updated_at`, `expires_at` (at most 6 h after `updated_at`), `reported_by` |
| `vet_case_confirmations` | a case-specific acceptance with its own `reference`, `confirmed_at`, `expires_at` |
| `vet_intake_reporters` | which signed-in accounts may report for which facility |
| `vet_directory_admins` | accounts allowed to review the directory |
| `vet_review_items` | the review queue: `kind`, `severity`, `details`, `status`, unique `dedupe_key` while open |
| `vet_job_runs` | one row per job + ISO week: status, stats, errors |
| `vet_search_quota` | rate-limit counters (hashed buckets, auto-pruned) |

Reads: the app reads approved/needs_review facilities and their current
claims through the view `vet_directory_public` (anonymous read allowed),
and live intake through `vet_intake_current` (expired rows filtered out
by `expires_at > now()`). Nobody but the service role, admins (via RPCs)
and registered reporters can write.

RPCs: `vet_is_admin()`, `vet_admin_review_items()`, `vet_admin_resolve(item, action, note)`,
`vet_admin_set_status(facility, status, note)`, `vet_admin_set_claim(...)`,
`vet_admin_link_place(facility, place_id)`, `vet_report_intake(facility, status, species, ttl_minutes)`,
`vet_confirm_case(facility, reference, accepted, ttl_minutes)`.

## Weekly job (Edge Function `vet-directory-weekly`)

Scheduled by `pg_cron` + `pg_net` every Monday 03:00 Israel time (see
`supabase/scheduling/vet_directory_weekly.sql`); callable by hand.
Protected by a `x-job-secret` header.

For every facility that is `approved` or `needs_review` and every claim
with a `source_url` of kind `facility_site`:

1. Fetch the page (10 s timeout, honest user agent, `robots.txt`
   respected, only the facility's own site domain or a registered partner
   source).
2. Look for the claim's evidence patterns (for `emergency`: e.g.
   `24/7`, `חירום`, `24 שעות`), Israeli phone numbers, and closure wording.
3. Compare with what we hold:
   - emergency evidence found → `checked_at` = now, `status = current`;
   - emergency evidence **gone** (pattern missing, 404/410) → claim
     `unverified` at once + `emergency_evidence_missing` (high);
   - page unreachable (timeout/5xx) → `source_unreachable` (medium); an
     emergency claim with no successful check for 14 days becomes
     `unverified`;
   - our phone missing from a page that lists other numbers →
     `phone_conflict` (medium) with the numbers found;
   - closure wording → `closure` (high), facility to `needs_review`;
   - new emergency wording on a facility without an emergency claim →
     `new_emergency_evidence` (low).
4. `last_checked_at` updated; review items upserted by `dedupe_key`.

Idempotent: one `vet_job_runs` row per ISO week (`period_key`); a rerun of
a finished week returns its stats unless `{"force": true}`; review items
never duplicate; a claim is only downgraded, never re-upgraded, by the job
(re-approval is an admin action with a source). Observable: run row with
counts and per-facility errors, and one structured log line per facility
in the function logs.

The job never calls Google and never stores provider content.

## Review mechanism (admins)

An account listed in `vet_directory_admins` sees **Directory review** in
the side menu: the open review items (most severe first) and every
facility, with Approve, Correct (edit a claim with its source URL),
Withdraw emergency, and Withdraw facility. Every action goes through an
RPC that checks the caller is an admin and writes who/when.

## Privacy

- Location is asked for only when the user taps "Use my location", after
  an explanation; denial leads straight to manual search.
- No search, location or area is stored on the server or the phone. The
  server keeps only hashed rate-limit counters.
- A vet is saved only when the user taps Save (it goes to Health's vets as
  the pet's regular vet, through the normal vet form so the user sees and
  confirms every field).

## Adding a country

1. Server: `supabase/functions/_shared/regions/<code>.ts` (bounds,
   languages, provider region code, phone normalization and scanning
   pattern, matching stop-words, evidence and closure words, radius
   ladders, time zone) and one line in `regions/index.ts`.
2. App: `lib/features/findvet/regions/<code>.dart` (bounds, the bundled
   localities for manual search, phone display, emergency numbers to show
   when nothing is found if the country has a national one) and one line
   in `regions/regions.dart`.
3. Data: curated facilities with that `country_code`, sourced per the
   rules above; check that country's provider terms and any public
   registers' reuse terms before ingesting anything.
4. Strings: the region's language in the `findvet` ARB files if new.

Which region a search uses: the region whose bounds contain the device
location or the chosen place; outside every registered region the app
says Find a vet is not available there yet.

## Limits that remain

- **Real-time emergency intake is not available** until hospitals send
  status updates through `vet_report_intake`. Until then every emergency
  card asks the user to call to confirm.
- The curated seed (two example hospitals that advertise 24/7 emergency
  service on their own sites) is `pending`: an admin must approve it.
- Species and services are shown only where a curated claim with a source
  exists; Google provides neither reliably.
- The Ministry of Agriculture register is not ingested (no
  dataset-specific licence or update schedule is stated; reuse terms to
  be confirmed by the owner).
- The weekly check reads plain HTML; sites that render their content with
  JavaScript produce `source_unreachable`/evidence-missing items for a
  human to resolve.

## The app (`lib/features/findvet/`)

- **Entry points:** "Find a vet" at the top of the side menu (choice of
  path); "Find an emergency vet nearby" in the Emergency sheet behind
  Home's Emergency pill; "Pet emergency? Find a vet" on the sign-in screen,
  which needs no account. The page is pushed over the whole app.
- **Flow:** choice (Emergency care / Long term care), then "Where should
  we look?": *Use my location* (asked only on that tap, after saying why
  and that it is not saved) or a typed city, address or postcode. City
  names match the region's bundled list at once; anything else goes to the
  server's geocoder. The area is shown ("Searching near Rehovot · within
  10 km") with *Change*; a rough device fix (over 1.5 km) says so. The
  Emergency / Long term switch keeps the area.
- **Emergency results:** a "Call before you go" banner; facilities that
  advertise emergency care first, the first two labelled *Nearest option*
  and *Second option*; then *Emergency service not re-confirmed*; then
  *Other vets nearby* (listings, not confirmed). Every card: distance,
  address, the intake line (**"Call to confirm they can receive your pet"**
  unless a fresh facility report exists), the emergency claim with its
  source and check date, published hours, a stale note when due, and Call
  and Directions. Call opens the dialler at once; nothing is marked
  confirmed afterwards. Widening, the live search being down, the phone's
  directory copy, nothing found, rate limits and errors each have their own
  message. "What the labels mean" explains the four levels.
- **Long term results:** practices nearest first with listing, hours,
  species/services only when sourced, Details (published week, website,
  View on Google Maps), Call, Directions and Save. Save (signed in only)
  picks the pet when there are several and opens Health's vet form
  pre-filled, as the pet's regular vet; the owner confirms every field.
- **No connection:** the app reads `vet_directory_public` directly when the
  function fails, and keeps a copy of the region's directory (our own
  records only, never provider listings or searches) for when there is no
  connection at all; results then say when the copy was saved.
- **Demo (no Supabase):** made-up "Demo ..." facilities around the chosen
  place, with a "Sample data" banner and no live status ever.
- **Directory review:** side-menu entry for accounts in
  `vet_directory_admins` (the demo account is one, on made-up data).
- **Hebrew / RTL** throughout (`lib/features/findvet/l10n/`, 168 strings);
  "Google Maps" is never translated.

## Decisions made

- The whole app is behind sign-in, so the emergency path is also reachable
  from the sign-in screen: "usable without sign-in" holds literally.
- Save goes through Health's existing vet form (one vet model, one place to
  edit) and replaces the pet's regular vet; only the place's name, phone
  and address are pre-filled, and only on the owner's explicit Save.
  Provider hours are not copied into the saved vet.
- Location: one fix at medium accuracy, no tracking; Android asks for
  coarse or fine (the owner may choose approximate).
- Directions use coordinates (exact even when address text is not): on
  Android a `geo:` link so the owner picks Waze or Google Maps, elsewhere a
  Google Maps directions link.
- Live intake reports are capped at 6 hours by the database and expire on
  screen by the app's own clock, even on a page left open.
- A facility citing several pages for its emergency service stays
  *advertised* only while every one still shows the evidence.
- The seed's two hospitals start `pending`, with approximate coordinates
  flagged for review: nothing is shown as advertised until an admin
  approves and the weekly check has run.
- Default caps keep Google within its free monthly usage (see Backend
  setup); without a key the feature still works on the curated directory.

## Backend setup

Everything below is done once by the project owner. Nothing here is run
by the app or by the agents. The backend is plain Supabase (free plan) plus
two Edge Functions; the only paid-capable service is Google Maps Platform,
kept inside its free monthly allowance by hard daily caps.

### 1. Database

1. Dashboard > SQL Editor > New query: paste
   `supabase/migrations/0012_vet_directory.sql` and Run (needs 0001; safe to
   run again). Then run `0013_vet_directory_hardening.sql`: it moves the
   owner-rights views and RPCs into the unexposed schema `vet_private` behind
   caller-rights wrappers of the same names, which clears the Security
   Advisor's errors and warnings without changing behaviour.
2. Optional example data: run `supabase/seed/vet_directory_seed.sql`. It adds
   the Hebrew University Veterinary Teaching Hospital and Vet Center (Rosh
   HaAyin) as **pending** (not shown until approved), with their emergency
   claims and sources, `checked_at` empty (nothing checked yet), no live
   status, and an open `verify_coordinates` review item each (their
   coordinates are approximate).
3. Make yourself a directory admin. Your user id is in Dashboard >
   Authentication > Users:
   ```sql
   insert into public.vet_directory_admins (user_id) values ('<your auth user id>');
   ```
   A facility's staff account that may send live intake status (future):
   ```sql
   insert into public.vet_intake_reporters (facility_id, user_id) values ('<facility id>', '<user id>');
   ```

### 2. Google Cloud key (optional: without it the search returns curated records only)

1. Google Cloud console: create a project and attach a **billing account**
   (required even when usage stays inside the free allowance).
2. APIs & Services > Library: enable **Places API (New)** and **Geocoding
   API**, nothing else.
3. Credentials > Create credentials > API key. Restrict it: *API
   restrictions* = Places API (New) + Geocoding API. (Edge Functions have no
   fixed outbound IP, so an IP restriction is not possible; the API
   restriction, quotas and the budget alert are the guard rails. The key
   never leaves the function's secrets.)
4. Quotas (APIs & Services > the API > Quotas): Places API (New)
   `SearchNearby` requests per day about 33; Geocoding requests per day about
   330. These sit just above the function's own caps, as a second fence.
5. Billing > Budgets & alerts: a small monthly budget (for example $5) with
   e-mail alerts at 50 % / 90 % / 100 %.

Cost arithmetic (October 2026 prices; check the current price list):

- A Nearby Search whose field mask includes phone, website or opening hours
  bills at the **Enterprise** SKU: 1,000 free calls per month, then about
  $35 per 1,000. Every `search` makes at most one Nearby Search call. With
  `VET_DAILY_PROVIDER_CAP = 30`: 30 x 31 days = 930 calls a month at most,
  inside the free 1,000. Past the cap, searches still answer with curated
  records (`provider.status = "quota"`).
- Geocoding: 10,000 free calls per month. `VET_DAILY_GEOCODE_CAP = 300`
  gives at most 9,300 a month. Past it, `geocode` answers 503 and the app's
  bundled locality list still works.
- Caps count per UTC day in `vet_search_quota` (atomically, through
  `vet_search_take`).

### 3. Deploy the functions

From the repository root, with Node installed (`npx` fetches the Supabase
CLI on first use):

```sh
npx supabase login
npx supabase link --project-ref <project-ref>
npx supabase functions deploy find-vet
npx supabase functions deploy vet-directory-weekly
```

`supabase/config.toml` sets `verify_jwt = false` for both (the search works
without sign-in; the weekly job checks its own secret). If you deploy any
other way (for example the Dashboard's function editor, which then needs
every file of `supabase/functions/_shared/` too), turn **Enforce JWT
verification** off for both functions.

### 4. Secrets

Dashboard > Edge Functions > Secrets, or:

```sh
npx supabase secrets set GOOGLE_PLACES_API_KEY=<key from step 2>
npx supabase secrets set VET_JOB_SECRET=<a long random string, e.g. openssl rand -hex 32>
npx supabase secrets set VET_DAILY_PROVIDER_CAP=30 VET_DAILY_GEOCODE_CAP=300
```

| Secret | Used by | Default |
|---|---|---|
| `GOOGLE_PLACES_API_KEY` | find-vet | none: provider disabled (`provider.status = "disabled"`) |
| `VET_DAILY_PROVIDER_CAP` | find-vet | 30 Nearby Search calls per UTC day |
| `VET_DAILY_GEOCODE_CAP` | find-vet | 300 Geocoding calls per UTC day |
| `VET_QUOTA_SALT` | find-vet | the service role key (mixed into the hashed client key) |
| `VET_JOB_SECRET` | vet-directory-weekly | none: the job refuses to run (503) |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase.

### 5. Schedule the weekly check

Open `supabase/scheduling/vet_directory_weekly.sql`, replace
`<project-ref>` and `<same as VET_JOB_SECRET>`, and run it in the SQL
editor. It enables `pg_cron` + `pg_net`, stores the project URL and the
secret in Vault, and schedules `vet-directory-weekly` for `0 0 * * 1`
(Monday 00:00 UTC = 03:00 Israel summer time, 02:00 in winter). Running it
again replaces the schedule.

Run the job once by hand (the answer contains the week's stats):

```sh
curl -X POST "https://<project-ref>.supabase.co/functions/v1/vet-directory-weekly" \
  -H "Content-Type: application/json" \
  -H "x-job-secret: <VET_JOB_SECRET>" \
  -d '{}'
```

`-d '{"force": true}'` redoes a week that already finished (review items
are never duplicated). In PowerShell call `curl.exe` (not the `curl`
alias). The SQL file also shows the same call through `net.http_post` and
how to read `vet_job_runs` and the cron history.

Smoke test of the search:

```sh
curl -X POST "https://<project-ref>.supabase.co/functions/v1/find-vet" \
  -H "Content-Type: application/json" -H "apikey: <publishable key>" \
  -d '{"action": "regions"}'
```

### 6. Tests (no network, no Supabase, no Deno needed)

From the repository root, with Node 24 (it runs the TypeScript directly):

```sh
node --test "supabase/functions/_tests/*.test.ts"
```

Keep the quotes (Node expands the glob itself; the bare directory form
`node --test supabase/functions/_tests/` does not work). The shared code
uses only web-standard APIs, so the same files run on Deno in the Edge
runtime.

### Backend reference (what the app can call)

- `POST /functions/v1/find-vet`, actions `search`, `geocode`, `regions`
  (see "API"). `mode` is `"emergency"` or `"long_term"`. `geocode` answers
  `{"region": "IL", "results": [...]}`. `regions` answers
  `{"regions": [{"code": "IL", "languages": ["he", "en"], "defaultLanguage": "he"}], "defaultRegion": "IL"}`.
  `provider.attribution` is `"Google Maps"` when the response holds
  provider content and `null` otherwise; every provider result keeps
  `mapsUri` (Google's link to the place). Show "Google Maps" as plain,
  untranslated text.
- Views (anon + authenticated): `vet_directory_public` (`id, country_code,
  name, name_he, address, city, lat, lng, phone, website, facility_type,
  review_status, last_checked_at, last_confirmed_at, emergency, facts`) and
  `vet_intake_current` (`facility_id, status, species, updated_at,
  expires_at`). A facility may cite several pages for its emergency claim:
  `emergency.state` is `advertised` only while every one of them is current
  and checked (or admin-confirmed); `checkedAt` is the oldest of their
  checks.
- Admin RPCs (signed in, listed in `vet_directory_admins`; otherwise error
  `42501`): `vet_is_admin()`, `vet_admin_review_items()`,
  `vet_admin_facilities()` (also returns `country_code`),
  `vet_admin_resolve(p_item, p_action, p_note)`,
  `vet_admin_set_status(p_facility, p_status, p_note)`,
  `vet_admin_set_claim(p_facility, p_key, p_value, p_source_url, p_source_kind, p_note)` (returns the claim id),
  `vet_admin_withdraw_claim(p_facility, p_key, p_note)`,
  `vet_admin_link_place(p_facility, p_place_id)`.
- Reporter RPCs (future): `vet_report_intake(p_facility, p_status,
  p_species, p_ttl_minutes)` returns `expires_at`;
  `vet_confirm_case(p_facility, p_reference, p_accepted, p_ttl_minutes)`;
  `vet_case_status(p_reference)` (anon allowed; references are 8-64
  characters).
- Service role only (Edge Functions): `vet_search_take`,
  `vet_upsert_review_item`, `vet_record_link_candidate`.

Open items for the owner:

- Google place IDs may be stored indefinitely but should be refreshed when
  older than 12 months. TODO: an admin-side refresh (the weekly job never
  calls Google, by design).
- The data.gov.il veterinarian register has no address, phone or clinic
  fields, no licence on the dataset, and its terms page was not reachable
  (403): nothing to ingest.

### Adding a country (server side)

1. Copy `supabase/functions/_shared/regions/il.ts` to `<code>.ts` (lower
   case ISO 3166-1 alpha-2) and fill every field of `RegionConfig`
   (`regions/types.ts`): bounding box(es), provider region code and geocode
   `components`, default + supported languages, the emergency and long-term
   radius ladders, phone calling code + trunk prefix + a scanning pattern,
   name stop-words (and glued prefixes, if the language has them), street
   words, default evidence patterns per claim key, closure words, time zone.
2. Add it to `REGIONS` in `regions/index.ts` (one line).
3. Add a test with real local samples (phone formats, a name with generic
   words, a closure sentence) next to the ZZ tests in
   `supabase/functions/_tests/`, run the tests, redeploy both functions.
4. Data: curated facilities with that `country_code` (phones in E.164),
   sourced per "Data sources" above; check the provider's terms for the
   country and any public register's reuse terms first. Nothing in the
   database changes: `country_code` already separates the countries.

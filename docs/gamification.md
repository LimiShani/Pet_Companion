# Gamification: milestones, rhythm, standing, shopper tiers

Plan of 13 October 2026, agreed in conversation with the owner. Nothing in
this document is built yet; the phases at the end say what comes first.

## Decisions

* **Quiet by design.** Rewards are about the pet's care, not app usage. No
  points on screen, no streaks that break, no red dots, no push
  notifications for any of this. At most one celebration per session, as a
  card tone change plus one sentence.
* **Standing unlocks capabilities, through the feature-access system.**
  Built as a foundation now: the groups and the mapping exist, the rules
  stay permissive.
* **Beta testers are never limited.** Everyone in the early beta belongs to
  a `beta_testers` access group that grants every capability. Gating is
  switched on later by changing group rules, with no app release.
* **Social layer is tag-only for now.** A standing tag next to the name in
  feed and chat; no monthly list, no leaderboard.
* **Shoppers get coupons, deals and tiers with built-in benefits.** See the
  shopper section: it needs a verified-purchase source, which the Store
  does not have today.

## The four layers

### 1. Pet milestones

A catalogue of about 25 moments derived from tables that already exist:

| Milestone | Source |
|---|---|
| First 30 days completed | `pet_first_days` |
| Emergency card complete | `lost_pet_cards`, `emergency_kit_items`, `vets` |
| Health profile complete | `health_profiles` |
| 30 / 100 / 365 walks, 100 meals | `care_logs` |
| Medication course finished | `medications`, `care_logs` |
| Weight tracked for 3 months | `health_observations` |
| First vet visit recorded, vaccinations up to date for a year | `health_events` |
| First photo shared, first meetup attended | `community_posts`, `community_meetup_answers` |

Phrased about the pet ("Kelly: 100 walks logged"). Shown as a "Moments"
row on the pet profile and once on the Home card's metric line the day
they happen. An unseen moment puts a sage tag on the pet pill; no counts.

### 2. Care rhythm (the personal ladder)

Per pet, three states: Settling in, Steady, Thriving (Hebrew names to be
chosen). Computed from the on-time rate of planned care over a rolling 28
days; 70% counts as Thriving. A missed day lowers the rate a little, the
next logged day raises it. Three days without logs pauses the rhythm
("Paused"), never a failure. One `AppTag` on the pet hero; tapping it shows
one sentence.

### 3. Community standing (the social ladder, tag-only)

* One new user action: **"This helped"** on a reply or a chat answer. Only
  the asker, once per thread.
* Levels Member, Regular, Helper, Guide, from helped marks, reactions
  received and the absence of upheld reports. An upheld report drops the
  level; it is regained slowly.
* Shown as a small tag next to the name in feed and chat. Nothing else in
  this phase.
* Foundation for unlocking: each level is an access group
  (`standing_regular`, `standing_helper`, `standing_guide`) whose
  membership the nightly rollup maintains. Capabilities that would later
  be gated: `community.rooms.create`, `store.ads.extra`,
  `outdoors.parks.suggest_unreviewed`, `community.moderate.invite`. During
  the beta the `beta_testers` group grants them all.

### 4. Shopper tiers, coupons and deals

**What a purchase is today.** The Store links out to the seller; there is
no checkout. The basket's "bought" is a self-report that records an
expense (`access_private.record_basket_purchase`). That is fine for a
budget, not for a tier that pays out benefits. Three purchase signals,
strongest first:

1. **Coupon redemption confirmed by the partner.** The user claims a
   coupon in the app and gets a unique code; the partner reports redeemed
   codes (a postback to an Edge Function, or a weekly CSV uploaded by an
   admin). The partner sees a code, never the user.
2. **Affiliate conversion.** Where a seller has an affiliate programme, the
   deal link carries a tracking id and the network's postback lands in the
   same Edge Function.
3. **Self-report** ("Bought it" on a deal or basket item, optional receipt
   photo). Counts at low weight, capped per month. Enough for the beta.

**Tiers.** Shopper, Regular shopper, Trusted shopper (names and Hebrew to
be chosen). Based on verified purchases in a rolling 12 months; a tier is
kept for the whole period after it is reached and then re-evaluated, so it
never drops mid-year. Self-reports alone cannot reach the top tier.

**Built-in benefits.**

* Tier-exclusive coupons (`min_tier` on the offer).
* Early access: new deals visible to Regular and Trusted shoppers 24 hours
  before everyone else.
* Deal alerts for saved categories, opt-in, delivered in-app and, if the
  user turns it on, by push. This is the one place push is allowed, because
  it is a benefit the user asked for, not a nudge.
* A pet-birthday coupon and partner free-shipping codes when partners
  provide them.

Tiers and coupons have no cash value and are not transferable. PetLoop is
not the seller; the partner's own terms apply to the purchase.

## Data model (all server-side, RLS on every table)

| Table | Purpose |
|---|---|
| `milestone_catalog` | id, feature, rule name, copy keys, icon id |
| `pet_milestones` | pet, milestone, reached_at, seen_at |
| `care_rhythm` | pet, state, rate, paused_since, computed_at |
| `helped_marks` | thread kind + id, answer id, asker, answerer, created_at |
| `member_standing` | profile, level, helped_count, reaction_count, computed_at |
| `coupon_offers` | partner, title, terms, code kind (shared / unique), min_tier, valid window, max claims |
| `coupon_claims` | user, offer, code, claimed_at, redeemed_at, verified_by |
| `purchase_events` | user, source (coupon / affiliate / self), deal, amount, currency, verified, occurred_at |
| `partner_postbacks` | raw inbound record, partner, received_at (kept 90 days) |
| `shopper_standing` | user, tier, verified_count, verified_value, computed_at |
| `partners` | name, contact, secret hash, postback format, affiliate tag |

Computation: a nightly `pg_cron` rollup (`gamification_rollup()`) plus
light triggers on `care_logs` and the community tables for same-day
milestones. One Edge Function `partner-postback` (per-partner secret,
idempotent on code). An admin page under Admin tools to add partners and
offers, and to upload a redemption CSV. No client-side counting, so it is
cheat-resistant and survives the offline write queue.

## App surfaces

* Pet profile: "Moments" row. Home card: milestone sentence on the day.
* Pet hero: rhythm tag. Feed and chat: standing tag by the name.
* Store: a "Coupons" segment (header segment row, max three segments keeps:
  Deals / Basket / Coupons), tier shown once at the top of Coupons, early
  deals marked with the one `AppTag`.
* You page: one row "Milestones and tiers" that opens a short overview;
  Settings: "Show milestones and rhythm" (default on), "Deal alerts"
  (default off).
* One reusable `MilestoneMoment` widget; one `StandingTag` widget.
* Every new screen gets the 320 px EN/HE fit test.

## Legal and privacy

* Privacy policy: new rows for derived standing, helped marks, purchase
  events and coupon claims; what partners receive (a code, a conversion
  id; never name or email).
* Terms: standing, tiers and coupons have no cash value, are not
  transferable, can be withdrawn after moderation; deal links may be
  affiliate links (disclosure in the Store header sentence, said once).
* Coupon terms per offer, shown before claiming; loyalty-club style rules
  under Israeli consumer protection law (clear terms, expiry notice,
  cancellation) go to the lawyer with the pending review.
* Partner agreements: data processing (codes only), who honours a coupon
  dispute, reporting cadence.

## Phases

0. **Foundations (2 to 3 days):** tables, catalogue, rollup job, access
   groups incl. `beta_testers`, SQL tests, privacy and terms text.
1. **Pet layer (3 days):** milestones, rhythm tag, Moments row, Home card
   sentence, fit tests.
2. **Community layer (3 days):** helped marks, standing, tags, moderation
   hook, group membership maintained by the rollup.
3. **Shopper layer (4 to 5 days):** partners and offers admin, coupon
   claims with unique codes, self-report with cap, postback Edge Function,
   tiers, Coupons segment, early access, deal alerts opt-in. One friendly
   partner seeded to test the loop end to end.
4. **Measure:** logs per pet per week and 28-day return for the pet layer;
   helped-mark rate for the social layer (under 5% after a month: keep the
   pet layer, remove the social one); coupon redemption rate for shoppers.

## Open

* Names of rhythm states, standing levels and shopper tiers, in Hebrew.
* First partner for the coupon loop.
* Whether self-reports need a receipt photo in the beta.

## Threat model (review of 13 October 2026)

High:
1. Sybil accounts: standing and coupon claims need an account older than
   14 days, a confirmed email and a pet with logs; helped marks count only
   from distinct askers who pass the same bar. Check that email
   confirmation is on in Supabase Auth.
2. Postback forgery/replay: per-partner HMAC over body + timestamp, 5-minute
   window, idempotency on the code, per-partner daily cap, body size limit,
   reject before parsing, secrets in Vault, rotation.
3. Coupon enumeration/sharing: 12+ random characters, one claim per user per
   offer, rate-limited claims, redemption bound to the claim, max claims
   and expiry on offers.
4. Backdated/bulk care logs: rollup trusts server `created_at`, backdating
   limited to 7 days, per-pet daily cap, rate-limited trigger.
5. Early access and tier-only coupons enforced in RLS, never in the client.

Medium:
6. Standing drops only on an upheld moderator decision, never on the
   3-report auto-hide (which is sock-puppet-able today); the queue shows
   reporter account age.
7. Reciprocity rings: same asker→answerer counts once per 30 days; a
   pairwise reciprocity ratio above 60% zeros both.
8. Self-reports capped, cannot reach the top tier; receipt photos in a
   private bucket, size-limited, no server-side image processing.
9. Partner compromise: per-partner caps, anomaly check in the rollup,
   append-only admin audit for offers and partners.
10. Admin CSV upload: strict format, row limit, codes validated against
    existing claims, no formula-capable export.
11. No insert policy on access group membership for users; only the rollup
    (definer function, narrow grants) writes it; bump `access_revision`.
12. Rollup batched by pet with `statement_timeout`, resumable.

Low:
13. Shopper tier is never public. 14. Opaque per-click affiliate ids.
15. Coupon code disclosed as data the partner can link to the buyer.
16. Deal alerts enqueued only from admin-created offers, capped per user
    per day, opt-out in Settings. 17. Helped marks `set null` the asker on
    account deletion instead of cascading. 18. Public repo: all controls in
    RLS/functions; no partner names or secrets in migrations or seeds.

## Phase 0 status (13 October 2026, branch `feat/gamification-foundation`)

Built: `supabase/migrations/0029_rewards_foundation.sql`, the schedule
`supabase/scheduling/rewards_rollup.sql`, the postback signature check
`supabase/functions/_shared/partner_auth.ts`, tests
`supabase/tests/rewards_foundation_test.sql` and
`supabase/functions/_tests/partner_auth.test.ts`, privacy policy and terms
version 1.1 (EN/HE). No app screens yet.

Capability names follow the app's rule that `a.b.c` needs `a.b.view`:
`rewards.view`, `rewards.mark_helped`, `rewards.claim_coupons`,
`rewards.report_purchase` (everyone); `community.chat.rooms_create`
(Regular), `community.parks.suggest_direct` (Helper),
`store.deals.share_extra` (Guide). The beta testers group holds all of them.

### Owner steps

1. Apply `0029_rewards_foundation.sql` in the SQL editor.
2. Run `supabase/scheduling/rewards_rollup.sql` once (pg_cron, every 10
   minutes; no secret needed).
3. Supabase Dashboard > Authentication > Sign In / Providers > Email: turn
   on **Confirm email**. With it off, Supabase marks every address
   confirmed at sign-up and the "confirmed email" check means nothing.
4. Republish `docs/legal` (GitHub Pages): privacy and terms are at 1.1.
5. When the beta ends: `update rewards_private.settings set beta_auto_join =
   false;` and empty the "Beta testers" group in Admin tools.
6. Thresholds live in `rewards_private.settings`: `trusted_account_age`
   (14 days; standing and coupons) and `reporter_account_age` (3 days;
   auto-hide). They apply to beta testers too: a brand-new tester can use
   every feature but cannot claim a coupon or earn standing for 14 days.

### Threat model: where each item stands

| Item | Status |
|---|---|
| 1 Sybil accounts | Done: trusted-account rule for standing, helped marks and coupons |
| 2 Postback forgery/replay | Done in the database (idempotent per external id, daily cap, size limit, service role only) and in `partner_auth.ts` (HMAC, 5-minute window, streamed size limit). The Edge Function that wires them is Phase 3 |
| 3 Coupon codes | Done: 64-bit random codes, one claim per member per offer, 10 claims a day, max claims, expiry |
| 4 Backdated/bulk logs | Done: `server_logged_at`, 7-day backdating limit, 6 walks / 8 meals a day, 500 logs an hour |
| 5 Early access, tier coupons | Done in RLS |
| 6 Report-bombing | Done: auto-hide needs established reporters; standing drops only on an upheld removal; moderators see reporter ages |
| 7 Rings | Done: once per asker per 30 days, reciprocal pairs zeroed |
| 8 Self-reports | Done: 4 a month, once per deal, cannot reach the top tier. Receipt photos: Phase 3 |
| 9 Partner compromise | Done: daily cap, automatic pause on a jump, append-only audit |
| 10 Admin CSV | Done in the database (500 codes a call, format check, only that partner's claims). The upload screen is Phase 3 |
| 11 Group self-grant | Done: members cannot write groups, standing, milestones or tiers (tested) |
| 12 Rollup cost | Done: batches, time budget, resumable, advisory lock, statement timeout |
| 13 Tier privacy | Done: owner-only RLS |
| 14 Affiliate ids | Phase 3 (link building) |
| 15 Code disclosure | Done: privacy policy 1.1 |
| 16 Deal alerts | Phase 3 (push kind with a daily cap) |
| 17 Deleted askers | Done: `asker_id` set null, marks kept |
| 18 Public repo | Done: no partner names or secrets in migrations or seeds |

Found and fixed on the way (not in the original list): members could set
`created_at` on posts, comments, messages and reports, and `posted_at` on
deals (a row dated 2099 stayed on top, a backdated one escaped the rate
limits, a pre-dated report re-hid an item after a moderator kept it); and a
request carrying many rows in one insert bypassed the per-row rate limits.

### Not in Phase 0

App screens and the Dart capability catalog (`packages/petloop_access`):
until Phase 1 the new capabilities are unknown to the app, so the
permissions screen does not list them and the app treats them as off.

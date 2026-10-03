-- PetLoop: optional example data for "Find a vet" (needs 0012_vet_directory.sql).
-- Run in the Supabase SQL editor after the migration. Safe to run more than once.
--
-- Two Israeli facilities whose OWN websites advertise round-the-clock
-- emergency service. Facts below were read from those pages on 2026-10-03.
--
-- On purpose:
--   * review_status = 'pending': nothing is shown until an admin approves it
--     (vet_admin_set_status(..., 'approved', ...)).
--   * checked_at is NULL on every claim: the weekly job has not run yet, so
--     nothing is "checked". Until it runs (or an admin confirms a claim with
--     vet_admin_set_claim) the emergency state stays 'unverified'.
--   * No vet_intake_status rows: a live status is never seeded or simulated.
--   * Coordinates are APPROXIMATE (not verified on the ground or against an
--     authoritative source); each facility gets an open 'verify_coordinates'
--     review item so an admin checks them before relying on distances.
--
-- Fixed UUIDs make the inserts idempotent (on conflict do nothing).

begin;

-- ---------------------------------------------------------------------------
-- Hebrew University Veterinary Teaching Hospital (Koret School), Rishon LeZion
-- Address and phone: https://vethospital.huji.ac.il/contact%20us
-- (03-9688588; the hospital also lists the short number *8818).
-- ---------------------------------------------------------------------------
insert into public.vet_facilities
  (id, country_code, name, name_he, address, city, lat, lng, phone, website, facility_type, review_status)
values (
  '2f6c1d0e-6a51-4b0f-9a52-7d1e00000001', 'IL',
  'Hebrew University Veterinary Teaching Hospital',
  'בית החולים הווטרינרי האוניברסיטאי ע"ש קורת',
  'דרך המכבים 70, הקריה החקלאית', 'ראשון לציון',
  -- Checked 2026-10-03: within a few metres of the hospital building's own
  -- map listing (the street-address point at the Beit Dagan junction is
  -- ~770 m away). Approximate to 4 decimals, not copied from any provider.
  31.9946, 34.8226,
  '+97239688588',
  'https://vethospital.huji.ac.il/',
  'hospital',
  'pending'
)
on conflict (id) do nothing;

-- Emergency, primary source: the hospital's emergency page. Inserted with
-- an earlier created_at so the public view picks it as the primary source.
insert into public.vet_facility_claims
  (id, facility_id, claim_key, value, source_url, source_kind, status, evidence_patterns, checked_at, created_at)
values (
  '2f6c1d0e-6a51-4b0f-9a52-7d1e00000101', '2f6c1d0e-6a51-4b0f-9a52-7d1e00000001',
  'emergency', '{"schedule": "24/7"}'::jsonb,
  'https://vethospital.huji.ac.il/emergency', 'facility_site', 'current',
  array['24 שעות ביממה', 'תורן'], null, now() - interval '2 seconds'
)
on conflict do nothing;

-- Emergency, second source: the "about" page.
insert into public.vet_facility_claims
  (id, facility_id, claim_key, value, source_url, source_kind, status, evidence_patterns, checked_at, created_at)
values (
  '2f6c1d0e-6a51-4b0f-9a52-7d1e00000102', '2f6c1d0e-6a51-4b0f-9a52-7d1e00000001',
  'emergency', '{"schedule": "24/7"}'::jsonb,
  'https://vethospital.huji.ac.il/book/%D7%90%D7%95%D7%93%D7%95%D7%AA', 'facility_site', 'current',
  array['24 שעות ביממה'], null, now() - interval '1 second'
)
on conflict do nothing;

-- Species, as published on the emergency page.
insert into public.vet_facility_claims
  (id, facility_id, claim_key, value, source_url, source_kind, status, evidence_patterns, checked_at)
values (
  '2f6c1d0e-6a51-4b0f-9a52-7d1e00000103', '2f6c1d0e-6a51-4b0f-9a52-7d1e00000001',
  'species', '["dog", "cat"]'::jsonb,
  'https://vethospital.huji.ac.il/emergency', 'facility_site', 'current',
  '{}', null
)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Vet Center, Rosh HaAyin (single branch)
-- ---------------------------------------------------------------------------
insert into public.vet_facilities
  (id, country_code, name, name_he, address, city, lat, lng, phone, website, facility_type, review_status)
values (
  '2f6c1d0e-6a51-4b0f-9a52-7d1e00000002', 'IL',
  'Vet Center',
  null, -- the Hebrew trade name was not confirmed on the site; left empty
  'המרץ 7', 'ראש העין',
  -- From the clinic's own website (its Waze link, waze.com/ul?ll=...),
  -- read 2026-10-03. The first seed guess was 2.3 km off.
  32.10562482, 34.93914127,
  '+97299668133',
  'https://www.vetcenter.co.il/',
  'other', -- its type (hospital / clinic) was not confirmed; correct it in the SQL editor once known
  'pending'
)
on conflict (id) do nothing;

insert into public.vet_facility_claims
  (id, facility_id, claim_key, value, source_url, source_kind, status, evidence_patterns, checked_at)
values (
  '2f6c1d0e-6a51-4b0f-9a52-7d1e00000201', '2f6c1d0e-6a51-4b0f-9a52-7d1e00000002',
  'emergency', '{"schedule": "24/7"}'::jsonb,
  'https://www.vetcenter.co.il/emergency/', 'facility_site', 'current',
  array['24 שעות ביממה', 'חירום'], null
)
on conflict do nothing;

insert into public.vet_facility_claims
  (id, facility_id, claim_key, value, source_url, source_kind, status, evidence_patterns, checked_at)
values (
  '2f6c1d0e-6a51-4b0f-9a52-7d1e00000202', '2f6c1d0e-6a51-4b0f-9a52-7d1e00000002',
  'species', '["dog", "cat"]'::jsonb,
  'https://www.vetcenter.co.il/emergency/', 'facility_site', 'current',
  '{}', null
)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Review items: check the approximate coordinates. Inserted only if no item
-- with the same dedupe key exists in any state, so a resolved one is not
-- reopened by running this file again.
-- ---------------------------------------------------------------------------
insert into public.vet_review_items (facility_id, kind, severity, details, dedupe_key)
select v.facility_id, 'verify_coordinates', 'medium', v.details, v.dedupe_key
from (values
  ('2f6c1d0e-6a51-4b0f-9a52-7d1e00000001'::uuid,
   '{"reason": "seed coordinates are approximate", "lat": 31.9946, "lng": 34.8226}'::jsonb,
   'verify_coordinates:2f6c1d0e-6a51-4b0f-9a52-7d1e00000001'),
  ('2f6c1d0e-6a51-4b0f-9a52-7d1e00000002'::uuid,
   '{"reason": "seed coordinates are approximate", "lat": 32.1027, "lng": 34.9631}'::jsonb,
   'verify_coordinates:2f6c1d0e-6a51-4b0f-9a52-7d1e00000002')
) as v (facility_id, details, dedupe_key)
where not exists (select 1 from public.vet_review_items i where i.dedupe_key = v.dedupe_key);

commit;

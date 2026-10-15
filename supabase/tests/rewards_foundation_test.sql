\set ON_ERROR_STOP on
-- Disposable database only. Rewards foundation and community hardening
-- (0029_rewards_foundation.sql): server time, bulk rate limits, reports from
-- new accounts, beta and standing groups, helped marks, the rollup
-- (milestones, rhythm, standing, shopper tiers), coupons, partner
-- redemptions, early access and the append-only audit.
begin;

insert into auth.users(id, email) values
 ('a1111111-1111-4111-8111-111111111111', 'ada@example.test'),
 ('a2222222-2222-4222-8222-222222222222', 'ben@example.test'),
 ('a3333333-3333-4333-8333-333333333333', 'cy@example.test'),
 ('a6666666-6666-4666-8666-666666666666', 'mod@example.test'),
 ('a7777777-7777-4777-8777-777777777777', 'ron@example.test'),
 ('a8888888-8888-4888-8888-888888888888', 'dan@example.test'),
 ('a9999999-9999-4999-8999-999999999999', 'avi-admin@example.test');
-- A brand-new account and an old one whose email was never confirmed.
insert into auth.users(id, email, created_at) values
 ('a4444444-4444-4444-8444-444444444444', 'noa-new@example.test', now());
insert into auth.users(id, email, email_confirmed_at) values
 ('a5555555-5555-4555-8555-555555555555', 'uri-unconfirmed@example.test', null);
insert into public.user_capability_rules(user_id, capability, allowed)
values ('a6666666-6666-4666-8666-666666666666', 'community.moderate', true);
insert into public.access_admins(user_id) values ('a9999999-9999-4999-8999-999999999999');

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub', p::text, true);
 perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.refused(statement text, code text, words text default null, why text default '')
returns void language plpgsql as $$
begin
 execute statement;
 raise exception 'Accepted, expected a refusal: % (%)', why, statement;
exception when others then
 if sqlerrm like 'Accepted, expected a refusal%' then raise; end if;
 if sqlstate <> code or (words is not null and position(words in sqlerrm) = 0) then
  raise exception 'Expected % % for "%" (%), got % %', code, coalesce(words, ''), statement, why, sqlstate, sqlerrm;
 end if;
end $$;
-- A pet with one done walk yesterday: what "a pet with logs" means.
create function pg_temp.owner_with_pet(p_owner uuid, p_pet uuid, p_name text) returns void language sql as $$
 insert into public.pets(id, owner_id, name) values (p_pet, p_owner, p_name);
 insert into public.care_logs(pet_id, owner_id, kind, due_on, status) values (p_pet, p_owner, 'walk', current_date - 1, 'done');
$$;
create function pg_temp.deal(p_title text, p_by uuid default null) returns uuid language sql as $$
 insert into public.store_deals(title, category, price, original_price, seller_name, link, shared_by)
 values (p_title, 'toys', 10, 20, 'Toy Barn', 'https://example.test/deal', p_by) returning id
$$;
create function pg_temp.rollup() returns jsonb language sql as $$
 update rewards_private.rollup_state set run_on = null;
 select rewards_private.rollup_step(200, interval '60 seconds');
$$;
create temp table ids(name text primary key, id uuid);
grant all on ids to authenticated, service_role;

select pg_temp.owner_with_pet('a1111111-1111-4111-8111-111111111111', 'b1111111-0000-4000-8000-000000000001', 'Kelly');
select pg_temp.owner_with_pet('a2222222-2222-4222-8222-222222222222', 'b2222222-0000-4000-8000-000000000001', 'Rex');
select pg_temp.owner_with_pet('a3333333-3333-4333-8333-333333333333', 'b3333333-0000-4000-8000-000000000001', 'Miso');
select pg_temp.owner_with_pet('a7777777-7777-4777-8777-777777777777', 'b7777777-0000-4000-8000-000000000001', 'Pita');
select pg_temp.owner_with_pet('a4444444-4444-4444-8444-444444444444', 'b4444444-0000-4000-8000-000000000001', 'Tofu');
select pg_temp.owner_with_pet('a5555555-5555-4555-8555-555555555555', 'b5555555-0000-4000-8000-000000000001', 'Lulu');

-- ===========================================================================
-- 1. Server time: members cannot date their own rows.
-- ===========================================================================
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
insert into public.community_posts(id, author_id, body, created_at)
values ('c0000000-0000-4000-8000-000000000001', 'a2222222-2222-4222-8222-222222222222', 'Pinned forever?', '2099-01-01');
-- Re-dating a post was already refused by the post guard (0022).
select pg_temp.refused($$update public.community_posts set created_at = '2099-01-01'
  where id = 'c0000000-0000-4000-8000-000000000001'$$, '42501', null, 're-dating a post');
insert into public.care_logs(pet_id, owner_id, kind, due_on, status, server_logged_at)
values ('b2222222-0000-4000-8000-000000000001', 'a2222222-2222-4222-8222-222222222222', 'walk', current_date, 'done', '2000-01-01');
insert into ids select 'ben_deal', pg_temp.deal('Ben''s chew toy', 'a2222222-2222-4222-8222-222222222222');
update public.store_deals set posted_at = '2099-01-01', early_until = now() + interval '1 day'
 where id = (select id from ids where name = 'ben_deal');
do $$ begin
 assert (select created_at from public.community_posts where id = 'c0000000-0000-4000-8000-000000000001') <= now(),
  'A post cannot be dated in the future, on insert or update';
 assert (select max(server_logged_at) from public.care_logs where owner_id = auth.uid()) >= now() - interval '1 minute',
  'server_logged_at is the server''s time';
 assert (select posted_at <= now() and early_until is null from public.store_deals where id = (select id from ids where name = 'ben_deal')),
  'A member cannot date a deal or hold it back for early access';
end $$;

-- ===========================================================================
-- 2. One request with many rows meets the same rate limit.
-- ===========================================================================
select pg_temp.refused($$insert into public.community_posts(author_id, body)
  select 'a2222222-2222-4222-8222-222222222222', 'Bulk ' || g from generate_series(1, 7) g$$,
  'P0001', 'rate_limited', 'seven posts in one request');
select pg_temp.refused($$insert into public.care_logs(pet_id, owner_id, kind, due_on, status)
  select 'b2222222-0000-4000-8000-000000000001', 'a2222222-2222-4222-8222-222222222222', 'walk', current_date, 'done'
  from generate_series(1, 501)$$,
  'P0001', 'rate_limited', '501 care logs in one request');
do $$ begin
 assert (select count(*) from public.community_posts where author_id = auth.uid()) = 1, 'The bulk request left nothing behind';
end $$;
reset role;

-- ===========================================================================
-- 3. Reports from new accounts reach moderators but do not hide.
-- ===========================================================================
do $$
declare reporter uuid;
begin
 foreach reporter in array array['a4444444-4444-4444-8444-444444444444', 'a8888888-8888-4888-8888-888888888888',
                                 'a3333333-3333-4333-8333-333333333333']::uuid[] loop
  perform pg_temp.act_as(reporter);
  insert into public.community_reports(post_id, reason) values ('c0000000-0000-4000-8000-000000000001', 'spam');
  perform set_config('role', 'none', true);
 end loop;
end $$;
reset role;
do $$ begin
 assert (select hidden_at is null from public.community_posts where id = 'c0000000-0000-4000-8000-000000000001'),
  'Two established reporters and one new account do not hide a post';
end $$;
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
insert into public.community_reports(post_id, reason) values ('c0000000-0000-4000-8000-000000000001', 'abusive');
reset role;
do $$ begin
 assert (select hidden_at is not null from public.community_posts where id = 'c0000000-0000-4000-8000-000000000001'),
  'A third established reporter hides it';
end $$;
select pg_temp.act_as('a6666666-6666-4666-8666-666666666666');
do $$
declare ages jsonb := public.community_report_reporters('post', 'c0000000-0000-4000-8000-000000000001');
begin
 assert jsonb_array_length(ages) = 4, 'The moderator sees every report';
 assert (select count(*) from jsonb_array_elements(ages) a where not (a->>'counts')::boolean) = 1, 'One report did not count';
 assert (select bool_and(not (a ? 'reporter_id') and not (a ? 'user_id')) from jsonb_array_elements(ages) a),
  'Never who reported';
end $$;
reset role;
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
select pg_temp.refused($$select public.community_report_reporters('post', 'c0000000-0000-4000-8000-000000000001')$$,
  '42501', null, 'a member reading reporter ages');
reset role;

-- ===========================================================================
-- 4. Beta testers get everything but roles; groups are server-written.
-- ===========================================================================
update rewards_private.settings set beta_auto_join = false;
insert into auth.users(id, email) values ('a0000000-0000-4000-8000-0000000000aa', 'after-beta@example.test');
insert into public.access_capabilities(id, feature_id, requires_view) values ('rewards.later_test', 'rewards', 'rewards.view');
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
do $$ begin
 assert public.can_use('community.chat.rooms_create') and public.can_use('store.deals.share_extra'),
  'A beta tester has the capabilities standing will unlock';
 assert public.can_use('rewards.later_test'), 'A capability added later reaches the beta testers';
 assert not public.can_use('community.moderate') and not public.can_use('access.admin'), 'Roles are not part of the beta';
end $$;
select pg_temp.refused($$insert into public.access_group_members(group_id, user_id)
  values ('acc35500-0000-4000-8000-000000000005', auth.uid())$$, '42501', null, 'joining the Guide group');
select pg_temp.refused($$insert into public.member_standing(user_id, level) values (auth.uid(), 'guide')$$,
  '42501', null, 'writing one''s own standing');
select pg_temp.refused($$insert into public.pet_milestones(pet_id, owner_id, milestone_id)
  values ('b2222222-0000-4000-8000-000000000001', auth.uid(), 'walks_365')$$, '42501', null, 'awarding a milestone');
select pg_temp.refused($$insert into public.shopper_standing(user_id, tier) values (auth.uid(), 'trusted')$$,
  '42501', null, 'writing one''s own tier');
select pg_temp.refused($$select rewards_private.rollup_step()$$, '42501', null, 'running the rollup');
reset role;
select pg_temp.act_as('a0000000-0000-4000-8000-0000000000aa');
do $$ begin
 assert public.can_use('rewards.view') and public.can_use('rewards.claim_coupons'), 'Everyone takes part in rewards';
 assert not public.can_use('community.chat.rooms_create'), 'Outside the beta, the unlocks need standing';
end $$;
reset role;

-- ===========================================================================
-- 5. "This helped": the asker, once per thread, not across a block.
-- ===========================================================================
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
insert into public.community_posts(id, author_id, body) values
 ('c0000000-0000-4000-8000-0000000000a1', 'a1111111-1111-4111-8111-111111111111', 'How do I stop the pulling?'),
 ('c0000000-0000-4000-8000-0000000000a2', 'a1111111-1111-4111-8111-111111111111', 'Best brush for a short coat?');
reset role;
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
insert into public.community_comments(id, post_id, author_id, body) values
 ('cc000000-0000-4000-8000-0000000000b1', 'c0000000-0000-4000-8000-0000000000a1', 'a2222222-2222-4222-8222-222222222222', 'A front-clip harness.');
select pg_temp.refused($$select public.mark_helped('comment', 'cc000000-0000-4000-8000-0000000000b1')$$,
  'P0001', 'not_the_asker', 'the answerer marking their own answer');
reset role;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
insert into public.community_comments(id, post_id, author_id, body) values
 ('cc000000-0000-4000-8000-0000000000c1', 'c0000000-0000-4000-8000-0000000000a1', 'a3333333-3333-4333-8333-333333333333', 'Short walks, many stops.');
reset role;
select pg_temp.act_as('a7777777-7777-4777-8777-777777777777');
insert into public.community_comments(id, post_id, author_id, body) values
 ('cc000000-0000-4000-8000-0000000000d1', 'c0000000-0000-4000-8000-0000000000a2', 'a7777777-7777-4777-8777-777777777777', 'A rubber mitt.');
reset role;
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
insert into public.user_blocks(blocked_id) values ('a7777777-7777-4777-8777-777777777777');
do $$ begin
 assert public.mark_helped('comment', 'cc000000-0000-4000-8000-0000000000b1'), 'The asker marks an answer';
 assert not public.mark_helped('comment', 'cc000000-0000-4000-8000-0000000000c1'), 'Once per thread';
end $$;
select pg_temp.refused($$select public.mark_helped('comment', 'cc000000-0000-4000-8000-0000000000d1')$$,
  'P0001', 'not_an_answer', 'marking someone blocked');
reset role;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 assert (select count(*) from public.helped_marks) = 0, 'Only the asker and the answerer read a mark';
end $$;
reset role;

-- ===========================================================================
-- 6. Standing: distinct trusted askers, rings, upheld removals.
-- ===========================================================================
-- Ben leaves the beta so the unlock can only come from standing.
delete from public.access_group_members
 where group_id = 'acc35500-0000-4000-8000-000000000002' and user_id = 'a2222222-2222-4222-8222-222222222222';
-- History (fixture): Ada marked Ben in two more 30-day periods, Cy once;
-- Noa (a new account) and Uri (unconfirmed) five times each, which never count.
insert into public.helped_marks(kind, answer_id, thread_id, answerer_id, asker_id, created_at)
select 'comment', gen_random_uuid(), gen_random_uuid(), 'a2222222-2222-4222-8222-222222222222'::uuid, a, now() - d
from (values ('a1111111-1111-4111-8111-111111111111'::uuid, interval '40 days'),
             ('a1111111-1111-4111-8111-111111111111'::uuid, interval '80 days'),
             ('a3333333-3333-4333-8333-333333333333'::uuid, interval '5 days')) v(a, d)
union all
select 'comment', gen_random_uuid(), gen_random_uuid(), 'a2222222-2222-4222-8222-222222222222'::uuid, a, now() - g * interval '31 days'
from unnest(array['a4444444-4444-4444-8444-444444444444', 'a5555555-5555-4555-8555-555555555555']::uuid[]) a,
     generate_series(0, 4) g;
-- Ron and Cy mark each other: a ring.
insert into public.helped_marks(kind, answer_id, thread_id, answerer_id, asker_id, created_at)
select 'comment', gen_random_uuid(), gen_random_uuid(), x.answerer, x.asker, now() - g * interval '31 days'
from (values ('a7777777-7777-4777-8777-777777777777'::uuid, 'a3333333-3333-4333-8333-333333333333'::uuid),
             ('a3333333-3333-4333-8333-333333333333'::uuid, 'a7777777-7777-4777-8777-777777777777'::uuid)) x(answerer, asker),
     generate_series(0, 3) g;
select pg_temp.rollup();
do $$ begin
 assert (select level from public.member_standing where user_id = 'a2222222-2222-4222-8222-222222222222') = 'regular',
  'Ben: four marks from two trusted askers make a Regular';
 assert (select qualifying_marks from public.member_standing where user_id = 'a2222222-2222-4222-8222-222222222222') = 4,
  'Marks from a new or unconfirmed account do not count';
 assert (select level from public.member_standing where user_id = 'a7777777-7777-4777-8777-777777777777') = 'member',
  'A ring counts for nobody';
 assert exists (select 1 from public.access_group_members where user_id = 'a2222222-2222-4222-8222-222222222222'
                and group_id = 'acc35500-0000-4000-8000-000000000003'), 'The rollup puts Ben in the Regular group';
 assert (select hidden_at is not null from public.community_posts where id = 'c0000000-0000-4000-8000-000000000001'),
  'Ben''s post was auto-hidden by reports, and that alone did not lower his standing';
end $$;
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
do $$ begin
 assert public.can_use('community.chat.rooms_create'), 'Standing unlocks its capability';
 assert not public.can_use('store.deals.share_extra'), 'Only the capabilities of its level';
end $$;
-- Ben deletes his own comment: not a removal against him.
insert into public.community_comments(id, post_id, author_id, body) values
 ('cc000000-0000-4000-8000-0000000000b2', 'c0000000-0000-4000-8000-0000000000a2', 'a2222222-2222-4222-8222-222222222222', 'Oops, wrong post.');
delete from public.community_comments where id = 'cc000000-0000-4000-8000-0000000000b2';
insert into public.community_comments(id, post_id, author_id, body) values
 ('cc000000-0000-4000-8000-0000000000b3', 'c0000000-0000-4000-8000-0000000000a2', 'a2222222-2222-4222-8222-222222222222', 'Buy my course!');
reset role;
do $$ begin
 assert not exists (select 1 from rewards_private.upheld_removals), 'Deleting one''s own item is not a removal';
end $$;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 assert (select count(*) from public.community_standing(array['a2222222-2222-4222-8222-222222222222',
          'a7777777-7777-4777-8777-777777777777']::uuid[])) = 1, 'Only levels above Member are shown';
 assert (select count(*) from public.member_standing) = 1, 'A member reads only their own standing row';
end $$;
reset role;
-- A moderator removes Ben's spam: Ben is capped at Member for 90 days.
select pg_temp.act_as('a6666666-6666-4666-8666-666666666666');
select public.community_moderate('comment', 'cc000000-0000-4000-8000-0000000000b3', 'remove');
reset role;
select pg_temp.rollup();
do $$ begin
 assert (select level from public.member_standing where user_id = 'a2222222-2222-4222-8222-222222222222') = 'member',
  'An upheld removal caps standing';
 assert (select capped_until > now() + interval '89 days' from public.member_standing where user_id = 'a2222222-2222-4222-8222-222222222222'),
  'For 90 days';
 assert not exists (select 1 from public.access_group_members where user_id = 'a2222222-2222-4222-8222-222222222222'
                    and group_id = 'acc35500-0000-4000-8000-000000000003'), 'And leaves the Regular group';
end $$;

-- ===========================================================================
-- 7. Pet milestones and rhythm count server time, honestly.
-- ===========================================================================
-- Kelly: a morning walk logged on time for the last 31 days.
insert into public.care_plan_items(id, pet_id, owner_id, kind, title, time_of_day, starts_on)
values ('d0000000-0000-4000-8000-000000000001', 'b1111111-0000-4000-8000-000000000001', 'a1111111-1111-4111-8111-111111111111',
        'walk', 'Morning walk', '08:00', current_date - 40);
insert into public.care_logs(pet_id, owner_id, plan_item_id, due_on, status, server_logged_at)
select 'b1111111-0000-4000-8000-000000000001', 'a1111111-1111-4111-8111-111111111111', 'd0000000-0000-4000-8000-000000000001',
       current_date - g, 'done', (current_date - g) + time '09:00'
from generate_series(1, 31) g;
-- Miso: 40 walks claimed for 2024, sent today (backdated: never count).
insert into public.care_logs(pet_id, owner_id, kind, due_on, status)
select 'b3333333-0000-4000-8000-000000000001', 'a3333333-3333-4333-8333-333333333333', 'walk', date '2024-01-01' + g, 'done'
from generate_series(1, 40) g;
-- Pita: 40 walks on one day (capped at 6).
insert into public.care_logs(pet_id, owner_id, kind, due_on, status)
select 'b7777777-0000-4000-8000-000000000001', 'a7777777-7777-4777-8777-777777777777', 'walk', current_date - 1, 'done'
from generate_series(1, 40);
-- Rex: a plan, but nothing logged for 10 days.
insert into public.care_plan_items(pet_id, owner_id, kind, title, time_of_day, starts_on)
values ('b2222222-0000-4000-8000-000000000001', 'a2222222-2222-4222-8222-222222222222', 'feeding', 'Breakfast', '07:00', current_date - 40);
update public.care_logs set server_logged_at = now() - interval '10 days', due_on = current_date - 10
 where pet_id = 'b2222222-0000-4000-8000-000000000001';
select pg_temp.rollup();
do $$ begin
 assert exists (select 1 from public.pet_milestones where pet_id = 'b1111111-0000-4000-8000-000000000001' and milestone_id = 'walks_30'),
  'Kelly reached 30 walks';
 assert not exists (select 1 from public.pet_milestones where pet_id = 'b3333333-0000-4000-8000-000000000001'),
  'Backdated logs earn nothing';
 assert not exists (select 1 from public.pet_milestones where pet_id = 'b7777777-0000-4000-8000-000000000001'),
  'Forty walks in a day count as six';
 assert (select state from public.care_rhythm where pet_id = 'b1111111-0000-4000-8000-000000000001') = 'thriving',
  'Every day on time: Thriving';
 assert (select state from public.care_rhythm where pet_id = 'b2222222-0000-4000-8000-000000000001') = 'paused',
  'Ten quiet days: Paused, not failed';
end $$;
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
do $$ begin
 assert public.rewards_mark_seen('b1111111-0000-4000-8000-000000000001') = 1, 'Ada saw Kelly''s milestone';
 assert public.rewards_mark_seen('b2222222-0000-4000-8000-000000000001') = 0, 'Nobody marks someone else''s pet';
 assert (select count(*) from public.care_rhythm) = 1, 'An owner reads only their own pets'' rhythm';
end $$;
reset role;

-- ===========================================================================
-- 8. Coupons, redemptions, tiers, early access, audit.
-- ===========================================================================
insert into public.partners(id, name, daily_redemption_cap) values
 ('e0000000-0000-4000-8000-000000000001', 'Happy Paws Market', 3),
 ('e0000000-0000-4000-8000-000000000002', 'Busy Shop', 1000);
insert into public.coupon_offers(id, partner_id, title, terms, min_tier, valid_until, max_claims) values
 ('f0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', '10% off food', 'One use.', 'shopper', now() + interval '30 days', 2),
 ('f0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000001', 'Free delivery', 'Regulars.', 'regular', now() + interval '30 days', 100),
 ('f0000000-0000-4000-8000-000000000003', 'e0000000-0000-4000-8000-000000000001', 'A toy with any order', 'While stocks last.', 'shopper', now() + interval '30 days', 100),
 ('f0000000-0000-4000-8000-000000000004', 'e0000000-0000-4000-8000-000000000002', 'Busy deal', 'Test.', 'shopper', now() + interval '30 days', 1000);
-- Members cannot buy-in, list partners or read the audit.
select pg_temp.act_as('a4444444-4444-4444-8444-444444444444');
select pg_temp.refused($$select public.claim_coupon('f0000000-0000-4000-8000-000000000001')$$,
  'P0001', 'not_eligible', 'a two-hour-old account');
reset role;
select pg_temp.act_as('a5555555-5555-4555-8555-555555555555');
select pg_temp.refused($$select public.claim_coupon('f0000000-0000-4000-8000-000000000001')$$,
  'P0001', 'not_eligible', 'an unconfirmed email');
reset role;
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
do $$
declare first jsonb := public.claim_coupon('f0000000-0000-4000-8000-000000000001');
begin
 assert first->>'code' ~ '^PL(-[0-9A-F]{4}){4}$', 'A unique code of 64 random bits: ' || (first->>'code');
 assert public.claim_coupon('f0000000-0000-4000-8000-000000000001')->>'code' = first->>'code', 'Claiming again returns the same code';
 assert (select count(*) from public.coupon_offers) = 3, 'Ada sees the offers of her tier and open partners';
 assert not exists (select 1 from public.coupon_offers where min_tier = 'regular'), 'Not the Regular shoppers'' offer';
 assert (select count(*) from public.partners) = 0, 'Members do not see partners';
end $$;
select pg_temp.refused($$select public.claim_coupon('f0000000-0000-4000-8000-000000000002')$$,
  'P0001', 'not_eligible', 'a Regular offer for a Shopper');
reset role;
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
select public.claim_coupon('f0000000-0000-4000-8000-000000000001');
reset role;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
select pg_temp.refused($$select public.claim_coupon('f0000000-0000-4000-8000-000000000001')$$,
  'P0001', 'sold_out', 'the third claim of two');
reset role;

-- Redemptions: an administrator's batch and a postback.
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
select pg_temp.refused($$select public.rewards_admin_record_redemptions('e0000000-0000-4000-8000-000000000001', array['PL-0000-0000-0000-0000'])$$,
  '42501', null, 'a member recording redemptions');
select pg_temp.refused($$select public.rewards_partner_postback('e0000000-0000-4000-8000-000000000001', 'x', 'PL-0000-0000-0000-0000', '{}')$$,
  '42501', null, 'a member calling the postback');
reset role;
-- The partner's file holds the codes; the administrator cannot read
-- members' claims (RLS), so the test picks them up as the owner.
create temp table codes as select user_id, code from public.coupon_claims;
grant select on codes to authenticated;
select pg_temp.act_as('a9999999-9999-4999-8999-999999999999');
do $$
declare
 ada_code text := (select code from codes where user_id = 'a1111111-1111-4111-8111-111111111111');
 tally jsonb;
begin
 assert ada_code is not null, 'The administrator was handed Ada''s code';
 assert not exists (select 1 from public.coupon_claims), 'An administrator does not read members'' claims either';
 tally := public.rewards_admin_record_redemptions('e0000000-0000-4000-8000-000000000001',
   array[ada_code, lower(ada_code), 'PL-0000-0000-0000-0000', '=HYPERLINK("x")']);
 assert tally = '{"redeemed": 1, "duplicate": 1, "unknown": 1, "invalid": 1}'::jsonb, 'Batch tally: ' || tally::text;
end $$;
select pg_temp.refused($$select public.rewards_admin_record_redemptions('e0000000-0000-4000-8000-000000000001',
  array(select 'PL-0000-0000-0000-0000' from generate_series(1, 501)))$$, '22023', null, '501 codes in one call');
reset role;
set local role service_role;
do $$
declare ben_code text := (select code from public.coupon_claims where user_id = 'a2222222-2222-4222-8222-222222222222');
begin
 assert public.rewards_partner_postback('e0000000-0000-4000-8000-000000000001', 'order-77', ben_code, '{"order":77}') = 'redeemed',
  'A postback redeems';
 assert public.rewards_partner_postback('e0000000-0000-4000-8000-000000000001', 'order-77', ben_code, '{"order":77}') = 'duplicate',
  'Replaying it changes nothing';
end $$;
reset role;
-- The daily cap: Cy claims the toy offer; the partner already redeemed two of three.
update public.partners set daily_redemption_cap = 2 where id = 'e0000000-0000-4000-8000-000000000001';
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
select public.claim_coupon('f0000000-0000-4000-8000-000000000003');
reset role;
do $$ begin
 assert rewards_private.redeem_code('e0000000-0000-4000-8000-000000000001',
   (select code from public.coupon_claims where user_id = 'a3333333-3333-4333-8333-333333333333'), 'partner_csv') = 'cap',
  'The partner''s daily cap holds';
end $$;

-- Self-reports: four a month, once per deal.
insert into ids select 'deal' || g, pg_temp.deal('Deal number ' || g) from generate_series(1, 5) g;
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
select public.report_purchase((select id from ids where name = 'deal1'), 49.90);
select pg_temp.refused($$select public.report_purchase((select id from ids where name = 'deal1'))$$,
  'P0001', 'already_reported', 'the same deal twice');
select public.report_purchase((select id from ids where name = 'deal2'));
select public.report_purchase((select id from ids where name = 'deal3'));
select public.report_purchase((select id from ids where name = 'deal4'));
select pg_temp.refused($$select public.report_purchase((select id from ids where name = 'deal5'))$$,
  'P0001', 'rate_limited', 'a fifth self-report this month');
reset role;

-- Tiers: Ada has 1 verified purchase and 4 self-reports (1 + 1 = 2: Shopper);
-- two more verified make her a Regular shopper, kept for a year.
insert into public.purchase_events(user_id, source, verified, occurred_at)
values ('a1111111-1111-4111-8111-111111111111', 'coupon', true, now() - interval '20 days'),
       ('a1111111-1111-4111-8111-111111111111', 'affiliate', true, now() - interval '200 days');
insert into ids select 'early', pg_temp.deal('Early bird food deal');
update public.store_deals set early_until = now() + interval '1 day' where id = (select id from ids where name = 'early');
select pg_temp.rollup();
do $$ begin
 assert (select tier from public.shopper_standing where user_id = 'a1111111-1111-4111-8111-111111111111') = 'regular',
  'Three verified purchases: Regular shopper';
 assert (select tier_until > now() + interval '364 days' from public.shopper_standing where user_id = 'a1111111-1111-4111-8111-111111111111'),
  'Kept for a year';
 assert (select tier from public.shopper_standing where user_id = 'a3333333-3333-4333-8333-333333333333') is distinct from 'regular',
  'No purchases, no tier';
end $$;
-- Self-reports alone never reach the top tier.
insert into public.purchase_events(user_id, source, verified, occurred_at)
select 'a7777777-7777-4777-8777-777777777777', 'self', false, now() - g * interval '1 day' from generate_series(1, 40) g;
select pg_temp.rollup();
do $$ begin
 assert (select tier from public.shopper_standing where user_id = 'a7777777-7777-4777-8777-777777777777') = 'regular',
  'Forty self-reports are worth three verified purchases at most';
end $$;
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
do $$ begin
 assert exists (select 1 from public.store_deals where id = (select id from ids where name = 'early')),
  'A Regular shopper sees the early deal';
 assert (select count(*) from public.shopper_standing) = 1, 'A tier is private';
end $$;
reset role;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 assert not exists (select 1 from public.store_deals where id = (select id from ids where name = 'early')),
  'A Shopper waits for it';
end $$;
reset role;

-- A partner whose redemptions jump is paused for review; its offers close.
insert into auth.users(id, email)
select ('0000aaaa-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'bulk' || g || '@example.test' from generate_series(1, 25) g;
insert into public.coupon_claims(offer_id, user_id, code, redeemed_at, verified_by)
select 'f0000000-0000-4000-8000-000000000004', ('0000aaaa-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       'PL-AAAA-AAAA-AAAA-' || lpad(g::text, 4, '0'), now() - interval '1 hour', 'partner_postback'
from generate_series(1, 25) g;
select pg_temp.rollup();
do $$ begin
 assert (select review_needed_at is not null from public.partners where id = 'e0000000-0000-4000-8000-000000000002'),
  'Twenty-five redemptions in a day from nothing: review';
 assert (select review_needed_at is null from public.partners where id = 'e0000000-0000-4000-8000-000000000001'),
  'An ordinary partner stays open';
 assert rewards_private.redeem_code('e0000000-0000-4000-8000-000000000002', 'PL-AAAA-AAAA-AAAA-0001', 'partner_csv') = 'paused',
  'A paused partner redeems nothing';
end $$;

-- The audit is append-only, even for the owner.
do $$ begin
 assert (select count(*) from rewards_private.audit where table_name = 'coupon_offers' and op = 'INSERT') = 4, 'Offers are audited';
 assert not exists (select 1 from rewards_private.audit where op = 'UPDATE' and table_name = 'coupon_offers'),
  'Claims moving the counter are not administrative changes';
end $$;
select pg_temp.refused($$update rewards_private.audit set actor_id = null$$, '42501', 'append-only', 'editing the audit');
select pg_temp.refused($$delete from rewards_private.audit$$, '42501', 'append-only', 'deleting the audit');

-- The rollup is resumable and takes one lock.
do $$
declare r jsonb;
begin
 update rewards_private.rollup_state set run_on = null;
 r := rewards_private.rollup_step(1, interval '0 seconds');
 assert r->>'phase' = 'pets' and (r->>'batches')::integer = 1, 'One batch, then it stops: ' || r::text;
 r := rewards_private.rollup_step(500, interval '60 seconds');
 assert r->>'phase' = 'done', 'It resumes and finishes: ' || r::text;
 r := rewards_private.rollup_step();
 assert (r->>'batches')::integer = 0, 'A finished day does nothing';
end $$;

rollback;
\echo 'Rewards foundation, server time, bulk limits, reports, standing, coupons and audit passed.'

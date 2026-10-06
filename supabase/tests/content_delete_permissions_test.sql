\set ON_ERROR_STOP on
-- Disposable database only. Deleting (and editing) your own post, comment
-- or deal needs the *.edit permission, the same one the app asks for;
-- posting and sharing need *.post / *.share.
do $$
declare
 expected record;
 expr text;
begin
 for expected in select * from (values
  ('community_posts','feature_delete','community.feed.edit'),
  ('community_posts','feature_update','community.feed.edit'),
  ('community_posts','feature_insert','community.feed.post'),
  ('community_comments','feature_delete','community.feed.edit'),
  ('community_comments','feature_insert','community.feed.post'),
  ('store_deals','feature_delete','store.deals.edit'),
  ('store_deals','feature_update','store.deals.edit'),
  ('store_deals','feature_insert','store.deals.share')
 ) as e(tbl,policy,capability) loop
  select coalesce(qual,'')||' '||coalesce(with_check,'') into expr
  from pg_policies where schemaname='public' and tablename=expected.tbl and policyname=expected.policy;
  assert expr is not null, format('%s.%s is missing',expected.tbl,expected.policy);
  assert position(''''||expected.capability||'''' in expr)>0,
   format('%s.%s should check %s: %s',expected.tbl,expected.policy,expected.capability,expr);
 end loop;
end $$;

begin;
insert into auth.users(id,email) values
 ('66666666-6666-4666-8666-666666666661','poster@example.test');
insert into public.community_posts(id,author_id,body) values
 ('66666666-6666-4666-8666-666666666662','66666666-6666-4666-8666-666666666661','Mine'),
 ('66666666-6666-4666-8666-666666666663','66666666-6666-4666-8666-666666666661','Also mine');
insert into public.user_capability_rules(user_id,capability,allowed) values
 ('66666666-6666-4666-8666-666666666661','community.feed.edit',false);
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666661',true);
set local role authenticated;
delete from public.community_posts where id='66666666-6666-4666-8666-666666666662';
reset role;
do $$ begin
 assert exists(select 1 from public.community_posts where id='66666666-6666-4666-8666-666666666662'),
  'Without community.feed.edit your own post is not deleted';
end $$;

update public.user_capability_rules set allowed=true
 where user_id='66666666-6666-4666-8666-666666666661' and capability='community.feed.edit';
insert into public.user_capability_rules(user_id,capability,allowed) values
 ('66666666-6666-4666-8666-666666666661','community.feed.post',false);
set local role authenticated;
delete from public.community_posts where id='66666666-6666-4666-8666-666666666663';
reset role;
do $$ begin
 assert not exists(select 1 from public.community_posts where id='66666666-6666-4666-8666-666666666663'),
  'With community.feed.edit (and no posting) your own post is deleted';
end $$;
rollback;
\echo 'Delete permissions match the app passed.'

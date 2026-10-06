\set ON_ERROR_STOP on
begin;
select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
set local role authenticated;
do $$ declare page jsonb; begin
 page:=public.access_admin_history(p_actor=>'persistent-admin',p_action=>'feature_catalog');
 assert jsonb_array_length(page->'entries')=1, 'History survives database restart and new connection';
 assert page->'entries'->0->'before_value'->>'enabled'='true', 'Original state survives restart';
 assert page->'entries'->0->'after_value'->>'enabled'='false', 'Saved change survives restart';
 assert page->'entries'->0->>'actor_email'='persistent-admin@example.test', 'Actor snapshot survives restart';
end $$;
rollback;
\echo 'Committed administration history survives database restart.'

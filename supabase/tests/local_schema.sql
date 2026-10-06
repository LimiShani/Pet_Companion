-- Minimal Supabase auth/storage API fixture for real PostgreSQL RLS tests.
-- Only run in the disposable Docker database, never in a remote project.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create schema storage;
create table auth.users(id uuid primary key,email text unique,raw_user_meta_data jsonb default '{}',created_at timestamptz default now());
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function auth.role() returns text language sql stable as $$ select nullif(current_setting('request.jwt.claim.role',true),'') $$;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,owner uuid,created_at timestamptz default now());
alter table storage.objects enable row level security;
create function storage.foldername(text) returns text[] language sql immutable as $$ select (string_to_array($1,'/'))[1:array_length(string_to_array($1,'/'),1)-1] $$;
grant usage on schema public,auth,storage to anon,authenticated,service_role;
grant execute on function auth.uid(),auth.role(),storage.foldername(text) to anon,authenticated,service_role;
grant all on storage.objects to authenticated,service_role;
alter default privileges in schema public grant all on tables to authenticated,service_role;
alter default privileges in schema public grant all on sequences to authenticated,service_role;

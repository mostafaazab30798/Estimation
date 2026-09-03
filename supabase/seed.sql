-- Supabase test helpers for pgTAP RLS suite (local / CI only).
-- Runs on `supabase db reset`, not on `supabase db push` to production.
-- Source: https://github.com/usebasejump/supabase-test-helpers (v0.0.6, trimmed)

create schema if not exists tests;

grant usage on schema tests to anon, authenticated, service_role;
alter default privileges in schema tests revoke execute on functions from public;
alter default privileges in schema tests grant execute on functions to anon, authenticated, service_role;

create or replace function tests.create_supabase_user(
  identifier text,
  email text default null,
  phone text default null,
  metadata jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = auth, extensions, pg_temp
as $$
declare
  user_id uuid;
begin
  user_id := extensions.uuid_generate_v4();
  insert into auth.users (
    id, email, phone, raw_user_meta_data, raw_app_meta_data, created_at, updated_at
  )
  values (
    user_id,
    coalesce(email, concat(user_id, '@test.com')),
    phone,
    jsonb_build_object('test_identifier', identifier) || coalesce(metadata, '{}'::jsonb),
    '{}'::jsonb,
    now(),
    now()
  )
  returning id into user_id;
  return user_id;
end;
$$;

create or replace function tests.get_supabase_user(identifier text)
returns json
language plpgsql
security definer
set search_path = auth, pg_temp
as $$
declare
  supabase_user json;
begin
  select json_build_object(
    'id', id,
    'email', email,
    'phone', phone,
    'raw_user_meta_data', raw_user_meta_data,
    'raw_app_meta_data', raw_app_meta_data
  )
  into supabase_user
  from auth.users
  where raw_user_meta_data ->> 'test_identifier' = identifier
  limit 1;

  if supabase_user is null or supabase_user -> 'id' is null then
    raise exception 'User with identifier % not found', identifier;
  end if;
  return supabase_user;
end;
$$;

create or replace function tests.get_supabase_uid(identifier text)
returns uuid
language plpgsql
security definer
set search_path = auth, pg_temp
as $$
declare
  supabase_user uuid;
begin
  select id into supabase_user
  from auth.users
  where raw_user_meta_data ->> 'test_identifier' = identifier
  limit 1;
  if supabase_user is null then
    raise exception 'User with identifier % not found', identifier;
  end if;
  return supabase_user;
end;
$$;

create or replace function tests.authenticate_as(identifier text)
returns void
language plpgsql
as $$
declare
  user_data json;
  original_auth_data text;
begin
  original_auth_data := current_setting('request.jwt.claims', true);
  user_data := tests.get_supabase_user(identifier);

  perform set_config('role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', user_data ->> 'id',
      'role', 'authenticated',
      'email', user_data ->> 'email',
      'phone', user_data ->> 'phone',
      'user_metadata', user_data -> 'raw_user_meta_data',
      'app_metadata', user_data -> 'raw_app_meta_data'
    )::text,
    true
  );
exception
  when others then
    perform set_config('role', 'authenticated', true);
    perform set_config('request.jwt.claims', original_auth_data, true);
    raise;
end;
$$;

create or replace function tests.authenticate_as_service_role()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'service_role', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'service_role')::text,
    true
  );
end;
$$;

create or replace function tests.clear_authentication()
returns void
language sql
as $$
  select set_config('role', 'anon', true);
  select set_config('request.jwt.claims', null, true);
$$;

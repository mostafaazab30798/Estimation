-- UGC moderation, account deletion, and public profile privacy (Phase 0 W0.4 / W0.8)

-- ─── Profile extensions ─────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists terms_version text;

-- ─── Public profile view (no email) ─────────────────────────────────────────

create or replace view public.public_profiles
with (security_invoker = false) as
select
  p.id,
  p.username,
  p.avatar_url,
  p.xp,
  p.level,
  p.games_played,
  p.games_won,
  p.created_at,
  p.updated_at
from public.profiles p
inner join auth.users u on u.id = p.id
where coalesce(u.is_anonymous, false) = false
  and u.email is not null
  and trim(u.email) <> '';

grant select on public.public_profiles to anon, authenticated;

-- Restrict full profile reads to the owner only.
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Users can view own profile." on public.profiles;
create policy "Users can view own profile."
  on public.profiles for select
  using (auth.uid() = id);

-- ─── Username validation ──────────────────────────────────────────────────────

create or replace function public.validate_profile_username()
returns trigger
language plpgsql
as $$
declare
  cleaned text;
begin
  cleaned := trim(coalesce(new.username, ''));
  if char_length(cleaned) < 2 or char_length(cleaned) > 20 then
    raise exception 'username length must be between 2 and 20 characters';
  end if;
  if cleaned !~ '^[[:alnum:]_\. ''\-]+$' then
    raise exception 'username contains disallowed characters';
  end if;
  if cleaned ~* '(fuck|shit|bitch|asshole|nigger|nazi|porn|sex|كسم|شرموط|عرص|زب|طيز)' then
    raise exception 'username contains blocked terms';
  end if;
  new.username := cleaned;
  return new;
end;
$$;

drop trigger if exists profiles_validate_username on public.profiles;
create trigger profiles_validate_username
  before insert or update of username on public.profiles
  for each row execute function public.validate_profile_username();

-- ─── Reports & blocks ───────────────────────────────────────────────────────

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reported_id uuid not null references auth.users (id) on delete cascade,
  reason text not null,
  details text,
  context_type text,
  context_id text,
  status text not null default 'open',
  created_at timestamptz not null default timezone('utc', now()),
  constraint user_reports_no_self check (reporter_id <> reported_id)
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id <> blocked_id)
);

alter table public.user_reports enable row level security;
alter table public.user_blocks enable row level security;

drop policy if exists "Users insert own reports" on public.user_reports;
create policy "Users insert own reports"
  on public.user_reports for insert
  with check (auth.uid() = reporter_id);

drop policy if exists "Users view own reports" on public.user_reports;
create policy "Users view own reports"
  on public.user_reports for select
  using (auth.uid() = reporter_id);

drop policy if exists "Users manage own blocks" on public.user_blocks;
create policy "Users manage own blocks"
  on public.user_blocks for all
  using (auth.uid() = blocker_id)
  with check (auth.uid() = blocker_id);

-- ─── RPCs ───────────────────────────────────────────────────────────────────

create or replace function public.submit_user_report(
  p_reported_id uuid,
  p_reason text,
  p_details text default null,
  p_context_type text default null,
  p_context_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter uuid := auth.uid();
begin
  if v_reporter is null then
    raise exception 'not authenticated';
  end if;
  if p_reported_id is null or p_reported_id = v_reporter then
    raise exception 'invalid reported user';
  end if;
  if char_length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'reason required';
  end if;

  insert into public.user_reports (
    reporter_id, reported_id, reason, details, context_type, context_id
  ) values (
    v_reporter, p_reported_id, trim(p_reason), nullif(trim(coalesce(p_details, '')), ''),
    p_context_type, p_context_id
  );
end;
$$;

create or replace function public.block_user(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_blocker uuid := auth.uid();
begin
  if v_blocker is null then raise exception 'not authenticated'; end if;
  if p_blocked_id is null or p_blocked_id = v_blocker then
    raise exception 'invalid blocked user';
  end if;
  insert into public.user_blocks (blocker_id, blocked_id)
  values (v_blocker, p_blocked_id)
  on conflict do nothing;
end;
$$;

create or replace function public.unblock_user(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_blocker uuid := auth.uid();
begin
  if v_blocker is null then raise exception 'not authenticated'; end if;
  delete from public.user_blocks
  where blocker_id = v_blocker and blocked_id = p_blocked_id;
end;
$$;

create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  delete from public.user_reports
  where reporter_id = v_user or reported_id = v_user;

  delete from public.user_blocks
  where blocker_id = v_user or blocked_id = v_user;

  delete from public.room_players
  where player_id = v_user;

  delete from public.profiles
  where id = v_user;

  delete from auth.users
  where id = v_user;
end;
$$;

grant execute on function public.submit_user_report(uuid, text, text, text, text) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.delete_user_account() to authenticated;

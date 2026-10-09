-- =====================================================================
-- Shnayim Mikra community: forums, moderation, account deletion, progress
-- backup. Schema, row-level security, triggers and RPCs for Supabase.
--
-- Security model: everything that matters is enforced here, not in the app.
--  * Anyone may read visible content; only signed-in users may write, and
--    only as themselves (author ids are stamped by triggers, never trusted).
--  * Posting requires accepting the community guidelines and is rate
--    limited (Discourse-style limits, stricter for new members).
--  * Reports auto-hide a post after 3 distinct reporters, pending review.
--  * Deletion is soft (Realtime does not apply RLS to DELETE events).
--  * Helper functions live in the unexposed `private` schema with a pinned
--    search_path.
-- Tested with supabase/tests/run_tests.sh against PostgreSQL 16.
-- See docs/research/forums.md for the design rationale.

create schema if not exists private;            -- NOT in "Exposed schemas"
grant usage on schema private to anon, authenticated;  -- needed so policies can call helpers

-- ---------- enums ----------
create type public.app_role      as enum ('moderator', 'admin');
create type public.report_reason as enum ('spam', 'lashon_hara', 'disrespect', 'misinformation',
                                          'proselytizing', 'off_topic', 'other');
create type public.report_status as enum ('open', 'actioned', 'dismissed');

-- ---------- helpers ----------
-- Search/match key: NFD, strip all Hebrew points/accents (and maqaf/paseq/sof pasuq), fold final letters.
-- Apply the SAME function to blocklist patterns, or 'שקרן' (final nun) will never match folded text.
create or replace function private.he_plain(t text) returns text
language sql immutable parallel safe set search_path = '' as $$
  select translate(
           regexp_replace(normalize(t, NFD), '[\u0591-\u05C7\u05C8\u05C9\u034F\u200C\u200D]', '', 'g'),
           'ךםןףץ', 'כמנפצ')
$$;

-- ---------- tables ----------
create table public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  display_name      text not null check (char_length(display_name) between 2 and 40),
  bio               text check (char_length(bio) <= 500),
  locale            text not null default 'en',
  trust_level       smallint not null default 0 check (trust_level between 0 and 4),
  accepted_terms_at timestamptz,          -- must be set (via RPC) before posting
  silenced_until    timestamptz,          -- temporary posting suspension
  banned_at         timestamptz,          -- permanent ban
  in_israel         boolean not null default false,  -- parasha schedule (Israel vs Diaspora)
  shabbat_region    text,                 -- optional key into private.shabbat_windows
  created_at        timestamptz not null default now()
);
create unique index profiles_display_name_ci on public.profiles (lower(display_name));

create table public.user_roles (
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       public.app_role not null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table public.categories (
  id          smallint generated always as identity primary key,
  slug        text not null unique,
  name_en     text not null,
  name_he     text not null,
  description_en text not null default '',
  description_he text not null default '',
  sort_order  smallint not null default 0,
  is_locked   boolean not null default false,
  min_trust_to_create_thread smallint not null default 0
);

create table public.parashot (
  id        smallint primary key,          -- 1..54 (combined parashot handled by schedule)
  name_en   text not null,
  name_he   text not null,
  book      smallint not null check (book between 1 and 5),
  start_ref text not null,                 -- e.g. 'Genesis 1:1'
  end_ref   text not null                  -- e.g. 'Genesis 6:8'
);

create table public.threads (
  id                bigint generated always as identity primary key,
  category_id       smallint not null references public.categories(id),
  parasha_id        smallint references public.parashot(id),
  hebrew_year       smallint,              -- e.g. 5787, for the weekly thread
  verse_ref         text,                  -- optional anchor, e.g. 'Genesis 1:1-5'
  kind              text not null default 'discussion'
                    check (kind in ('discussion', 'weekly', 'question', 'announcement')),
  title             text not null check (char_length(title) between 5 and 150),
  author_id         uuid references public.profiles(id) on delete set null,
  is_pinned         boolean not null default false,
  is_locked         boolean not null default false,
  slow_mode_seconds integer not null default 0 check (slow_mode_seconds >= 0),
  post_count        integer not null default 0,
  last_post_at      timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  deleted_by        uuid,
  delete_reason     text
);
create unique index threads_one_weekly_per_parasha_year
  on public.threads (parasha_id, hebrew_year) where kind = 'weekly' and deleted_at is null;
create index threads_listing  on public.threads (category_id, is_pinned desc, last_post_at desc) where deleted_at is null;
create index threads_author   on public.threads (author_id);
create index threads_parasha  on public.threads (parasha_id, hebrew_year);

create table public.posts (
  id               bigint generated always as identity primary key,
  thread_id        bigint not null references public.threads(id) on delete cascade,
  author_id        uuid references public.profiles(id) on delete set null,
  reply_to_post_id bigint references public.posts(id) on delete set null,   -- one-level "in reply to"
  body             text not null check (char_length(body) between 2 and 10000),
  body_plain       text generated always as (private.he_plain(body)) stored,
  created_at       timestamptz not null default now(),
  edited_at        timestamptz,
  hidden_at        timestamptz,            -- auto-hidden (flags/filter) pending review
  hidden_reason    text,
  deleted_at       timestamptz,            -- soft delete (tombstone)
  deleted_by       uuid,
  delete_reason    text
);
create index posts_thread_visible on public.posts (thread_id, created_at) where deleted_at is null;
create index posts_author_recent  on public.posts (author_id, created_at desc);
create index posts_reply_to       on public.posts (reply_to_post_id);

create table public.post_revisions (
  id         bigint generated always as identity primary key,
  post_id    bigint not null references public.posts(id) on delete cascade,
  body       text not null,
  edited_by  uuid,
  edited_at  timestamptz not null default now()
);
create index post_revisions_post on public.post_revisions (post_id);

create table public.reactions (
  post_id    bigint not null references public.posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null default 'todah' check (kind in ('todah', 'insightful')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, kind)
);
create index reactions_user on public.reactions (user_id);

create table public.reports (
  id               bigint generated always as identity primary key,
  reporter_id      uuid not null references public.profiles(id) on delete cascade,
  post_id          bigint references public.posts(id) on delete cascade,
  thread_id        bigint references public.threads(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete cascade,
  reason           public.report_reason not null,
  details          text check (char_length(details) <= 1000),
  status           public.report_status not null default 'open',
  created_at       timestamptz not null default now(),
  resolved_by      uuid references public.profiles(id) on delete set null,
  resolved_at      timestamptz,
  resolution_note  text,
  check (num_nonnulls(post_id, thread_id, reported_user_id) >= 1)
);
create unique index reports_one_per_reporter_post on public.reports (reporter_id, post_id) where post_id is not null;
create index reports_queue    on public.reports (status, created_at);
create index reports_post     on public.reports (post_id);
create index reports_reporter on public.reports (reporter_id);

create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index user_blocks_blocked on public.user_blocks (blocked_id);

create table public.moderation_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid references public.profiles(id) on delete set null,
  action      text not null,       -- hide_post, restore_post, delete_post, lock_thread, pin_thread, silence_user, ban_user, resolve_report ...
  target_type text not null,
  target_id   text not null,
  reason      text,
  created_at  timestamptz not null default now()
);
create index moderation_log_recent on public.moderation_log (created_at desc);

-- Private (never exposed): word/regex blocklist and optional Shabbat windows.
create table private.banned_terms (
  id         int generated always as identity primary key,
  pattern    text not null,                       -- POSIX regex on private.he_plain(body)
  action     text not null check (action in ('reject', 'hold')),
  note       text,
  created_at timestamptz not null default now()
);
create table private.shabbat_windows (            -- filled yearly by a job (hebcal / kosher_dart)
  region    text not null,                        -- e.g. 'jerusalem', 'new_york'
  starts_at timestamptz not null,                 -- candle lighting
  ends_at   timestamptz not null,                 -- havdalah
  primary key (region, starts_at)
);
create table private.settings (key text primary key, value text not null);
insert into private.settings values ('block_posting_on_shabbat', 'false');

-- ---------- role helper (security definer, pinned search_path, private schema) ----------
create or replace function private.is_moderator() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles r
                 where r.user_id = (select auth.uid()) and r.role in ('moderator', 'admin'))
$$;
revoke execute on function private.is_moderator() from public;
grant execute on function private.is_moderator() to authenticated;

-- ---------- RLS ----------
alter table public.profiles       enable row level security;
alter table public.user_roles     enable row level security;
alter table public.categories     enable row level security;
alter table public.parashot       enable row level security;
alter table public.threads        enable row level security;
alter table public.posts          enable row level security;
alter table public.post_revisions enable row level security;
alter table public.reactions      enable row level security;
alter table public.reports        enable row level security;
alter table public.user_blocks    enable row level security;
alter table public.moderation_log enable row level security;

-- Column-level privileges: RLS filters rows, not columns.
revoke all on public.profiles from anon, authenticated;
grant select (id, display_name, bio, trust_level, created_at) on public.profiles to anon, authenticated;
grant update (display_name, bio, locale, in_israel, shabbat_region) on public.profiles to authenticated;

revoke all on public.threads from anon, authenticated;
grant select on public.threads to anon, authenticated;
grant insert (category_id, parasha_id, verse_ref, title, kind) on public.threads to authenticated;
grant update (title) on public.threads to authenticated;

revoke all on public.posts from anon, authenticated;
grant select on public.posts to anon, authenticated;
grant insert (thread_id, reply_to_post_id, body) on public.posts to authenticated;
grant update (body) on public.posts to authenticated;

revoke all on public.post_revisions, public.moderation_log, public.user_roles from anon, authenticated;
grant select on public.post_revisions, public.moderation_log, public.user_roles to authenticated;

revoke all on public.reports from anon, authenticated;
grant select on public.reports to authenticated;
grant insert (post_id, thread_id, reported_user_id, reason, details) on public.reports to authenticated;

revoke insert, update, delete on public.user_blocks from anon;  -- keep SELECT: the posts policy subquery runs as the caller (RLS returns no rows to anon)
revoke all on public.reactions from anon;
grant select on public.reactions to anon;
revoke all on public.categories, public.parashot from anon, authenticated;
grant select on public.categories, public.parashot to anon, authenticated;

-- profiles
create policy "profiles readable by all" on public.profiles for select to anon, authenticated using (true);
create policy "update own profile" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- roles: a user may see own roles (to show mod UI); only service role/admin RPCs write.
create policy "read own roles" on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()));

-- reference data
create policy "categories readable" on public.categories for select to anon, authenticated using (true);
create policy "parashot readable"   on public.parashot   for select to anon, authenticated using (true);

-- threads
create policy "visible threads readable" on public.threads for select to anon, authenticated
  using (deleted_at is null);
create policy "moderators read all threads" on public.threads for select to authenticated
  using ((select private.is_moderator()));
create policy "create own thread" on public.threads for insert to authenticated
  with check (author_id = (select auth.uid()));
create policy "edit own thread title" on public.threads for update to authenticated
  using (author_id = (select auth.uid()) and deleted_at is null and not is_locked)
  with check (author_id = (select auth.uid()));

-- posts (blocked authors are filtered server-side for the blocker; also applies to Realtime)
create policy "visible posts readable" on public.posts for select to anon, authenticated
  using (deleted_at is null and hidden_at is null
         and not exists (select 1 from public.user_blocks b
                         where b.blocker_id = (select auth.uid()) and b.blocked_id = posts.author_id));
create policy "authors see own hidden posts" on public.posts for select to authenticated
  using (author_id = (select auth.uid()) and deleted_at is null);
create policy "moderators read all posts" on public.posts for select to authenticated
  using ((select private.is_moderator()));
create policy "create own post" on public.posts for insert to authenticated
  with check (author_id = (select auth.uid()));
create policy "edit own post" on public.posts for update to authenticated
  using (author_id = (select auth.uid()) and deleted_at is null)
  with check (author_id = (select auth.uid()));
-- no DELETE policies: deletion is soft, via RPC.

create policy "revisions: moderators" on public.post_revisions for select to authenticated
  using ((select private.is_moderator()));

create policy "reactions readable" on public.reactions for select to anon, authenticated using (true);
create policy "react as self" on public.reactions for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "unreact own" on public.reactions for delete to authenticated
  using (user_id = (select auth.uid()));

create policy "file a report" on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));
create policy "see own reports" on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()));
create policy "moderators see reports" on public.reports for select to authenticated
  using ((select private.is_moderator()));

create policy "own blocks: read" on public.user_blocks for select to authenticated
  using (blocker_id = (select auth.uid()));
create policy "own blocks: add" on public.user_blocks for insert to authenticated
  with check (blocker_id = (select auth.uid()));
create policy "own blocks: remove" on public.user_blocks for delete to authenticated
  using (blocker_id = (select auth.uid()));

create policy "mod log: moderators" on public.moderation_log for select to authenticated
  using ((select private.is_moderator()));

-- ---------- triggers ----------
-- New auth user -> profile row.
-- The default name uses the start of the user id, lengthened on the rare
-- collision (display names are unique) so sign-up can never fail.
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_hex text := replace(new.id::text, '-', ''); v_len int := 8;
begin
  loop
    begin
      insert into public.profiles (id, display_name) values (new.id, 'user_' || substr(v_hex, 1, v_len));
      return new;
    exception when unique_violation then
      if v_len >= 32 then raise; end if;
      v_len := v_len + 4;
    end;
  end loop;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- Shared posting gate: terms accepted, not silenced/banned, optional Shabbat window.
create or replace function private.assert_can_post(p_user uuid) returns public.profiles
language plpgsql stable security definer set search_path = '' as $$
declare v public.profiles;
begin
  select * into v from public.profiles where id = p_user;
  if v.id is null then raise exception 'no_profile' using errcode = 'P0001'; end if;
  if v.accepted_terms_at is null then raise exception 'terms_not_accepted' using errcode = 'P0001'; end if;
  if v.banned_at is not null then raise exception 'banned' using errcode = 'P0001'; end if;
  if v.silenced_until is not null and v.silenced_until > now() then
    raise exception 'silenced_until:%', v.silenced_until using errcode = 'P0001';
  end if;
  if (select value from private.settings where key = 'block_posting_on_shabbat') = 'true'
     and exists (select 1 from private.shabbat_windows w
                 where w.region = coalesce(v.shabbat_region, 'jerusalem')
                   and now() >= w.starts_at and now() < w.ends_at) then
    raise exception 'shabbat_closed' using errcode = 'P0001';
  end if;
  return v;
end $$;

create or replace function private.content_check(p_text text) returns text
language sql stable security definer set search_path = '' as $$
  -- returns 'reject', 'hold' or null
  select case when bool_or(action = 'reject') then 'reject'
              when bool_or(action = 'hold')   then 'hold' end
  from private.banned_terms
  where private.he_plain(p_text) ~* private.he_plain(pattern)   -- case-insensitive; patterns folded the same way
$$;

create or replace function private.posts_before_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_prof public.profiles;
  v_thread public.threads;
  v_check text;
  v_min_gap interval;
begin
  -- never trust client-supplied ownership/state
  new.author_id := (select auth.uid());
  new.created_at := now();
  new.hidden_at := null; new.hidden_reason := null;
  new.deleted_at := null; new.deleted_by := null; new.delete_reason := null;

  v_prof := private.assert_can_post(new.author_id);

  select * into v_thread from public.threads where id = new.thread_id;
  if v_thread.id is null or v_thread.deleted_at is not null then
    raise exception 'thread_not_found' using errcode = 'P0001';
  end if;
  if v_thread.is_locked and not private.is_moderator() then
    raise exception 'thread_locked' using errcode = 'P0001';
  end if;

  -- serialize this user's inserts so the checks below are race-free
  perform pg_advisory_xact_lock(hashtextextended(new.author_id::text, 0));

  -- Discourse-style limits (defaults: 5 s between posts, 30 s for new users)
  v_min_gap := case when v_prof.trust_level = 0 then interval '30 seconds' else interval '5 seconds' end;
  if exists (select 1 from public.posts p
             where p.author_id = new.author_id and p.created_at > now() - v_min_gap) then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'Please wait before posting again.';
  end if;
  if v_thread.slow_mode_seconds > 0 and exists (
       select 1 from public.posts p where p.thread_id = new.thread_id and p.author_id = new.author_id
         and p.created_at > now() - make_interval(secs => v_thread.slow_mode_seconds)) then
    raise exception 'slow_mode' using errcode = 'P0001';
  end if;
  if v_prof.trust_level = 0 and (select count(*) from public.posts p
       where p.author_id = new.author_id and p.created_at > now() - interval '24 hours') >= 10 then
    raise exception 'daily_limit_new_user' using errcode = 'P0001';
  end if;
  -- duplicate content within 5 minutes (Discourse unique_posts_mins = 5)
  if exists (select 1 from public.posts p where p.author_id = new.author_id
               and p.created_at > now() - interval '5 minutes' and p.body = new.body) then
    raise exception 'duplicate_post' using errcode = 'P0001';
  end if;
  -- new users: at most 2 links (Discourse newuser_max_links = 2)
  if v_prof.trust_level = 0
     and (select count(*) from regexp_matches(new.body, 'https?://', 'g')) > 2 then
    raise exception 'too_many_links' using errcode = 'P0001';
  end if;

  v_check := private.content_check(new.body);
  if v_check = 'reject' then
    raise exception 'content_rejected' using errcode = 'P0001';
  elsif v_check = 'hold' then
    new.hidden_at := now(); new.hidden_reason := 'filter_hold';
  end if;
  return new;
end $$;
create trigger posts_before_insert before insert on public.posts
  for each row execute function private.posts_before_insert();

create or replace function private.posts_after_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.threads set post_count = post_count + 1, last_post_at = new.created_at
  where id = new.thread_id;
  return null;
end $$;
create trigger posts_after_insert after insert on public.posts
  for each row execute function private.posts_after_insert();

-- Edits: keep a revision, stamp edited_at, re-run the content filter.
create or replace function private.posts_before_update() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_check text;
begin
  if new.body is distinct from old.body then
    perform private.assert_can_post((select auth.uid()));
    insert into public.post_revisions (post_id, body, edited_by) values (old.id, old.body, (select auth.uid()));
    new.edited_at := now();
    v_check := private.content_check(new.body);
    if v_check = 'reject' then raise exception 'content_rejected' using errcode = 'P0001';
    elsif v_check = 'hold' then new.hidden_at := now(); new.hidden_reason := 'filter_hold'; end if;
  end if;
  return new;
end $$;
create trigger posts_before_update before update on public.posts
  for each row execute function private.posts_before_update();

create or replace function private.threads_before_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_prof public.profiles; v_cat public.categories;
begin
  -- Weekly parsha threads are created by public.ensure_weekly_thread().
  if current_setting('app.system_insert', true) = 'on' then
    new.author_id := null;
    new.created_at := now(); new.last_post_at := now(); new.post_count := 0;
    new.is_locked := false; new.deleted_at := null;
    return new;
  end if;
  new.author_id := (select auth.uid());
  new.created_at := now(); new.last_post_at := now(); new.post_count := 0;
  new.is_pinned := false; new.is_locked := false; new.deleted_at := null;
  if new.kind in ('weekly', 'announcement') and not private.is_moderator() then
    raise exception 'kind_not_allowed' using errcode = 'P0001';
  end if;
  v_prof := private.assert_can_post(new.author_id);
  select * into v_cat from public.categories where id = new.category_id;
  if v_cat.is_locked or v_prof.trust_level < v_cat.min_trust_to_create_thread then
    raise exception 'category_restricted' using errcode = 'P0001';
  end if;
  if v_prof.trust_level = 0 and (select count(*) from public.threads t
       where t.author_id = new.author_id and t.created_at > now() - interval '24 hours') >= 3 then
    raise exception 'daily_thread_limit_new_user' using errcode = 'P0001';   -- Discourse max_topics_in_first_day = 3
  end if;
  if private.content_check(new.title) = 'reject' then
    raise exception 'content_rejected' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger threads_before_insert before insert on public.threads
  for each row execute function private.threads_before_insert();

-- Reports: stamp reporter; auto-hide a post after 3 distinct open reports (pending review).
create or replace function private.reports_before_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.reporter_id := (select auth.uid());
  new.status := 'open'; new.created_at := now();
  new.resolved_by := null; new.resolved_at := null; new.resolution_note := null;
  return new;
end $$;
create trigger reports_before_insert before insert on public.reports
  for each row execute function private.reports_before_insert();

create or replace function private.reports_after_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.post_id is not null and (select count(distinct reporter_id) from public.reports
        where post_id = new.post_id and status = 'open') >= 3 then
    update public.posts set hidden_at = now(), hidden_reason = 'community_flags'
    where id = new.post_id and hidden_at is null;
  end if;
  return null;
end $$;
create trigger reports_after_insert after insert on public.reports
  for each row execute function private.reports_after_insert();

-- ---------- RPCs (public schema = callable via Data API; each checks the caller) ----------
create or replace function public.accept_terms() returns void
language sql security definer set search_path = '' as $$
  update public.profiles set accepted_terms_at = now() where id = (select auth.uid());
$$;

create or replace function public.soft_delete_post(p_post_id bigint, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v_author uuid; v_is_mod boolean := private.is_moderator();
begin
  select author_id into v_author from public.posts where id = p_post_id and deleted_at is null;
  if not found then raise exception 'not_found' using errcode = 'P0001'; end if;
  if v_author is distinct from (select auth.uid()) and not v_is_mod then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.posts set deleted_at = now(), deleted_by = (select auth.uid()), delete_reason = p_reason
  where id = p_post_id;
  if v_is_mod and v_author is distinct from (select auth.uid()) then
    insert into public.moderation_log (actor_id, action, target_type, target_id, reason)
    values ((select auth.uid()), 'delete_post', 'post', p_post_id::text, p_reason);
  end if;
end $$;

create or replace function public.moderate(p_action text, p_target_id text, p_reason text default null,
                                           p_until timestamptz default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_moderator() then raise exception 'forbidden' using errcode = '42501'; end if;
  case p_action
    when 'hide_post'    then update public.posts set hidden_at = now(), hidden_reason = p_reason where id = p_target_id::bigint;
    when 'restore_post' then update public.posts set hidden_at = null, hidden_reason = null, deleted_at = null where id = p_target_id::bigint;
    when 'lock_thread'  then update public.threads set is_locked = true  where id = p_target_id::bigint;
    when 'unlock_thread' then update public.threads set is_locked = false where id = p_target_id::bigint;
    when 'pin_thread'   then update public.threads set is_pinned = true  where id = p_target_id::bigint;
    when 'unpin_thread' then update public.threads set is_pinned = false where id = p_target_id::bigint;
    when 'delete_thread' then update public.threads set deleted_at = now(), deleted_by = (select auth.uid()), delete_reason = p_reason where id = p_target_id::bigint;
    when 'silence_user' then update public.profiles set silenced_until = coalesce(p_until, now() + interval '7 days') where id = p_target_id::uuid;
    when 'ban_user'     then update public.profiles set banned_at = now() where id = p_target_id::uuid;
    when 'unban_user'   then update public.profiles set banned_at = null, silenced_until = null where id = p_target_id::uuid;
    when 'set_trust'    then update public.profiles set trust_level = p_reason::smallint where id = p_target_id::uuid;
    when 'resolve_report' then update public.reports set status = 'actioned', resolved_by = (select auth.uid()), resolved_at = now() where id = p_target_id::bigint;
    when 'dismiss_report' then update public.reports set status = 'dismissed', resolved_by = (select auth.uid()), resolved_at = now() where id = p_target_id::bigint;
    else raise exception 'unknown_action' using errcode = 'P0001';
  end case;
  insert into public.moderation_log (actor_id, action, target_type, target_id, reason)
  values ((select auth.uid()), p_action, split_part(p_action, '_', 2), p_target_id, p_reason);
end $$;

-- Account deletion (Apple 5.1.1(v) / Google Play). Deletes the user's posts' content, then the auth user.
-- Delete the user's Storage objects first (Storage ownership blocks auth user deletion).
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  delete from public.posts where author_id = v_uid;                 -- UGC removed (Apple FAQ expectation)
  delete from public.threads t where t.author_id = v_uid
     and not exists (select 1 from public.posts p where p.thread_id = t.id);
  delete from auth.users where id = v_uid;                          -- cascades profiles, roles, blocks, reports, reactions
end $$;


-- ---------- progress backup ----------
create table public.user_progress (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb not null check (pg_column_size(data) < 1000000),
  updated_at timestamptz not null default now()
);
alter table public.user_progress enable row level security;
revoke all on public.user_progress from anon, authenticated;
grant select, insert, update, delete on public.user_progress to authenticated;
create policy "own progress" on public.user_progress for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create or replace function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;
create trigger user_progress_touch before insert or update on public.user_progress
  for each row execute function private.touch_updated_at();

-- ---------- app RPCs ----------
-- The caller's own profile, including fields not readable through the API.
create or replace function public.my_profile() returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'id', p.id,
    'display_name', p.display_name,
    'accepted_terms', p.accepted_terms_at is not null,
    'is_moderator', exists (select 1 from public.user_roles r
                            where r.user_id = p.id and r.role in ('moderator', 'admin')))
  from public.profiles p where p.id = (select auth.uid())
$$;

-- A thread and its first post, atomically. Runs as the caller, so every
-- policy and trigger above applies.
create or replace function public.create_thread(p_category_id smallint, p_title text, p_body text,
                                                p_parasha_id smallint default null) returns bigint
language plpgsql security invoker set search_path = '' as $$
declare v_id bigint;
begin
  insert into public.threads (category_id, parasha_id, title, kind)
  values (p_category_id, p_parasha_id, p_title, 'discussion')
  returning id into v_id;
  insert into public.posts (thread_id, body) values (v_id, p_body);
  return v_id;
end $$;

-- The shared discussion for a parsha in a given year, created on first use.
-- The title is built here from reference data, so callers can't choose it.
create or replace function public.ensure_weekly_thread(p_parasha_id smallint, p_hebrew_year smallint) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_id bigint; v_par public.parashot; v_cat smallint;
begin
  if p_hebrew_year not between 5780 and 6100 then raise exception 'invalid_year' using errcode = 'P0001'; end if;
  select * into v_par from public.parashot where id = p_parasha_id;
  if v_par.id is null then raise exception 'invalid_parasha' using errcode = 'P0001'; end if;
  select id into v_id from public.threads
   where kind = 'weekly' and parasha_id = p_parasha_id and hebrew_year = p_hebrew_year and deleted_at is null;
  if v_id is not null then return v_id; end if;
  select id into v_cat from public.categories where slug = 'parsha';
  perform set_config('app.system_insert', 'on', true);
  insert into public.threads (category_id, parasha_id, hebrew_year, kind, title, is_pinned)
  values (v_cat, p_parasha_id, p_hebrew_year, 'weekly',
          v_par.name_en || ' · ' || v_par.name_he || ' · ' || p_hebrew_year, true)
  on conflict do nothing
  returning id into v_id;
  perform set_config('app.system_insert', 'off', true);
  if v_id is null then  -- created concurrently
    select id into v_id from public.threads
     where kind = 'weekly' and parasha_id = p_parasha_id and hebrew_year = p_hebrew_year and deleted_at is null;
  end if;
  return v_id;
end $$;

revoke execute on function public.my_profile(), public.create_thread(smallint, text, text, smallint),
  public.ensure_weekly_thread(smallint, smallint) from public;
grant execute on function public.my_profile(), public.create_thread(smallint, text, text, smallint) to authenticated;
grant execute on function public.ensure_weekly_thread(smallint, smallint) to anon, authenticated;

revoke execute on function public.accept_terms(), public.soft_delete_post(bigint, text),
  public.moderate(text, text, text, timestamptz), public.delete_my_account() from public, anon;
grant execute on function public.accept_terms(), public.soft_delete_post(bigint, text),
  public.moderate(text, text, text, timestamptz), public.delete_my_account() to authenticated;
-- trigger/helper functions live in the private schema; also close them off:
revoke execute on all functions in schema private from public, anon;
grant execute on function private.is_moderator(), private.he_plain(text) to authenticated;

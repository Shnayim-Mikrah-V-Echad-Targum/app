-- Behavior tests for the community schema. Run with run_tests.sh.
-- Each check raises an exception (and stops the run) if it fails.
\set ON_ERROR_STOP 1
\set QUIET 1
\pset tuples_only on
\o /dev/null

\set alice   '00000000-0000-0000-0000-00000000000a'
\set bob     '00000000-0000-0000-0000-00000000000b'
\set carol   '00000000-0000-0000-0000-00000000000c'
\set dave    '00000000-0000-0000-0000-00000000000d'
\set mod     '00000000-0000-0000-0000-0000000000ff'

-- Helper: assert that a statement fails with an error starting with `expected`.
create function public.expect_error(stmt text, expected text) returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    if sqlerrm like expected || '%' then return; end if;
    raise exception 'expected error "%" but got "%" for: %', expected, sqlerrm, stmt;
  end;
  raise exception 'expected error "%" but statement succeeded: %', expected, stmt;
end $$;
grant execute on function public.expect_error(text, text) to anon, authenticated;

create function public.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not coalesce(ok, false) then raise exception 'CHECK FAILED: %', what; end if;
  raise notice 'ok: %', what;
end $$;
grant execute on function public.check(boolean, text) to anon, authenticated;

-- ---- setup (as the database owner) ----
insert into auth.users (id, email) values
  (:'alice', 'alice@example.org'), (:'bob', 'bob@example.org'), (:'carol', 'carol@example.org'),
  (:'dave', 'dave@example.org'), (:'mod', 'mod@example.org');
insert into public.user_roles (user_id, role) values (:'mod', 'moderator');
select public.check((select count(*) = 5 from public.profiles), 'a profile is created for every new user');
select public.check((select count(*) = 54 from public.parashot), 'reference data: 54 parshiyot');
select public.check((select count(*) = 6 from public.categories), 'reference data: 6 forum categories');

-- ---- posting requires accepting the guidelines ----
set role authenticated;
select set_config('request.jwt.claim.sub', :'alice', false);
select public.expect_error($$select public.create_thread(2::smallint, 'A question about Bereshit', 'Why does it start with bet?')$$, 'terms_not_accepted');
select public.accept_terms();
select public.check((select (public.my_profile()->>'accepted_terms')::boolean), 'my_profile reports accepted guidelines');
select public.create_thread(2::smallint, 'A question about Bereshit', 'Why does the Torah begin with a bet?') as t1 \gset
select set_config('test.t1', :'t1', false);
select public.check((select author_id = :'alice' and post_count = 1 from public.threads where id = :t1), 'thread created with first post, author stamped by trigger');

-- ---- rate limits (new members wait 30 s between posts) ----
select public.expect_error(format('insert into public.posts (thread_id, body) values (%s, %L)', :t1, 'A quick follow-up'), 'rate_limited');
reset role;
update public.posts set created_at = now() - interval '2 minutes' where author_id = :'alice';
set role authenticated;
select set_config('request.jwt.claim.sub', :'alice', false);

-- ---- authors can't be spoofed ----
select public.expect_error(format('insert into public.posts (thread_id, body, author_id) values (%s, %L, %L)', :t1, 'Spoofed post', :'bob'), 'permission denied');

-- ---- anonymous visitors can read but not write ----
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
select public.check((select count(*) = 1 from public.threads), 'anon can read threads');
select public.check((select count(*) = 1 from public.posts), 'anon can read posts');
select public.expect_error(format('insert into public.posts (thread_id, body) values (%s, %L)', :t1, 'anon post'), 'permission denied');

-- ---- blocking hides a member's posts from the blocker only ----
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub', :'bob', false);
select public.accept_terms();
insert into public.posts (thread_id, body) values (:t1, 'Rashi asks this very question!');
insert into public.user_blocks (blocker_id, blocked_id) values (:'bob', :'alice');
select public.check((select count(*) = 1 from public.posts where thread_id = :t1), 'blocked author''s posts are hidden from the blocker');
select set_config('request.jwt.claim.sub', :'carol', false);
select public.check((select count(*) = 2 from public.posts where thread_id = :t1), 'other members still see both posts');

-- ---- the app's todah and blocks may be sent twice (upserts that ignore duplicates) ----
select id as bob_post from public.posts where author_id = :'bob' \gset
insert into public.reactions (post_id, user_id) values (:bob_post, :'carol') on conflict (post_id, user_id, kind) do nothing;
insert into public.reactions (post_id, user_id) values (:bob_post, :'carol') on conflict (post_id, user_id, kind) do nothing;
select public.check((select count(*) = 1 from public.reactions where post_id = :bob_post), 'todah given twice counts once');
select set_config('request.jwt.claim.sub', :'bob', false);
insert into public.user_blocks (blocker_id, blocked_id) values (:'bob', :'alice') on conflict (blocker_id, blocked_id) do nothing;
select public.check((select count(*) = 1 from public.user_blocks), 'blocking twice keeps one block');
select set_config('request.jwt.claim.sub', :'carol', false);

-- ---- three distinct reports hide a post pending review ----
select id as alice_post from public.posts where author_id = :'alice' \gset
insert into public.reports (post_id, reason) values (:alice_post, 'spam');
select set_config('request.jwt.claim.sub', :'dave', false);
insert into public.reports (post_id, reason) values (:alice_post, 'spam');
select set_config('request.jwt.claim.sub', :'bob', false);
insert into public.reports (post_id, reason) values (:alice_post, 'disrespect');
-- The app tells this apart from a taken display name by the index's name.
select public.expect_error(format('insert into public.reports (post_id, reason) values (%s, %L)', :alice_post, 'spam'),
  'duplicate key value violates unique constraint "reports_one_per_reporter_post"');
select set_config('request.jwt.claim.sub', :'carol', false);
select public.check((select count(*) = 1 from public.posts where thread_id = :t1), 'post auto-hidden after 3 reports');
select set_config('request.jwt.claim.sub', :'alice', false);
select public.check((select count(*) = 1 from public.posts where id = :alice_post), 'author still sees own hidden post');
select public.check((select count(*) = 0 from public.reports), 'members cannot see reports filed by others');

-- ---- moderation ----
select public.expect_error(format('select public.moderate(%L, %L)', 'lock_thread', :t1), 'forbidden');
select set_config('request.jwt.claim.sub', :'mod', false);
select public.check((select count(*) = 3 from public.reports), 'moderators see all reports');
select public.moderate('lock_thread', :'t1');
select public.check((select count(*) = 1 from public.moderation_log where action = 'lock_thread'), 'moderator actions are logged');
select set_config('request.jwt.claim.sub', :'carol', false);
select public.accept_terms();
select public.expect_error(format('insert into public.posts (thread_id, body) values (%s, %L)', :t1, 'Reply to locked thread'), 'thread_locked');

-- ---- members may edit only their own posts; edits keep revisions ----
select set_config('request.jwt.claim.sub', :'bob', false);
select id as bob_post from public.posts where author_id = :'bob' \gset
update public.posts set body = 'Rashi asks this very question — see his first comment.' where id = :bob_post;
select set_config('request.jwt.claim.sub', :'carol', false);
update public.posts set body = 'vandalized' where id = :bob_post;
reset role;
select public.check((select body like 'Rashi asks%' and edited_at is not null from public.posts where id = :bob_post), 'edit by author applied; edit by another member ignored');
select public.check((select count(*) = 1 from public.post_revisions where post_id = :bob_post), 'edit kept a revision');
set role authenticated;
select set_config('request.jwt.claim.sub', :'carol', false);
select public.expect_error(format('select public.soft_delete_post(%s)', :bob_post), 'forbidden');

-- ---- a thread's post count leaves out deleted posts ----
select set_config('request.jwt.claim.sub', :'bob', false);
select public.soft_delete_post(:bob_post);
select public.check((select post_count = 1 from public.threads where id = :t1), 'a deleted post leaves its thread''s count');
select set_config('request.jwt.claim.sub', :'mod', false);
select public.moderate('restore_post', :'bob_post');
select public.check((select post_count = 2 from public.threads where id = :t1), 'a restored post counts again');

-- ---- content filter folds vowels, cantillation and final letters ----
reset role;
insert into private.banned_terms (pattern, action) values ('שקרן', 'reject');
set role authenticated;
select set_config('request.jwt.claim.sub', :'dave', false);
select public.accept_terms();
select public.expect_error($$select public.create_thread(3::smallint, 'An insight on the parsha', 'He is a שַׁקְרָן!')$$, 'content_rejected');

-- ---- locked categories: only moderators start threads ----
select public.expect_error($$select public.create_thread(6::smallint, 'Big announcement here', 'Hello everyone')$$, 'category_restricted');

-- ---- weekly parsha threads ----
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
select public.ensure_weekly_thread(1::smallint, 5787::smallint) as w1 \gset
select public.ensure_weekly_thread(1::smallint, 5787::smallint) as w2 \gset
select public.check(:w1 = :w2, 'weekly thread is created once and reused');
select public.check((select title = 'Bereshit · בראשית · 5787' and kind = 'weekly' and author_id is null from public.threads where id = :w1), 'weekly thread title comes from reference data');
select public.ensure_weekly_thread(3::smallint, 5787::smallint) as w3 \gset
select public.check((select title = 'Lech Lecha · לך־לך · 5787' from public.threads where id = :w3),
                    'weekly thread titles spell names as the app does, with the maqaf of a Hebrew name');
-- The app's "This week" card opens it: pinned, past weeks would crowd out every other thread.
select public.check((select not is_pinned from public.threads where id = :w1), 'a new weekly thread is not pinned');
select public.expect_error($$select public.ensure_weekly_thread(99::smallint, 5787::smallint)$$, 'invalid_parasha');
select public.expect_error($$insert into public.threads (category_id, title, kind) values (1, 'Fake weekly thread', 'weekly')$$, 'permission denied');
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub', :'dave', false);
select public.expect_error($$insert into public.threads (category_id, title, kind) values (1, 'Fake weekly thread', 'weekly')$$, 'kind_not_allowed');

-- ---- progress backup is private to its owner ----
select set_config('request.jwt.claim.sub', :'alice', false);
insert into public.user_progress (user_id, data) values (:'alice', '{"version": 1}');
select set_config('request.jwt.claim.sub', :'bob', false);
select public.check((select count(*) = 0 from public.user_progress), 'members cannot read others'' progress');
select public.expect_error(format('insert into public.user_progress (user_id, data) values (%L, %L)', :'alice', '{}'), 'new row violates row-level security');

-- ---- display names are unique, case-insensitively ----
update public.profiles set display_name = 'Bob the Reader' where id = :'bob';
select set_config('request.jwt.claim.sub', :'carol', false);
select public.expect_error($$update public.profiles set display_name = 'bob THE reader' where id = auth.uid()$$,
  'duplicate key value violates unique constraint "profiles_display_name_ci"');
select public.expect_error($$update public.profiles set trust_level = 4 where id = auth.uid()$$, 'permission denied');

-- ---- forum lists: each discussion's excerpt and thanks, and each forum's activity ----
select set_config('request.jwt.claim.sub', :'dave', false);
update public.profiles set display_name = 'Dave' where id = auth.uid();
select public.create_thread(4::smallint, 'Looking for a chavruta', E'Is anyone reading the Targum aloud each evening?\n\nI would love a partner for the second half of the week, by phone or in person, and I am happy to go slowly through the harder verses.') as t2 \gset
select id as dave_post from public.posts where thread_id = :t2 \gset
select public.check((select excerpt = 'Is anyone reading the Targum aloud each evening? I would love a partner for the second half of the week, by phone or in person, and I am…'
                       and author_name = 'Dave'
                     from public.thread_listing where id = :t2),
                    'a discussion is listed with its author and its first post''s opening, its lines run together and cut at a word');
update public.posts set body = 'Notes: https://example.org/' || repeat('a', 200) where id = :dave_post;
select public.check((select excerpt = 'Notes: https://example.org/' || repeat('a', 112) || '…' from public.thread_listing where id = :t2),
                    'a long link is cut short rather than dropped');
update public.posts set body = 'Is anyone reading the Targum aloud each evening?' where id = :dave_post;
select public.check((select excerpt = 'Is anyone reading the Targum aloud each evening?' from public.thread_listing where id = :t2),
                    'a short post is its own excerpt, edits included');
select set_config('request.jwt.claim.sub', :'carol', false);
insert into public.posts (thread_id, body) values (:t2, 'Count me in for Wednesday evenings.');
select id as carol_post from public.posts where thread_id = :t2 and author_id = :'carol' \gset
insert into public.reactions (post_id, user_id) values (:dave_post, :'carol');
select set_config('request.jwt.claim.sub', :'bob', false);
insert into public.reactions (post_id, user_id) values (:dave_post, :'bob'), (:carol_post, :'bob');
select set_config('request.jwt.claim.sub', :'dave', false);
insert into public.reactions (post_id, user_id) values (:carol_post, :'dave');
select public.check((select excerpt like 'Is anyone reading%' and todah_total = 4 and post_count = 2 from public.thread_listing where id = :t2),
                    'a reply leaves the excerpt as it was, and every todah on the thread''s posts counts');
select set_config('request.jwt.claim.sub', :'bob', false);
insert into public.reactions (post_id, user_id, kind) values (:carol_post, :'bob', 'insightful');
select public.check((select todah_total = 4 from public.thread_listing where id = :t2),
                    'another kind of reaction is no todah, and leaves the count');
delete from public.reactions where post_id = :carol_post and user_id = :'bob' and kind = 'insightful';
select set_config('request.jwt.claim.sub', :'dave', false);
-- Blocking hides the blocked member's excerpt, and the thanks on their posts, from the blocker alone.
select set_config('request.jwt.claim.sub', :'carol', false);
insert into public.user_blocks (blocker_id, blocked_id) values (:'carol', :'dave');
select public.check((select excerpt is null and todah_total = 2 from public.thread_listing where id = :t2),
                    'a blocked author''s excerpt is hidden from the blocker, and so are the thanks on their posts');
select set_config('request.jwt.claim.sub', :'bob', false);
select public.check((select excerpt like 'Is anyone reading%' and todah_total = 4 from public.thread_listing where id = :t2),
                    'other members still see the excerpt and every todah');
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
select public.check((select excerpt like 'Is anyone reading%' and todah_total = 4 from public.thread_listing where id = :t2),
                    'anon can read the listing');
select public.expect_error($$insert into public.thread_listing (category_id, title) values (4, 'Written through the view')$$, 'permission denied');
reset role;
set role authenticated;
-- The first thread's opening post is hidden pending review (three reports, above).
select set_config('request.jwt.claim.sub', :'carol', false);
select public.check((select excerpt is null from public.thread_listing where id = :t1),
                    'a post hidden pending review gives other members no excerpt');
-- A todah given to it before it was hidden counts only for those who may see it.
select todah_total as t1_todah from public.thread_listing where id = :t1 \gset
reset role;
insert into public.reactions (post_id, user_id) values (:alice_post, :'dave');
set role authenticated;
select set_config('request.jwt.claim.sub', :'carol', false);
select public.check((select todah_total = :t1_todah from public.thread_listing where id = :t1),
                    'a todah on a post hidden pending review is not counted for other members');
select set_config('request.jwt.claim.sub', :'mod', false);
select public.check((select todah_total = :t1_todah + 1 from public.thread_listing where id = :t1),
                    'but is for moderators, who see the post');
select set_config('request.jwt.claim.sub', :'carol', false);
select set_config('request.jwt.claim.sub', :'alice', false);
select public.check((select excerpt = 'Why does the Torah begin with a bet?' from public.thread_listing where id = :t1),
                    'its author still sees the excerpt of their own hidden post');
select set_config('request.jwt.claim.sub', :'mod', false);
select public.check((select excerpt = 'Why does the Torah begin with a bet?' from public.thread_listing where id = :t1),
                    'so do moderators');
-- A deleted first post gives way to the next.
select set_config('request.jwt.claim.sub', :'dave', false);
select public.soft_delete_post(:dave_post);
select set_config('request.jwt.claim.sub', :'bob', false);
select public.check((select excerpt = 'Count me in for Wednesday evenings.' and todah_total = 2 from public.thread_listing where id = :t2),
                    'once the first post is deleted, the excerpt is the next post''s, and the deleted post''s thanks no longer count');
-- Each forum: how many discussions, and when one was last posted in.
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
select public.check((select count(*) = 6 from public.category_stats), 'every forum has its stats, empty or not');
select public.check((select thread_count = 1 and last_post_at = (select last_post_at from public.threads where id = :t2)
                     from public.category_stats where category_id = 4),
                    'a forum counts its discussions, and was last active at its latest post');
select public.check((select thread_count = 2 and last_post_at is null from public.category_stats where category_id = 1),
                    'weekly threads not yet posted in count as discussions, but not as activity');
select public.check((select thread_count = 0 and last_post_at is null from public.category_stats where category_id = 6),
                    'a forum with no discussions counts none');
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub', :'mod', false);
select public.moderate('delete_thread', :'t2');
select public.check((select count(*) = 1 from public.threads where id = :t2), 'moderators can still read a deleted thread');
select public.check((select count(*) = 0 from public.thread_listing where id = :t2), 'but the listing leaves it out, for them too');
select public.check((select thread_count = 0 and last_post_at is null from public.category_stats where category_id = 4),
                    'and so does its forum''s count');
select set_config('request.jwt.claim.sub', :'carol', false);
select public.check((select thread_count = 0 from public.category_stats where category_id = 4), 'for members too');
delete from public.user_blocks where blocker_id = :'carol';

-- ---- account deletion removes the account and everything posted ----
select set_config('request.jwt.claim.sub', :'alice', false);
select public.delete_my_account();
reset role;
select public.check((select count(*) = 0 from auth.users where id = :'alice'), 'auth user deleted');
select public.check((select count(*) = 0 from public.profiles where id = :'alice'), 'profile deleted');
select public.check((select count(*) = 0 from public.posts where author_id = :'alice'), 'posts deleted');
select public.check((select post_count = 1 from public.threads where id = :t1), 'deleted posts leave their thread''s count');
select public.check((select count(*) = 0 from public.user_progress where user_id = :'alice'), 'progress backup deleted');

\echo 'All community schema tests passed.'

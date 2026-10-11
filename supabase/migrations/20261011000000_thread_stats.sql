-- Signs of life in the forum lists.
--
-- A forum listed its discussions by title alone, and the Community page its
-- forums by name, so nothing showed what a discussion was about or which
-- forums were busy. A discussion is now listed with the opening of its first
-- post and the thanks its posts have been given, and a forum with how many
-- discussions it holds and when one was last posted in.
--
-- Both views run as the caller (security_invoker), so every policy applies
-- as it does to the tables beneath: no one reads through them a post they
-- couldn't read, such as one hidden pending review or one by a member they
-- have blocked.

-- The first post of a thread that has not been deleted, whoever may read it.
-- The listing reads that post as the caller, so a reader who may not see it
-- gets no excerpt rather than another post's words in its place.
create or replace function private.first_post_id(p_thread_id bigint) returns bigint
language sql stable security definer set search_path = '' as $$
  select p.id from public.posts p
   where p.thread_id = p_thread_id and p.deleted_at is null
   order by p.created_at, p.id
   limit 1
$$;
revoke execute on function private.first_post_id(bigint) from public;
grant execute on function private.first_post_id(bigint) to anon, authenticated;

-- A forum's discussions as the app lists them: each thread with its author's
-- name, an excerpt and the thanks given to the posts the reader can see.
-- The excerpt is the first post with its spaces and line breaks run
-- together; past 140 characters it is cut after the last whole word that
-- fits (or at 139, where that would lose more than 40, as in a long link)
-- and ends with an ellipsis. Deleted threads are left out, for moderators
-- too, which also lets the listing use its index.
create view public.thread_listing with (security_invoker = true) as
select t.id, t.category_id, t.parasha_id, t.hebrew_year, t.kind, t.title, t.author_id,
       t.is_pinned, t.is_locked, t.post_count, t.last_post_at, t.created_at,
       (select pr.display_name from public.profiles pr where pr.id = t.author_id) as author_name,
       (select case when f.body = '' then null
                    when char_length(f.body) <= 140 then f.body
                    when char_length(w.cut) >= 100 then w.cut || '…'
                    else left(f.body, 139) || '…'
               end
          from (select btrim(regexp_replace(p.body, '\s+', ' ', 'g')) as body
                  from public.posts p
                 where p.id = private.first_post_id(t.id)) f
          cross join lateral (select substring(left(f.body, 141) from '^(.*\S)\s') as cut) w) as excerpt,
       (select count(*)::integer
          from public.reactions r
          join public.posts p on p.id = r.post_id
         where p.thread_id = t.id and p.deleted_at is null and r.kind = 'todah') as todah_total
from public.threads t
where t.deleted_at is null;

-- Each forum's discussions, and when one was last posted in: a weekly
-- thread opened but not yet posted in counts as a discussion, as the forum
-- lists it, but is no sign of activity.
create view public.category_stats with (security_invoker = true) as
select c.id as category_id,
       count(t.id)::integer as thread_count,
       max(t.last_post_at) filter (where t.post_count > 0) as last_post_at
from public.categories c
left join public.threads t on t.category_id = c.id and t.deleted_at is null
group by c.id;

-- Read-only, whatever the schema's default privileges grant.
revoke all on public.thread_listing, public.category_stats from anon, authenticated;
grant select on public.thread_listing, public.category_stats to anon, authenticated;

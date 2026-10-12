-- A question about a verse is listed by its question.
--
-- "Ask about this verse" begins a discussion's first post by quoting the
-- verse: "> " and its Hebrew (after a left-to-right mark, for a question
-- written from the left), a blank line, then the question. The listing ran
-- the post's lines together, so a forum showed the quote in place of the
-- question, as raw text, and a long verse filled the excerpt on its own.
-- The excerpt now starts after the quote, as the app reads one
-- (splitVerseQuote, lib/features/community/data/models.dart): a post that
-- begins with "> " and Hebrew quotes a verse up to its first blank line.
-- A post of nothing but the quote has no excerpt. The posts themselves are
-- unchanged.

-- [p_body] without the verse it begins by quoting, if it quotes one.
create or replace function private.after_verse_quote(p_body text) returns text
language sql immutable set search_path = '' as $$
  select case
           when p_body !~ '^\u200e?> [\u0590-\u05ff]' then p_body
           when strpos(p_body, E'\n\n') = 0 then ''
           else substr(p_body, strpos(p_body, E'\n\n') + 2)
         end
$$;
revoke execute on function private.after_verse_quote(text) from public;
grant execute on function private.after_verse_quote(text) to anon, authenticated;

-- As in 20261011000000_thread_stats.sql, but for where the excerpt starts.
create or replace view public.thread_listing with (security_invoker = true) as
select t.id, t.category_id, t.parasha_id, t.hebrew_year, t.kind, t.title, t.author_id,
       t.is_pinned, t.is_locked, t.post_count, t.last_post_at, t.created_at,
       (select pr.display_name from public.profiles pr where pr.id = t.author_id) as author_name,
       (select case when f.body = '' then null
                    when char_length(f.body) <= 140 then f.body
                    when char_length(w.cut) >= 100 then w.cut || '…'
                    else left(f.body, 139) || '…'
               end
          from (select btrim(regexp_replace(private.after_verse_quote(p.body), '\s+', ' ', 'g')) as body
                  from public.posts p
                 where p.id = private.first_post_id(t.id)) f
          cross join lateral (select substring(left(f.body, 141) from '^(.*\S)\s') as cut) w) as excerpt,
       (select count(*)::integer
          from public.reactions r
          join public.posts p on p.id = r.post_id
         where p.thread_id = t.id and p.deleted_at is null and r.kind = 'todah') as todah_total
from public.threads t
where t.deleted_at is null;

-- Read-only, whatever the schema's default privileges grant.
revoke all on public.thread_listing from anon, authenticated;
grant select on public.thread_listing to anon, authenticated;

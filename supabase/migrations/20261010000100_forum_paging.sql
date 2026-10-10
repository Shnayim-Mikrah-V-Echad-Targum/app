-- Paging a forum's threads and a thread's posts.
--
-- The app pages by keyset: threads newest activity first and posts newest
-- first, each tied on id, so that a page never repeats or skips a row. The
-- indexes below match those orders exactly.
--
-- A thread's post count is shown above its posts, whose earliest the reader
-- may not have loaded, so it now stays exact: a post deleted (or restored by
-- a moderator) no longer counts (or counts again).

drop index public.threads_listing;
create index threads_listing on public.threads (category_id, is_pinned desc, last_post_at desc, id desc)
  where deleted_at is null;

drop index public.posts_thread_visible;
create index posts_thread_visible on public.posts (thread_id, created_at desc, id desc) where deleted_at is null;

create or replace function private.posts_after_delete_change() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_delta integer;
begin
  if tg_op = 'DELETE' then
    v_delta := case when old.deleted_at is null then -1 else 0 end;
  else
    v_delta := case when old.deleted_at is null and new.deleted_at is not null then -1
                    when old.deleted_at is not null and new.deleted_at is null then 1
                    else 0 end;
  end if;
  if v_delta <> 0 then
    update public.threads set post_count = greatest(post_count + v_delta, 0) where id = old.thread_id;
  end if;
  return null;
end $$;
create trigger posts_after_soft_delete after update of deleted_at on public.posts
  for each row execute function private.posts_after_delete_change();
create trigger posts_after_delete after delete on public.posts
  for each row execute function private.posts_after_delete_change();
revoke execute on function private.posts_after_delete_change() from public, anon;

-- Counts kept before this migration included deleted posts.
update public.threads t set post_count =
  (select count(*) from public.posts p where p.thread_id = t.id and p.deleted_at is null);

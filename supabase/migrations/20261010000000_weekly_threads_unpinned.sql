-- Weekly parsha threads are no longer pinned.
--
-- Every weekly thread used to be created pinned, and pinned threads are
-- listed before all others. After half a year the first page of the Parsha
-- forum held nothing but past weeks, and new discussions were out of sight.
-- The app's "This week" card opens the current week's thread, so it needs
-- no pin. Moderators can still pin any thread by hand.

update public.threads set is_pinned = false where kind = 'weekly';

-- As in 20261009000000_community.sql, but the new thread is not pinned.
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
          v_par.name_en || ' · ' || v_par.name_he || ' · ' || p_hebrew_year, false)
  on conflict do nothing
  returning id into v_id;
  perform set_config('app.system_insert', 'off', true);
  if v_id is null then  -- created concurrently
    select id into v_id from public.threads
     where kind = 'weekly' and parasha_id = p_parasha_id and hebrew_year = p_hebrew_year and deleted_at is null;
  end if;
  return v_id;
end $$;

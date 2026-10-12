-- The Parshat HaShavua forum's description, typeset.
--
-- The app sets every apostrophe it shows as ’, never the typewriter's ',
-- which its serif draws as a straight tick. 20261009000100_reference_data.sql
-- now has the typeset description for a new database; this brings an
-- existing one up to date, unless a moderator has reworded it since.

update public.categories
   set description_en = 'A discussion thread for every week’s parsha.'
 where slug = 'parsha'
   and description_en = 'A discussion thread for every week''s parsha.';

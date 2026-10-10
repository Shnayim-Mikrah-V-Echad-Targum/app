-- One spelling for the parsha names.
--
-- The English names were @hebcal's data keys, which mix styles: "Lech-Lecha"
-- but "Ki Tisa", "Vezot Haberakhah" but "Noach", "Sh'lach", "Nasso". And the
-- Hebrew names lost their maqaf, so that "לך־לך" read "לךלך". The app now
-- shows one style, and 20261009000100_reference_data.sql has these names
-- for a new database; this brings an existing one up to date, along with
-- the titles of its weekly threads, which are built from them.

update public.parashot p set name_en = v.name_en, name_he = v.name_he
from (values
  (3, 'Lech Lecha', 'לך־לך'),
  (5, 'Chayei Sarah', 'חיי שרה'),
  (14, 'Va''era', 'וארא'),
  (26, 'Shemini', 'שמיני'),
  (29, 'Acharei Mot', 'אחרי מות'),
  (35, 'Naso', 'נשא'),
  (37, 'Shelach', 'שלח־לך'),
  (45, 'Va''etchanan', 'ואתחנן'),
  (49, 'Ki Teitzei', 'כי־תצא'),
  (50, 'Ki Tavo', 'כי־תבוא'),
  (54, 'Vezot HaBerachah', 'וזאת הברכה')
) as v (id, name_en, name_he)
where p.id = v.id;

-- As ensure_weekly_thread titles a new one.
update public.threads t set title = p.name_en || ' · ' || p.name_he || ' · ' || t.hebrew_year
from public.parashot p
where t.kind = 'weekly' and t.parasha_id = p.id and t.hebrew_year is not null
  and t.title is distinct from p.name_en || ' · ' || p.name_he || ' · ' || t.hebrew_year;

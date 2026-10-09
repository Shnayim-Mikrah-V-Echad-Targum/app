"""Generates supabase/migrations/20261009000100_reference_data.sql (forum
categories and the 54 parshiyot) from assets/data/parshiyot.json.

    python3 tool/data/gen_supabase_reference.py
"""
import json
import os
import re

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
data = json.load(open(os.path.join(root, 'assets/data/parshiyot.json')))
BOOKS = ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy']

CATEGORIES = [
    ('parsha', 'Parshat HaShavua', 'פרשת השבוע', "A discussion thread for every week's parsha.", 'שרשור דיון לכל פרשת שבוע.', 1, False),
    ('questions', 'Questions & answers', 'שאלות ותשובות', 'Ask about a verse, a Targum or a Rashi.', 'שאלות על פסוק, תרגום או רש״י.', 2, False),
    ('divrei-torah', 'Divrei Torah', 'דברי תורה', 'Share an insight on the parsha.', 'שיתוף חידוש על הפרשה.', 3, False),
    ('chavruta', 'Chavruta & encouragement', 'חברותא ועידוד', 'Find a learning partner and keep each other going.', 'מציאת חברותא ועידוד הדדי.', 4, False),
    ('feedback', 'App feedback', 'משוב על האפליקציה', 'Ideas, bugs and accessibility feedback.', 'רעיונות, תקלות ומשוב על נגישות.', 5, False),
    ('announcements', 'Announcements', 'הודעות', 'News from the maintainers.', 'חדשות מצוות האפליקציה.', 6, True),
]


def q(s):
    return "'" + s.replace("'", "''") + "'"


def strip_marks(s):
    return re.sub('[֑-ׇ]', '', s)


out = [
    '-- Reference data: forum categories and the 54 parshiyot.',
    '-- GENERATED from assets/data/parshiyot.json by tool/data/gen_supabase_reference.py.',
    '',
    'insert into public.categories (slug, name_en, name_he, description_en, description_he, sort_order, is_locked) values',
    ',\n'.join(f"  ({q(a)}, {q(b)}, {q(c)}, {q(d)}, {q(e)}, {f}, {'true' if g else 'false'})" for a, b, c, d, e, f, g in CATEGORIES)
    + '\non conflict (slug) do update set name_en = excluded.name_en, name_he = excluded.name_he,'
    + '\n  description_en = excluded.description_en, description_he = excluded.description_he,'
    + '\n  sort_order = excluded.sort_order, is_locked = excluded.is_locked;',
    '',
    'insert into public.parashot (id, name_en, name_he, book, start_ref, end_ref) values',
    ',\n'.join(
        f"  ({p['num']}, {q(p['key'])}, {q(strip_marks(p['he']))}, {BOOKS.index(p['book']) + 1}, "
        f"{q(p['book'] + ' ' + p['start'])}, {q(p['book'] + ' ' + p['end'])})"
        for p in data['parshiyot'])
    + '\non conflict (id) do update set name_en = excluded.name_en, name_he = excluded.name_he,'
    + '\n  book = excluded.book, start_ref = excluded.start_ref, end_ref = excluded.end_ref;',
]
path = os.path.join(root, 'supabase/migrations/20261009000100_reference_data.sql')
with open(path, 'w') as f:
    f.write('\n'.join(out) + '\n')
print('wrote', os.path.relpath(path, root))

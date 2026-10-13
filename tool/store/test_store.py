"""Checks the store listings in store/ against the stores' limits, and
frame.py's framing of the store screenshots.

    python3 -m unittest discover -s tool/store

Needs the packages in tool/branding/requirements.txt.
"""

import re
import tempfile
import unittest
from pathlib import Path

import frame
from PIL import Image

STORE = frame.ROOT / 'store'

# Each listing's files and their limits, in characters (fastlane's layout:
# supply for Google Play, deliver for the App Store).
PLAY = {'title': 30, 'short_description': 80, 'full_description': 4000}
IOS = {'name': 30, 'subtitle': 30, 'keywords': 100, 'promotional_text': 170,
       'description': 4000}
LISTINGS = {
    STORE / 'play' / 'en-US': PLAY,
    STORE / 'play' / 'iw-IL': PLAY,
    STORE / 'ios' / 'en-US': {**IOS, 'support_url': None, 'privacy_url': None},
    STORE / 'ios' / 'he': {**IOS, 'support_url': None, 'privacy_url': None},
}
# Google Play's release notes, whatsnew-<locale> for each listing, which the
# Release workflow uploads with every bundle (.github/workflows/release.yml).
WHATSNEW = STORE / 'play' / 'whatsnew'
WHATSNEW_LIMIT = 500
# A field of one line, which a trailing newline would join.
ONE_LINE = {'title', 'short_description', 'name', 'subtitle', 'keywords',
            'promotional_text', 'support_url', 'privacy_url'}
HEBREW = re.compile('[֐-׿]')
# Each store refuses metadata that names the other's platform (App Store
# guideline 2.3.10).
NOT_ON_IOS = re.compile(r'Android|Google|TalkBack', re.IGNORECASE)
NOT_ON_PLAY = re.compile(r'\bi(Phone|Pad|OS)\b|Apple|VoiceOver|App Store')


def read(folder: Path, field: str) -> str:
    return (folder / f'{field}.txt').read_text(encoding='utf-8')


class ListingTest(unittest.TestCase):
    def test_every_field_is_within_its_limit(self):
        for folder, fields in LISTINGS.items():
            for field, limit in fields.items():
                with self.subTest(f'{folder.parent.name}/{folder.name}/{field}'):
                    text = read(folder, field)
                    self.assertTrue(text)
                    self.assertEqual(text, text.strip(), 'no surrounding whitespace')
                    if field in ONE_LINE:
                        self.assertNotIn('\n', text)
                    if limit:
                        self.assertLessEqual(len(text), limit)

    def test_hebrew_listings_are_in_hebrew(self):
        for folder in (STORE / 'play' / 'iw-IL', STORE / 'ios' / 'he'):
            for field in LISTINGS[folder]:
                if not field.endswith('_url'):
                    with self.subTest(f'{folder.name}/{field}'):
                        self.assertRegex(read(folder, field), HEBREW)

    def test_quotes_are_typeset(self):
        # ’ and “ ” in English, ׳ and ״ in Hebrew, as in the app.
        for folder, fields in LISTINGS.items():
            for field in fields:
                if not field.endswith('_url'):
                    with self.subTest(f'{folder.parent.name}/{folder.name}/{field}'):
                        self.assertNotRegex(read(folder, field), '[\'"]')

    def test_keywords_are_a_plain_list_without_the_name(self):
        for folder in (STORE / 'ios' / 'en-US', STORE / 'ios' / 'he'):
            with self.subTest(folder.name):
                keywords = read(folder, 'keywords').lower().split(',')
                self.assertEqual(len(keywords), len(set(keywords)))
                for keyword in keywords:
                    self.assertEqual(keyword, keyword.strip())
                    self.assertGreater(len(keyword), 2)
                # The App Store searches the name already.
                name = read(folder, 'name').lower().split()
                self.assertFalse(set(name) & set(keywords))
                # Under 100 bytes too, in case Hebrew is counted so.
                self.assertLessEqual(len(read(folder, 'keywords').encode()), 100)

    def test_urls_point_at_the_public_pages(self):
        for folder, suffix in ((STORE / 'ios' / 'en-US', ''), (STORE / 'ios' / 'he', '.he')):
            for field, page in (('support_url', 'support'), ('privacy_url', 'privacy')):
                with self.subTest(f'{folder.name}/{field}'):
                    self.assertRegex(read(folder, field),
                                     rf'^(<WEB_URL>|https://\S+/)legal/{page}{suffix}\.html$')

    def test_no_listing_names_the_other_store(self):
        for folder, fields in LISTINGS.items():
            other = NOT_ON_IOS if folder.parent.name == 'ios' else NOT_ON_PLAY
            for field in fields:
                with self.subTest(f'{folder.parent.name}/{folder.name}/{field}'):
                    self.assertNotRegex(read(folder, field), other)


class ReleaseNotesTest(unittest.TestCase):
    LOCALES = {folder.name for folder in LISTINGS if folder.parent.name == 'play'}

    def test_one_for_each_google_play_listing(self):
        self.assertEqual({path.name for path in WHATSNEW.iterdir()},
                         {f'whatsnew-{locale}' for locale in self.LOCALES})

    def test_each_is_within_the_limit_and_typeset(self):
        for locale in self.LOCALES:
            with self.subTest(locale):
                text = (WHATSNEW / f'whatsnew-{locale}').read_text(encoding='utf-8')
                self.assertTrue(text)
                self.assertEqual(text, text.strip(), 'no surrounding whitespace')
                self.assertLessEqual(len(text), WHATSNEW_LIMIT)
                self.assertNotRegex(text, '[\'"]')
                self.assertNotRegex(text, NOT_ON_PLAY)
                if locale == 'iw-IL':
                    self.assertRegex(text, HEBREW)


class FrameTest(unittest.TestCase):
    PLAY = next(d for d in frame.DEVICES if d.name == 'play')

    def capture(self, size=None):
        # A capture as the harness writes them: opaque, with alpha.
        image = Image.new('RGBA', size or self.PLAY.size, (40, 80, 120, 255))
        image.paste((250, 250, 250, 255), (0, 0, image.width, image.height // 10))
        return image

    def test_shots_use_the_harness_store_screens(self):
        source = (frame.ROOT / 'test' / 'screens' / 'capture_test.dart').read_text(
            encoding='utf-8')
        block = re.search(r'const _storeScreens = \{(.*?)\};', source, re.DOTALL)
        self.assertIsNotNone(block)
        screens = set(re.findall(r"^\s*'(\w+)',", block.group(1), re.MULTILINE))
        self.assertEqual(screens, frame.SCREENS)

    def test_six_headlines_in_each_language(self):
        self.assertEqual(len(frame.SHOTS), 6)
        for shot in frame.SHOTS:
            self.assertNotRegex(shot.en + shot.he, '[\'"]')
            self.assertRegex(shot.he, HEBREW)

    def test_framed_capture_keeps_its_size_without_alpha(self):
        framed = frame.frame(self.capture(), frame.SHOTS[0].en, 'en-US')
        self.assertEqual(framed.size, self.PLAY.size)
        self.assertEqual(framed.mode, 'RGB')
        klaf = Image.new('RGB', (1, 1), frame.KLAF).getpixel((0, 0))
        # Klaf round the capture, whose corners are rounded.
        width, height = framed.size
        shot_w = round(frame.SHOT_HEIGHT * height * width / height)
        x = (width - shot_w) // 2
        y = height - round(frame.SHOT_BOTTOM * height) - round(frame.SHOT_HEIGHT * height)
        self.assertEqual(framed.getpixel((x // 2, height // 2)), klaf)
        self.assertEqual(framed.getpixel((x + 2, y + 2)), klaf)
        self.assertEqual(framed.getpixel((width // 2, height - y // 4)), klaf)
        self.assertEqual(framed.getpixel((width // 2, height // 2)), (40, 80, 120))

    def test_headline_is_techelet_above_the_capture(self):
        for language in frame.LANGUAGES:
            with self.subTest(language):
                framed = frame.frame(self.capture(), frame.SHOTS[2].headline(language),
                                     language)
                top = framed.crop((0, 0, framed.width,
                                   round((1 - frame.SHOT_HEIGHT - frame.SHOT_BOTTOM)
                                         * framed.height)))
                colours = {c for _, c in top.getcolors(1 << 20)}
                techelet = Image.new('RGB', (1, 1), frame.TECHELET).getpixel((0, 0))
                self.assertIn(techelet, colours)

    def test_writes_each_shot_in_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            captures, out = Path(tmp) / 'screens', Path(tmp) / 'store'
            captures.mkdir()
            for shot in frame.SHOTS:
                self.capture().save(frame.capture_path(captures, self.PLAY, 'he',
                                                       shot.screen_on(self.PLAY)))
            written = frame.write_device(self.PLAY, 'he', captures, out)
            self.assertEqual([p.name for p in written],
                             [f'{n:02d}_{s.screen_on(self.PLAY)}.png'
                              for n, s in enumerate(frame.SHOTS, start=1)])
            for path in written:
                self.assertEqual(path.parent, out / 'play' / 'he')
                with Image.open(path) as image:
                    self.assertEqual((image.size, image.mode), (self.PLAY.size, 'RGB'))

    def test_refuses_a_capture_of_another_size(self):
        with tempfile.TemporaryDirectory() as tmp:
            captures = Path(tmp)
            for shot in frame.SHOTS:
                self.capture((412, 915)).save(frame.capture_path(
                    captures, self.PLAY, 'en-US', shot.screen_on(self.PLAY)))
            with self.assertRaises(SystemExit):
                frame.write_device(self.PLAY, 'en-US', captures, captures / 'out')


if __name__ == '__main__':
    unittest.main()

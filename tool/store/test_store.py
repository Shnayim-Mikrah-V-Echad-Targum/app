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
# The Microsoft Store's listing is entered by hand in Partner Center
# (docs/RELEASE.md, Windows): its description, for each of the package's
# languages.
WINDOWS = {'description': 10000}
LISTINGS = {
    STORE / 'play' / 'en-US': PLAY,
    STORE / 'play' / 'iw-IL': PLAY,
    STORE / 'ios' / 'en-US': {**IOS, 'support_url': None, 'privacy_url': None},
    STORE / 'ios' / 'he': {**IOS, 'support_url': None, 'privacy_url': None},
    STORE / 'windows' / 'en-us': WINDOWS,
    STORE / 'windows' / 'he-il': WINDOWS,
}
HEBREW_LISTINGS = (STORE / 'play' / 'iw-IL', STORE / 'ios' / 'he', STORE / 'windows' / 'he-il')
# Google Play's release notes, whatsnew-<locale> for each listing, which the
# Release workflow uploads with every bundle (.github/workflows/release.yml).
WHATSNEW = STORE / 'play' / 'whatsnew'
WHATSNEW_LIMIT = 500
# A field of one line, which a trailing newline would join.
ONE_LINE = {'title', 'short_description', 'name', 'subtitle', 'keywords',
            'promotional_text', 'support_url', 'privacy_url'}
HEBREW = re.compile('[֐-׿]')
# Each store refuses metadata that names the other's platform (App Store
# guideline 2.3.10), and Windows has neither's screen reader nor a
# home-screen widget.
NOT_ON_IOS = re.compile(r'Android|Google|TalkBack', re.IGNORECASE)
NOT_ON_PLAY = re.compile(r'\bi(Phone|Pad|OS)\b|Apple|VoiceOver|App Store')
NOT_ON_WINDOWS = re.compile(NOT_ON_IOS.pattern + '|' + NOT_ON_PLAY.pattern + r'|widget|ווידג׳ט|device|מכשיר',
                            re.IGNORECASE)
NOT_ON = {'ios': NOT_ON_IOS, 'play': NOT_ON_PLAY, 'windows': NOT_ON_WINDOWS}


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
        for folder in HEBREW_LISTINGS:
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

    def test_keywords_are_a_plain_list_without_the_name_or_subtitle(self):
        for folder in (STORE / 'ios' / 'en-US', STORE / 'ios' / 'he'):
            with self.subTest(folder.name):
                keywords = read(folder, 'keywords').lower().split(',')
                self.assertEqual(len(keywords), len(set(keywords)))
                for keyword in keywords:
                    self.assertEqual(keyword, keyword.strip())
                    self.assertGreater(len(keyword), 2)
                # The App Store searches the name and the subtitle already:
                # their words would waste the field.
                words = set(re.findall(r'\w+', (read(folder, 'name') + ' ' + read(folder, 'subtitle')).lower()))
                for keyword in keywords:
                    self.assertFalse(set(keyword.split()) & words, keyword)
                # Under 100 bytes too, as App Store Connect counts them.
                self.assertLessEqual(len(read(folder, 'keywords').encode()), 100)

    def test_hebrew_keywords_have_the_traditional_spelling(self):
        # As in "שנים מקרא ואחד תרגום" (Berachot 8a), which many search for:
        # the name spells it שניים.
        self.assertIn('שנים', read(STORE / 'ios' / 'he', 'keywords').split(','))

    def test_descriptions_name_the_plans_as_the_app_does(self):
        # lib/l10n/app_en.arb's planAliyahPerDay, planShevii, planErevShabbat,
        # and their Hebrew in tool/l10n/he_strings.py.
        plans = {
            'en': ['an aliyah a day', 'Shevi’i on Shabbat morning', 'all on Friday'],
            'he': ['עלייה ליום', 'שביעי בשבת בבוקר', 'הכול ביום שישי'],
        }
        for folder, field in ((STORE / 'play' / 'en-US', 'full_description'), (STORE / 'ios' / 'en-US', 'description'),
                              (STORE / 'windows' / 'en-us', 'description'),
                              (STORE / 'play' / 'iw-IL', 'full_description'), (STORE / 'ios' / 'he', 'description'),
                              (STORE / 'windows' / 'he-il', 'description')):
            with self.subTest(f'{folder.parent.name}/{folder.name}'):
                text = read(folder, field)
                for plan in plans['he' if folder in HEBREW_LISTINGS else 'en']:
                    self.assertIn(plan, text)

    def test_urls_point_at_the_public_pages(self):
        for folder, suffix in ((STORE / 'ios' / 'en-US', ''), (STORE / 'ios' / 'he', '.he')):
            for field, page in (('support_url', 'support'), ('privacy_url', 'privacy')):
                with self.subTest(f'{folder.name}/{field}'):
                    self.assertRegex(read(folder, field),
                                     rf'^(<WEB_URL>|https://\S+/)legal/{page}{suffix}\.html$')

    def test_no_listing_names_the_other_store(self):
        for folder, fields in LISTINGS.items():
            other = NOT_ON[folder.parent.name]
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


def harness() -> str:
    return (frame.ROOT / 'test' / 'screens' / 'capture_test.dart').read_text(encoding='utf-8')


def arithmetic(expression: str) -> float:
    """A number the harness writes as one, or as a quotient (1080 / 2.625)."""
    numbers = [float(n) for n in expression.split('/')]
    value = numbers[0]
    for n in numbers[1:]:
        value /= n
    return value


class FrameTest(unittest.TestCase):
    PLAY = next(d for d in frame.DEVICES if d.name == 'play')

    def capture(self, size=None):
        # A capture as the harness writes them: opaque, with alpha.
        image = Image.new('RGBA', size or self.PLAY.size, (40, 80, 120, 255))
        image.paste((250, 250, 250, 255), (0, 0, image.width, image.height // 10))
        return image

    def test_shots_use_the_harness_store_screens(self):
        # Each store mode renders only the screens its device's shots use.
        block = re.search(r'const _storeScreensByMode = \{(.*?)\n\};', harness(), re.DOTALL)
        self.assertIsNotNone(block)
        modes = {mode: set(re.findall(r"'(\w+)'", screens))
                 for mode, screens in re.findall(r"^\s*'(\w+)': \{(.*?)\},", block.group(1), re.MULTILINE)}
        self.assertEqual(modes, {d.mode: set(frame.screens_on(d)) for d in frame.DEVICES})
        for device in frame.DEVICES:
            self.assertEqual(len(set(frame.screens_on(device))), len(frame.SHOTS), device.name)

    def test_devices_are_the_harness_store_modes(self):
        # Each mode's tag, size in logical pixels and pixel ratio, which make
        # the store's size; and its Hebrew twin.
        source = harness()
        self.assertIn("_Mode('${tag}he', size, (s) => s.copyWith(language: AppLanguage.hebrew), pixelRatio: ratio)",
                      source)
        modes = {tag: (arithmetic(w), arithmetic(h), float(ratio)) for tag, w, h, ratio in re.findall(
            r"\('(store\w+)', Size\(([\d./ ]+), ([\d./ ]+)\), ([\d.]+)\)", source)}
        self.assertEqual(set(modes), {d.mode for d in frame.DEVICES})
        for device in frame.DEVICES:
            with self.subTest(device.name):
                w, h, ratio = modes[device.mode]
                self.assertEqual(ratio, device.ratio)
                self.assertEqual((round(w * ratio), round(h * ratio)), device.size)
                self.assertAlmostEqual(device.width_dp, w)

    def test_side_by_side_only_where_the_full_text_shows_it(self):
        # The full text sets the Targum beside each verse from a pane this
        # wide (lib/features/reader/scripture_text.dart).
        pane = float(re.search(r'static const parallelMinPane = ([\d.]+);', (
            frame.ROOT / 'lib' / 'features' / 'reader' / 'scripture_text.dart').read_text(encoding='utf-8')).group(1))
        for device in frame.DEVICES:
            for shot in frame.SHOTS:
                for language in frame.LANGUAGES:
                    text = shot.headline(language, device).replace('\n', ' ')
                    if re.search(r'side by side|זה לצד זה', text):
                        with self.subTest(f'{device.name} {language} {text}'):
                            self.assertEqual(shot.screen_on(device), 'store_full')
                            self.assertGreaterEqual(device.width_dp, pane)
                if shot.screen_on(device) == 'store_full':
                    self.assertGreaterEqual(device.width_dp, pane, device.name)

    def captions(self):
        for shot in frame.SHOTS:
            for caption in (shot.caption, *shot.captions.values()):
                yield caption

    def test_six_headlines_in_each_language(self):
        self.assertEqual(len(frame.SHOTS), 6)
        for caption in self.captions():
            self.assertNotRegex(caption.en + caption.he, '[\'"]')
            self.assertRegex(caption.he, HEBREW)
            self.assertNotRegex(caption.en, HEBREW)

    def test_headlines_break_once_where_their_phrases_do(self):
        for caption in self.captions():
            for language in frame.LANGUAGES:
                text = caption.text(language)
                with self.subTest(text):
                    lines = text.split('\n')
                    self.assertEqual(len(lines), 2)
                    self.assertTrue(all(line and line == line.strip() for line in lines))
                    # After a comma or colon, where it has one, so that no
                    # phrase ("aliyah by aliyah", "Mikra and Targum") is split.
                    if re.search(r'[,:]', text):
                        self.assertRegex(lines[0], r'[,:]$')

    def test_headlines_are_set_at_one_size_on_every_device(self):
        # No line is wider than its capture, so none is set smaller than the
        # rest of its set.
        for device in frame.DEVICES:
            width, height = device.size
            px = frame.HEADLINE_PX * height / frame.REFERENCE_HEIGHT
            room = round(frame.SHOT_HEIGHT * height) * width / height
            for shot in frame.SHOTS:
                for language in frame.LANGUAGES:
                    for line in shot.headline(language, device).split('\n'):
                        with self.subTest(f'{device.name} {line}'):
                            self.assertLessEqual(frame.ink_width(line, px, language), room)

    def test_framed_capture_keeps_its_size_without_alpha(self):
        framed = frame.frame(self.capture(), frame.SHOTS[0].headline('en-US', self.PLAY), 'en-US')
        self.assertEqual(framed.size, self.PLAY.size)
        self.assertEqual(framed.mode, 'RGB')
        klaf = Image.new('RGB', (1, 1), frame.KLAF).getpixel((0, 0))
        hairline = Image.new('RGB', (1, 1), frame.HAIRLINE).getpixel((0, 0))
        # Klaf round the capture, whose corners are rounded.
        width, height = framed.size
        shot_h = round(frame.SHOT_HEIGHT * height)
        shot_w = round(shot_h * width / height)
        x = (width - shot_w) // 2
        y = height - round(frame.SHOT_BOTTOM * height) - shot_h
        self.assertEqual(framed.getpixel((x // 2, height // 2)), klaf)
        self.assertEqual(framed.getpixel((x + 2, y + 2)), klaf)
        self.assertEqual(framed.getpixel((width // 2, height - y // 4)), klaf)
        self.assertEqual(framed.getpixel((width // 2, height // 2)), (40, 80, 120))
        # The hairline just outside each edge, and nothing beyond it.
        for at in ((x - 1, height // 2), (x + shot_w, height // 2), (width // 2, y + shot_h)):
            self.assertEqual(framed.getpixel(at), hairline, at)
        self.assertEqual(framed.getpixel((x - 2, height // 2)), klaf)

    def test_rounded_corners_are_anti_aliased(self):
        mask = frame.rounded_mask((200, 100), 24)
        self.assertEqual((mask.getpixel((0, 0)), mask.getpixel((199, 99)), mask.getpixel((100, 50))), (0, 0, 255))
        self.assertEqual(mask.getpixel((0, 50)), 255, 'straight sides')
        # Partly covered along the arc.
        self.assertTrue(any(0 < mask.getpixel((i, i)) < 255 for i in range(3, 12)))
        self.assertEqual(mask.getpixel((7, 7)), frame.rounded_mask((200, 100), 24).transpose(
            Image.Transpose.ROTATE_180).getpixel((7, 7)))

    def test_headline_is_techelet_above_the_capture(self):
        for language in frame.LANGUAGES:
            with self.subTest(language):
                framed = frame.frame(self.capture(), frame.SHOTS[2].headline(language, self.PLAY),
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

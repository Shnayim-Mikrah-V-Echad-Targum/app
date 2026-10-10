"""Checks make_icon.py's glyph-order assertion, the launch screens' logo,
the launch themes' system bars, the MSIX icons, the web's link preview,
shortcut icons and loading mark, and iOS's shortcut icon.

    python3 -m unittest discover -s tool/branding

Needs the packages in requirements.txt, and network access unless
assets/fonts/FrankRuhlLibre-Bold.ttf exists.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import make_icon
from fontTools.ttLib import TTFont
from PIL import Image, ImageChops


class GlyphOrderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.font_path = make_icon.load_font(Path(cls.tmp.name))
        cls.font = TTFont(cls.font_path)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def visual_clusters(self, direction):
        glyphs, _ = make_icon.shape(self.font_path, self.font, direction)
        return make_icon.visual_clusters(glyphs, self.font.getGlyphSet())

    def test_right_to_left_puts_shin_rightmost(self):
        clusters = self.visual_clusters('rtl')
        self.assertEqual(clusters, [4, 3, 2, 1, 0])
        make_icon.check_order(clusters)

    def test_left_to_right_layout_is_rejected(self):
        # The original icon's mistake: letters placed left to right (ת״ומש).
        clusters = self.visual_clusters('ltr')
        self.assertEqual(clusters, [0, 1, 2, 3, 4])
        with self.assertRaises(SystemExit):
            make_icon.check_order(clusters)


class SplashLogoTest(unittest.TestCase):
    def test_reach_of_a_rounded_square(self):
        self.assertAlmostEqual(make_icon.rounded_square_reach(2, 0), math.sqrt(2))
        self.assertAlmostEqual(make_icon.rounded_square_reach(2, 1), 1)

    def test_tile_stays_inside_the_android_12_circle(self):
        tile = make_icon.SPLASH_TILE
        reach = make_icon.rounded_square_reach(tile, make_icon.MARK_RADIUS * tile)
        self.assertLess(reach, make_icon.SPLASH_SAFE_RADIUS)


class LaunchThemeTest(unittest.TestCase):
    def test_launch_themes_draw_their_own_system_bars(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = Path(tmp)
            styles = res / 'values-night-v31' / 'styles.xml'
            styles.parent.mkdir()
            styles.write_text(make_icon.SPLASH_BARS_FALSE, encoding='utf-8')
            other = res / 'values-v29' / 'styles.xml'
            other.parent.mkdir()
            other.write_text('<resources/>', encoding='utf-8')
            with mock.patch.object(make_icon, 'ANDROID_RES', res), \
                    mock.patch.object(make_icon, 'report'):
                make_icon.fix_launch_themes()
            self.assertEqual(styles.read_text(encoding='utf-8'),
                             make_icon.SPLASH_BARS_TRUE)
            self.assertEqual(other.read_text(encoding='utf-8'), '<resources/>')


class MsixIconTest(unittest.TestCase):
    def test_small_app_icons_are_the_rules_and_the_logo_is_the_tile(self):
        tile = make_icon.document('', background='gradient',
                                  radius=make_icon.TILE_RADIUS * make_icon.CANVAS)
        with tempfile.TemporaryDirectory() as tmp:
            msix = Path(tmp)
            with mock.patch.object(make_icon, 'MSIX', msix), \
                    mock.patch.object(make_icon, 'ROOT', msix):
                make_icon.write_msix(tile)
            with Image.open(msix / 'logo.png') as logo:
                self.assertEqual(logo.size, (make_icon.MSIX_LOGO,) * 2)
                self.assertEqual(logo.getpixel((0, 0))[3], 0)
            names = sorted(p.name for p in (msix / 'Images').iterdir())
            self.assertEqual(len(names), 15)
            for size in make_icon.MSIX_SMALL_SIZES:
                self.assertLessEqual(size, 32)
                icons = [msix / 'Images' / f'Square44x44Logo.{form}-{size}.png'
                         for form in make_icon.MSIX_SMALL_FORMS]
                expected = make_icon.render(make_icon.small_mark(size), size)
                for icon in icons:
                    with Image.open(icon) as image:
                        self.assertEqual(image.size, (size, size))
                        self.assertEqual(image.convert('RGBA').tobytes(),
                                         expected.tobytes(), icon.name)


class WebTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory() as tmp:
            font_path = make_icon.load_font(Path(tmp))
            font = TTFont(font_path)
            glyphs, upem = make_icon.shape(font_path, font)
            cls.mark = make_icon.layout(glyphs, upem, font)

    def test_link_preview_keeps_to_the_middle_for_square_crops(self):
        image = make_icon.render(make_icon.og_image(self.mark), make_icon.OG_WIDTH,
                                 height=make_icon.OG_HEIGHT, opaque=True)
        self.assertEqual(image.size, (1200, 630))
        # Inside the frame, everything lies within the middle 630 px.
        inside = image.crop((60, 60, 1140, 570))
        ink = ImageChops.difference(
            inside, Image.new('RGB', inside.size, make_icon.KLAF)).getbbox()
        self.assertGreater(60 + ink[0], (1200 - 630) / 2)
        self.assertLess(60 + ink[2], (1200 + 630) / 2)

    def test_hebrew_title_runs_right_to_left(self):
        font_path = make_icon.FONTS / 'FrankRuhlLibre-Medium.ttf'
        glyphs, _ = make_icon.shape(font_path, TTFont(font_path), 'rtl',
                                    text=make_icon.OG_TITLE_HE)
        # The first letter, ש of שניים, is the rightmost glyph.
        self.assertEqual(max(glyphs, key=lambda g: g.x).cluster, 0)

    def test_loading_mark_replaces_what_lies_between_the_markers(self):
        with tempfile.TemporaryDirectory() as tmp:
            web = Path(tmp)
            index = web / 'index.html'
            index.write_text(
                '<div>\n    <!-- mark: tool/branding/make_icon.py --post -->\n'
                '    old\n    <!-- /mark -->\n</div>\n', encoding='utf-8')
            with mock.patch.object(make_icon, 'WEB', web), \
                    mock.patch.object(make_icon, 'ROOT', web), \
                    mock.patch.object(make_icon, 'report'):
                make_icon.write_loader_mark(self.mark)
                once = index.read_text(encoding='utf-8')
                make_icon.write_loader_mark(self.mark)
            self.assertEqual(index.read_text(encoding='utf-8'), once)
            self.assertEqual(once.splitlines(), [
                '<div>',
                '    <!-- mark: tool/branding/make_icon.py --post -->',
                '    ' + make_icon.loader_mark(self.mark),
                '    <!-- /mark -->',
                '</div>',
            ])

    def test_web_index_shows_the_current_mark(self):
        html = (make_icon.WEB / 'index.html').read_text(encoding='utf-8')
        self.assertIn(make_icon.loader_mark(self.mark), html,
                      'run python3 tool/branding/make_icon.py --post')

    def test_shortcut_icons_are_cream_glyphs_on_the_tile(self):
        try:
            icons = TTFont(make_icon.material_icons_font())
        except SystemExit:
            self.skipTest('no Flutter SDK, so no Material icons font')
        for codepoint in make_icon.SHORTCUT_ICONS.values():
            image = make_icon.render(make_icon.shortcut_icon(icons, codepoint),
                                     make_icon.SHORTCUT_SIZE)
            self.assertEqual(image.getpixel((0, 0))[3], 0, 'rounded corners')
            cream = Image.new('RGBA', image.size, make_icon.CREAM)
            glyph = ImageChops.difference(image, cream).convert('L').point(
                lambda v: 255 if v < 24 else 0).getbbox()
            # The glyph sits in the middle, within its 58% em box.
            self.assertIsNotNone(glyph)
            margin = (1 - 0.58) / 2 * make_icon.SHORTCUT_SIZE
            self.assertGreaterEqual(min(glyph[:2]), margin - 1)
            self.assertLessEqual(max(glyph[2:]), make_icon.SHORTCUT_SIZE - margin + 1)



class IosShortcutTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory() as tmp:
            font_path = make_icon.load_font(Path(tmp))
            font = TTFont(font_path)
            glyphs, upem = make_icon.shape(font_path, font)
            cls.mark = make_icon.layout(glyphs, upem, font)

    def test_icon_is_the_mark_centred_in_one_ink(self):
        size = 3 * make_icon.IOS_SHORTCUT_POINTS
        image = make_icon.render(make_icon.ios_shortcut_icon(self.mark), size)
        self.assertEqual(image.size, (size, size))
        # One ink: iOS draws a template from its alpha alone.
        self.assertEqual({px[:3] for px in image.getdata() if px[3] == 255},
                         {(0, 0, 0)})
        left, top, right, bottom = image.getchannel('A').getbbox()
        self.assertAlmostEqual((right - left) / size,
                               make_icon.IOS_SHORTCUT_WIDTH, delta=0.02)
        self.assertLessEqual(abs(left - (size - right)), 1)
        self.assertLessEqual(abs(top - (size - bottom)), 1)

    def test_image_set_is_a_template_at_2x_and_3x(self):
        with tempfile.TemporaryDirectory() as tmp:
            assets = Path(tmp)
            with mock.patch.object(make_icon, 'IOS_ASSETS', assets), \
                    mock.patch.object(make_icon, 'ROOT', assets):
                make_icon.write_ios_shortcut(self.mark)
            folder = assets / 'ShortcutMark.imageset'
            contents = json.loads((folder / 'Contents.json').read_text())
            self.assertEqual(contents['properties'],
                             {'template-rendering-intent': 'template'})
            self.assertEqual(
                [(i['scale'], i['filename']) for i in contents['images']],
                [('2x', 'ShortcutMark@2x.png'), ('3x', 'ShortcutMark@3x.png')])
            for scale in (2, 3):
                with Image.open(folder / f'ShortcutMark@{scale}x.png') as image:
                    self.assertEqual(image.size, (35 * scale,) * 2)

    def test_catalog_holds_the_current_icon(self):
        folder = make_icon.IOS_ASSETS / 'ShortcutMark.imageset'
        expected = make_icon.render(make_icon.ios_shortcut_icon(self.mark), 105)
        with Image.open(folder / 'ShortcutMark@3x.png') as image:
            self.assertEqual(image.convert('RGBA').tobytes(), expected.tobytes(),
                             'run python3 tool/branding/make_icon.py --post')


if __name__ == '__main__':
    unittest.main()

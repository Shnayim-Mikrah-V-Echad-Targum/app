"""Checks make_icon.py's glyph-order assertion.

    python3 -m unittest discover -s tool/branding

Needs the packages in requirements.txt, and network access unless
assets/fonts/FrankRuhlLibre-Bold.ttf exists.
"""

import tempfile
import unittest
from pathlib import Path

import make_icon
from fontTools.ttLib import TTFont


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


if __name__ == '__main__':
    unittest.main()

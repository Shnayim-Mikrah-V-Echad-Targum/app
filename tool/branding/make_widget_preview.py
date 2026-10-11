#!/usr/bin/env python3
"""Writes android/app/src/main/res/drawable-nodpi/widget_preview.png, the
picture of the home-screen widget that launchers before Android 12 show in
their widget picker. Android 12 and later draw the widget's own preview
layout instead (res/layout/widget_parsha_preview.xml), which this follows.

It is the medium widget (docs/DESIGN_SYSTEM.md §6.30) for a reader partway
through Bereshit, in the light theme, at 3×. The launcher sets the widget in
the system's serif, which an image can't use, so the image sets the names in
the app's own (Frank Ruhl Libre, EB Garamond) and the lines in Noto Sans.
Hebrew is shaped by HarfBuzz, as make_icon.py shapes it.

Usage: python3 tool/branding/make_widget_preview.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_icon import FONTS, ROOT, num, render, shape, write_png  # noqa: E402

OUT = ROOT / 'android' / 'app' / 'src' / 'main' / 'res' / 'drawable-nodpi' / 'widget_preview.png'

SCALE = 3
WIDTH, HEIGHT = 320, 150  # dp: about 4×2 cells
PADDING = 16
GUTTER = 16

# The light theme's tokens (res/values/widget_colors.xml).
PAPER = '#FFFDF8'
HAIRLINE = '#D8CFBF'
INK = '#1E1A16'
INK_MUTED = '#575046'
TECHELET = '#1D3F75'
GOLD = '#7A5712'
BARS = (('#1D3F75', 3), ('#55779F', 3), ('#946C1E', 2))
TRACK = '#E8E1D3'

# res/values/strings.xml's preview strings.
EYEBROW = 'PARSHAT HASHAVUA'
HEBREW = 'בְּרֵאשִׁית'
NAME = 'Bereshit'
PROGRESS = '2 of 7 aliyot'
TODAY = 'Today: Shlishi'
CONTINUE = ('Continue · Shlishi,', 'Targum')
# Material's chevron_right, in its 24-unit box.
CHEVRON = 'M10,6L8.59,7.41 13.17,12l-4.58,4.59L10,18l6,-6z'


def text(font: str, value: str, size: float, *, x: float, baseline: float,
         fill: str, direction: str = 'ltr', spacing: float = 0) -> tuple[str, float]:
    """[value] shaped at [size] dp, its pen starting at x = [x] (left to
    right), with [spacing] em between letters; the SVG path and its advance."""
    path = FONTS / font
    ttf = TTFont(path)
    glyph_set = ttf.getGlyphSet()
    glyphs, upem = shape(path, ttf, direction, text=value)
    scale = size / upem
    pen = SVGPathPen(glyph_set, ntos=num)
    extra = spacing * upem
    for i, g in enumerate(glyphs):
        glyph_set[g.name].draw(TransformPen(
            pen, (scale, 0, 0, -scale, x + (g.x + i * extra) * scale, baseline - g.y * scale)))
    hmtx = ttf['hmtx']
    advance = sum(hmtx[g.name][0] for g in glyphs) + extra * (len(glyphs) - 1)
    return f'<path fill="{fill}" d="{pen.getCommands()}"/>', advance * scale


def preview() -> str:
    column = (WIDTH - 2 * PADDING - 2 * GUTTER - 1) / 2
    left = PADDING
    right = PADDING + column + 2 * GUTTER + 1
    parts = [
        f'<rect x="0.5" y="0.5" width="{WIDTH - 1}" height="{HEIGHT - 1}" rx="16" '
        f'fill="{PAPER}" stroke="{HAIRLINE}"/>',
        f'<rect x="{num(PADDING + column + GUTTER)}" y="{PADDING}" width="1" '
        f'height="{HEIGHT - 2 * PADDING}" fill="{HAIRLINE}"/>',
    ]
    # The parsha, its bars and the aliyot read.
    top = 17
    parts.append(text('EBGaramond-SemiBold.ttf', EYEBROW, 11.5, x=left, baseline=top + 11,
                      fill=GOLD, spacing=0.12)[0])
    parts.append(text('FrankRuhlLibre-Medium.ttf', HEBREW, 24, x=left, baseline=top + 42,
                      fill=TECHELET, direction='rtl')[0])
    parts.append(text('EBGaramond-Medium.ttf', NAME, 16, x=left, baseline=top + 62, fill=INK)[0])
    for i, (colour, done) in enumerate(BARS):
        y = top + 72 + i * 7
        parts.append(f'<rect x="{left}" y="{y}" width="{num(column)}" height="4" rx="2" fill="{TRACK}"/>')
        parts.append(f'<rect x="{left}" y="{y}" width="{num(column * done / 7)}" height="4" rx="2" '
                     f'fill="{colour}"/>')
    parts.append(text('NotoSans-Regular.ttf', PROGRESS, 12, x=left, baseline=top + 106, fill=INK_MUTED)[0])
    # Today's reading, and Continue.
    parts.append(text('NotoSans-Medium.ttf', TODAY, 13, x=right, baseline=58, fill=INK)[0])
    parts.append(text('NotoSans-Medium.ttf', CONTINUE[0], 13, x=right, baseline=84, fill=TECHELET)[0])
    last, advance = text('NotoSans-Medium.ttf', CONTINUE[1], 13, x=right, baseline=102, fill=TECHELET)
    parts.append(last)
    parts.append(f'<path fill="{TECHELET}" transform="translate({num(right + advance + 1)} 89) '
                 f'scale(0.75)" d="{CHEVRON}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" '
            f'viewBox="0 0 {WIDTH} {HEIGHT}">\n' + '\n'.join(parts) + '\n</svg>\n')


def main() -> None:
    write_png(OUT, render(preview(), WIDTH * SCALE, height=HEIGHT * SCALE))


if __name__ == '__main__':
    main()

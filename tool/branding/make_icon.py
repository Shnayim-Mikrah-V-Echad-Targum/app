#!/usr/bin/env python3
"""Generates the Shnayim Mikra app icon and every raster derived from it.

The icon's wordmark is שמו״ת. Hebrew runs right to left, so the letters are
shaped by HarfBuzz instead of being placed by hand, and the script refuses to
write anything unless ש comes out as the rightmost glyph
(docs/DESIGN_SYSTEM.md §7.8).

From the repository root:

    pip install -r tool/branding/requirements.txt
    python3 tool/branding/make_icon.py          # assets/branding/*
    dart run flutter_launcher_icons             # Android, iOS and web icons
    dart run flutter_native_splash:create       # Android and iOS launch screens
    python3 tool/branding/make_icon.py --post   # maskable, favicons, Windows,
                                                # launch screens' system bars

A Hebrew reader checks the results by eye before every release.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import math
import sys
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import NoReturn

import cairosvg
import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BRANDING = ROOT / 'assets' / 'branding'
ANDROID_RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'

BUNDLED_FONT = ROOT / 'assets' / 'fonts' / 'FrankRuhlLibre-Bold.ttf'
FONT_URL = ('https://raw.githubusercontent.com/google/fonts/'
            '2eb0b48d5f760f62e286216f0859a8c540dbc1bd/'
            'ofl/frankruhllibre/FrankRuhlLibre%5Bwght%5D.ttf')
FONT_SHA256_PREFIX = 'f9bf26966681037a'

# ש מ ו ״ ת in logical order. U+05F4 is the Hebrew gershayim, not ASCII quotes.
WORD = (0x05E9, 0x05DE, 0x05D5, 0x05F4, 0x05EA)
# Cluster (logical index) of each glyph, read left to right: ש is rightmost.
EXPECTED_VISUAL_CLUSTERS = [4, 3, 2, 1, 0]

CANVAS = 1024
CENTRE = CANVAS / 2
GRADIENT_TOP = '#23497F'
GRADIENT_BOTTOM = '#16315C'
CREAM = '#F6F0E2'
GOLD = '#D2A64A'
WHITE = '#FFFFFF'

FONT_PX = 300
BASELINE = 500
RULE_X, RULE_WIDTH, RULE_HEIGHT = 292, 440, 26
# Two Mikra passes, then the Targum.
RULES = ((580, CREAM), (628, CREAM), (676, GOLD))

# Android adaptive foreground: everything within 300 px of the centre keeps
# the art inside the 66/108 safe circle.
FOREGROUND_SCALE = 0.70
FOREGROUND_SAFE_RADIUS = 300
# Web maskable icons: the safe zone is a circle of radius 40%.
MASKABLE_SCALE = 0.90
MASKABLE_SAFE_RADIUS = 0.40 * CANVAS
MARK_RADIUS = 0.22  # the in-app mark (mark_128.png) and the launch screens
# Every favicon and Windows .ico entry, whatever its size, so the tile keeps
# one shape as Windows switches entries between views and DPI settings.
TILE_RADIUS = 0.1875
# Launch screens: flutter_native_splash reads the logo at 4× (1152 px for
# 288 dp or pt). Android 12 and later show only the central 768 px circle
# (192 dp), so the tile's rounded corners must stay inside it.
SPLASH_CANVAS = 1152
SPLASH_SAFE_RADIUS = 384
SPLASH_TILE = 576  # 144 dp or pt


def fail(message: str) -> NoReturn:
    sys.exit(f'make_icon: {message}')


def num(value: float) -> str:
    """Formats an SVG coordinate with at most two decimals."""
    text = f'{value:.2f}'.rstrip('0').rstrip('.')
    return '0' if text == '-0' else text


# Font and shaping ---------------------------------------------------------


def load_font(tmp: Path) -> Path:
    """Returns Frank Ruhl Libre Bold: the bundled file if it covers the word,
    otherwise the pinned upstream variable font instanced at wght=700."""
    if BUNDLED_FONT.exists():
        cmap = TTFont(BUNDLED_FONT).getBestCmap()
        if all(cp in cmap for cp in WORD):
            return BUNDLED_FONT
        print(f'{BUNDLED_FONT.relative_to(ROOT)} lacks a glyph; downloading.')
    print('Downloading Frank Ruhl Libre from google/fonts…')
    with urllib.request.urlopen(FONT_URL, timeout=60) as response:
        data = response.read()
    digest = hashlib.sha256(data).hexdigest()
    if not digest.startswith(FONT_SHA256_PREFIX):
        fail(f'unexpected font download (SHA-256 {digest})')
    bold = instancer.instantiateVariableFont(TTFont(io.BytesIO(data)),
                                             {'wght': 700})
    path = tmp / 'FrankRuhlLibre-Bold.ttf'
    bold.save(path)
    return path


@dataclass(frozen=True)
class Glyph:
    name: str
    cluster: int
    x: float  # font units, pen position plus offset
    y: float


def shape(font_path: Path, font: TTFont,
          direction: str = 'rtl') -> tuple[list[Glyph], int]:
    """Shapes WORD as Hebrew; returns the glyphs and the units per em."""
    face = hb.Face(hb.Blob.from_file_path(str(font_path)))
    buf = hb.Buffer()
    buf.add_codepoints(list(WORD))
    buf.direction = direction
    buf.script = 'Hebr'
    buf.language = 'he'
    hb.shape(hb.Font(face), buf, {})

    order = font.getGlyphOrder()
    glyphs = []
    pen_x = pen_y = 0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        if info.codepoint == 0:
            fail(f'the font has no glyph for cluster {info.cluster}')
        glyphs.append(Glyph(order[info.codepoint], info.cluster,
                            pen_x + pos.x_offset, pen_y + pos.y_offset))
        pen_x += pos.x_advance
        pen_y += pos.y_advance
    return glyphs, face.upem


def visual_clusters(glyphs: list[Glyph], glyph_set) -> list[int]:
    """Cluster indices ordered by where each glyph's ink sits, left to right."""
    def ink_centre(glyph: Glyph) -> float:
        pen = BoundsPen(glyph_set)
        glyph_set[glyph.name].draw(pen)
        x_min, _, x_max, _ = pen.bounds
        return glyph.x + (x_min + x_max) / 2
    return [g.cluster for g in sorted(glyphs, key=ink_centre)]


def check_order(clusters: list[int]) -> None:
    if clusters != EXPECTED_VISUAL_CLUSTERS:
        fail(f'wrong glyph order: clusters left to right are {clusters}, '
             f'expected {EXPECTED_VISUAL_CLUSTERS}')


# Layout -------------------------------------------------------------------


@dataclass(frozen=True)
class Mark:
    """The wordmark and the three rules, in master (1024 px) coordinates."""
    word: str  # SVG path data
    rules: tuple[tuple[float, str], ...]  # (top, fill)
    bounds: tuple[float, float, float, float]  # x_min, y_min, x_max, y_max
    letter_height: float
    word_width: float
    advance_width: float

    def radius(self, scale: float) -> float:
        """Farthest corner of the group's box from the centre, once scaled."""
        x_min, y_min, x_max, y_max = self.bounds
        return scale * max(math.hypot(x - CENTRE, y - CENTRE)
                           for x in (x_min, x_max) for y in (y_min, y_max))


def layout(glyphs: list[Glyph], upem: int, font: TTFont) -> Mark:
    glyph_set = font.getGlyphSet()
    scale = FONT_PX / upem

    ink = BoundsPen(glyph_set)
    for g in glyphs:
        glyph_set[g.name].draw(TransformPen(ink, (1, 0, 0, 1, g.x, g.y)))
    ink_x_min, ink_y_min, ink_x_max, ink_y_max = ink.bounds

    # Centre the ink horizontally, then centre the text-and-rules group
    # vertically, rounding to whole pixels so the rules' edges stay crisp.
    dx = CENTRE - (ink_x_min + ink_x_max) / 2 * scale
    top = BASELINE - ink_y_max * scale
    bottom = RULES[-1][0] + RULE_HEIGHT
    dy = round(CENTRE - (top + bottom) / 2)
    baseline = BASELINE + dy

    path = SVGPathPen(glyph_set, ntos=num)
    for g in glyphs:
        glyph_set[g.name].draw(TransformPen(
            path, (scale, 0, 0, -scale, dx + g.x * scale, baseline - g.y * scale)))

    x_min = min(dx + ink_x_min * scale, RULE_X)
    x_max = max(dx + ink_x_max * scale, RULE_X + RULE_WIDTH)
    advance = sum(glyph_set[g.name].width for g in glyphs) * scale
    return Mark(
        word=path.getCommands(),
        rules=tuple((y + dy, fill) for y, fill in RULES),
        bounds=(x_min, top + dy, x_max, bottom + dy),
        letter_height=(ink_y_max - ink_y_min) * scale,
        word_width=(ink_x_max - ink_x_min) * scale,
        advance_width=advance,
    )


# SVG ----------------------------------------------------------------------


def rounded_rect(x: float, y: float, width: float, height: float,
                 radius: float, fill: str) -> str:
    corner = f' rx="{num(radius)}"' if radius else ''
    return (f'<rect x="{num(x)}" y="{num(y)}" width="{num(width)}" '
            f'height="{num(height)}"{corner} fill="{fill}"/>')


def group(mark: Mark, *, scale: float = 1.0, colour: str | None = None) -> str:
    """The mark; [colour] replaces every fill (monochrome variants)."""
    shapes = [f'<path fill="{colour or CREAM}" d="{mark.word}"/>']
    shapes += [rounded_rect(RULE_X, y, RULE_WIDTH, RULE_HEIGHT, RULE_HEIGHT / 2,
                            colour or fill) for y, fill in mark.rules]
    transform = ''
    if scale != 1:
        transform = (f' transform="translate({num(CENTRE)} {num(CENTRE)}) '
                     f'scale({num(scale)}) translate(-{num(CENTRE)} -{num(CENTRE)})"')
    return f'<g{transform}>\n' + '\n'.join(shapes) + '\n</g>'


GRADIENT = 'url(#bg)'
GRADIENT_DEFS = ('<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
                 f'<stop offset="0" stop-color="{GRADIENT_TOP}"/>'
                 f'<stop offset="1" stop-color="{GRADIENT_BOTTOM}"/>'
                 '</linearGradient></defs>\n')


def document(body: str, *, background: str | None, radius: float = 0,
             size: int = CANVAS) -> str:
    """An SVG of [size]² user units. [background] is 'gradient', 'black' or
    None (transparent); [radius] rounds the background's corners. The
    gradient is defined whenever a layer (the body included) fills with it."""
    layers = []
    if background == 'gradient':
        layers.append(rounded_rect(0, 0, size, size, radius, GRADIENT))
    elif background == 'black':
        layers.append(rounded_rect(0, 0, size, size, radius, '#000000'))
    layers.append(body)
    content = '\n'.join(layers)
    defs = GRADIENT_DEFS if GRADIENT in content else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" '
            f'height="{size}" viewBox="0 0 {size} {size}">\n'
            + defs + content + '\n</svg>\n')


def small_mark(size: int) -> str:
    """The three rules alone, for sizes of 32 px and below: each 62.5% of the
    canvas wide and 9.4% high with 7.8% gaps, snapped to whole pixels."""
    width = 2 * round(0.625 * size / 2)
    height = max(1, round(0.094 * size))
    gap = max(1, round(0.078 * size))
    x = (size - width) // 2
    top = (size - 3 * height - 2 * gap) // 2
    rules = [rounded_rect(x, top + i * (height + gap), width, height,
                          height / 2, fill)
             for i, (_, fill) in enumerate(RULES)]
    return document('\n'.join(rules), background='gradient',
                    radius=TILE_RADIUS * size, size=size)


def rounded_square_reach(side: float, radius: float) -> float:
    """How far a rounded square's outline reaches from its centre: the
    middle of a corner arc."""
    return (side / 2 - radius) * math.sqrt(2) + radius


def splash_logo(mark: Mark) -> str:
    """The launch screens' logo: the in-app mark's tile (the master's art on
    the gradient, with its rounded corners), SPLASH_TILE px wide in the
    middle of a transparent SPLASH_CANVAS. The screen's own colour shows
    around it, cream in light mode and lamplight brown in dark."""
    offset = (SPLASH_CANVAS - SPLASH_TILE) / 2
    tile = (f'<g transform="translate({num(offset)} {num(offset)}) '
            f'scale({num(SPLASH_TILE / CANVAS)})">\n'
            + rounded_rect(0, 0, CANVAS, CANVAS, MARK_RADIUS * CANVAS, GRADIENT)
            + '\n' + group(mark) + '\n</g>')
    return document(tile, background=None, size=SPLASH_CANVAS)


# Raster output ------------------------------------------------------------


def render(svg: str, size: int, *, opaque: bool = False) -> Image.Image:
    png = cairosvg.svg2png(bytestring=svg.encode('utf-8'),
                           output_width=size, output_height=size)
    image = Image.open(io.BytesIO(png))
    return image.convert('RGB' if opaque else 'RGBA')


def report(path: Path, detail: str) -> None:
    print(f'  {path.relative_to(ROOT)}  {detail}')


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')
    report(path, 'SVG')


def write_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    report(path, f'{image.width}×{image.height} {image.mode}')


def write_ico(path: Path, images: list[Image.Image]) -> None:
    """Writes one .ico entry per image (Pillow resizes nothing given exact
    sizes; the largest image must be the base)."""
    images = sorted(images, key=lambda im: im.width, reverse=True)
    sizes = [im.size for im in images]
    path.parent.mkdir(parents=True, exist_ok=True)
    images[0].save(path, format='ICO', sizes=sizes, append_images=images[1:])
    with Image.open(path) as ico:
        written = sorted(ico.info['sizes'])
    if written != sorted(sizes):
        fail(f'{path.name} holds {written}, expected {sorted(sizes)}')
    report(path, ', '.join(str(w) for w, _ in sorted(sizes)))


def write_sources(mark: Mark) -> None:
    """The opaque master and the variants flutter_launcher_icons reads."""
    master = document(group(mark), background='gradient')
    svg_path = BRANDING / 'icon.svg'
    write_text(svg_path, master)
    write_png(BRANDING / 'icon.png',
              render(svg_path.read_text(encoding='utf-8'), CANVAS, opaque=True))
    write_png(BRANDING / 'icon_foreground.png', render(
        document(group(mark, scale=FOREGROUND_SCALE), background=None), CANVAS))
    write_png(BRANDING / 'icon_monochrome.png', render(document(
        group(mark, scale=FOREGROUND_SCALE, colour=WHITE), background=None),
        CANVAS))
    # iOS dark and tinted appearances keep the master's proportions, so the
    # icon does not shrink when the home screen switches appearance.
    write_png(BRANDING / 'icon_dark.png',
              render(document(group(mark), background=None), CANVAS))
    write_png(BRANDING / 'icon_tinted.png', render(
        document(group(mark, colour=WHITE), background='black'), CANVAS,
        opaque=True))
    write_png(BRANDING / 'mark_128.png', render(
        document(group(mark), background='gradient', radius=MARK_RADIUS * CANVAS),
        128))
    # flutter_native_splash reads this for the Android and iOS launch screens.
    write_png(BRANDING / 'splash_logo.png',
              render(splash_logo(mark), SPLASH_CANVAS))


# flutter_native_splash writes this into every LaunchTheme unless the splash
# is full screen. Android then paints the system bars black around the launch
# screen, whatever the themes say; edge to edge, the window must draw them.
SPLASH_BARS_FALSE = ('<item name="android:windowDrawsSystemBarBackgrounds">'
                     'false</item>')
SPLASH_BARS_TRUE = SPLASH_BARS_FALSE.replace('false', 'true')


def fix_launch_themes() -> None:
    """Lets every LaunchTheme draw its own, transparent, system bars."""
    for path in sorted(ANDROID_RES.glob('values*/styles.xml')):
        text = path.read_text(encoding='utf-8')
        if SPLASH_BARS_FALSE in text:
            path.write_text(text.replace(SPLASH_BARS_FALSE, SPLASH_BARS_TRUE),
                            encoding='utf-8')
            report(path, 'LaunchTheme draws its system bars')


def write_post(mark: Mark) -> None:
    """Outputs flutter_launcher_icons cannot make, and the launch themes'
    system bars after flutter_native_splash; run after both."""
    master = document(group(mark), background='gradient')
    # The larger tiles: the master's art, with the small tiles' corners.
    tile = document(group(mark), background='gradient',
                    radius=TILE_RADIUS * CANVAS)
    maskable = document(group(mark, scale=MASKABLE_SCALE), background='gradient')

    for size in (192, 512):
        write_png(ROOT / 'web' / 'icons' / f'Icon-maskable-{size}.png',
                  render(maskable, size, opaque=True))
    write_png(ROOT / 'web' / 'favicon.png', render(small_mark(32), 32))
    write_ico(ROOT / 'web' / 'favicon.ico',
              [render(small_mark(s), s) for s in (16, 32)]
              + [render(tile, 48)])
    write_png(ROOT / 'web' / 'apple-touch-icon.png',
              render(master, 180, opaque=True))
    write_ico(ROOT / 'windows' / 'runner' / 'resources' / 'app_icon.ico',
              [render(small_mark(s), s) for s in (16, 20, 24, 32)]
              + [render(tile, s) for s in (40, 48, 64, 256)])
    fix_launch_themes()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument(
        '--post', action='store_true',
        help='write the web maskable icons, favicons and Windows .ico, and '
             'fix the launch themes\' system bars; run after '
             '`dart run flutter_launcher_icons` and '
             '`dart run flutter_native_splash:create`')
    args = parser.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        font_path = load_font(Path(tmp))
        font = TTFont(font_path)
        glyphs, upem = shape(font_path, font)
        clusters = visual_clusters(glyphs, font.getGlyphSet())
        check_order(clusters)
        mark = layout(glyphs, upem, font)

    if mark.radius(FOREGROUND_SCALE) > FOREGROUND_SAFE_RADIUS:
        fail('the adaptive foreground leaves the safe circle')
    if mark.radius(MASKABLE_SCALE) > MASKABLE_SAFE_RADIUS:
        fail('the maskable icon leaves the safe zone')
    if (rounded_square_reach(SPLASH_TILE, MARK_RADIUS * SPLASH_TILE)
            > SPLASH_SAFE_RADIUS):
        fail("the launch screen's tile leaves the Android 12 icon circle")

    print(f'Wordmark: letters {mark.letter_height:.0f} px tall, ink '
          f'{mark.word_width:.0f} px wide ({mark.advance_width:.0f} px of '
          f'advances); group spans y {mark.bounds[1]:.0f}–{mark.bounds[3]:.0f}.')
    if args.post:
        write_post(mark)
    else:
        write_sources(mark)

    rightmost = clusters[-1]
    print(f'Glyph clusters left to right: {clusters} '
          f'({" ".join(f"U+{WORD[c]:04X}" for c in clusters)}).')
    print(f'Rightmost glyph: cluster {rightmost} '
          f'({chr(WORD[rightmost])}, U+{WORD[rightmost]:04X}).')


if __name__ == '__main__':
    main()

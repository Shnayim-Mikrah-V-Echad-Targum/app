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
    python3 tool/branding/make_icon.py --post   # maskable, favicons, Windows
                                                # .ico and MSIX icons, launch
                                                # screens' system bars, the
                                                # web's link preview, shortcut
                                                # icons and loading mark

A Hebrew reader checks the results by eye before every release.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import math
import os
import re
import shutil
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
MSIX = ROOT / 'windows' / 'msix'
WEB = ROOT / 'web'
FONTS = ROOT / 'assets' / 'fonts'

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
# The MSIX package's icons. The msix tool makes every size from one logo, up
# to 1240 px (the large tile at 400%); tool/windows/make_msix.sh then
# replaces the app icons of 32 px and below, which keep these msix file
# names, with the three rules alone, as app_icon.ico has them.
MSIX_LOGO = 1240
MSIX_SMALL_SIZES = (16, 20, 24, 30, 32)
MSIX_SMALL_FORMS = ('targetsize', 'altform-unplated_targetsize',
                    'altform-lightunplated_targetsize')

# The web's link preview (og:image): the About header on Klaf, in a title
# page's frame (docs/DESIGN_SYSTEM.md §7.4).
OG_WIDTH, OG_HEIGHT = 1200, 630
KLAF = '#FAF7F0'
TECHELET = '#1D3F75'
INK_VARIANT = '#575046'  # onSurfaceVariant
HAIRLINE = '#D8CFBF'
GOLD_LEAF = '#B38D3F'
OG_TITLE_HE = 'שניים מקרא ואחד תרגום'
OG_TITLE_EN = 'Shnayim Mikra v’Echad Targum'
# The web app's shortcuts (manifest.json) wear the navigation's icons
# (lib/app/shell.dart): Icons.today and Icons.donut_large, from the Material
# icons font in the Flutter SDK.
SHORTCUT_ICONS = {'today': 0xE66A, 'progress': 0xE1F9}
SHORTCUT_SIZE = 192
# web/index.html's loading screen shows the in-app mark inline, between these.
LOADER_MARK_START = '<!-- mark: tool/branding/make_icon.py --post -->'
LOADER_MARK_END = '<!-- /mark -->'
LOADER_MARK = re.compile(rf'([ \t]*){re.escape(LOADER_MARK_START)}.*?'
                         rf'{re.escape(LOADER_MARK_END)}', re.DOTALL)


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


def shape(font_path: Path, font: TTFont, direction: str = 'rtl', *,
          text: str | None = None) -> tuple[list[Glyph], int]:
    """Shapes WORD as Hebrew, or [text] (Hebrew when [direction] is 'rtl',
    otherwise English); returns the glyphs and the units per em."""
    face = hb.Face(hb.Blob.from_file_path(str(font_path)))
    buf = hb.Buffer()
    if text is None:
        buf.add_codepoints(list(WORD))
    else:
        buf.add_str(text)
    hebrew = text is None or direction == 'rtl'
    buf.direction = direction
    buf.script = 'Hebr' if hebrew else 'Latn'
    buf.language = 'he' if hebrew else 'en'
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


def text_path(font_path: Path, text: str, px: float, *, centre: float,
              baseline: float, fill: str,
              direction: str = 'ltr') -> tuple[str, float]:
    """[text] shaped by HarfBuzz at [px], its ink centred on x = [centre],
    as an SVG path; and the ink's width."""
    font = TTFont(font_path)
    glyph_set = font.getGlyphSet()
    glyphs, upem = shape(font_path, font, direction, text=text)
    scale = px / upem
    ink = BoundsPen(glyph_set)
    for g in glyphs:
        glyph_set[g.name].draw(TransformPen(ink, (1, 0, 0, 1, g.x, g.y)))
    x_min, _, x_max, _ = ink.bounds
    dx = centre - (x_min + x_max) / 2 * scale
    pen = SVGPathPen(glyph_set, ntos=num)
    for g in glyphs:
        glyph_set[g.name].draw(TransformPen(
            pen, (scale, 0, 0, -scale, dx + g.x * scale, baseline - g.y * scale)))
    return f'<path fill="{fill}" d="{pen.getCommands()}"/>', (x_max - x_min) * scale


def tile_at(mark: Mark, x: float, y: float, side: float) -> str:
    """The in-app mark's tile (mark_128.png), [side] px wide at (x, y)."""
    return (f'<g transform="translate({num(x)} {num(y)}) '
            f'scale({num(side / CANVAS)})">'
            + rounded_rect(0, 0, CANVAS, CANVAS, MARK_RADIUS * CANVAS, GRADIENT)
            + group(mark).replace('\n', '') + '</g>')


def og_image(mark: Mark) -> str:
    """The link preview, as the About header is laid out: the mark's tile,
    the full name in Hebrew (Techelet) and in English, a divider between,
    on Klaf in a title page's frame. Everything sits in the middle 630 px,
    so a square crop keeps it."""
    centre = OG_WIDTH / 2
    tile = 168
    top = 126
    he_baseline = top + tile + 98
    divider = he_baseline + 40
    en_baseline = divider + 62
    hebrew, he_width = text_path(FONTS / 'FrankRuhlLibre-Medium.ttf', OG_TITLE_HE,
                                 58, centre=centre, baseline=he_baseline,
                                 fill=TECHELET, direction='rtl')
    english, en_width = text_path(FONTS / 'EBGaramond-Medium.ttf', OG_TITLE_EN,
                                  36, centre=centre, baseline=en_baseline,
                                  fill=INK_VARIANT)
    if max(he_width, en_width, tile) > OG_HEIGHT - 2 * 48:
        fail('the link preview is too wide for a square crop')
    # SeferDivider (§7.2) at 2×, 0.45 of the square crop wide: hairlines to
    # 20 px short of a gold lozenge.
    rules = ''.join(
        f'<path d="M{num(a)} {num(divider)}H{num(b)}" stroke="{HAIRLINE}" '
        'stroke-width="2"/>'
        for a, b in ((centre - 140, centre - 20), (centre + 20, centre + 140)))
    lozenge = (f'<path fill="{GOLD_LEAF}" d="M{num(centre)} {num(divider - 8)}'
               f'L{num(centre + 8)} {num(divider)}L{num(centre)} '
               f'{num(divider + 8)}L{num(centre - 8)} {num(divider)}Z"/>')
    # TitlePageFrame (§7.4) at 2×: a hairline, and a gold rule inset within it.
    frame = (f'<rect x="32" y="32" width="{OG_WIDTH - 64}" height="{OG_HEIGHT - 64}" '
             f'rx="24" fill="none" stroke="{HAIRLINE}" stroke-width="2"/>'
             f'<rect x="44" y="44" width="{OG_WIDTH - 88}" height="{OG_HEIGHT - 88}" '
             f'rx="16" fill="none" stroke="{GOLD_LEAF}" stroke-width="2"/>')
    body = '\n'.join([
        f'<rect width="{OG_WIDTH}" height="{OG_HEIGHT}" fill="{KLAF}"/>',
        frame,
        tile_at(mark, centre - tile / 2, top, tile),
        hebrew, rules, lozenge, english,
    ])
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{OG_WIDTH}" '
            f'height="{OG_HEIGHT}" viewBox="0 0 {OG_WIDTH} {OG_HEIGHT}">\n'
            + GRADIENT_DEFS + body + '\n</svg>\n')


def loader_mark(mark: Mark) -> str:
    """The in-app mark for web/index.html's loading screen: one line of
    inline SVG, with a gradient id of its own."""
    gradient = 'loading-mark-bg'
    defs = GRADIENT_DEFS.strip().replace('id="bg"', f'id="{gradient}"')
    return (f'<svg class="mark" viewBox="0 0 {CANVAS} {CANVAS}" width="96" '
            'height="96" aria-hidden="true" focusable="false">' + defs
            + rounded_rect(0, 0, CANVAS, CANVAS, MARK_RADIUS * CANVAS,
                           f'url(#{gradient})')
            + group(mark).replace('\n', '') + '</svg>')


def material_icons_font() -> Path:
    """The Material icons font the Flutter SDK bundles with the app."""
    roots = [Path(os.environ['FLUTTER_ROOT'])] if 'FLUTTER_ROOT' in os.environ else []
    if flutter := shutil.which('flutter'):
        roots.append(Path(flutter).resolve().parents[1])
    for root in roots:
        path = (root / 'bin' / 'cache' / 'artifacts' / 'material_fonts'
                / 'MaterialIcons-Regular.otf')
        if path.exists():
            return path
    fail('no Material icons font: put flutter on the PATH or set FLUTTER_ROOT')


def shortcut_icon(font: TTFont, codepoint: int) -> str:
    """A shortcut's icon: the navigation's glyph in cream on the favicons'
    tile, its em box (24 dp in the app) 58% of the tile."""
    name = font.getBestCmap()[codepoint]
    upem = font['head'].unitsPerEm
    em = 0.58 * CANVAS
    scale = em / upem
    origin = CENTRE - em / 2
    pen = SVGPathPen(font.getGlyphSet(), ntos=num)
    # The em box runs from 0 to upem on both axes; SVG's y runs down.
    font.getGlyphSet()[name].draw(TransformPen(
        pen, (scale, 0, 0, -scale, origin, origin + em)))
    glyph = f'<path fill="{CREAM}" d="{pen.getCommands()}"/>'
    return document(glyph, background='gradient', radius=TILE_RADIUS * CANVAS)


# Raster output ------------------------------------------------------------


def render(svg: str, size: int, *, opaque: bool = False,
           height: int | None = None) -> Image.Image:
    """[svg] at [size]² px, or [size] × [height]."""
    png = cairosvg.svg2png(bytestring=svg.encode('utf-8'),
                           output_width=size, output_height=height or size)
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


def write_msix(tile: str) -> None:
    """The MSIX package's logo, [tile] (the .ico's larger entries), and its
    app icons of 32 px and below."""
    write_png(MSIX / 'logo.png', render(tile, MSIX_LOGO))
    for size in MSIX_SMALL_SIZES:
        small = render(small_mark(size), size)
        for form in MSIX_SMALL_FORMS:
            write_png(MSIX / 'Images' / f'Square44x44Logo.{form}-{size}.png',
                      small)


def write_loader_mark(mark: Mark) -> None:
    """Puts the mark inline in web/index.html, between its markers."""
    path = WEB / 'index.html'
    html = path.read_text(encoding='utf-8')
    if not LOADER_MARK.search(html):
        fail(f'{path.relative_to(ROOT)} lacks the loading mark\'s markers')
    svg = loader_mark(mark)
    html = LOADER_MARK.sub(
        lambda m: '\n'.join(m.group(1) + line
                            for line in (LOADER_MARK_START, svg, LOADER_MARK_END)),
        html, count=1)
    path.write_text(html, encoding='utf-8')
    report(path, 'loading mark')


def write_web(mark: Mark) -> None:
    """The web's link preview, its shortcuts' icons and its loading mark."""
    write_png(WEB / 'og.png', render(og_image(mark), OG_WIDTH, height=OG_HEIGHT,
                                     opaque=True))
    icons = TTFont(material_icons_font())
    for name, codepoint in SHORTCUT_ICONS.items():
        write_png(WEB / 'icons' / f'shortcut-{name}.png',
                  render(shortcut_icon(icons, codepoint), SHORTCUT_SIZE))
    write_loader_mark(mark)


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
    write_msix(tile)
    write_web(mark)
    fix_launch_themes()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument(
        '--post', action='store_true',
        help='write the web maskable icons, favicons, link preview, '
             'shortcut icons and loading mark, the Windows .ico and MSIX '
             'icons, and fix the launch themes\' system bars; run after '
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

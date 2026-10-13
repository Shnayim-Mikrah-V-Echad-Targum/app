#!/usr/bin/env python3
"""Frames the capture harness's store screenshots for the App Store and
Google Play: each capture on Klaf under a headline, at the store's exact
size, without alpha.

From the repository root:

    CAPTURE=1 MODES=storeios,storeioshe,storeipad,storeipadhe,storeplay,storeplayhe,storeplaytab,storeplaytabhe \\
        flutter test test/screens/capture_test.dart
    python3 tool/store/frame.py

writes build/store/<ios|ipad|play|playtab>/<en-US|he>/NN_<screen>.png
(docs/RELEASE.md says where each goes). The headlines are shaped by
HarfBuzz, as the icon's Hebrew is (tool/branding/make_icon.py); a Hebrew
reader approves the Hebrew ones before upload.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'branding'))
import make_icon  # noqa: E402  (shaping, SVG paths and rasterizing)

ROOT = make_icon.ROOT
CAPTURES = ROOT / 'build' / 'screens'
OUT = ROOT / 'build' / 'store'

KLAF = make_icon.KLAF  # surface
TECHELET = make_icon.TECHELET  # primary
HAIRLINE = make_icon.HAIRLINE

# Lengths are given for Play's phone canvas, 1920 px tall, and scale with
# the canvas's height, so every store's screenshots look alike.
REFERENCE_HEIGHT = 1920
SHOT_HEIGHT = 0.82  # of the canvas
SHOT_RADIUS = 48
SHOT_BOTTOM = 0.04  # the margin under the capture, of the canvas
HEADLINE_PX = 64
LINE_HEIGHT = 1.3
SUPERSAMPLE = 4  # for smooth rounded corners

FONTS = {
    'en-US': (make_icon.FONTS / 'EBGaramond-Medium.ttf', 'ltr'),
    'he': (make_icon.FONTS / 'FrankRuhlLibre-Medium.ttf', 'rtl'),
}
REFERENCE_LETTER = {'en-US': 'H', 'he': 'ה'}


@dataclass(frozen=True)
class Device:
    name: str  # the folder under build/store
    mode: str  # the capture mode; its Hebrew twin adds 'he'
    size: tuple[int, int]  # the store's, in pixels


DEVICES = (
    Device('ios', 'storeios', (1320, 2868)),  # 6.9" iPhone
    Device('ipad', 'storeipad', (2064, 2752)),  # 13" iPad
    Device('play', 'storeplay', (1080, 1920)),  # phone
    Device('playtab', 'storeplaytab', (1600, 2560)),  # 10" tablet
)
LANGUAGES = {'en-US': '', 'he': 'he'}  # the folder, and its mode's suffix


@dataclass(frozen=True)
class Shot:
    screen: str  # a capture harness screen in its _storeScreens
    en: str
    he: str
    # Another screen on some devices: on a tablet's page, the guided reader
    # shows a section rather than a verse, and large print shows in the full
    # text; the iPad's full text sets the Targum beside each verse.
    instead: dict[str, str] = field(default_factory=dict)

    def screen_on(self, device: Device) -> str:
        return self.instead.get(device.name, self.screen)

    def headline(self, language: str) -> str:
        return self.he if language == 'he' else self.en


# In order. They describe the app as it is: no streak counts, and nothing
# from the demo community, whose members are made up.
SHOTS = (
    Shot('today', 'The parsha twice, the Targum once', 'שניים מקרא ואחד תרגום'),
    Shot('reader', 'Guided aliyah by aliyah, verse by verse',
         'עלייה אחר עלייה, פסוק אחר פסוק',
         instead={'ipad': 'reader_section', 'playtab': 'reader_section'}),
    Shot('week', 'Always the right parsha, in Israel or abroad',
         'תמיד הפרשה הנכונה, בארץ ובחו״ל'),
    Shot('progress', 'A gentle rhythm that respects Shabbat', 'קצב נינוח ששומר שבת'),
    Shot('reader_listen', 'Listen along, or read Mikra and Targum side by side',
         'להאזין, או לקרוא מקרא ותרגום זה לצד זה',
         instead={'ipad': 'reader_full'}),
    Shot('store_access', 'For every reader: large text, high contrast, screen readers',
         'לכל קורא: טקסט גדול, ניגודיות גבוהה וקוראי מסך',
         instead={'ipad': 'store_access_full', 'playtab': 'store_access_full'}),
)

# Every screen the shots use: test/screens/capture_test.dart's _storeScreens.
SCREENS = frozenset(s.screen_on(d) for s in SHOTS for d in DEVICES)


def fail(message: str):
    sys.exit(f'frame: {message}')


# Headline -----------------------------------------------------------------


def ink_width(text: str, px: float, language: str) -> float:
    font, direction = FONTS[language]
    return make_icon.text_path(font, text, px, centre=0, baseline=0, fill=TECHELET,
                               direction=direction)[1]


def break_lines(text: str, px: float, language: str) -> list[str]:
    """[text] on two lines of about equal width, preferring a break after a
    comma or colon when the lines are still nearly even."""
    words = text.split(' ')
    if len(words) < 2:
        return [text]
    best, best_cost = None, float('inf')
    for i in range(1, len(words)):
        lines = [' '.join(words[:i]), ' '.join(words[i:])]
        cost = max(ink_width(line, px, language) for line in lines)
        if lines[0][-1] in ',:':
            cost *= 0.92
        if cost < best_cost:
            best, best_cost = lines, cost
    return best


def letter_height(language: str, px: float) -> float:
    """How far a capital (in Hebrew, a ה) rises above the baseline."""
    font_path, _ = FONTS[language]
    font = TTFont(font_path)
    glyphs = font.getGlyphSet()
    pen = BoundsPen(glyphs)
    glyphs[font.getBestCmap()[ord(REFERENCE_LETTER[language])]].draw(pen)
    return pen.bounds[3] * px / font['head'].unitsPerEm


def headline(text: str, language: str, size: tuple[int, int],
             max_width: float, px: float) -> Image.Image:
    """[text] on two lines in techelet, on a transparent [size], centred,
    no line wider than [max_width]. The lines' letters, from the top of the
    first line's capitals to the second's baseline, are centred vertically,
    so every headline of a set stands on the same baselines."""
    lines = break_lines(text, px, language)
    widest = max(ink_width(line, px, language) for line in lines)
    if widest > max_width:
        px *= max_width / widest
    font, direction = FONTS[language]
    width, height = size
    leading = px * LINE_HEIGHT
    rise = letter_height(language, px)
    first = (height - rise - leading * (len(lines) - 1)) / 2 + rise
    paths = [make_icon.text_path(font, line, px, centre=width / 2,
                                 baseline=first + leading * i, fill=TECHELET,
                                 direction=direction)[0]
             for i, line in enumerate(lines)]
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
           f'height="{height}" viewBox="0 0 {width} {height}">\n'
           + '\n'.join(paths) + '\n</svg>\n')
    return make_icon.render(svg, width, height=height)


# Framing ------------------------------------------------------------------


def rounded_mask(size: tuple[int, int], radius: float) -> Image.Image:
    w, h = size
    big = Image.new('L', (w * SUPERSAMPLE, h * SUPERSAMPLE), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, w * SUPERSAMPLE - 1, h * SUPERSAMPLE - 1),
        radius=radius * SUPERSAMPLE, fill=255)
    return big.resize(size, Image.LANCZOS)


def hairline(size: tuple[int, int], box: tuple[int, int, int, int],
             radius: float) -> Image.Image:
    """A 1 px hairline just outside [box], following its rounded corners."""
    w, h = size
    big = Image.new('RGBA', (w * SUPERSAMPLE, h * SUPERSAMPLE), (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    ImageDraw.Draw(big).rounded_rectangle(
        ((x0 - 1) * SUPERSAMPLE, (y0 - 1) * SUPERSAMPLE,
         (x1 + 1) * SUPERSAMPLE - 1, (y1 + 1) * SUPERSAMPLE - 1),
        radius=(radius + 1) * SUPERSAMPLE, outline=HAIRLINE, width=SUPERSAMPLE)
    return big.resize(size, Image.LANCZOS)


def flatten(image: Image.Image) -> Image.Image:
    """[image] on Klaf, without alpha."""
    if image.mode in ('RGBA', 'LA', 'P'):
        base = Image.new('RGBA', image.size, KLAF)
        base.alpha_composite(image.convert('RGBA'))
        return base.convert('RGB')
    return image.convert('RGB')


def frame(capture: Image.Image, text: str, language: str) -> Image.Image:
    """[capture] scaled into a canvas of its own size, on Klaf, with its
    corners rounded and a hairline round it, under [text]."""
    width, height = capture.size
    scale = height / REFERENCE_HEIGHT
    canvas = Image.new('RGBA', capture.size, KLAF)

    shot_h = round(SHOT_HEIGHT * height)
    shot_w = round(shot_h * width / height)
    x = (width - shot_w) // 2
    y = height - round(SHOT_BOTTOM * height) - shot_h
    radius = SHOT_RADIUS * scale
    shot = flatten(capture).resize((shot_w, shot_h), Image.LANCZOS)
    canvas.paste(shot, (x, y), rounded_mask((shot_w, shot_h), radius))
    canvas.alpha_composite(hairline(capture.size, (x, y, x + shot_w, y + shot_h),
                                    radius))

    # The headline in the space above, as wide as the capture at most.
    canvas.alpha_composite(headline(text, language, (width, y), max_width=shot_w,
                                    px=HEADLINE_PX * scale))
    return canvas.convert('RGB')


def capture_path(captures: Path, device: Device, language: str,
                 screen: str) -> Path:
    return captures / f'{device.mode}{LANGUAGES[language]}_{screen}.png'


def write_device(device: Device, language: str, captures: Path,
                 out: Path) -> list[Path]:
    folder = out / device.name / language
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob('*.png'):
        old.unlink()
    written = []
    for number, shot in enumerate(SHOTS, start=1):
        screen = shot.screen_on(device)
        with Image.open(capture_path(captures, device, language, screen)) as capture:
            if capture.size != device.size:
                fail(f'{capture.filename} is {capture.size[0]}×{capture.size[1]}, '
                     f'expected {device.size[0]}×{device.size[1]}')
            image = frame(capture, shot.headline(language), language)
        path = folder / f'{number:02d}_{screen}.png'
        image.save(path, optimize=True)
        written.append(path)
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--captures', type=Path, default=CAPTURES,
                        help='the capture harness\'s PNGs (build/screens)')
    parser.add_argument('--out', type=Path, default=OUT,
                        help='where to write the framed screenshots (build/store)')
    args = parser.parse_args()

    missing = sorted({
        capture_path(args.captures, d, language, s.screen_on(d)).name
        for d in DEVICES for language in LANGUAGES for s in SHOTS
        if not capture_path(args.captures, d, language, s.screen_on(d)).exists()})
    if missing:
        modes = ','.join(d.mode + suffix for d in DEVICES
                         for suffix in LANGUAGES.values())
        fail(f'{len(missing)} captures missing ({", ".join(missing[:3])}…). '
             f'Run: CAPTURE=1 MODES={modes} flutter test '
             'test/screens/capture_test.dart')

    for device in DEVICES:
        for language in LANGUAGES:
            for path in write_device(device, language, args.captures, args.out):
                with Image.open(path) as image:
                    print(f'  {path}  {image.width}×{image.height} {image.mode}')


if __name__ == '__main__':
    main()

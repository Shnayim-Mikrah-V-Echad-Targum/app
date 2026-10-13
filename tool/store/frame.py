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
reader approves the Hebrew ones, and where each breaks, before upload.
"""

from __future__ import annotations

import argparse
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageChops, ImageDraw

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
    ratio: float  # the capture mode's device pixel ratio

    @property
    def width_dp(self) -> float:
        """How wide the app is laid out, in logical pixels."""
        return self.size[0] / self.ratio


DEVICES = (
    Device('ios', 'storeios', (1320, 2868), 3.0),  # 6.9" iPhone
    Device('ipad', 'storeipad', (2064, 2752), 2.0),  # 13" iPad
    Device('play', 'storeplay', (1080, 1920), 2.625),  # phone
    Device('playtab', 'storeplaytab', (1600, 2560), 2.0),  # 10" tablet
)
LANGUAGES = {'en-US': '', 'he': 'he'}  # the folder, and its mode's suffix


@dataclass(frozen=True)
class Caption:
    """A headline in each language, broken where it reads best ('\\n'),
    approved with the Hebrew."""
    en: str
    he: str

    def text(self, language: str) -> str:
        return self.he if language == 'he' else self.en


@dataclass(frozen=True)
class Shot:
    screen: str  # a capture harness screen in its _storeScreensByMode
    caption: Caption
    # Another screen, and its caption, on some devices: a tablet shows large
    # print in the full text, which fills its page, and the iPad, wide
    # enough for the Targum beside each verse, the full text in place of
    # Listen.
    instead: dict[str, str] = field(default_factory=dict)
    captions: dict[str, Caption] = field(default_factory=dict)

    def screen_on(self, device: Device) -> str:
        return self.instead.get(device.name, self.screen)

    def headline(self, language: str, device: Device) -> str:
        return self.captions.get(device.name, self.caption).text(language)


# In order. They describe the app as it is, on each device: a reader some
# weeks into the year with nothing overdue, no streak counts, and nothing
# from the demo community, whose members are made up.
SHOTS = (
    Shot('store_today', Caption('The parsha twice,\nthe Targum once', 'שניים מקרא\nואחד תרגום')),
    Shot('store_reader', Caption('Guided aliyah by aliyah,\nverse by verse', 'עלייה אחר עלייה,\nפסוק אחר פסוק')),
    Shot('store_week', Caption('Always the right parsha,\nin Israel or abroad', 'תמיד הפרשה הנכונה,\nבארץ ובחו״ל')),
    Shot('store_progress', Caption('A gentle rhythm\nthat respects Shabbat', 'קצב נינוח\nששומר שבת')),
    Shot('store_listen', Caption('Listen along,\nhands-free', 'להאזין לקריאה,\nבלי לגעת במסך'),
         instead={'ipad': 'store_full'},
         captions={'ipad': Caption('Mikrah and Targum,\nside by side', 'מקרא ותרגום,\nזה לצד זה')}),
    Shot('store_access', Caption('For every reader: large text,\nhigh contrast, screen readers',
                                 'לכל קורא: טקסט גדול,\nניגודיות גבוהה וקוראי מסך'),
         instead={'ipad': 'store_access_full', 'playtab': 'store_access_full'}),
)


def screens_on(device: Device) -> list[str]:
    """The capture harness screens [device]'s shots use, in order: its
    mode's in test/screens/capture_test.dart's _storeScreensByMode."""
    return [shot.screen_on(device) for shot in SHOTS]


def fail(message: str):
    sys.exit(f'frame: {message}')


# Headline -----------------------------------------------------------------


def ink_width(text: str, px: float, language: str) -> float:
    font, direction = FONTS[language]
    return make_icon.text_path(font, text, px, centre=0, baseline=0, fill=TECHELET,
                               direction=direction)[1]


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
    """[text] on its lines (broken at its '\\n's) in techelet, on a
    transparent [size], centred, no line wider than [max_width]. The lines'
    letters, from the top of the first line's capitals to the last's
    baseline, are centred vertically, so every headline of a set stands on
    the same baselines."""
    lines = text.split('\n')
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
    """An opaque [size] with its corners rounded to [radius], anti-aliased:
    each corner drawn at SUPERSAMPLE times and scaled down, the rest as it
    is, so that no image of SUPERSAMPLE times the whole is needed."""
    w, h = size
    mask = Image.new('L', size, 255)
    r = min(math.ceil(radius), w // 2, h // 2)
    if r <= 0:
        return mask
    big = Image.new('L', (r * SUPERSAMPLE, r * SUPERSAMPLE), 0)
    d = 2 * radius * SUPERSAMPLE
    ImageDraw.Draw(big).ellipse((0, 0, d - 1, d - 1), fill=255)
    corner = big.resize((r, r), Image.LANCZOS)
    mask.paste(corner, (0, 0))
    mask.paste(corner.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (w - r, 0))
    mask.paste(corner.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, h - r))
    mask.paste(corner.transpose(Image.Transpose.ROTATE_180), (w - r, h - r))
    return mask


def hairline(box: tuple[int, int, int, int], radius: float) -> Image.Image:
    """A 1 px hairline just outside [box], following its rounded corners, on
    a transparent image 1 px larger than the box all round, to be laid at
    the box's corner less 1 px."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    inside = Image.new('L', (w + 2, h + 2), 0)
    inside.paste(rounded_mask((w, h), radius), (1, 1))
    line = ImageChops.subtract(rounded_mask((w + 2, h + 2), radius + 1), inside)
    image = Image.new('RGBA', line.size, HAIRLINE)
    image.putalpha(line)
    return image


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
    canvas.alpha_composite(hairline((x, y, x + shot_w, y + shot_h), radius), (x - 1, y - 1))

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
            image = frame(capture, shot.headline(language, device), language)
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

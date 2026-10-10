#!/usr/bin/env python3
"""Writes assets/branding/notification.png, the app icon Windows shows on
reminder toasts and in its notification settings.

Windows draws it at 16-32 px, so it is the small mark of DESIGN_SYSTEM.md
§7.8 (sizes <= 32 px): the three rules only, with no wordmark, on the icon's
gradient with rounded corners. Rendered at 256 px, as Windows recommends.

Usage: python3 tool/branding/notification_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 256
SUPERSAMPLE = 8

TOP = (0x23, 0x49, 0x7F)
BOTTOM = (0x16, 0x31, 0x5C)
CREAM = (0xF6, 0xF0, 0xE2)
GOLD = (0xD2, 0xA6, 0x4A)

# Fractions of the canvas, from the design system.
CORNER = 0.1875
RULE_WIDTH = 0.625
RULE_HEIGHT = 0.094
RULE_GAP = 0.078
# Two readings of the Mikra, then the Targum.
RULE_FILLS = (CREAM, CREAM, GOLD)


def small_mark(size: int) -> Image.Image:
    s = size * SUPERSAMPLE
    gradient = Image.new('RGB', (1, s))
    for y in range(s):
        t = y / (s - 1)
        gradient.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    image = gradient.resize((s, s)).convert('RGBA')

    mask = Image.new('L', (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=CORNER * s, fill=255)
    image.putalpha(mask)

    draw = ImageDraw.Draw(image)
    width, height, gap = RULE_WIDTH * s, RULE_HEIGHT * s, RULE_GAP * s
    left = (s - width) / 2
    top = (s - (3 * height + 2 * gap)) / 2
    for i, fill in enumerate(RULE_FILLS):
        y = top + i * (height + gap)
        draw.rounded_rectangle([left, y, left + width, y + height], radius=height / 2, fill=fill)

    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    out = Path(__file__).resolve().parents[2] / 'assets' / 'branding' / 'notification.png'
    small_mark(SIZE).save(out, optimize=True)
    print(f'Wrote {out.relative_to(out.parents[2])}')


if __name__ == '__main__':
    main()

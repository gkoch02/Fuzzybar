#!/usr/bin/env python3
"""Render the README logo banner at Assets/banner.png.

    python3 Tools/make_banner.py

The ground, clock face and hands follow the app icon (Assets/make_icon.swift):
the same indigo gradient, the face reading 8:40, the coral boss. The pills
are what the menubar shows at that minute in four personalities, led by a
blurred "8:40" for the exact time FuzzyBar declines to show. Change a phrase
here if its personality's wording changes.

Drawn at 2x (3200 x 800) so it stays sharp at the README's 800-point width.
Deterministic: re-running writes the same pixels on the same macOS. Needs
Pillow.
"""

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets" / "banner.png"

SF = "/System/Library/Fonts/SFNS.ttf"
SF_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"

S = 2  # pixel scale; layout numbers below are in 1600 x 400 points
W, H = 1600 * S, 400 * S

# make_icon.swift's colours.
GROUND = ((0x5C, 0x4D, 0xF2), (0x29, 0x1F, 0x8C))
FACE = (0xFA, 0xFA, 0xFA)
INK = (0x21, 0x1A, 0x73)
ACCENT = (0xFA, 0x73, 0x66)
EYEBROW = (0xC9, 0xC3, 0xF5)

PILLS = ["8:40", "twenty to nine", "zwanzig vor neun", "T-20 MINUTES, 0900 HOURS", "morning"]
BLURRED = {"8:40"}


def font(path, size, weight):
    f = ImageFont.truetype(path, size * S)
    f.set_variation_by_name(weight)
    return f


def diagonal_gradient(size, start, end):
    """Top-left to bottom-right, as the icon's gradient runs."""
    w, h = size
    small = Image.new("RGB", (64, 16))
    px = small.load()
    for y in range(16):
        for x in range(64):
            t = (x / 63 * w + y / 15 * h) / (w + h)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(start, end))
    return small.resize(size, Image.BICUBIC)


def soft_shadow(canvas, shape_mask, offset, radius, opacity):
    shadow = Image.new("L", canvas.size, 0)
    shadow.paste(shape_mask, (0, 0))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius * S))
    shadow = ImageChops.offset(shadow, 0, offset * S).point(lambda v: round(v * opacity))
    canvas.paste((0, 0, 0), (0, 0), shadow)


def draw_clock(canvas, cx, cy, r):
    disc = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(disc).ellipse(((cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S), fill=255)
    soft_shadow(canvas, disc, 8, 18, 0.35)

    # Drawn 4x larger on its own tile and scaled down, since ImageDraw does
    # not antialias.
    k = 4 * S
    size = round(2 * r * k)
    c = size / 2
    rr = r * k
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.ellipse((0, 0, size - 1, size - 1), fill=FACE)

    def stroke(angle_deg, r0, r1, width, colour):
        a = math.radians(angle_deg - 90)
        x0, y0 = c + r0 * math.cos(a), c + r0 * math.sin(a)
        x1, y1 = c + r1 * math.cos(a), c + r1 * math.sin(a)
        d.line((x0, y0, x1, y1), fill=colour, width=round(width))
        for x, y in ((x0, y0), (x1, y1)):
            d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=colour)

    for hour in range(12):
        major = hour % 3 == 0
        colour = (0x4A, 0x44, 0x99) if major else (0xBB, 0xB8, 0xDA)
        stroke(hour * 30, rr * (0.72 if major else 0.78), rr * 0.88,
               rr * (0.045 if major else 0.028), colour)
    stroke((8 + 40 / 60) * 30, 0, rr * 0.5, rr * 0.09, INK)
    stroke(40 * 6, 0, rr * 0.72, rr * 0.065, INK)
    boss = rr * 0.09
    d.ellipse((c - boss, c - boss, c + boss, c + boss), fill=ACCENT)

    px = round(2 * r * S)
    tile = tile.resize((px, px), Image.LANCZOS)
    canvas.alpha_composite(tile, (round((cx - r) * S), round((cy - r) * S)))


def draw_pills(canvas, x, y, height, gap):
    fnt = font(SF, 24, "Medium")
    pad = 18 * S
    x, y, height, gap = x * S, y * S, height * S, gap * S
    for text in PILLS:
        tw = ImageDraw.Draw(canvas).textlength(text, font=fnt)
        box = (x, y, x + tw + 2 * pad, y + height)
        plate = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(plate).rounded_rectangle(box, radius=height / 2, fill=(255, 255, 255, 34))
        canvas.alpha_composite(plate)
        label = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(label).text(((box[0] + box[2]) / 2, y + height / 2), text,
                                   font=fnt, fill=(255, 255, 255, 255), anchor="mm")
        if text in BLURRED:
            label = label.filter(ImageFilter.GaussianBlur(2.2 * S))
        canvas.alpha_composite(label)
        x = box[2] + gap


def main():
    canvas = diagonal_gradient((W, H), *GROUND).convert("RGBA")

    # The icon's top highlight, as a faint glow from the upper left.
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((-300 * S, -500 * S, 900 * S, 300 * S), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(120 * S)).point(lambda v: round(v * 0.16))
    canvas.paste((255, 255, 255), (0, 0), glow)

    draw_clock(canvas, 215, 200, 135)

    d = ImageDraw.Draw(canvas)
    left = 410 * S
    d.text((left + 4 * S, 92 * S), "THE TIME, IN WORDS", font=font(SF, 24, "Semibold"),
           fill=EYEBROW, anchor="ls")
    d.text((left, 232 * S), "FuzzyBar", font=font(SF_ROUNDED, 150, "Bold"), fill=(255, 255, 255),
           anchor="ls")
    draw_pills(canvas, 410, 276, 46, 12)

    canvas.convert("RGB").save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

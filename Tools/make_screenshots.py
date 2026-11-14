#!/usr/bin/env python3
"""Composite the captioned Mac App Store screenshot set.

Reads the raw captures in Assets/screenshots/ (the source of truth: retake
those on a Mac, ⇧⌘4, not in a simulator) and renders a captioned frame for
each into Assets/screenshots/captioned/, on a canvas App Store Connect
accepts for macOS. The caption sits above the capture, which sits on a
ground taken from the app icon's indigo gradient (Assets/make_icon.swift).

    python3 Tools/make_screenshots.py              # every frame, plus the strips
    python3 Tools/make_screenshots.py 01-menubar   # one frame

Besides the store frames it writes Assets/screenshots/strips/: the menubar
captures cropped to the bar itself and equalized to one width (right edge
kept, where the icons are), one PNG per personality plus personalities.png
with all of them stacked on a transparent ground. The README embeds the
stack; plumpbug.dev's FuzzyBar page copies the singles.

Captions reuse the App Store listing copy (subtitle, promotional text,
description). Edit them here and nowhere else.

The menubar raws were shot in one sitting with the other menubar items
hidden, so the strips differ only in the phrase. The phrase changes with
the clock, so retake the set together rather than one alone, and crop
each to the right 880 px of the bar.

The raw's pixel scale is read from menubar-spoken.png: a 1x capture of that
strip is under 600 px wide, a Retina one is over. At 1x the canvas is the
store's smallest size, 1280 x 800; at 2x it is 2560 x 1600 and everything
scales with it, which is the set to ship. Needs Pillow.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "Assets" / "screenshots"
OUT = SHOTS / "captioned"

# San Francisco, as macOS ships it: the app's own face.
SF = "/System/Library/Fonts/SFNS.ttf"

# The icon's deep indigo (make_icon.swift), darkening to the bottom.
GROUND = ((0x2A, 0x22, 0x8C), (0x1A, 0x14, 0x5E))
EYEBROW = (0xC9, 0xC3, 0xF5)
HEADLINE = (0xFF, 0xFF, 0xFF)

# One frame per entry, in store order. `shots` lists raw filenames and the
# factor each is placed at (relative to the raw's own scale); "fit" means
# 1, shrunk only if the capture would not fit under the caption. A third
# element crops the raw to that many points from the top before placing,
# so menubar strips shot with different amounts of wallpaper line up. The
# raws are 33 points tall: 01-menubar keeps all of it, while the stacked
# frame and the strips crop to 32. Asking for more than the raw holds pads
# it with transparency rather than erroring.
# `uniform=True` crops every shot to the widest one's width, keeping the right
# edge (where the menubar icons are) and extending a narrower capture's left
# edge from its own first column, so strips of different widths come out
# identical. Several shots stack in a centred column, `gap` points apart
# (28 unless the frame says otherwise).
# Window captures taken with ⇧⌘4 then Space carry their own shadow and
# transparent margins; list those in PLAIN so they are placed untouched.
FRAMES = {
    "01-menubar": dict(
        eyebrow="The time, in words",
        headline="Instead of 8:44, your menubar reads “quarter to nine”.",
        shots=[("menubar-spoken.png", 2.4, 33)],
    ),
    "02-popover": dict(
        eyebrow="Click it",
        headline="Exact time, full date, sunrise and sunset, and a month calendar.",
        shots=[("popover.png", "fit")],
    ),
    "03-personalities": dict(
        eyebrow="Ten personalities, or write your own",
        headline="Plain spoken English, Classic, Shakespeare, German, Spanish, "
                 "French, Mission Control, Eldritch, Latin, or Vague.",
        shots=[("menubar-spoken.png", 1, 32), ("menubar-classic.png", 1, 32),
               ("menubar-shakespeare.png", 1, 32), ("menubar-german.png", 1, 32),
               ("menubar-spanish.png", 1, 32), ("menubar-french.png", 1, 32),
               ("menubar-missioncontrol.png", 1, 32), ("menubar-eldritch.png", 1, 32),
               ("menubar-latin.png", 1, 32), ("menubar-vague.png", 1, 32)],
        uniform=True,
        gap=12,
    ),
    "04-settings": dict(
        eyebrow="Small on purpose",
        headline="No Dock icon, no network, no analytics, no account.",
        shots=[("settings.png", "fit")],
    ),
}


PLAIN = {"settings.png"}

# The menubar captures, in the order Personality.allCases declares them.
STRIPS = [shot[0] for shot in FRAMES["03-personalities"]["shots"]]


def raw_scale():
    return 2 if Image.open(SHOTS / "menubar-spoken.png").width > 600 else 1


def font(size, weight):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(weight)
    return f


def gradient(size, top, bottom):
    strip = Image.new("RGB", (1, size[1]))
    px = strip.load()
    for y in range(size[1]):
        t = y / (size[1] - 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return strip.resize(size)


def wrap(draw, text, fnt, width):
    """Balanced word wrap: as few lines as fit, then the narrowest measure
    that still gives that many, so no line is left holding one word."""
    def greedy(w):
        lines, line = [], []
        for word in text.split():
            trial = " ".join(line + [word])
            if line and draw.textlength(trial, font=fnt) > w:
                lines.append(" ".join(line))
                line = [word]
            else:
                line.append(word)
        lines.append(" ".join(line))
        return lines
    lines = greedy(width)
    while True:
        width -= 8
        tighter = greedy(width)
        if len(tighter) > len(lines):
            return lines
        lines = tighter


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def shadowed(canvas, im, xy, blur, alpha):
    shadow = Image.new("RGBA", (im.width + blur * 4, im.height + blur * 4), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (blur * 2, blur * 2, blur * 2 + im.width, blur * 2 + im.height), 12, fill=(0, 0, 0, alpha))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow, (xy[0] - blur * 2, xy[1] - blur * 2 + blur // 2))
    canvas.alpha_composite(im, xy)


def load(raw, s, crop=None):
    im = Image.open(SHOTS / raw).convert("RGBA")
    if crop:
        im = im.crop((0, 0, im.width, crop * s))
    return im


def anchor_right(im, s):
    """Crop so the rightmost menubar icon (the clock ring, the brightest
    thing at the right end of the bar) ends the same distance from the edge
    in every strip. A ⇧⌘4 drag never stops on the same pixel twice."""
    px = im.convert("L").load()
    bar = min(im.height, 32 * s)
    for x in range(im.width - 1, -1, -1):
        if any(px[x, y] > 170 for y in range(4 * s, bar - 4 * s)):
            right = x + 1 + 12 * s
            if right > im.width:  # tight capture: extend the bar from its last column
                wide = Image.new("RGBA", (right, im.height))
                wide.paste(im, (0, 0))
                wide.paste(im.crop((im.width - 1, 0, im.width, im.height)).resize((right - im.width, im.height)), (im.width, 0))
                return wide
            return im.crop((0, 0, right, im.height))
    return im


def equalize(ims, s):
    ims = [anchor_right(im, s) for im in ims]
    width = max(im.width for im in ims)
    out = []
    for im in ims:
        if im.width < width:
            padded = Image.new("RGBA", (width, im.height))
            padded.paste(im.crop((0, 0, 1, im.height)).resize((width - im.width, im.height)), (0, 0))
            padded.paste(im, (width - im.width, 0))
            im = padded
        out.append(im)
    return out


def place(raw, im, factor, s, avail):
    if factor == "fit":
        factor = min(1, avail / im.height)
    if factor != 1:
        im = im.resize((round(im.width * factor), round(im.height * factor)), Image.LANCZOS)
    return im if raw in PLAIN else rounded(im, 10 * s)


def render(name, spec, s):
    W, H = 1280 * s, 800 * s
    img = gradient((W, H), *GROUND).convert("RGBA")
    d = ImageDraw.Draw(img)
    margin = int(W * 0.06)

    eb_font = font(22 * s, "Semibold")
    y = int(H * 0.085)
    d.text((W // 2, y), spec["eyebrow"].upper(), font=eb_font, fill=EYEBROW, anchor="ms")
    hl_font = font(44 * s, "Bold")
    lines = wrap(d, spec["headline"], hl_font, W - 2 * margin)
    y += 20 * s
    for line in lines:
        y += 54 * s
        d.text((W // 2, y), line, font=hl_font, fill=HEADLINE, anchor="ms")
    top = y + 44 * s

    avail = H - top - int(H * 0.06)
    raws = [load(shot[0], s, *shot[2:]) for shot in spec["shots"]]
    if spec.get("uniform"):
        raws = equalize(raws, s)
    shots = [place(shot[0], im, shot[1], s, avail) for shot, im in zip(spec["shots"], raws)]
    plain = [im for im, shot in zip(shots, spec["shots"]) if shot[0] in PLAIN]
    gap = spec.get("gap", 28) * s
    block_h = sum(im.height for im in shots) + gap * (len(shots) - 1)
    if block_h > avail:  # never crop; a frame that does not fit is a spec error
        raise SystemExit(f"{name}: captures need {block_h}px, only {avail}px below the caption")
    y = top + (avail - block_h) // 2
    for im in shots:
        x = (W - im.width) // 2
        if any(im is p for p in plain):
            img.alpha_composite(im, (x, y))
        else:
            shadowed(img, im, (x, y), blur=8 * s, alpha=110)
        y += im.height + gap

    OUT.mkdir(exist_ok=True)
    img.convert("RGB").save(OUT / f"{name}.png", optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}/{name}.png {img.width}x{img.height}")


def strips(s):
    out = SHOTS / "strips"
    out.mkdir(exist_ok=True)
    ims = equalize([load(raw, s, 32) for raw in STRIPS], s)
    gap = 12 * s
    stack = Image.new("RGBA", (ims[0].width, sum(im.height for im in ims) + gap * (len(ims) - 1)))
    y = 0
    for raw, im in zip(STRIPS, ims):
        im = rounded(im, 6 * s)
        im.save(out / raw.replace("menubar-", ""), optimize=True)
        stack.alpha_composite(im, (0, y))
        y += im.height + gap
    stack.save(out / "personalities.png", optimize=True)
    print(f"wrote {out.relative_to(ROOT)}/ ({len(ims)} strips + personalities.png {stack.width}x{stack.height})")


def main(argv):
    wanted = argv[1:] or list(FRAMES)
    missing = sorted({shot[0] for spec in FRAMES.values() for shot in spec["shots"]
                      if not (SHOTS / shot[0]).exists()})
    if missing:
        raise SystemExit(f"no capture in {SHOTS.relative_to(ROOT)}/ for: {', '.join(missing)}")
    s = raw_scale()
    for name in wanted:
        if name not in FRAMES:
            raise SystemExit(f"unknown frame {name!r}; choose from {', '.join(FRAMES)}")
        render(name, FRAMES[name], s)
    if not argv[1:]:
        strips(s)


if __name__ == "__main__":
    main(sys.argv)

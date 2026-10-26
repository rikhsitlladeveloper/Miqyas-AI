#!/usr/bin/env python3
"""The App Store pictures: each raw iPhone screenshot from AppStoreShots.swift under a headline on METRX blue.

    python3 design/appstore/frame_shots.py <raw shots folder> [<out folder>] [--langs uz,ru,en]

For every language and every picture in captions.json (next to this file) it reads <raw>/<lang>-<shot>.png (the
1320 x 2868 shots of the 6.9-inch iPhone; the entry's fallback shots when that one is missing) and writes
<out>/<lang>/<n>-<name>.png, also 1320 x 2868: a blue gradient with a soft glow, the headline (white, bold, about 96 px,
at most two lines) and its subline (about 48 px, 85% white) at the top, and the screenshot below them at 84% of the
width with round corners and a soft shadow, running past the bottom edge. <out> is <raw>/final unless given.

Fonts are the app's own (ios-native/METRX/Fonts): Plus Jakarta Sans for Latin text, Manrope for Cyrillic (Plus Jakarta
Sans has no Cyrillic letters, as in the app). Needs Python 3 and Pillow only (pip install pillow). A missing shot is
reported and left out; the exit code is 1 only when no picture at all was made.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
FONTS = REPO / "ios-native" / "METRX" / "Fonts"

W, H = 1320, 2868
TOP = (0x35, 0x50, 0xE0)       # METRX blue
BOTTOM = (0x24, 0x33, 0xA8)    # deeper
GLOW = (0x8A, 0x9C, 0xFF)      # the lighter glow behind the text
SHOT_W = round(W * 0.84)
RADIUS = 60
TITLE_PX, SUB_PX = 96, 48
SIDE = 110                     # the text's side margin
TEXT_TOP = 120                 # the band the headline and subline are centred in
TEXT_BAND = 440
SHOT_TOP = TEXT_TOP + TEXT_BAND + 60


def font(cyrillic, weight, size):
    """The app's face for the text (Manrope for Cyrillic), else the first TTF in the fonts folder, else Pillow's own."""
    fam = "Manrope" if cyrillic else "PlusJakartaSans"
    for name in (f"{fam}-{weight}.ttf", f"{fam}-Bold.ttf", "Manrope-Bold.ttf"):
        p = FONTS / name
        if p.exists():
            return ImageFont.truetype(str(p), size)
    for p in sorted(FONTS.glob("*.ttf")):
        return ImageFont.truetype(str(p), size)
    return ImageFont.load_default(size)


def is_cyrillic(text):
    return any("Ѐ" <= c <= "ӿ" for c in text)


def wrap(draw, text, f, width):
    """Words in lines no wider than width (a lone long word stays whole)."""
    lines, cur = [], ""
    for word in text.split():
        t = (cur + " " + word).strip()
        if cur and draw.textlength(t, font=f) > width:
            lines.append(cur)
            cur = word
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def balanced(draw, text, f, width):
    """Two lines of about the same width instead of a long first line and an orphan word."""
    lines = wrap(draw, text, f, width)
    if len(lines) != 2:
        return lines
    words = text.split()

    def cost(a, b):
        # the wider line, and a short word (a preposition: "в", "и", "va") never left at the end of the first line
        return max(draw.textlength(a, font=f), draw.textlength(b, font=f)) + (10_000 if len(a.split()[-1]) <= 2 else 0)

    best = lines
    best_c = cost(*lines)
    for i in range(1, len(words)):
        a, b = " ".join(words[:i]), " ".join(words[i:])
        if max(draw.textlength(a, font=f), draw.textlength(b, font=f)) <= width and cost(a, b) < best_c:
            best, best_c = [a, b], cost(a, b)
    return best


def fit(draw, text, cyrillic, weight, size, width, max_lines):
    """The font and lines for text: size made smaller until it fits in max_lines."""
    while True:
        f = font(cyrillic, weight, size)
        lines = balanced(draw, text, f, width)
        too_wide = any(draw.textlength(s, font=f) > width for s in lines)
        if (len(lines) <= max_lines and not too_wide) or size <= 40:
            return f, lines[:max_lines] if len(lines) > max_lines else lines
        size -= 4


def background():
    """The blue gradient (a little diagonal) with a soft lighter glow behind the text and a faint one lower down."""
    # vertical ramp, then a gentle sideways tilt
    ramp = Image.linear_gradient("L").resize((W, H))
    tilt = Image.linear_gradient("L").rotate(90, expand=True).resize((W, H))
    mask = ImageChops.add(ramp.point(lambda v: v * 0.85), tilt.point(lambda v: (255 - v) * 0.15))
    bg = Image.composite(Image.new("RGB", (W, H), BOTTOM), Image.new("RGB", (W, H), TOP), mask)
    glow = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(glow)
    d.ellipse((W * 0.5 - 760, -420, W * 0.5 + 760, 900), fill=150)
    d.ellipse((W * 0.62 - 600, H * 0.55 - 520, W * 0.62 + 600, H * 0.55 + 520), fill=55)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    return Image.composite(Image.new("RGB", (W, H), GLOW), bg, glow)


def rounded_mask(size, r):
    m = Image.new("L", (size[0] * 2, size[1] * 2), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, m.width - 1, m.height - 1), radius=r * 2, fill=255)
    return m.resize(size, Image.LANCZOS)


def compose(raw_path, title, sub):
    canvas = background().convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    width = W - 2 * SIDE

    # the headline and its subline, centred
    cyr = is_cyrillic(title + sub)
    tf, tlines = fit(draw, title, cyr, "ExtraBold", TITLE_PX, width, 2)
    sf, slines = fit(draw, sub, cyr, "Medium", SUB_PX, width, 2)
    # the text block is centred in its band, so every picture's screenshot starts at the same height
    t_step, gap, s_step = round(tf.size * 1.14), round(sf.size * 0.75), round(sf.size * 1.34)
    block = t_step * len(tlines) + gap + s_step * len(slines)
    y = TEXT_TOP + max(0, (TEXT_BAND - block) // 2)
    for line in tlines:
        draw.text((W / 2, y), line, font=tf, fill=(255, 255, 255, 255), anchor="ma")
        y += t_step
    y += gap
    for line in slines:
        draw.text((W / 2, y), line, font=sf, fill=(255, 255, 255, 217), anchor="ma")
        y += s_step
    text_bottom = y

    # the screenshot, 84% of the width, round corners, a soft shadow; past the bottom edge when it is longer
    shot = Image.open(raw_path).convert("RGB")
    sh = round(shot.height * SHOT_W / shot.width)
    shot = shot.resize((SHOT_W, sh), Image.LANCZOS)
    x0 = (W - SHOT_W) // 2
    y0 = max(text_bottom + 50, SHOT_TOP)
    mask = rounded_mask((SHOT_W, sh), RADIUS)

    shadow = Image.new("L", (W, H + 400), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x0, y0 + 34, x0 + SHOT_W, y0 + sh + 34), radius=RADIUS, fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(50)).crop((0, 0, W, H))
    dark = Image.new("RGBA", (W, H), (10, 16, 70, 255))
    canvas = Image.composite(dark, canvas, shadow)

    # a hairline of light round the screenshot, so it stands off the blue
    rim = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    ImageDraw.Draw(rim).rounded_rectangle((x0 - 3, y0 - 3, x0 + SHOT_W + 2, y0 + sh + 2), radius=RADIUS + 3,
                                          fill=(255, 255, 255, 70))
    canvas.alpha_composite(rim)
    visible = min(sh, H - y0)
    canvas.paste(shot.crop((0, 0, SHOT_W, visible)), (x0, y0), mask.crop((0, 0, SHOT_W, visible)))
    return canvas.convert("RGB")


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    langs = ["uz", "ru", "en"]
    for i, a in enumerate(argv):
        if a == "--langs" and i + 1 < len(argv):
            langs = [s for s in argv[i + 1].split(",") if s]
            args = [x for x in args if x != argv[i + 1]]
    if not args:
        print(__doc__)
        return 2
    raw = Path(args[0])
    out = Path(args[1]) if len(args) > 1 else raw / "final"
    spec = json.loads((HERE / "captions.json").read_text(encoding="utf-8"))
    made, missing = 0, []
    for lang in langs:
        for e in spec["shots"]:
            cap = e.get(lang)
            if not cap:
                missing.append(f"{lang}: no caption for {e['name']}")
                continue
            src = next((raw / f"{lang}-{s}.png" for s in [e["raw"], *e.get("fallback", [])]
                        if (raw / f"{lang}-{s}.png").exists()), None)
            if src is None:
                missing.append(f"{lang}-{e['raw']}.png")
                continue
            if src.name != f"{lang}-{e['raw']}.png":
                print(f"  {lang} {e['n']}-{e['name']}: {lang}-{e['raw']}.png missing, made from {src.name}")
            dst = out / lang / f"{e['n']}-{e['name']}.png"
            dst.parent.mkdir(parents=True, exist_ok=True)
            compose(src, cap["title"], cap["sub"]).save(dst, optimize=True)
            made += 1
            print(f"  {dst}")
    print(f"{made} App Store pictures in {out}")
    for m in missing:
        print(f"  missing: {m}")
    return 0 if made else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

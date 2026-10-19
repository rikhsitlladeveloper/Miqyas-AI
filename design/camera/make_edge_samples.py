"""Draws the edge-finder test photos (the same scenes as design/camera/edge-measure-mockup.html) into the Android
test resources, where the iPhone tests read them too. Run: python design/camera/make_edge_samples.py"""
import os
import numpy as np
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "android-native", "app", "src", "test", "resources", "edges")
os.makedirs(OUT, exist_ok=True)


def vgrad(d, box, c0, c1):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        d.line([(x0, y), (x1 - 1, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(c0, c1)))


def hgrad(d, box, c0, c1):
    x0, y0, x1, y1 = box
    for x in range(x0, x1):
        t = (x - x0) / max(1, x1 - x0 - 1)
        d.line([(x, y0), (x, y1 - 1)], fill=tuple(int(a + (b - a) * t) for a, b in zip(c0, c1)))


def grain(im, amount, seed):
    a = np.asarray(im).astype(np.float32)
    n = (np.random.default_rng(seed).random(a.shape[:2]) - .5) * amount
    a += n[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def hexc(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def table():
    im = Image.new("RGB", (1200, 900)); d = ImageDraw.Draw(im)
    vgrad(d, (0, 0, 1200, 560), hexc("D9D3C8"), hexc("C9C2B5"))
    vgrad(d, (0, 560, 1200, 900), hexc("8C6E52"), hexc("6F5641"))
    d.rectangle([0, 540, 1199, 561], fill=hexc("EFEBE4"))
    for x in range(-200, 1200, 150): d.line([(x + 260, 562), (x - 60, 900)], fill=(110, 85, 62), width=2)
    d.polygon([(880, 110), (1100, 110), (1100, 330), (880, 330)], fill=hexc("B9B2A5"))
    d.polygon([(896, 126), (1084, 126), (1084, 314), (896, 314)], fill=hexc("7E9AB2"))
    d.ellipse([180, 710, 1040, 830], fill=(95, 74, 55))
    d.polygon([(250, 470), (930, 450), (1040, 600), (170, 630)], fill=hexc("CDAB80"))
    d.polygon([(170, 630), (1040, 600), (1040, 640), (170, 672)], fill=hexc("8F6B47"))
    for i, (x, y, x2) in enumerate([(200, 672, 232), (990, 640, 1020), (300, 628, 322), (880, 606, 902)]):
        d.polygon([(x, y), (x2, y - 1), (x2, 850 if i < 2 else 760), (x, 850 if i < 2 else 760)], fill=hexc("7A5A3C") if i < 2 else hexc("6A4E35"))
    d.ellipse([514, 504, 606, 536], fill=hexc("F4F4F2")); d.rectangle([514, 470, 606, 520], fill=hexc("F4F4F2"))
    d.ellipse([514, 454, 606, 486], fill=hexc("E4E4E0"))
    return grain(im, 14, 7)


def door():
    im = Image.new("RGB", (900, 1200)); d = ImageDraw.Draw(im)
    hgrad(d, (0, 0, 900, 1200), hexc("D4D7D2"), hexc("C5C9C3"))
    d.rectangle([0, 1020, 899, 1199], fill=hexc("9C8B78")); d.rectangle([0, 1000, 899, 1021], fill=hexc("ECEDEA"))
    d.rectangle([250, 160, 649, 1009], fill=hexc("F2F0EB"))
    vgrad(d, (282, 192, 618, 1010), hexc("8E6A48"), hexc("7A583A"))
    for a, b, c, e in [(318, 240, 582, 560), (318, 610, 582, 950)]:
        d.rectangle([a, b, c - 1, e - 1], fill=(115, 87, 61)); d.rectangle([a + 8, b + 8, c - 9, e - 9], fill=(125, 96, 69))
    d.rectangle([570, 600, 599, 607], fill=hexc("D9D9D6")); d.ellipse([566, 595, 584, 613], fill=hexc("D9D9D6"))
    d.rectangle([720, 560, 789, 639], fill=hexc("F6F6F4")); d.rectangle([742, 584, 767, 615], fill=hexc("E2E2DE"))
    return grain(im, 12, 11)


def wall():
    y, x = np.mgrid[0:900, 0:1200]
    r = np.clip(np.hypot(x - 400, y - 300) / 900, 0, 1)[..., None]
    a = np.array(hexc("F7F6F3")) * (1 - r) + np.array(hexc("E6E4DF")) * r
    return grain(Image.fromarray(a.astype(np.uint8)), 10, 3)


for name, f in [("table", table), ("door", door), ("wall", wall)]:
    f().save(os.path.join(OUT, name + ".jpg"), quality=90)   # photos come to the app as JPEG too
    print("wrote", name)

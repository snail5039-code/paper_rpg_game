"""죽음·부활 효과 소품(fx_die_*)을 그림 대신 코드로 그린다. ChatGPT 시트(106_die_fx)를 받으면 tools/import_ui_v7.py 106_die_fx 로 덮어쓴다.

  python tools/make_die_fx.py
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprites import sprite_path  # noqa: E402

INK = (60, 44, 40, 255)
PINK = (244, 172, 184, 255)
WHITE = (255, 248, 240, 255)
YELLOW = (255, 214, 72, 255)
GOLD = (255, 190, 60, 255)
GRAY = (150, 148, 156, 255)
Q = 4  # 크게 그린 뒤 줄여 부드럽게


def canvas(n):
    return Image.new("RGBA", (n * Q, n * Q), (0, 0, 0, 0))


def done(im, name, n):
    out = im.resize((n, n), Image.LANCZOS)
    out.save(sprite_path(name))
    print(name, out.size)


def blob(d, cx, cy, r, fill, outline=INK, w=3):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill, outline=outline, width=w * Q // 2)


def crumbs(stage, rng):
    n = 128
    im = canvas(n)
    d = ImageDraw.Draw(im)
    c = n * Q // 2
    count = [7, 11, 12, 6][stage]
    spread = [0.12, 0.30, 0.44, 0.48][stage]
    size = [0.07, 0.065, 0.05, 0.035][stage]
    for i in range(count):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.35, 1.0) * spread * n * Q
        x, y = c + math.cos(a) * r, c + math.sin(a) * r * 0.85
        s = rng.uniform(0.7, 1.2) * size * n * Q
        col = PINK if i % 3 else WHITE
        if i % 2:
            blob(d, x, y, s, col)
        else:
            d.rounded_rectangle((x - s, y - s * 0.7, x + s, y + s * 0.7), radius=int(s * 0.4), fill=col, outline=INK, width=2 * Q // 2)
    if stage == 0:
        blob(d, c, c, 0.10 * n * Q, WHITE)
    return im


def ink(rng):
    n = 128
    im = canvas(n)
    d = ImageDraw.Draw(im)
    c = n * Q // 2
    pts = []
    for i in range(24):
        a = i / 24 * math.tau
        r = (0.40 + rng.uniform(-0.06, 0.10)) * n * Q
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r * 0.5))
    d.polygon(pts, fill=(48, 36, 40, 235))
    for _ in range(5):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.42, 0.55) * n * Q
        blob(d, c + math.cos(a) * r, c + math.sin(a) * r * 0.5, rng.uniform(0.02, 0.04) * n * Q, (48, 36, 40, 235), (48, 36, 40, 0), 0)
    return im


def paper():
    n = 64
    im = canvas(n)
    d = ImageDraw.Draw(im)
    pts = [(0.18, 0.25), (0.55, 0.12), (0.88, 0.38), (0.72, 0.85), (0.30, 0.78), (0.12, 0.52)]
    pts = [(x * n * Q, y * n * Q) for x, y in pts]
    d.polygon(pts, fill=(255, 252, 240, 255), outline=INK)
    d.line(pts + [pts[0]], fill=INK, width=3 * Q // 2)
    for k in range(3):
        y = (0.35 + k * 0.17) * n * Q
        d.line((0.28 * n * Q, y, 0.74 * n * Q, y + 3 * Q), fill=(130, 170, 220, 255), width=Q)
    d.line((0.5 * n * Q, 0.12 * n * Q, 0.46 * n * Q, 0.8 * n * Q), fill=(190, 186, 176, 255), width=Q)
    return im


def star(n=96):
    im = canvas(n)
    d = ImageDraw.Draw(im)
    c = n * Q / 2
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = (0.46 if i % 2 == 0 else 0.20) * n * Q
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(pts, fill=YELLOW, outline=INK)
    d.line(pts + [pts[0]], fill=INK, width=3 * Q // 2)
    return im


def smoke(rng):
    n = 128
    im = canvas(n)
    d = ImageDraw.Draw(im)
    c = n * Q // 2
    for i in range(9):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.22) * n * Q
        blob(d, c + math.cos(a) * r, c + math.sin(a) * r, rng.uniform(0.12, 0.2) * n * Q, (170, 168, 176, 235), INK, 2)
    for i in range(3):
        d.arc((c - (0.2 + i * 0.07) * n * Q, c - (0.18 + i * 0.07) * n * Q, c + (0.2 + i * 0.07) * n * Q, c + (0.22 + i * 0.07) * n * Q),
              rng.uniform(0, 200), rng.uniform(220, 360), fill=INK, width=Q)
    return im


def rub():
    n = 128
    im = Image.new("RGBA", (n * Q, n * Q // 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    h = n * Q // 2
    d.ellipse((0.04 * n * Q, 0.1 * h, 0.96 * n * Q, 0.9 * h), fill=(255, 255, 255, 120))
    for i in range(7):
        y = (0.2 + i * 0.1) * h
        d.line((0.12 * n * Q, y, 0.88 * n * Q, y + 0.08 * h), fill=(255, 255, 255, 235), width=3 * Q // 2)
    return im.resize((n * Q, n * Q), Image.NEAREST) if False else _square(im)


def _square(im):
    out = Image.new("RGBA", (im.width, im.width), (0, 0, 0, 0))
    out.paste(im, (0, (im.width - im.height) // 2))
    return out


def dust(rng):
    n = 128
    im = canvas(n)
    d = ImageDraw.Draw(im)
    c = n * Q // 2
    for i in range(8):
        a = i / 8 * math.tau
        blob(d, c + math.cos(a) * 0.22 * n * Q, c + math.sin(a) * 0.15 * n * Q + 0.08 * n * Q, rng.uniform(0.11, 0.16) * n * Q, WHITE, (170, 164, 170, 255), 2)
    blob(d, c, c + 0.02 * n * Q, 0.2 * n * Q, WHITE, (170, 164, 170, 255), 2)
    return im


def glint(n=96):
    im = canvas(n)
    d = ImageDraw.Draw(im)
    c = n * Q / 2
    for ang, ln in ((0, 0.46), (math.pi / 2, 0.46), (math.pi / 4, 0.28), (-math.pi / 4, 0.28)):
        dx, dy = math.cos(ang) * ln * n * Q, math.sin(ang) * ln * n * Q
        d.line((c - dx, c - dy, c + dx, c + dy), fill=INK, width=7 * Q // 2)
        d.line((c - dx, c - dy, c + dx, c + dy), fill=GOLD, width=4 * Q // 2)
    blob(d, c, c, 0.07 * n * Q, WHITE, INK, 2)
    return im


def ring(n=160):
    im = canvas(n)
    d = ImageDraw.Draw(im)
    c = n * Q / 2
    r = 0.42 * n * Q
    for w, col in ((9, INK), (6, YELLOW)):
        d.ellipse((c - r, c - r, c + r, c + r), outline=col, width=w * Q // 2)
    return im


def main():
    rng = random.Random(7)
    for i in range(4):
        done(crumbs(i, rng), "fx_die_%d" % i, 128)
    done(ink(rng), "fx_die_ink", 128)
    done(paper(), "fx_die_paper", 64)
    done(star(), "fx_die_star", 96)
    done(smoke(rng), "fx_die_smoke", 128)
    done(rub(), "fx_die_rub", 128)
    done(dust(rng), "fx_die_dust", 128)
    done(glint(), "fx_die_glint", 96)
    done(ring(), "fx_die_ring", 160)


if __name__ == "__main__":
    main()

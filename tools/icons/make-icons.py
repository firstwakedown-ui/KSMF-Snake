#!/usr/bin/env python
# Generátor PWA ikon pro AchtungDieKM.
# Motiv: tmavé pozadí (#0d1117, ladí s tématem) + modrá "stopa" (snake trail)
# zatáčející k vlaječce u cíle (motiv startovního bodu).
#
# Proč skript (a ne hotové PNG od designera): na vývojovém stroji není sharp ani
# ImageMagick; Pillow je nejjednodušší reprodukovatelná cesta. Spustí se:
#     python -m pip install pillow
#     python tools/icons/make-icons.py
# Výstup jde rovnou do app/public/ (pwa-192/512, maskable, apple-touch, favicon).
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "app", "public"))

BG_TOP = (27, 35, 48)      # #1b2330 (světlejší navy nahoře)
BG_BOT = (13, 17, 23)      # #0d1117 (téma)
BLUE = (31, 111, 235)      # #1f6feb hráčská modrá
BLUE_L = (88, 166, 255)    # #58a6ff
GREEN = (46, 160, 67)      # #2ea043 druhá stopa (náznak multiplayeru)
RED = (229, 72, 77)        # #e5484d vlajka
WHITE = (255, 255, 255)

SS = 4  # supersampling kvůli antialiasingu


def vgrad(size, top, bot):
    img = Image.new("RGB", (1, size), top)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        px[0, y] = tuple(round(top[i] * (1 - t) + bot[i] * t) for i in range(3))
    return img.resize((size, size))


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def thick_path(draw, pts, width, color):
    draw.line(pts, fill=color, width=width, joint="curve")
    r = width // 2
    for (x, y) in (pts[0], pts[-1]):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def draw_content(draw, S, margin):
    def m(x, y):
        span = S - 2 * margin
        return (margin + x * span, margin + y * span)

    # Druhá (zelená) stopa – decentní, vzadu.
    g = [m(0.10, 0.62), m(0.30, 0.70), m(0.42, 0.52), m(0.60, 0.58)]
    thick_path(draw, g, int(0.085 * S), GREEN)

    # Hlavní modrá stopa: zdola-zleva klikatě nahoru k vlajce.
    trail = [m(0.16, 0.90), m(0.30, 0.74), m(0.20, 0.56),
             m(0.40, 0.46), m(0.62, 0.52), m(0.66, 0.30)]
    thick_path(draw, trail, int(0.11 * S), BLUE)
    thick_path(draw, trail, int(0.04 * S), BLUE_L)  # světlejší zvýraznění navrch

    # Vlaječka na špičce stopy.
    tipx, tipy = trail[-1]
    pole_top = (tipx, tipy - 0.26 * S)
    draw.line([(tipx, tipy), pole_top], fill=WHITE, width=int(0.022 * S))
    fx, fy = pole_top
    draw.polygon([(fx, fy), (fx + 0.20 * S, fy + 0.055 * S), (fx, fy + 0.11 * S)], fill=RED)
    r = int(0.03 * S)
    draw.ellipse([tipx - r, tipy - r, tipx + r, tipy + r], fill=WHITE)


def make(size, margin_frac, rounded, opaque_bg):
    S = size * SS
    base = vgrad(S, BG_TOP, BG_BOT).convert("RGBA")
    overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_content(ImageDraw.Draw(overlay), S, int(margin_frac * S))
    img = Image.alpha_composite(base, overlay)
    if rounded:
        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        out.paste(img, (0, 0), rounded_mask(S, int(0.22 * S)))
        img = out
    elif opaque_bg:
        img = img.convert("RGB").convert("RGBA")
    return img.resize((size, size), Image.LANCZOS)


def save(img, name):
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


if __name__ == "__main__":
    save(make(512, 0.16, rounded=True, opaque_bg=False), "pwa-512x512.png")
    save(make(192, 0.16, rounded=True, opaque_bg=False), "pwa-192x192.png")
    save(make(512, 0.26, rounded=False, opaque_bg=True), "pwa-maskable-512x512.png")
    save(make(180, 0.16, rounded=False, opaque_bg=True), "apple-touch-icon.png")
    save(make(48, 0.12, rounded=True, opaque_bg=False), "favicon.png")
    print("done ->", OUT)

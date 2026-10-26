"""Generates the Dirito launcher icons. Run: python tool/make_icon.py (needs Pillow)."""
import os
from PIL import Image, ImageDraw, ImageFont

S = 1024
TOP = (187, 63, 221)      # Pallete.gradient1
BOTTOM = (251, 109, 169)  # Pallete.gradient2
WHITE = (255, 255, 255)
FONT = "C:/Windows/Fonts/ariblk.ttf"


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
    return img


def note(draw, x, y, r, color, stem_w, stem_h, flag=True):
    """Eighth note with head centred at (x, y)."""
    draw.ellipse((x - r * 1.2, y - r * 0.9, x + r * 1.2, y + r * 0.9), fill=color)
    sx = x + r * 1.2 - stem_w
    draw.rectangle((sx, y - stem_h, sx + stem_w, y), fill=color)
    if flag:
        draw.polygon(
            [(sx + stem_w, y - stem_h), (sx + stem_w + r * 1.6, y - stem_h + r * 1.6),
             (sx + stem_w + r * 1.2, y - stem_h + r * 3.0), (sx + stem_w, y - stem_h + r * 1.8)],
            fill=color,
        )


def build_foreground():
    """Transparent layer with a custom-drawn D whose opening holds a beamed pair of notes."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # D = stem + half-ring. Outer box then a smaller counter punched out.
    x0, y0, x1, y1 = 230, 215, 800, 810
    t = 125  # stroke thickness
    mid = (x0 + x1) // 2 - 40  # where the straight top/bottom meet the curve
    r_out = (y1 - y0) / 2
    d.rectangle((x0, y0, mid, y1), fill=WHITE)
    d.pieslice((x1 - 2 * r_out, y0, x1, y1), -90, 90, fill=WHITE)
    d.rectangle((mid, y0, x1 - r_out, y1), fill=WHITE)

    cx0, cy0, cy1 = x0 + t, y0 + t, y1 - t
    r_in = (cy1 - cy0) / 2
    cx1 = x1 - t
    hole = Image.new("L", (S, S), 0)
    h = ImageDraw.Draw(hole)
    h.rectangle((cx0, cy0, cx1 - r_in, cy1), fill=255)
    h.pieslice((cx1 - 2 * r_in, cy0, cx1, cy1), -90, 90, fill=255)
    alpha = layer.getchannel("A")
    alpha = Image.composite(Image.new("L", (S, S), 0), alpha, hole)
    layer.putalpha(alpha)
    d = ImageDraw.Draw(layer)

    # Beamed pair of eighth notes centred in the opening
    ccx, ccy = (cx0 + cx1) / 2 - 18, (cy0 + cy1) / 2
    r, sw, sh = 38, 15, 175
    gap = 120
    xa, xb = ccx - gap / 2, ccx + gap / 2
    hy = ccy + 85
    for x in (xa, xb):
        d.ellipse((x - r * 1.2, hy - r * 0.9, x + r * 1.2, hy + r * 0.9), fill=WHITE)
        d.rectangle((x + r * 1.2 - sw, hy - sh, x + r * 1.2, hy), fill=WHITE)
    left, right = xa + r * 1.2 - sw, xb + r * 1.2
    top = hy - sh
    d.polygon([(left, top), (right, top - 34), (right, top + 30), (left, top + 64)], fill=WHITE)

    # Small accent note, top right
    note(d, x1 + 62, y0 + 55, 24, WHITE, 10, 125)
    return layer


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=255)
    return m


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    fg = build_foreground()
    bg = gradient(S)

    full = bg.convert("RGBA")
    full.alpha_composite(fg)
    legacy = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    legacy.paste(full, (0, 0), rounded_mask(S, 230))

    os.makedirs(os.path.join(root, "assets", "icon"), exist_ok=True)
    legacy.save(os.path.join(root, "assets", "icon", "dirito_icon.png"))

    res = os.path.join(root, "android", "app", "src", "main", "res")
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        legacy.resize((px, px), Image.LANCZOS).save(os.path.join(res, f"mipmap-{name}", "ic_launcher.png"))

    # Adaptive icon (Android 8+): 108dp canvas, content scaled into the central safe zone
    for name, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        inner = int(px * 0.62)
        canvas.alpha_composite(fg.resize((inner, inner), Image.LANCZOS), ((px - inner) // 2, (px - inner) // 2))
        canvas.save(os.path.join(res, f"mipmap-{name}", "ic_launcher_foreground.png"))
    print("done")


if __name__ == "__main__":
    main()

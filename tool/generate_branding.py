#!/usr/bin/env python3
"""
Decant — brand image generator (launcher icon, adaptive foreground, splash logo).

Renders a dimensional Decant mark — a glowing glass test tube with a luminous
teal liquid level and meniscus, topped by a polished droplet — on the app's
dark twilight gradient. Re-run after tweaking:

    python3 tool/generate_branding.py

Outputs (branding/):
    decant_icon.png        1024  twilight gradient + glowing mark   (launcher icon)
    decant_foreground.png  1024  transparent mark (adaptive safe zone)
    decant_splash.png      1024  transparent mark (native splash logo)
"""
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "branding")

# Brand colors (match lib/ui/theme/app_theme.dart).
ACCENT = (0x49, 0xD6, 0xC3)
ACCENT_DEEP = (0x2B, 0xB6, 0xA6)
BG_TOP = (0x1B, 0x24, 0x40)
BG_BOT = (0x2E, 0x21, 0x50)
WHITE = (255, 255, 255)

SS = 2  # supersample factor for the mark


def _mix(c0, c1, t):
    return tuple(int(round(c0[i] + (c1[i] - c0[i]) * t)) for i in range(3))


def vertical_gradient(w, h, c0, c1):
    """Vertical top→bottom gradient (RGBA, opaque). Pure Pillow — no numpy."""
    strip = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        strip.putpixel((0, y), (
            round(c0[0] + (c1[0] - c0[0]) * t),
            round(c0[1] + (c1[1] - c0[1]) * t),
            round(c0[2] + (c1[2] - c0[2]) * t),
            255,
        ))
    return strip.resize((w, h))


def draw_mark(size, scale):
    """Render the colored, dimensional mark centered on a transparent layer."""
    n = size * SS
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))

    cx = n / 2
    h = n * scale
    top = (n - h) / 2

    tube_w = 0.30 * h
    tube_top = top + 0.46 * h
    tube_bottom = top + h
    left, right = cx - tube_w / 2, cx + tube_w / 2
    rr = [left, tube_top, right, tube_bottom]
    corners = (False, False, True, True)
    rad = tube_w * 0.46  # just under half-width (== half breaks PIL's outline)
    lw = max(2, int(n * 0.013))

    # 1) Soft teal halo behind the liquid. Kept tight so that even after the
    #    Gaussian blur it stays well inside the canvas — otherwise the blurred
    #    glow clips against the bottom edge and looks like the logo is cropped.
    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cy_tube = (tube_top + tube_bottom) / 2
    gd.ellipse(
        [cx - tube_w * 1.5, cy_tube - tube_w * 1.2,
         cx + tube_w * 1.5, tube_bottom + tube_w * 0.3],
        fill=ACCENT + (130,),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.018))
    layer.alpha_composite(glow)

    # 2) Translucent glass body.
    body = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle(
        rr, radius=rad, corners=corners, fill=(255, 255, 255, 46))
    layer.alpha_composite(body)

    # 3) Luminous liquid (gradient) clipped to the tube's lower portion.
    liquid_top = tube_top + (tube_bottom - tube_top) * 0.40
    mask = Image.new("L", (n, n), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle(rr, radius=rad, corners=corners, fill=255)
    md.rectangle([0, 0, n, int(liquid_top)], fill=0)
    layer.paste(vertical_gradient(n, n, _mix(ACCENT, WHITE, 0.10), ACCENT_DEEP),
                (0, 0), mask)

    dl = ImageDraw.Draw(layer)
    # meniscus — bright glossy surface ellipse
    md_h = tube_w * 0.18
    dl.ellipse([left, liquid_top - md_h, right, liquid_top + md_h],
               fill=_mix(ACCENT, WHITE, 0.55) + (235,))

    # 4) Glass detailing: outline, vertical highlight, mouth rim.
    dl.rounded_rectangle(rr, radius=rad, corners=corners,
                         outline=WHITE + (255,), width=lw)
    stripe = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(stripe).rounded_rectangle(
        [left + tube_w * 0.20, tube_top + tube_w * 0.55,
         left + tube_w * 0.36, tube_bottom - tube_w * 0.70],
        radius=tube_w * 0.1, fill=(255, 255, 255, 150))
    layer.alpha_composite(stripe.filter(ImageFilter.GaussianBlur(n * 0.004)))
    # open mouth rim (ellipse outline)
    dl.ellipse([left, tube_top - tube_w * 0.16, right, tube_top + tube_w * 0.16],
               outline=WHITE + (255,), width=lw)

    # 5) Droplet floating above, with specular highlight.
    r = 0.105 * h
    tip_y = top + 0.02 * h
    ccy = tip_y + 0.15 * h + r
    drop_mask = Image.new("L", (n, n), 0)
    dmd = ImageDraw.Draw(drop_mask)
    dmd.ellipse([cx - r, ccy - r, cx + r, ccy + r], fill=255)
    dmd.polygon([(cx, tip_y), (cx - r * 0.72, ccy - r * 0.30),
                 (cx + r * 0.72, ccy - r * 0.30)], fill=255)
    layer.paste(vertical_gradient(n, n, _mix(ACCENT, WHITE, 0.30), ACCENT_DEEP),
                (0, 0), drop_mask)
    # thin rim + specular dot + bottom shade for volume
    dl.ellipse([cx - r, ccy - r, cx + r, ccy + r],
               outline=WHITE + (180,), width=max(1, int(lw * 0.5)))
    dl.ellipse([cx - r * 0.55, ccy - r * 0.55, cx - r * 0.05, ccy - r * 0.05],
               fill=(255, 255, 255, 205))

    return layer.resize((size, size), Image.LANCZOS)


def make_icon():
    n = 1024
    img = vertical_gradient(n, n, BG_TOP, BG_BOT)
    # gentle radial lift behind the mark
    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [n * 0.30, n * 0.26, n * 0.70, n * 0.74], fill=ACCENT + (60,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(n * 0.08)))
    # soft drop shadow under the mark
    shadow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [n * 0.34, n * 0.78, n * 0.66, n * 0.86], fill=(0, 0, 0, 120))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(n * 0.02)))
    img.alpha_composite(draw_mark(n, scale=0.60))
    return img.convert("RGBA")


def make_foreground():
    n = 1024
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    img.alpha_composite(draw_mark(n, scale=0.48))  # adaptive safe zone
    return img


def make_splash():
    n = 1024
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    img.alpha_composite(draw_mark(n, scale=0.58))  # extra padding so nothing clips
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    make_icon().save(os.path.join(OUT, "decant_icon.png"))
    make_foreground().save(os.path.join(OUT, "decant_foreground.png"))
    make_splash().save(os.path.join(OUT, "decant_splash.png"))
    print("Wrote branding PNGs ->", os.path.abspath(OUT))
    for f in ("decant_icon.png", "decant_foreground.png", "decant_splash.png"):
        p = os.path.join(OUT, f)
        print(f"  {f:24s} {os.path.getsize(p)//1024:4d} KB")


if __name__ == "__main__":
    main()

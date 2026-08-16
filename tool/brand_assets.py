#!/usr/bin/env python3
"""Regenerate every derived BudgetSense brand asset from the source masters.

The masters in ``assets/branding`` are the only hand-authored artwork. Everything
this script writes is disposable and reproducible, so never edit a generated file
by hand: change the recipe here and re-run.

    python3 -m venv /tmp/bsimg && /tmp/bsimg/bin/pip install Pillow numpy
    /tmp/bsimg/bin/python tool/brand_assets.py

Pillow is a build-time tool only. It is deliberately not a dependency of the app
or the documentation site.

Outputs
    assets/branding/derived/     shared derived masters (a subset ships in the app)
    android/app/src/main/res/    launcher, splash and notification resources
    docs/assets/brand/           documentation-site and social artwork

Two ideas keep the asset count low. First, single-colour artwork ships as an
*alpha mask*: the dry-brush texture lives entirely in the alpha channel, so one
file can be tinted to any theme colour at runtime and stays correct in light and
dark without a second copy. Second, only the two-colour ensō logos (espresso ring
with a terracotta dot, and its cream counterpart) ship as real light/dark pairs,
because tinting would destroy the two-colour relationship.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

Image.MAX_IMAGE_PIXELS = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "branding")
DERIVED = os.path.join(SRC, "derived")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
WEB = os.path.join(ROOT, "docs", "assets", "brand")

CREAM = (0xEF, 0xE7, 0xD6)
ESPRESSO = (0x26, 0x22, 0x19)
TERRACOTTA = (0xB0, 0x7C, 0x5E)
SAND = (0xD9, 0xC6, 0xA8)

# Launcher background. Sampled from the light app-icon master rather than the
# flat brand cream so the icon matches the artwork it was cut from.
ICON_BG = (0xF5, 0xEA, 0xD1)

# Fraction of the canvas left empty around a standalone mark. The brand guide
# asks for 12-18%; 14% reads as generous without shrinking the mark.
SAFE = 0.14

# Android adaptive icons reserve the inner 66 of 108dp. Sitting the mark at 56%
# of the canvas keeps every brush fibre clear of the most aggressive mask.
ADAPTIVE_SAFE = 0.56

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def load(name: str) -> Image.Image:
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def visible_bbox(im: Image.Image, threshold: int = 10) -> tuple[int, int, int, int]:
    """Bounding box of pixels with meaningful alpha."""
    a = np.asarray(im)[..., 3]
    ys, xs = np.where(a > threshold)
    if not len(xs):
        return (0, 0, im.size[0], im.size[1])
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def trim(im: Image.Image) -> Image.Image:
    return im.crop(visible_bbox(im))


def square_with_margin(im: Image.Image, size: int, safe: float = SAFE) -> Image.Image:
    """Centre a trimmed mark on a transparent square, preserving aspect ratio."""
    art = trim(im)
    inner = max(1, int(round(size * (1 - 2 * safe))))
    art = contain(art, inner)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(art, ((size - art.size[0]) // 2, (size - art.size[1]) // 2))
    return out


def contain(im: Image.Image, box: int) -> Image.Image:
    """Scale to fit a box without distortion."""
    w, h = im.size
    s = min(box / w, box / h)
    return im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


def to_mask(im: Image.Image, rgb=ESPRESSO) -> Image.Image:
    """Flatten artwork to a tintable alpha mask.

    The RGB channels are replaced with a flat colour so the file still renders
    sensibly if drawn untinted; the shape and every dry-brush gradation survive
    untouched in the alpha channel.
    """
    a = np.asarray(im).copy()
    a[..., 0], a[..., 1], a[..., 2] = rgb
    return Image.fromarray(a, "RGBA")


def ink_alpha(im: Image.Image) -> Image.Image:
    """Derive a single-colour alpha mask from dark ink on a baked light background.

    Luminance drives the mask, which keeps antialiased brush edges smooth instead
    of producing the hard, chewed-up outline a colour-key removal would give.

    This flattens every hue to one colour, so it is only used where a one-colour
    silhouette is the intended result (the themed icon and the notification
    icon). Anything that has to keep the terracotta dot uses the two-colour
    transparent master instead.
    """
    a = np.asarray(im).astype(float)
    lum = a[..., :3] @ (0.2126, 0.7152, 0.0722)
    corner = float(np.median(lum[: max(2, lum.shape[0] // 40), : max(2, lum.shape[1] // 40)]))
    alpha = np.clip((corner - lum) / max(corner * 0.72, 1.0), 0, 1) * 255
    out = np.zeros_like(a, dtype=np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = ESPRESSO
    out[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def rounded_mask(size: int, radius_pct: float) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * radius_pct), fill=255
    )
    return m


def circle_mask(size: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size - 1, size - 1], fill=255)
    return m


def save_png(im: Image.Image, path: str, opaque: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        im = im.convert("RGB")
    # optimize=True plus no ancillary chunks keeps the files lean and metadata-free.
    im.save(path, "PNG", optimize=True)


def save_webp(im: Image.Image, path: str, quality: int = 88, lossless: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, "WEBP", quality=quality, lossless=lossless, method=6)


def report(paths: list[str]) -> None:
    total = 0
    for p in sorted(paths):
        if os.path.isfile(p):
            n = os.path.getsize(p)
            total += n
            print(f"  {os.path.relpath(p, ROOT):64} {n/1024:8.1f} KB")
    print(f"  {'TOTAL':64} {total/1024:8.1f} KB")


written: list[str] = []


def w(path: str) -> str:
    written.append(path)
    return path


# --------------------------------------------------------------------------- #
# 1. shared derived masters
# --------------------------------------------------------------------------- #
def build_derived() -> None:
    print("\n== derived masters ==")

    # Two-colour ensō logos. These are the only assets that need a real
    # light/dark pair, because the terracotta dot must survive.
    primary = load("BudgetSense_Primary_Transparent.png")
    inverse = load("Dark_Background_Hero_BudgetSense_Logo_Transparent.png")

    for name, art in (("primary-on-light", primary), ("inverse-on-dark", inverse)):
        save_png(square_with_margin(art, 512), w(f"{DERIVED}/budgetsense-logo-{name}.png"))

    # Compact mark: the flat-weight ensō keeps a readable silhouette when it is
    # only a few pixels across, which the textured hero logo does not.
    compact_src = load("BudgetSense_Flaticon_Transparent.png")
    save_png(square_with_margin(compact_src, 512, safe=0.08),
             w(f"{DERIVED}/budgetsense-mark-compact.png"))

    # Tintable single-colour masks.
    masks = {
        "budgetsense-mark-monochrome": ("BudgetSense_Flaticon_Transparent.png", 512, 0.08),
        "budgetsense-enso-ring": ("BudgetSense_BrushStroke_withoutDot_Transparent.png", 512, 0.08),
        "budgetsense-botanical": ("Leaf_Branding_BudgetSense.png", 512, 0.06),
        "budgetsense-milestone": ("Meditative_Enso_with_Terracotta_Accent_BudgetSense.png", 512, 0.06),
    }
    for out, (src, size, safe) in masks.items():
        m = to_mask(load(src))
        save_png(square_with_margin(m, size, safe=safe), w(f"{DERIVED}/{out}.png"))

    # Wide decoratives keep their own aspect ratio; squaring them would waste
    # most of the file on empty pixels.
    for out, src, width in (
        ("budgetsense-divider-espresso", "Horizontal_Brush_Stroke_Divider_BudgetSense.png", 1024),
        ("budgetsense-waves", "Sweeping_Espresso_Ink_Waves_BudgetSense.png", 768),
    ):
        m = to_mask(load(src))
        save_png(contain(trim(m), width), w(f"{DERIVED}/{out}.png"))

    # The underline and the seal stay in their own colour: terracotta holds up on
    # both cream and espresso, so a tinted variant would gain nothing.
    save_png(contain(trim(load("Short_Terracota_Underline_BudgetSense.png")), 1024),
             w(f"{DERIVED}/budgetsense-underline-terracotta.png"))
    save_png(square_with_margin(load("Budgetsense_Seal_Transparent.png"), 384, safe=0.06),
             w(f"{DERIVED}/budgetsense-seal-terracotta.png"))

    # Documentation-facing previews of the launcher tiles. Small on purpose: the
    # full-resolution masters already live beside them in assets/branding, so a
    # second 1024px copy would be dead weight.
    for out, src in (
        ("budgetsense-app-icon-light", "Light_Theme_BudgetSense_App_Icon.png"),
        ("budgetsense-app-icon-dark", "Dark_Theme_BudgetSense_App_Icon.png"),
    ):
        save_png(load(src).resize((256, 256), Image.LANCZOS), w(f"{DERIVED}/{out}.png"), opaque=True)

    report([p for p in written if p.startswith(DERIVED)])


# --------------------------------------------------------------------------- #
# 2. Android launcher, splash and notification resources
# --------------------------------------------------------------------------- #
def build_android() -> None:
    print("\n== android resources ==")
    start = len(written)

    # The two-colour transparent masters, so the terracotta dot survives into the
    # launcher tile. Deriving the mark from the baked icon master by luminance
    # would flatten the dot into the espresso ring and lose it.
    enso_light = load("BudgetSense_Primary_Transparent.png")
    enso_dark = load("Dark_Background_Hero_BudgetSense_Logo_Transparent.png")

    # One-colour silhouette for the layers Android tints itself.
    silhouette = ink_alpha(load("Light_Theme_BudgetSense_App_Icon.png"))

    for density, scale in DENSITIES.items():
        # --- legacy square and round icons -------------------------------------
        px = int(round(48 * scale))
        tile = Image.new("RGBA", (px, px), ICON_BG + (255,))
        tile.alpha_composite(square_with_margin(enso_light, px, safe=0.16))

        # A rounded silhouette rather than a filled square: launchers that do not
        # mask legacy icons then still show a deliberate shape.
        sq = tile.copy()
        sq.putalpha(rounded_mask(px, 0.22))
        save_png(sq, w(f"{RES}/mipmap-{density}/ic_launcher.png"))

        rnd = tile.copy()
        rnd.putalpha(circle_mask(px))
        save_png(rnd, w(f"{RES}/mipmap-{density}/ic_launcher_round.png"))

        # --- adaptive foreground (108dp canvas, mark inside the safe zone) -----
        fpx = int(round(108 * scale))
        save_png(square_with_margin(enso_light, fpx, safe=(1 - ADAPTIVE_SAFE) / 2),
                 w(f"{RES}/mipmap-{density}/ic_launcher_foreground.png"))

        # --- monochrome/themed layer: flat silhouette Android can tint ---------
        save_png(square_with_margin(to_mask(silhouette, (255, 255, 255)), fpx,
                                    safe=(1 - ADAPTIVE_SAFE) / 2),
                 w(f"{RES}/mipmap-{density}/ic_launcher_monochrome.png"))

        # --- notification small icon: white silhouette, Android tints it ------
        npx = int(round(24 * scale))
        save_png(square_with_margin(to_mask(silhouette, (255, 255, 255)), npx, safe=0.04),
                 w(f"{RES}/drawable-{density}/ic_notification.png"))

    # --- splash marks, one density each ---------------------------------------
    # A soft dry-brush mark shows no scaling artefacts, so a single nodpi asset
    # replaces ten density-bucketed copies and saves close to two megabytes.
    save_png(square_with_margin(enso_light, 384, safe=0.02),
             w(f"{RES}/drawable-nodpi/splash_mark.png"))
    save_png(square_with_margin(enso_dark, 384, safe=0.02),
             w(f"{RES}/drawable-night-nodpi/splash_mark.png"))

    report(written[start:])


# --------------------------------------------------------------------------- #
# 3. documentation site and social artwork
# --------------------------------------------------------------------------- #
def build_web() -> None:
    print("\n== web + social ==")
    start = len(written)

    primary = square_with_margin(load("BudgetSense_Primary_Transparent.png"), 640)
    inverse = square_with_margin(load("Dark_Background_Hero_BudgetSense_Logo_Transparent.png"), 640)
    compact = square_with_margin(load("BudgetSense_Flaticon_Transparent.png"), 512, safe=0.08)

    save_webp(primary, w(f"{WEB}/budgetsense-logo-primary-on-light.webp"), quality=92)
    save_webp(inverse, w(f"{WEB}/budgetsense-logo-inverse-on-dark.webp"), quality=92)
    # PNG alongside WebP: GitHub renders README images, and PNG is the safe bet
    # for every Markdown consumer.
    save_png(contain(primary, 480), w(f"{WEB}/budgetsense-logo-primary-on-light.png"))
    save_png(contain(inverse, 480), w(f"{WEB}/budgetsense-logo-inverse-on-dark.png"))

    # Favicons from the compact mark. Espresso ink on a cream tile keeps the ring
    # visible against both light and dark browser chrome, which a transparent
    # mark cannot do.
    for size in (16, 32, 48, 180, 192, 512):
        tile = Image.new("RGBA", (size, size), ICON_BG + (255,))
        # Tiny favicons get a tighter margin: at 16px the ring needs every pixel
        # it can claim, while the large tiles can afford to breathe.
        margin = 0.04 if size <= 32 else 0.12
        tile.alpha_composite(square_with_margin(compact, size, safe=margin))
        if size == 180:
            save_png(tile, w(f"{WEB}/apple-touch-icon.png"), opaque=True)
        else:
            save_png(tile, w(f"{WEB}/favicon-{size}.png"))

    ico = [Image.open(f"{WEB}/favicon-{s}.png").convert("RGBA") for s in (16, 32, 48)]
    os.makedirs(WEB, exist_ok=True)
    ico[0].save(w(f"{WEB}/favicon.ico"), format="ICO",
                sizes=[(16, 16), (32, 32), (48, 48)])

    # Maskable PWA icon: full-bleed tile with the mark inside the 80% safe circle.
    mask_tile = Image.new("RGBA", (512, 512), ICON_BG + (255,))
    mask_tile.alpha_composite(square_with_margin(compact, 512, safe=0.22))
    save_png(mask_tile, w(f"{WEB}/maskable-512.png"), opaque=True)

    # Decoratives for the site, as tintable masks.
    save_webp(contain(trim(to_mask(load("Horizontal_Brush_Stroke_Divider_BudgetSense.png"))), 1024),
              w(f"{WEB}/budgetsense-divider.webp"), lossless=True)
    save_webp(contain(trim(load("Short_Terracota_Underline_BudgetSense.png")), 768),
              w(f"{WEB}/budgetsense-underline-terracotta.webp"), lossless=True)

    build_social()
    report(written[start:])


def build_social() -> None:
    """A 1280x640 social card: espresso field, cream ensō, one line of copy."""
    W, H = 1280, 640
    card = Image.new("RGBA", (W, H), ESPRESSO + (255,))

    # A whisper of the espresso paper texture keeps the field from looking flat.
    # Kept light: at higher blends the grain starts competing with the mark.
    tex = load("Dark_Espresso_Paper_Texture_Background_BudgetSense.png").resize((W, H), Image.LANCZOS)
    card = Image.blend(card.convert("RGB"), tex.convert("RGB"), 0.35).convert("RGBA")

    mark = contain(trim(load("Dark_Background_Hero_BudgetSense_Logo_Transparent.png")), 300)
    card.alpha_composite(mark, (118, (H - mark.size[1]) // 2))

    d = ImageDraw.Draw(card)
    x = 118 + 300 + 92
    font_lg = _font(78)
    font_sm = _font(31)
    d.text((x, 246), "BudgetSense", font=font_lg, fill=CREAM + (255,))
    d.text((x, 349), "A calm, private budgeting app", font=font_sm, fill=SAND + (235,))
    # Terracotta rule, echoing the underline gesture without importing the asset.
    d.rectangle([x, 410, x + 132, 415], fill=TERRACOTTA + (255,))

    # JPEG, not PNG: the card is a photographic-looking texture field with no
    # transparency, so JPEG is roughly a tenth of the size at the same quality,
    # and every social scraper and the GitHub social-preview upload accept it.
    os.makedirs(WEB, exist_ok=True)
    card.convert("RGB").save(w(f"{WEB}/budgetsense-social-preview.jpg"),
                             "JPEG", quality=90, optimize=True, progressive=True)


def _font(size: int):
    """Prefer the bundled UI typeface so the card matches the product."""
    from PIL import ImageFont

    for cand in (
        os.path.join(ROOT, "assets", "fonts", "ZenMaruGothic-Bold.ttf"),
        os.path.join(ROOT, "assets", "fonts", "ZenMaruGothic-Medium.ttf"),
    ):
        if os.path.isfile(cand):
            try:
                return ImageFont.truetype(cand, size)
            except OSError:
                pass
    return ImageFont.load_default(size)


def main() -> None:
    if not os.path.isdir(SRC):
        sys.exit(f"missing source directory: {SRC}")
    build_derived()
    build_android()
    build_web()
    print(f"\n{len(written)} files written.")


if __name__ == "__main__":
    main()

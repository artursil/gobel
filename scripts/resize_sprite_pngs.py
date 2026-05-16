#!/usr/bin/env python3
"""Trim transparent margins from PNGs, then resize onto fixed 2.5×3.5 canvases (1024×1435).

- Stances: every ``*.png`` under ``STANCES_DIR`` (skips names ending with ``_r.png``).
- Cards: only files matching ``background*.png`` under ``CARDS_DIR``.

Outputs sit next to sources as ``<stem>_r.png`` (originals are not modified).

Requires Pillow: ``pip install pillow``

Edge trim (before resize), using alpha > ``ALPHA_TRIM_THRESHOLD`` as opaque:

- **Left**: in the left half of the width, each row is scanned left→right; the
  leftmost first-opaque column among rows is the crop line (everything left is
  removed on all rows).
- **Right**: in the right half, each row is scanned right→left; the rightmost
  first-opaque column among rows is the crop line.
- **Top**: in the top half of the height, each column is scanned top→bottom; the
  topmost first-opaque row among columns is the crop line.
- **Bottom**: in the bottom half, each column is scanned bottom→top; the
  bottommost first-opaque row among columns is the crop line.

The trimmed image is then scaled to the target width and height.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

STANCE_WIDTH = 1024
STANCE_HEIGHT = 1435
CARD_WIDTH = 1024
CARD_HEIGHT = 1435

REPO_ROOT = Path(__file__).resolve().parent.parent
STANCES_DIR = REPO_ROOT / "sprites" / "stances"
CARDS_DIR = REPO_ROOT / "sprites" / "cards"

ALPHA_TRIM_THRESHOLD = 8


def _repo_relative(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def _is_opaque(alpha: int) -> bool:
    return alpha > ALPHA_TRIM_THRESHOLD


def _trim_edges(im: Image.Image) -> Image.Image:
    """Trim transparent margins using half-image scans from each edge."""
    rgba = im.convert("RGBA")
    w, h = rgba.size
    if w <= 0 or h <= 0:
        raise ValueError("empty image")
    px = rgba.load()
    mid_x = w // 2
    mid_y = h // 2

    crop_left = w
    for y in range(h):
        for x in range(mid_x):
            if _is_opaque(px[x, y][3]):
                crop_left = min(crop_left, x)
                break
    if crop_left == w:
        crop_left = 0

    crop_right = 0
    for y in range(h):
        for x in range(w - 1, mid_x - 1, -1):
            if _is_opaque(px[x, y][3]):
                crop_right = max(crop_right, x + 1)
                break
    if crop_right == 0:
        crop_right = w

    crop_top = h
    for x in range(w):
        for y in range(mid_y):
            if _is_opaque(px[x, y][3]):
                crop_top = min(crop_top, y)
                break
    if crop_top == h:
        crop_top = 0

    crop_bottom = 0
    for x in range(w):
        for y in range(h - 1, mid_y - 1, -1):
            if _is_opaque(px[x, y][3]):
                crop_bottom = max(crop_bottom, y + 1)
                break
    if crop_bottom == 0:
        crop_bottom = h

    if crop_right <= crop_left or crop_bottom <= crop_top:
        raise ValueError("no visible pixels after edge trim")
    return rgba.crop((crop_left, crop_top, crop_right, crop_bottom))


def _resize_to_canvas(src: Image.Image, out_w: int, out_h: int) -> Image.Image:
    trimmed = _trim_edges(src)
    return trimmed.resize((out_w, out_h), Image.Resampling.LANCZOS)


def _output_path(src: Path) -> Path:
    return src.with_name(f"{src.stem}_r{src.suffix}")


def _process_one(src: Path, out_w: int, out_h: int) -> bool:
    out_path = _output_path(src)
    try:
        with Image.open(src) as im:
            result = _resize_to_canvas(im, out_w, out_h)
    except Exception as e:
        print(f"SKIP {_repo_relative(src)}: {e}", file=sys.stderr)
        return False
    result.save(out_path, format="PNG", optimize=True)
    print(f"OK {_repo_relative(src)} -> {_repo_relative(out_path)}")
    return True


def _iter_pngs(directory: Path) -> list[Path]:
    if not directory.is_dir():
        return []
    paths = sorted(p for p in directory.iterdir() if p.suffix.lower() == ".png")
    return [p for p in paths if not p.stem.endswith("_r")]


def process_stances() -> tuple[int, int]:
    ok = skipped = 0
    for src in _iter_pngs(STANCES_DIR):
        if _process_one(src, STANCE_WIDTH, STANCE_HEIGHT):
            ok += 1
        else:
            skipped += 1
    return ok, skipped


def process_card_backgrounds() -> tuple[int, int]:
    ok = skipped = 0
    if not CARDS_DIR.is_dir():
        return 0, 0
    for src in sorted(CARDS_DIR.glob("background*.png")):
        if src.stem.endswith("_r"):
            continue
        if _process_one(src, CARD_WIDTH, CARD_HEIGHT):
            ok += 1
        else:
            skipped += 1
    return ok, skipped


def main() -> int:
    s_ok, s_bad = process_stances()
    c_ok, c_bad = process_card_backgrounds()
    print(
        f"Done. stances: {s_ok} ok, {s_bad} skipped | "
        f"card backgrounds: {c_ok} ok, {c_bad} skipped"
    )
    return 0 if (s_bad + c_bad) == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

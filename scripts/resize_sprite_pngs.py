#!/usr/bin/env python3
"""Trim transparent margins from PNGs, then scale onto fixed canvases.

- Stances: every ``*.png`` under ``STANCES_DIR`` (skips names ending with ``_r.png``).
- Cards: only files matching ``background*.png`` under ``CARDS_DIR``.

Outputs sit next to sources as ``<stem>_r.png`` (originals are not modified).

Requires Pillow: ``pip install pillow``

Trimming uses the alpha channel: pixels with alpha above ``ALPHA_TRIM_THRESHOLD`` are
considered content. ``EDGE_PADDING_PX`` expands the crop box so anti-aliased rounded
corners are not clipped; uniform scale + centered paste on a transparent WxH canvas
preserves aspect ratio and keeps outer corners transparent when aspect differs from the target.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

# --- output canvas sizes (edit these) ---
STANCE_WIDTH = 512
STANCE_HEIGHT = 704
CARD_WIDTH = 512
CARD_HEIGHT = 704

# --- layout relative to this file ---
REPO_ROOT = Path(__file__).resolve().parent.parent
STANCES_DIR = REPO_ROOT / "sprites" / "stances"
CARDS_DIR = REPO_ROOT / "sprites" / "cards"

# --- trim: treat alpha <= threshold as empty (0 = only fully transparent) ---
ALPHA_TRIM_THRESHOLD = 8
# --- extra pixels around tight bbox (helps rounded corners / AA) ---
EDGE_PADDING_PX = 2


def _repo_relative(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def _alpha_bbox_rgba(im: Image.Image) -> tuple[int, int, int, int] | None:
    """Bounding box of pixels with alpha > ALPHA_TRIM_THRESHOLD."""
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    alpha = im.split()[3]
    if ALPHA_TRIM_THRESHOLD <= 0:
        bbox = alpha.getbbox()
        return bbox
    # Build mask: content where alpha > threshold
    mask = alpha.point(lambda p: 255 if p > ALPHA_TRIM_THRESHOLD else 0)
    return mask.getbbox()


def _expand_bbox(
    bbox: tuple[int, int, int, int],
    width: int,
    height: int,
    pad: int,
) -> tuple[int, int, int, int]:
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(width, r + pad)
    b = min(height, b + pad)
    return l, t, r, b


def _trim_and_fit_canvas(src: Image.Image, out_w: int, out_h: int) -> Image.Image:
    """Crop empty transparency, then uniformly scale to fit inside out_w x out_h, centered on RGBA canvas."""
    rgba = src.convert("RGBA")
    bbox = _alpha_bbox_rgba(rgba)
    if bbox is None:
        raise ValueError("image has no visible pixels (fully transparent)")
    w, h = rgba.size
    l, t, r, b = _expand_bbox(bbox, w, h, EDGE_PADDING_PX)
    cropped = rgba.crop((l, t, r, b))
    cw, ch = cropped.size
    if cw <= 0 or ch <= 0:
        raise ValueError("degenerate crop")

    scale = min(out_w / cw, out_h / ch)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    x = (out_w - nw) // 2
    y = (out_h - nh) // 2
    canvas.paste(resized, (x, y), resized)
    return canvas


def _output_path(src: Path) -> Path:
    return src.with_name(f"{src.stem}_r{src.suffix}")


def _process_one(src: Path, out_w: int, out_h: int, dry_run: bool) -> bool:
    out_path = _output_path(src)
    try:
        with Image.open(src) as im:
            result = _trim_and_fit_canvas(im, out_w, out_h)
    except Exception as e:
        print(f"SKIP {_repo_relative(src)}: {e}", file=sys.stderr)
        return False
    if dry_run:
        print(f"DRY-RUN would write {_repo_relative(out_path)}")
        return True
    result.save(out_path, format="PNG", optimize=True)
    print(f"OK {_repo_relative(src)} -> {_repo_relative(out_path)}")
    return True


def _iter_pngs(directory: Path) -> list[Path]:
    if not directory.is_dir():
        return []
    paths = sorted(p for p in directory.iterdir() if p.suffix.lower() == ".png")
    return [p for p in paths if not p.stem.endswith("_r")]


def process_stances(dry_run: bool) -> tuple[int, int]:
    ok = skipped = 0
    for src in _iter_pngs(STANCES_DIR):
        if _process_one(src, STANCE_WIDTH, STANCE_HEIGHT, dry_run):
            ok += 1
        else:
            skipped += 1
    return ok, skipped


def process_card_backgrounds(dry_run: bool) -> tuple[int, int]:
    ok = skipped = 0
    if not CARDS_DIR.is_dir():
        return 0, 0
    for src in sorted(CARDS_DIR.glob("background*.png")):
        if src.stem.endswith("_r"):
            continue
        if _process_one(src, CARD_WIDTH, CARD_HEIGHT, dry_run):
            ok += 1
        else:
            skipped += 1
    return ok, skipped


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    s_ok, s_bad = process_stances(dry_run)
    c_ok, c_bad = process_card_backgrounds(dry_run)
    print(
        f"Done. stances: {s_ok} ok, {s_bad} skipped | "
        f"card backgrounds: {c_ok} ok, {c_bad} skipped"
    )
    return 0 if (s_bad + c_bad) == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

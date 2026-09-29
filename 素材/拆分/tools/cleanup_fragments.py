"""Post-process sliced master assets without redrawing anything.

Fixes the review items that are pure image processing:
  1. Slicing leftovers: remove connected components that touch the image border
     (pieces of neighbouring sheet items) unless it is the main (largest) component.
  2. Trim every transparent asset to its content bounds + 4px padding.
  3. Floor/wall tiles: make fully opaque by compositing over the tile's own mean colour
     (keyed-out edges left dark seams when tiled).
  4. Swap sprite-generator / sprite-generator-fixed (semantics were reversed).

Originals are backed up to 素材/拆分/cleanup_backup/ once. Re-runnable.
"""
import os, shutil, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MASTER = os.path.join(ROOT, "UI拆分资产", "00-共享资产")
BACKUP = os.path.join(ROOT, "拆分", "cleanup_backup")
TRANSPARENT_CATS = ["02-Logo", "04-按钮", "05-图标", "06-头像", "07-身份徽记", "08-装饰", "09-道具图标", "10-事件图标", "11-HUD控件", "12-局内精灵"]
OPAQUE_TILES = {"tile-floor-wood", "tile-floor-tile", "tile-floor-concrete", "tile-wall-solid", "tile-wall-cracked"}
SKIP_TRIM = {"hud-vignette-red", "app_icon_1024"}  # full-canvas by design
# HUD buttons and in-game sprites keep their canvas: the client stretches them to fixed
# square/2:3 rects and anchors characters by the bottom edge, so trimming would distort them.
NO_TRIM_CATS = {"11-HUD控件", "12-局内精灵"}
BAND = 7  # sheet slicing pads 4px, so leftovers sit a few px inside the edge


def backup(path):
    rel = os.path.relpath(path, MASTER)
    dst = os.path.join(BACKUP, rel)
    if not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(path, dst)


def remove_border_fragments(arr):
    alpha = arr[:, :, 3]
    mask = alpha > 16
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n <= 1:
        return arr, 0
    sizes = ndimage.sum(mask, labels, range(1, n + 1))
    main = int(np.argmax(sizes)) + 1
    h, w = mask.shape
    border = np.zeros_like(mask)
    border[:BAND, :] = border[-BAND:, :] = True
    border[:, :BAND] = border[:, -BAND:] = True
    touching = set(np.unique(labels[border & mask]).tolist()) - {0, main}
    removed = 0
    for lab in touching:
        # Only drop pieces clearly smaller than the main shape.
        if sizes[lab - 1] < sizes[main - 1] * 0.5:
            arr[labels == lab, 3] = 0
            removed += 1
    return arr, removed


def trim(arr, pad=4):
    alpha = arr[:, :, 3]
    ys, xs = np.nonzero(alpha > 8)
    if len(xs) == 0:
        return arr
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    h, w = alpha.shape
    if x0 <= pad and y0 <= pad and x1 >= w - pad and y1 >= h - pad:
        return arr
    out = np.zeros((y1 - y0 + pad * 2, x1 - x0 + pad * 2, 4), dtype=arr.dtype)
    out[pad:pad + y1 - y0, pad:pad + x1 - x0] = arr[y0:y1, x0:x1]
    return out


def make_opaque(path):
    im = Image.open(path).convert("RGBA")
    arr = np.asarray(im).astype(np.float32)
    a = arr[:, :, 3:4] / 255.0
    solid = arr[:, :, 3] > 200
    mean = arr[solid][:, :3].mean(axis=0) if solid.any() else arr[:, :, :3].mean(axis=(0, 1))
    rgb = arr[:, :, :3] * a + mean * (1 - a)
    out = np.dstack([rgb, np.full(a.shape, 255.0)]).clip(0, 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path)


def main():
    report = {"fragments": [], "trimmed": [], "opaque": [], "swapped": False}
    for cat in TRANSPARENT_CATS:
        folder = os.path.join(MASTER, cat)
        if not os.path.isdir(folder):
            continue
        for f in sorted(os.listdir(folder)):
            if not f.endswith(".png"):
                continue
            name, path = f[:-4], os.path.join(folder, f)
            if name.endswith("_preview"):
                continue
            if name in OPAQUE_TILES:
                backup(path); make_opaque(path); report["opaque"].append(name)
                continue
            if name.startswith("tile-") or name in SKIP_TRIM:
                continue
            arr = np.array(Image.open(path).convert("RGBA"))
            before = arr.shape
            arr, removed = remove_border_fragments(arr)
            if cat not in NO_TRIM_CATS:
                arr = trim(arr)
            if removed or arr.shape != before:
                backup(path)
                Image.fromarray(arr, "RGBA").save(path)
                if removed:
                    report["fragments"].append("%s(-%d)" % (name, removed))
                if arr.shape != before:
                    report["trimmed"].append("%s %dx%d->%dx%d" % (name, before[1], before[0], arr.shape[1], arr.shape[0]))
    # Generator art was reversed: "fixed" showed a broken smoking machine.
    sprites = os.path.join(MASTER, "12-局内精灵")
    a, b = os.path.join(sprites, "sprite-generator.png"), os.path.join(sprites, "sprite-generator-fixed.png")
    flag = os.path.join(BACKUP, ".generator_swapped")
    if os.path.exists(a) and os.path.exists(b) and not os.path.exists(flag):
        backup(a); backup(b)
        tmp = a + ".tmp"
        os.replace(a, tmp); os.replace(b, a); os.replace(tmp, b)
        open(flag, "w").close()
        report["swapped"] = True
    for k, v in report.items():
        print(k, v if not isinstance(v, list) else "%d: %s" % (len(v), ", ".join(v)))


if __name__ == "__main__":
    sys.exit(main())

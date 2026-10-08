"""Zero out near-invisible keying leftovers (alpha < 24) in the generated character /
cosmetic sprites and the logo; they show up as faint lines when composited or scaled, and
inflate the opaque bounds used for layout (the splash tagline sits under the logo's bounds).
Usage: python 素材/拆分/tools/clear_faint_alpha.py"""
import glob, os
import numpy as np
from PIL import Image

SHARED = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "UI拆分资产", "00-共享资产")
SPRITES = os.path.join(SHARED, "12-局内精灵")
patterns = [os.path.join(SPRITES, p) for p in ["hat-*.png", "anim-*.png", "footprint-*.png", "furn-*.png", "decor-*.png"]]
patterns.append(os.path.join(SHARED, "02-Logo", "game_logo_title.png"))
for pattern in patterns:
    for path in sorted(glob.glob(pattern)):
        img = np.array(Image.open(path).convert("RGBA"))
        faint = (img[..., 3] > 0) & (img[..., 3] < 24)
        if faint.any():
            img[faint] = 0
            Image.fromarray(img).save(path)
            print(f"{os.path.basename(path)}: cleared {int(faint.sum())} px")

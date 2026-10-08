"""Zero out near-invisible keying leftovers (alpha < 24) in the generated character /
cosmetic sprites; they show up as faint lines when composited or scaled.
Usage: python 素材/拆分/tools/clear_faint_alpha.py"""
import glob, os
import numpy as np
from PIL import Image

SPRITES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "UI拆分资产", "00-共享资产", "12-局内精灵")
for pattern in ["hat-*.png", "anim-*.png", "footprint-*.png", "furn-*.png", "decor-*.png"]:
    for path in sorted(glob.glob(os.path.join(SPRITES, pattern))):
        img = np.array(Image.open(path).convert("RGBA"))
        faint = (img[..., 3] > 0) & (img[..., 3] < 24)
        if faint.any():
            img[faint] = 0
            Image.fromarray(img).save(path)
            print(f"{os.path.basename(path)}: cleared {int(faint.sum())} px")

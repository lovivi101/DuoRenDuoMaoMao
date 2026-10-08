"""Remove stray pixel fragments from hat overlays (hat-*.png): keep only connected parts
that are a real piece of the hat (>= 5% of the largest part and >= 40 px).
Originals go to 拆分/cleanup_backup/T7-hats/ once. Usage: python 素材/拆分/tools/clean_hat_fragments.py"""
import glob, os, shutil
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(HERE, "..", "..", "UI拆分资产", "00-共享资产", "12-局内精灵")
BACKUP = os.path.join(HERE, "..", "cleanup_backup", "T7-hats")
os.makedirs(BACKUP, exist_ok=True)
for path in sorted(glob.glob(os.path.join(SPRITES, "hat-*.png"))):
    img = np.array(Image.open(path).convert("RGBA"))
    labels, n = ndimage.label(img[..., 3] > 0, structure=np.ones((3, 3)))
    if n <= 1:
        continue
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
    keep = {i + 1 for i, s in enumerate(sizes) if s >= max(40, 0.05 * sizes.max())}
    drop = ~np.isin(labels, list(keep)) & (labels > 0)
    if drop.any():
        backup = os.path.join(BACKUP, os.path.basename(path))
        if not os.path.exists(backup):
            shutil.copy2(path, backup)
        img[drop] = 0
        Image.fromarray(img).save(path)
        print(f"{os.path.basename(path)}: removed {int(drop.sum())} px in {n - len(keep)} fragments")

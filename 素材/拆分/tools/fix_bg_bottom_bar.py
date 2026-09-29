"""Remove the bright horizontal bar some generated backgrounds carry near the bottom edge.

Rows from the first bright row down to the bottom are replaced with a mirror of the rows
just above it. Originals are copied to 拆分/cleanup_backup/ first.
Usage: python 素材/拆分/tools/fix_bg_bottom_bar.py
"""
from pathlib import Path
import shutil
from PIL import Image

HERE = Path(__file__).resolve().parents[1]
BG = HERE.parent / "UI拆分资产" / "00-共享资产" / "01-背景"
BACKUP = HERE / "cleanup_backup" / "01-背景"


def row_brightness(img, y):
    w = img.width
    return sum(sum(img.getpixel((x, y))[:3]) / 3 for x in range(0, w, 10)) / len(range(0, w, 10))


for path in sorted(BG.glob("*.png")):
    img = Image.open(path).convert("RGB")
    h = img.height
    base = sum(row_brightness(img, y) for y in range(h - 120, h - 80)) / 40
    bar = next((y for y in range(h - 70, h) if row_brightness(img, y) > base * 1.8 + 25), None)
    if bar is None:
        continue
    BACKUP.mkdir(parents=True, exist_ok=True)
    if not (BACKUP / path.name).exists():
        shutil.copy2(path, BACKUP / path.name)
    start = bar - 6  # include the bar's soft glow
    for y in range(start, h):
        src = start - 1 - (y - start)
        img.paste(img.crop((0, src, img.width, src + 1)), (0, y))
    img.save(path)
    print(f"{path.name}: bar at row {bar}, rebuilt rows {start}-{h - 1}")

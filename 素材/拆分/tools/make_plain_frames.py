"""Generate ornament-free "*_plain.png" variants of the nine-patch frames.

The generated panels/buttons carry sparkles and moons inside their corners. Nine-patch
stretching smears those ornaments and they collide with labels, so the client uses plain
variants: the border bands are kept as drawn and every interior row is refilled with
that row's centre pixel (which keeps vertical gradients such as a button's highlight).

Usage: python 素材/拆分/tools/make_plain_frames.py   (then run tools/sync_assets.ps1)
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "UI拆分资产" / "00-共享资产"
FRAMES = {
    "03-面板": ["panel_content_large", "panel_modal", "panel_keypad", "panel_player_card", "panel_input_field",
              "panel_score_row", "panel_list_row", "panel_top_resource_bar", "panel_bottom_nav",
              "panel_header_bar", "panel_room_code_cell", "panel_notice_board"],
    "04-按钮": ["button_primary_yellow", "button_primary_yellow_pressed", "button_secondary_dark",
              "button_secondary_dark_pressed", "button_small_action", "button_ready_green", "button_danger_red",
              "button_phone_blue", "button_account_purple",
              "button_guest_ghost", "tab_active", "tab_inactive"],
}
TOLERANCE = 40


def close(a, b):
    return max(abs(a[i] - b[i]) for i in range(3)) <= TOLERANCE


def border(pixels, coords, fill):
    """Distance along `coords` past the frame's border ring: the dark outer outline can
    resemble the fill, so first cross a pixel that differs from it, then wait for four
    consecutive fill-coloured pixels."""
    seen = False
    for i in range(len(coords) - 4):
        if not close(pixels[coords[i]], fill) and pixels[coords[i]][3] > 200:
            seen = True
        elif seen and all(close(pixels[coords[i + k]], fill) for k in range(4)):
            return i
    return 0


def make_plain(src: Path) -> Path:
    img = Image.open(src).convert("RGBA")
    left, top, right, bottom = img.getbbox()
    px = img.load()
    cx, cy = (left + right) // 2, (top + bottom) // 2
    fill = px[cx, cy]
    bl = left + border(px, [(x, cy) for x in range(left, cx)], fill) + 2
    br = right - border(px, [(x, cy) for x in range(right - 1, cx, -1)], fill) - 2
    bt = top + border(px, [(cx, y) for y in range(top, cy)], fill) + 2
    bb = bottom - border(px, [(cx, y) for y in range(bottom - 1, cy, -1)], fill) - 2
    for y in range(bt, bb):
        row = px[cx, y]
        for x in range(bl, br):
            px[x, y] = row
    out = src.with_name(src.stem + "_plain.png")
    img.save(out)
    print(f"{out.name}: interior x {bl}-{br}, y {bt}-{bb}")
    return out


if __name__ == "__main__":
    for folder, names in FRAMES.items():
        for name in names:
            path = ROOT / folder / (name + ".png")
            if path.exists():
                make_plain(path)
            else:
                print("missing", path)

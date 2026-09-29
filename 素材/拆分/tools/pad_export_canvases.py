"""Restore specified transparent canvas dimensions without redrawing artwork.

The review requested tight crop for a few named assets; those are excluded.
Likewise T3d has ownership of its explicit replacement list and is excluded.
"""
from PIL import Image
import os
from catalog import categories, target_size, MASTER

EXCLUDE=set('game_logo_title banner_victory_hider banner_victory_hunter decor-mvp-ribbon hud-stamina-frame hud-stamina-fill hud-survivor-counter hud-timer-frame'.split())
EXCLUDE.update('hud-btn-main-interact hud-btn-main-slap hud-btn-skill-disguise hud-btn-skill-flashlight hud-joystick-base hud-vignette-red item-frame-common item-frame-rare item-frame-legendary event-warning-banner add-friend-icon vibration-icon wardrobe-icon divider_pixel'.split())

def main():
    changed=[]
    for name,cat in categories().items():
        if name in EXCLUDE or cat in ('01-背景','13-地图卡') or name.startswith('tile-'):continue
        path=MASTER/cat/(name+'.png')
        if not path.exists():continue
        with Image.open(path) as source:im=source.convert('RGBA')
        size=target_size(name)
        if im.size==size:continue
        if im.width>size[0]-8 or im.height>size[1]-8:
            im.thumbnail((size[0]-8,size[1]-8),Image.Resampling.NEAREST if cat=='12-局内精灵' else Image.Resampling.LANCZOS)
        dest=Image.new('RGBA',size)
        dest.alpha_composite(im,((size[0]-im.width)//2,(size[1]-im.height)//2))
        tmp=path.with_suffix('.padding.tmp.png')
        dest.save(tmp);os.replace(tmp,path);changed.append(name)
    print('padded/resized image_gen source art:',len(changed))

if __name__=='__main__':main()

"""Audit the full §6 name list and T3 extensions; never invent missing files."""
from pathlib import Path
import csv, sys
import numpy as np
from PIL import Image
from catalog import OUT, MASTER, categories, target_size

OPAQUE_TILES={'tile-floor-wood','tile-floor-tile','tile-floor-concrete','tile-wall-solid','tile-wall-cracked'}
OPAQUE_TILES |= {n+'_preview' for n in list(OPAQUE_TILES)}
TRIM_REQUESTED={'game_logo_title','banner_victory_hider','banner_victory_hunter',
                'decor-mvp-ribbon','hud-stamina-frame','hud-stamina-fill',
                'hud-survivor-counter','hud-timer-frame'}

def inspect(path,name,cat):
    raw=Image.open(path).convert('RGBA'); a=np.asarray(raw); alpha=a[:,:,3]
    h,w=alpha.shape; size=(w,h); expected=target_size(name)
    opaque=(cat in ('01-背景','13-地图卡') or name=='app_icon_1024' or name in OPAQUE_TILES)
    visible=alpha>16
    red=(a[:,:,0]>248)&(a[:,:,1]<12)&(a[:,:,2]>248)
    green=(a[:,:,1]>248)&(a[:,:,0]<12)&(a[:,:,2]<12)
    chroma=float(np.mean((red|green)&visible))
    corners=[int(alpha[y,x]) for y,x in ((0,0),(0,w-1),(h-1,0),(h-1,w-1))]
    issue=[];warn=[]
    if name.startswith('tile-') and not name.endswith('_preview') and size!=(32,32):issue.append('tile-not-32x32')
    if name in OPAQUE_TILES and np.min(alpha)!=255:issue.append('terrain-alpha-gap')
    if cat=='01-背景' and size!=(1334,750):issue.append('background-size')
    if cat=='13-地图卡' and size!=(640,360):issue.append('map-size')
    if name=='hud-vignette-red' and size!=(1334,750):issue.append('vignette-size')
    if name not in TRIM_REQUESTED and cat not in ('01-背景','13-地图卡') and name not in OPAQUE_TILES:
        if any(abs(v/e-1)>.10 for v,e in zip(size,expected)):issue.append('size-outside-10pct')
    elif size!=expected and name in TRIM_REQUESTED:warn.append('review-requested-content-trim')
    if not opaque and name!='hud-vignette-red':
        if np.min(alpha)!=0 or not all(x==0 for x in corners):issue.append('opaque-corner')
        if chroma>=.005:issue.append('visible-chroma')
    elif cat in ('01-背景','13-地图卡') and np.min(alpha)!=255:issue.append('background-alpha')
    if not np.any(visible):issue.append('empty-art')
    if name=='hud-vignette-red' and alpha[h//2,w//2]>8:issue.append('vignette-center-not-clear')
    note=';'.join(issue+warn) if issue or warn else 'ok'
    return [str(path.relative_to(OUT)).replace('\\','/'),cat,w,h,bool(np.any(alpha<255)),
            int(alpha.min()),int(alpha.max()),f'{np.mean(alpha==255):.4f}',note], issue, warn

def main():
    rows=[];missing=[];bad=[];warn=[]
    expected=categories()
    for p in MASTER.rglob('*.png'):
        if p.stem not in expected or p.parent.name!=expected[p.stem]:
            bad.append(f'unexpected-location: {p.relative_to(MASTER)}')
    for n,cat in expected.items():
        path=MASTER/cat/(n+'.png')
        if not path.exists():missing.append(f'{cat}/{n}.png');continue
        row,issues,warnings=inspect(path,n,cat);rows.append(row)
        if issues:bad.append(f'{n}: {";".join(issues)} ({row[2]}x{row[3]})')
        if warnings:warn.append(n)
    with (OUT/'ASSET_AUDIT.csv').open('w',newline='',encoding='utf-8-sig') as f:
        writer=csv.writer(f);writer.writerow(['path','category','width','height','has_alpha',
            'alpha_min','alpha_max','opaque_ratio','notes']);writer.writerows(rows)
    print(f'checked={len(rows)} missing={len(missing)} bad={len(bad)} trimmed={len(warn)}')
    if missing:print('MISSING\n'+'\n'.join(missing))
    if bad:print('BAD\n'+'\n'.join(bad))
    return 1 if missing or bad else 0

if __name__=='__main__':sys.exit(main())

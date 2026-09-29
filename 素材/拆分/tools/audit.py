"""Acceptance audit for T3 assets; emits ASSET_AUDIT.csv and a zero-error summary."""
from pathlib import Path
import csv
from PIL import Image
from catalog import OUT, MASTER, categories, target_size

def inspect(p):
    im=Image.open(p).convert('RGBA'); a=list(im.getdata()); al=[x[3] for x in a];
    # count only near-pure chroma spill, not legitimate red/pink/green artwork
    mag=sum(r>235 and b>205 and g<70 for r,g,b,_ in a)/len(a)
    green=sum(g>220 and r<70 and b<150 for r,g,b,_ in a)/len(a)
    return im.size, any(x<255 for x in al), min(al),max(al),sum(x==255 for x in al)/len(al),mag+green

rows=[]; missing=[]; bad=[]
for n,cat in categories().items():
    if n.endswith('_preview') and not (MASTER/cat/(n+'.png')).exists(): continue
    p=MASTER/cat/(n+'.png')
    if not p.exists(): missing.append(str(p)); continue
    size,ha,amin,amax,opaque,chroma=inspect(p); bg=cat in ('01-背景','13-地图卡') or n=='app_icon_1024'
    expected=target_size(n)
    ok=(size==expected and (bg or (ha and amin==0 and chroma<.005)))
    if cat=='12-局内精灵' and n.startswith('tile-') and not n.endswith('_preview'): ok &= size==(32,32)
    if not ok: bad.append(f'{n}: {size}, alpha={ha}, corners/min={amin}, chroma={chroma:.4f}, expected={expected}')
    rows.append([str(p.relative_to(OUT)).replace('\\','/'),cat,size[0],size[1],ha,amin,amax,f'{opaque:.4f}','ok' if ok else 'FAIL'])
with (OUT/'ASSET_AUDIT.csv').open('w',newline='',encoding='utf-8-sig') as f:
    w=csv.writer(f); w.writerow(['path','category','width','height','has_alpha','alpha_min','alpha_max','opaque_ratio','notes']); w.writerows(rows)
print(f'checked={len(rows)} missing={len(missing)} bad={len(bad)}')
if missing: print('MISSING',*missing,sep='\n')
if bad: print('BAD',*bad,sep='\n')

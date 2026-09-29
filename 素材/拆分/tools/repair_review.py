"""Re-cut image_gen originals and apply only crop/scale/alpha image operations.

No graphics are drawn. Run after source atlases and the two individual image_gen
outputs have been saved. Originals are retained in sheets/ and cleanup_backup/.
"""
from pathlib import Path
import shutil
import numpy as np
from PIL import Image
from scipy import ndimage
from catalog import MASTER, WORK, categories, target_size

SHEETS = WORK / 'sheets'
EVENT_SOURCE=Path(r'C:\Users\Administrator\.codex\generated_images\01a0eaf4-cdc1-74c2-83a9-878af82a376e\exec-733a6861-681d-47ad-a44e-925eea169c82.png')
BANNER_SOURCES={
 'banner_victory_hider':Path(r'C:\Users\Administrator\.codex\generated_images\01a0eaf4-cdc1-74c2-83a9-878af82a376e\exec-c1c5aaf2-7d54-4ddd-81be-63696975ae07.png'),
 'banner_victory_hunter':Path(r'C:\Users\Administrator\.codex\generated_images\01a0eaf4-cdc1-74c2-83a9-878af82a376e\exec-efb5d0f5-57d2-4bec-b3a9-1472b538118e.png'),
}
# T3d now owns its narrowed replacement list. This script must not overwrite
# those newer image_gen exports if re-run.

def bbox_crop(im, margin=0):
    a=np.asarray(im.convert('RGBA'))[:,:,3]
    yy,xx=np.where(a>8)
    if not len(xx): raise ValueError('No source pixels')
    return im.crop((max(0,int(xx.min())-margin),max(0,int(yy.min())-margin),
                    min(im.width,int(xx.max())+1+margin),min(im.height,int(yy.max())+1+margin)))

def fit(im, size, stretch=False, nearest=False):
    im=bbox_crop(im)
    res=Image.Resampling.NEAREST if nearest else Image.Resampling.LANCZOS
    if stretch: im=im.resize((size[0]-8,size[1]-8),res)
    else: im.thumbnail((size[0]-8,size[1]-8),res)
    canvas=Image.new('RGBA',size)
    canvas.alpha_composite(im,((size[0]-im.width)//2,(size[1]-im.height)//2))
    return canvas

def save(name, im):
    p=MASTER/categories()[name]/(name+'.png')
    im.save(p)
    print(name, im.size)

def source_cell(filename, idx, cols, rows):
    im=Image.open(SHEETS/filename).convert('RGBA'); w,h=im.size
    x,y=idx%cols,idx//cols
    return im.crop((round(x*w/cols),round(y*h/rows),round((x+1)*w/cols),round((y+1)*h/rows)))

def isolated(im, min_fraction=.02):
    """Retain substantial generated shapes in a cell; remove edge debris.

    Multiple separated intentional shapes (eyes, footprints, stars) are kept if
    they are substantial and centered, unlike small clipped neighbor fragments.
    """
    a=np.asarray(im.convert('RGBA')).copy(); mask=a[:,:,3]>24
    labs,n=ndimage.label(mask,np.ones((3,3)))
    if not n:return im
    counts=np.bincount(labs.ravel()); counts[0]=0; main=int(counts.argmax())
    dist=ndimage.distance_transform_edt(labs!=main)
    keep=np.zeros_like(mask)
    h,w=mask.shape
    for lab in range(1,n+1):
        yy,xx=np.where(labs==lab)
        if not len(xx):continue
        near=dist[yy,xx].min()<6
        centered=(xx.min()>w*.06 and xx.max()<w*.94 and yy.min()>h*.06 and yy.max()<h*.94)
        substantial=len(xx)>counts[main]*min_fraction
        if lab==main or near or (centered and substantial):keep|=(labs==lab)
    a[~keep]=0
    return Image.fromarray(a,'RGBA')

def run():
    for name,src in BANNER_SOURCES.items():
        if not src.exists():continue
        old=MASTER/'08-装饰'/(name+'.png')
        backup=WORK/'cleanup_backup/T3c-semantic'/(name+'.png')
        backup.parent.mkdir(parents=True,exist_ok=True)
        if old.exists() and not backup.exists():shutil.copy2(old,backup)
        shutil.copy2(src,SHEETS/src.name)
        save(name,fit(Image.open(src).convert('RGBA'),(720,200),stretch=True))
    if EVENT_SOURCE.exists():
        old=MASTER/'10-事件图标/event-emergency-light.png'
        backup=WORK/'cleanup_backup/T3c-semantic/event-emergency-light.png'
        backup.parent.mkdir(parents=True,exist_ok=True)
        if old.exists() and not backup.exists():shutil.copy2(old,backup)
        shutil.copy2(EVENT_SOURCE,SHEETS/EVENT_SOURCE.name)
        save('event-emergency-light',fit(Image.open(EVENT_SOURCE).convert('RGBA'),(128,128)))
    icons_b='exec-5fcd21ee-9f82-46bf-a2b2-89baf4964ebc.png'
    for i,n in ((2,'gem-icon'),(4,'invite-icon'),(5,'mail-icon')):
        save(n,fit(isolated(source_cell(icons_b,i,3,3),.025),(128,128)))

    # Re-cut named review failures from their original generated atlas cells.
    decor='exec-7138acdc-6b15-4e02-a341-eb408a6f8eb6.png'
    decnames=['divider_pixel','decor-moon','decor-red-eyes','decor-lightbulb-off',
              'decor-zzz','decor-footprints','decor-ripple-ring','decor-mvp-ribbon',
              'banner_victory_hider','banner_victory_hunter','decor-caught-burst','decor-sparkle']
    for n in ('decor-caught-burst','decor-lightbulb-off','decor-moon','decor-red-eyes',
              'decor-sparkle','decor-footprints'):
        c=isolated(source_cell(decor,decnames.index(n),4,3),.025)
        save(n,fit(c,target_size(n)))

    # A larger cell crop plus component isolation avoids colored arcs from
    # neighboring HUD glyphs, without drawing or replacing any HUD artwork.
    hud='exec-d22dd8d7-e0f8-43da-a65b-5fe3b0b63d02.png'
    hudnames=['hud-joystick-base','hud-joystick-knob','hud-btn-main-interact','hud-btn-main-slap',
       'hud-btn-skill-disguise','hud-btn-skill-flashlight','hud-btn-skill-report','hud-btn-ghost-skill',
       'hud-btn-item-slot','hud-btn-accuse','hud-stamina-frame','hud-stamina-fill',
       'hud-timer-frame','hud-survivor-counter','hud-minimap-frame','hud-disguise-wheel']
    for n in hudnames:
        if n not in ('hud-stamina-frame','hud-stamina-fill','hud-timer-frame','hud-survivor-counter',
                     'hud-btn-skill-report','hud-btn-ghost-skill','hud-btn-item-slot','hud-btn-accuse'):continue
        c=isolated(source_cell(hud,hudnames.index(n),4,4),.03)
        size=target_size(n)
        # Stamina/timer art is narrow; use proportional fit rather than a tiny
        # icon on a huge transparent bar canvas.
        save(n,fit(c,size,stretch=n in ('hud-stamina-frame','hud-stamina-fill',
                                       'hud-timer-frame','hud-survivor-counter')))
    hud2='exec-e512515a-618d-4b2c-81a2-e784c543e917.png'
    for i,n in ((1,'hud-progress-ring'),(2,'hud-edge-arrow')):
        save(n,fit(isolated(source_cell(hud2,i,5,1),.03),target_size(n)))
    sprite='exec-ff9095d5-2b07-4c34-a6cb-db5688db0992.png'
    save('sprite-hider',fit(isolated(source_cell(sprite,0,4,4),.03),(128,192),nearest=True))

    # Opaque floor/wall tiles: use only actual generated texture pixels, not a
    # synthetic mean-color fill at their former transparent key edges.
    tile='exec-d8453725-8c0f-489b-9394-a87bb54ff72b.png'
    for i,n in enumerate(('tile-floor-wood','tile-floor-tile','tile-floor-concrete',
                          'tile-wall-solid','tile-wall-cracked')):
        c=bbox_crop(source_cell(tile,i,3,3))
        # Crop through the transparent border and edge glow into opaque texture.
        a=np.asarray(c)[:,:,3]
        ys,xs=np.where(a>250)
        if len(xs):
            l,t,r,b=int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1
            inset=max(3,round(min(r-l,b-t)*.045))
            c=c.crop((l+inset,t+inset,r-inset,b-inset))
        c=c.convert('RGB').resize((32,32),Image.Resampling.NEAREST)
        save(n,c)
        save(n+'_preview',c.resize((128,128),Image.Resampling.NEAREST))

if __name__=='__main__':run()

"""Slice generated 4x3 sheets, remove chroma, and export content with a 4px transparent margin."""
from pathlib import Path
import json, shutil, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from catalog import OUT, MASTER, WORK, categories, target_size, pages

def remove_chroma(im):
    a=np.asarray(im.convert('RGBA')).copy()
    # Native alpha takes precedence; colored artwork must not be mistaken for a key.
    if np.mean(a[:,:,3]<8)>.08:
        a[a[:,:,3]<8]=0
        return Image.fromarray(a)
    rgb=a[:,:,:3].astype(np.float32)
    samples=np.concatenate([rgb[:4].reshape(-1,3),rgb[-4:].reshape(-1,3),rgb[:,:4].reshape(-1,3),rgb[:,-4:].reshape(-1,3)])
    key=np.array([255,0,255] if np.median(samples[:,0]+samples[:,2]-2*samples[:,1])>0 else [0,255,0],dtype=np.float32)
    dist=np.max(np.abs(rgb-key),axis=2)
    alpha=np.clip((dist-24)/80,0,1)
    a[:,:,3]=(alpha*a[:,:,3]).astype(np.uint8)
    # Unmix key color at partially covered edges, rather than darkening them.
    safe=np.maximum(alpha,.02)[:,:,None]
    unmixed=(rgb-key[None,None,:]*(1-alpha[:,:,None]))/safe
    a[:,:,:3]=np.clip(unmixed,0,255).astype(np.uint8)
    a[a[:,:,3]<8]=0
    return Image.fromarray(a)

def components(mask):
    """8-connected labeling; ignore only very small isolated alpha noise."""
    from scipy.ndimage import label, find_objects
    labels,count=label(mask,np.ones((3,3)))
    sizes=np.bincount(labels.ravel())
    return labels,[(i,sl,int(sizes[i])) for i,sl in enumerate(find_objects(labels),1) if sl and sizes[i]>=12]

def trim(im):
    a=np.asarray(im); ys,xs=np.where(a[:,:,3]>8)
    if not len(xs): return Image.new('RGBA',(8,8),(0,0,0,0))
    box=(max(0,xs.min()-4),max(0,ys.min()-4),min(im.width,xs.max()+5),min(im.height,ys.max()+5))
    return im.crop(box)

def slice_sheet(src, job):
    im=remove_chroma(Image.open(src).convert('RGBA')); w,h=im.size
    cols,rows=job.get('cols',4),job.get('rows',3); names=job['names']
    # Assign connected objects to the nearest declared grid center. This avoids
    # cutting wide objects at the nominal grid edge, and groups detached sparkles.
    arr=np.asarray(im); labels,regions=components(arr[:,:,3]>8)
    buckets=[[] for _ in names]
    for k,sl,area in regions:
        cy=(sl[0].start+sl[0].stop)/2; cx=(sl[1].start+sl[1].stop)/2
        idx=min(rows-1,int(cy/h*rows))*cols+min(cols-1,int(cx/w*cols))
        if idx<len(names): buckets[idx].append((k,sl,area))
    for i,n in enumerate(names):
        regions=buckets[i]
        if not regions: raise ValueError(f'{job["id"]}/{n}: no connected content')
        x0=min(sl[1].start for _,sl,_ in regions); x1=max(sl[1].stop for _,sl,_ in regions)
        y0=min(sl[0].start for _,sl,_ in regions); y1=max(sl[0].stop for _,sl,_ in regions)
        cropped=arr[y0:y1,x0:x1].copy(); kept=np.isin(labels[y0:y1,x0:x1],[k for k,_,_ in regions]); cropped[~kept]=0
        out=Image.fromarray(cropped)
        (WORK/'sheets'/'intermediate'/job['id']).mkdir(parents=True,exist_ok=True)
        out.save(WORK/'sheets'/'intermediate'/job['id']/(n+'.png'))
        tw,th=target_size(n)
        if n.startswith(('sprite-','prop-')):
            logical=(tw//4,th//4)
            out.thumbnail((logical[0]-2,logical[1]-2),Image.Resampling.NEAREST)
            canvas=Image.new('RGBA',logical); canvas.alpha_composite(out,((logical[0]-out.width)//2,(logical[1]-out.height)//2))
            out=canvas.resize((tw,th),Image.Resampling.NEAREST)
        else:
            if categories()[n] in ('03-面板','04-按钮') or n in ('divider_pixel','event-warning-banner') or 'stamina' in n:
                out=out.resize((tw-8,th-8),Image.Resampling.LANCZOS)
            else: out.thumbnail((tw-8,th-8),Image.Resampling.LANCZOS)
            canvas=Image.new('RGBA',(tw,th)); canvas.alpha_composite(out,((tw-out.width)//2,(th-out.height)//2)); out=canvas
        path=MASTER/categories()[n]/(n+'.png'); path.parent.mkdir(parents=True,exist_ok=True); out.save(path)
    shutil.copy2(src, WORK/'sheets'/Path(src).name)

def build_contacts():
    qa=OUT
    groups={'all-transparent-assets':[], 'icons':[], 'avatars':[], 'backgrounds':[], 'hud':[], 'sprites':[]}
    for p in MASTER.rglob('*.png'):
        rel=p.relative_to(MASTER); cat=rel.parts[0]; groups['all-transparent-assets'].append(p)
        if cat in ('05-图标','09-道具图标','10-事件图标'): groups['icons'].append(p)
        if cat=='06-头像': groups['avatars'].append(p)
        if cat=='01-背景' or cat=='13-地图卡': groups['backgrounds'].append(p)
        if cat=='11-HUD控件': groups['hud'].append(p)
        if cat=='12-局内精灵': groups['sprites'].append(p)
    for key, files in groups.items():
        if not files: continue
        cell=180; cols=6; rows=(len(files)+cols-1)//cols
        canvas=Image.new('RGBA',(cols*cell,rows*cell),(205,205,205,255))
        d=ImageDraw.Draw(canvas)
        for i,p in enumerate(sorted(files)):
            x=i%cols*cell; y=i//cols*cell; q=Image.open(p).convert('RGBA'); q.thumbnail((cell-16,cell-36),Image.Resampling.LANCZOS)
            canvas.alpha_composite(q,(x+(cell-q.width)//2,y+4)); d.text((x+4,y+cell-28),p.stem[:25],fill=(20,20,30,255))
        canvas.convert('RGB').save(qa/f'_QA-{key}-contact-sheet.png')

if __name__=='__main__':
    data=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8')) if len(sys.argv)>1 else []
    for job in data: slice_sheet(job['source'],job)
    build_contacts()

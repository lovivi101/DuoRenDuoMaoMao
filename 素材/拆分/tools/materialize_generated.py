from PIL import Image
from pathlib import Path

ROOT=Path(r'E:\Game_Work\AI 游戏\多人躲猫猫')
GEN=Path(r'C:\Users\Administrator\.codex\generated_images\01a0e71d-d07f-7911-a8c0-6c880de13892')
OUT=ROOT/'素材'/'UI拆分资产'/'00-共享资产'

SHEETS={
 'icons_a':('exec-506dfb7a-c1b3-4980-9ef5-d4b2320a446a.png',3,3),
 'icons_b':('exec-5fcd21ee-9f82-46bf-a2b2-89baf4964ebc.png',3,3),
 'icons_c':('exec-7c6bbc07-4127-4f5e-9914-1678f8334438.png',3,3),
 'icons_d':('exec-f82fc456-d6d6-40ba-95be-896f558ec1bc.png',2,2),
 'items_a':('exec-4546c7df-4db2-4c2f-99fb-6aeea5b392bb.png',3,3),
 'items_b':('exec-487d3537-0d08-46ce-af88-bf048610331e.png',3,3),
 'items_c':('exec-dd5e651a-f559-4add-896d-a759b21d7c2a.png',3,3),
 'events':('exec-81a64545-fffb-46bc-a360-f737fc1c28cc.png',3,3),
}

MAPS={
 'icons_a':['add-friend-icon','check-icon','coin-icon','copy-icon','crown-icon','dice-icon','task-icon','timer-icon','trophy-icon'],
 'icons_b':['exit-icon','friends-icon','gem-icon','heart-icon','invite-icon','mail-icon','map-icon','mic-icon','notice-icon'],
 'icons_c':['plus-icon','record-icon','refresh-icon','robot-icon','search-icon','share-icon','shop-icon','skull-icon','star-icon'],
 'icons_d':['vibration-icon','wardrobe-icon'],
 'items_a':['item-frame-common','item-frame-rare','item-frame-legendary','item-hider-decoy','item-hider-dynamite','item-hider-invis-cloak','item-hider-jammer','item-hider-master-key','item-hider-mirror'],
 'items_b':['item-hider-smoke','item-hider-speed-shoes','item-hider-wood-board','item-hunter-bell-trap','item-hunter-door-nails','item-hunter-full-scan','item-hunter-heart-radar','item-hunter-iron-fence','item-hunter-net'],
 'items_c':['item-box','item-hider-banana','item-hider-energy-drink','item-hunter-sprint-shoes','item-hunter-strong-flashlight','item-hunter-tracker','item-hunter-wall-hammer'],
 'events':['event-adrenaline','event-airdrop','event-blackout','event-broadcast','event-emergency-light','event-final-30s','event-fog','event-hunter-confused','event-lockdown'],
}

def extract(im, idx, cols, rows, size=(128,128)):
    w,h=im.size; cw,ch=w/cols,h/rows
    x0=int(idx%cols*cw); y0=int(idx//cols*ch); x1=int((idx%cols+1)*cw); y1=int((idx//cols+1)*ch)
    cell=im.crop((x0,y0,x1,y1)).convert('RGBA')
    # remove residual chroma spill from generated atlas edges (allowed chroma extraction)
    px=cell.load()
    for yy in range(cell.height):
        for xx in range(cell.width):
            r,g,b,a0=px[xx,yy]
            if (r>170 and r>g*1.35 and r>b*1.25) or (g>150 and g>r*1.35 and g>b*1.15):
                px[xx,yy]=(r,g,b,0)
    a=cell.getchannel('A'); bb=a.getbbox()
    if bb: cell=cell.crop(bb)
    cell.thumbnail((size[0]-8,size[1]-8),Image.Resampling.LANCZOS)
    out=Image.new('RGBA',size,(0,0,0,0)); out.alpha_composite(cell,((size[0]-cell.width)//2,(size[1]-cell.height)//2))
    return out

for key,(fn,cols,rows) in SHEETS.items():
    im=Image.open(GEN/fn)
    names=MAPS[key]
    cat='05-图标' if key.startswith('icons') else ('09-道具图标' if key.startswith('items') else '10-事件图标')
    d=OUT/cat; d.mkdir(parents=True,exist_ok=True)
    for i,name in enumerate(names):
        extract(im,i,cols,rows).save(d/(name+'.png'))

print('materialized',sum(len(v) for v in MAPS.values()))

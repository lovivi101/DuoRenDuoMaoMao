"""Slice only image_gen atlases; no programmatic art is created here."""
from pathlib import Path
from PIL import Image
import shutil
from catalog import target_size

ROOT = Path(r'E:\Game_Work\AI 游戏\多人躲猫猫')
GEN = Path(r'C:\Users\Administrator\.codex\generated_images\01a0e765-dc0d-7132-9aed-7d8db76c9e94')
SHEETS = ROOT/'素材/拆分/sheets'
MASTER = ROOT/'素材/UI拆分资产/00-共享资产'

SPRITES = ['sprite-hider','sprite-hunter','sprite-ghost','sprite-cage',
           'sprite-generator','sprite-generator-fixed','sprite-item-box','prop-cardboard-box',
           'prop-chair','prop-potted-plant','prop-pillow','prop-desk-lamp',
           'prop-trash-can','prop-oil-drum','prop-food-tray','tile-furniture']
HUD_A = ['hud-joystick-base','hud-joystick-knob','hud-btn-main-interact','hud-btn-main-slap',
         'hud-btn-skill-disguise','hud-btn-skill-flashlight','hud-btn-skill-report','hud-btn-ghost-skill',
         'hud-btn-item-slot','hud-btn-accuse','hud-stamina-frame','hud-stamina-fill',
         'hud-timer-frame','hud-survivor-counter','hud-minimap-frame','hud-disguise-wheel']
HUD_B = ['hud-mark-wheel','hud-progress-ring','hud-edge-arrow','hud-cooldown-mask','tile-shelf']

def sliced(filename, names, cols, rows, kind):
    src=GEN/filename
    if not src.exists(): return
    SHEETS.mkdir(parents=True,exist_ok=True)
    shutil.copy2(src,SHEETS/filename)
    im=Image.open(src).convert('RGBA')
    w,h=im.size
    for i,n in enumerate(names):
        x,y=i%cols,i//cols
        cell=im.crop((round(x*w/cols),round(y*h/rows),round((x+1)*w/cols),round((y+1)*h/rows)))
        a=cell.getchannel('A'); bbox=a.getbbox()
        if not bbox: continue
        cell=cell.crop(bbox)
        cat='12-局内精灵' if n.startswith(('sprite-','prop-','tile-')) else '11-HUD控件'
        if cat=='12-局内精灵':
            size=(128,192) if n in ('sprite-hider','sprite-hunter','sprite-ghost') else (128,128)
            method=Image.Resampling.NEAREST
        else:
            size=target_size(n)
            method=Image.Resampling.LANCZOS
        # Fit inside transparent canvas with four-pixel safety margin, preserving the generated image's alpha.
        cell.thumbnail((size[0]-8,size[1]-8),method)
        out=Image.new('RGBA',size,(0,0,0,0))
        out.alpha_composite(cell,((size[0]-cell.width)//2,(size[1]-cell.height)//2))
        d=MASTER/cat; d.mkdir(parents=True,exist_ok=True)
        out.save(d/(n+'.png'))

sliced('exec-ff9095d5-2b07-4c34-a6cb-db5688db0992.png',SPRITES,4,4,'sprite')
sliced('exec-d22dd8d7-e0f8-43da-a65b-5fe3b0b63d02.png',HUD_A,4,4,'hud')
sliced('exec-e512515a-618d-4b2c-81a2-e784c543e917.png',HUD_B,5,1,'hud')

def sheet_ui(filename,names,cols,rows,cat):
    src=GEN/filename
    shutil.copy2(src,SHEETS/filename)
    im=Image.open(src).convert('RGBA'); w,h=im.size
    d=MASTER/cat; d.mkdir(parents=True,exist_ok=True)
    for i,n in enumerate(names):
        x,y=i%cols,i//cols
        cell=im.crop((round(x*w/cols),round(y*h/rows),round((x+1)*w/cols),round((y+1)*h/rows)))
        bb=cell.getchannel('A').getbbox()
        if not bb: continue
        cell=cell.crop(bb)
        size=target_size(n) if not n.startswith('unused-') else (128,128)
        cell.thumbnail((size[0]-8,size[1]-8),Image.Resampling.LANCZOS)
        out=Image.new('RGBA',size,(0,0,0,0))
        out.alpha_composite(cell,((size[0]-cell.width)//2,(size[1]-cell.height)//2))
        out.save(d/(n+'.png'))

sheet_ui('exec-1ed02831-4ad9-44ef-84cc-1a498a6373d0.png',[
    'button_primary_yellow','button_primary_yellow_pressed','button_secondary_dark','button_secondary_dark_pressed',
    'button_danger_red','button_account_purple','button_guest_ghost','button_phone_blue',
    'button_ready_green','button_small_action'],2,5,'04-按钮')
# The first generated rarity sheet has alpha-zero hollow centers; the second retry was unrelated and discarded.
frame_sheet='exec-eb0dab56-846d-44d3-b33e-7bc3f057902d.png'
sheet_ui(frame_sheet,['item-frame-common','item-frame-rare','item-frame-legendary'],2,2,'09-道具图标')
sheet_ui(frame_sheet,['unused-top-left','unused-top-right','unused-bottom-left','event-warning-banner'],2,2,'10-事件图标')
for n in ('unused-top-left','unused-top-right','unused-bottom-left'):
    (MASTER/'10-事件图标'/(n+'.png')).unlink(missing_ok=True)

tile_source=GEN/'exec-d8453725-8c0f-489b-9394-a87bb54ff72b.png'
shutil.copy2(tile_source,SHEETS/tile_source.name)
tile_sheet=Image.open(tile_source).convert('RGBA'); tw,th=tile_sheet.size
tile_names=['tile-floor-wood','tile-floor-tile','tile-floor-concrete',
            'tile-wall-solid','tile-wall-cracked','tile-rubble',
            'tile-door','tile-shelf','tile-furniture']
for i,n in enumerate(tile_names):
    x,y=i%3,i//3
    c=tile_sheet.crop((round(x*tw/3),round(y*th/3),round((x+1)*tw/3),round((y+1)*th/3)))
    bb=c.getchannel('A').getbbox()
    if not bb: continue
    c=c.crop(bb)
    # Terrain from image_gen only; 32px game tile and nearest-neighbor 4x preview.
    tile=c.resize((32,32),Image.Resampling.NEAREST)
    d=MASTER/'12-局内精灵'
    tile.save(d/(n+'.png'))
    tile.resize((128,128),Image.Resampling.NEAREST).save(d/(n+'_preview.png'))

vig_source=GEN/'exec-81359794-0ebc-49cf-b759-812c93b93fed.png'
shutil.copy2(vig_source,SHEETS/vig_source.name)
Image.open(vig_source).convert('RGBA').resize((1334,750),Image.Resampling.LANCZOS).save(MASTER/'11-HUD控件/hud-vignette-red.png')
print('Materialized generated atlas components')

dec_source=GEN/'exec-7138acdc-6b15-4e02-a341-eb408a6f8eb6.png'
shutil.copy2(dec_source,SHEETS/dec_source.name)
di=Image.open(dec_source).convert('RGBA'); dw,dh=di.size
dec_names=['divider_pixel','decor-moon','decor-red-eyes','decor-lightbulb-off','decor-zzz','decor-footprints','decor-ripple-ring','decor-mvp-ribbon','banner_victory_hider','banner_victory_hunter','decor-caught-burst','decor-sparkle']
for i,n in enumerate(dec_names):
    x,y=i%4,i//4; c=di.crop((round(x*dw/4),round(y*dh/3),round((x+1)*dw/4),round((y+1)*dh/3)))
    bb=c.getchannel('A').getbbox()
    if not bb: continue
    c=c.crop(bb); size=target_size(n); c.thumbnail((size[0]-8,size[1]-8),Image.Resampling.LANCZOS)
    out=Image.new('RGBA',size,(0,0,0,0)); out.alpha_composite(c,((size[0]-c.width)//2,(size[1]-c.height)//2)); out.save(MASTER/'08-装饰'/(n+'.png'))

logo_source=GEN/'exec-0e6cb771-a3db-44dd-aaef-a682f04b312a.png'
shutil.copy2(logo_source,SHEETS/logo_source.name)
li=Image.open(logo_source).convert('RGBA'); lw,lh=li.size
for i,n in enumerate(['game_logo_title','app_icon_1024','crest_hunter','crest_hider']):
    x,y=i%2,i//2; c=li.crop((round(x*lw/2),round(y*lh/2),round((x+1)*lw/2),round((y+1)*lh/2))); bb=c.getchannel('A').getbbox()
    if not bb: continue
    c=c.crop(bb); size=target_size(n); c.thumbnail((size[0]-8,size[1]-8),Image.Resampling.LANCZOS); out=Image.new('RGBA',size,(0,0,0,0)); out.alpha_composite(c,((size[0]-c.width)//2,(size[1]-c.height)//2));
    if n=='app_icon_1024':
        bg=Image.new('RGBA',size,(27,22,62,255)); bg.alpha_composite(out); out=bg
    out.save(MASTER/'02-Logo'/(n+'.png'))

ghost_source=GEN/'exec-f8167945-6e19-4456-926d-51c4573dea8e.png'; shutil.copy2(ghost_source,SHEETS/ghost_source.name)
gi=Image.open(ghost_source).convert('RGBA'); gw,gh=gi.size
for i,n in enumerate(['role-ghost-guardian','role-ghost-wraith']):
    c=gi.crop((round(i*gw/2),0,round((i+1)*gw/2),gh)); bb=c.getchannel('A').getbbox()
    if not bb: continue
    c=c.crop(bb); size=(256,256); c.thumbnail((248,248),Image.Resampling.LANCZOS); out=Image.new('RGBA',size,(0,0,0,0)); out.alpha_composite(c,((size[0]-c.width)//2,(size[1]-c.height)//2)); out.save(MASTER/'07-身份徽记'/(n+'.png'))

map_source=GEN/'exec-cb31fe76-3967-4642-b16d-ba4c159bd7ad.png'
shutil.copy2(map_source,SHEETS/map_source.name)
mi=Image.open(map_source).convert('RGB'); mw,mh=mi.size
map_names=['map-old-dorm','map-night-hospital','map-night-mall','map-midnight-cruise','map-snow-lodge']
for i,n in enumerate(map_names):
    c=mi.crop((0,round(i*mh/5),mw,round((i+1)*mh/5)))
    c.resize((640,360),Image.Resampling.LANCZOS).save(MASTER/'13-地图卡'/(n+'.png'))

background_sources=[
 ('exec-57b6368e-16e3-43c8-b767-f21e7321c2af.png',['bg-splash-dorm-night','bg-login-dorm-gate','bg-lobby-dorm-hall']),
 ('exec-abcb5a47-8d47-4da7-87f1-0d60047fdf5c.png',['bg-matching-corridor','bg-room-waiting-hall','bg-role-reveal-dark']),
 ('exec-e6d6badb-1fff-4e61-b09b-ed9b0938d290.png',['bg-map-vote-blueprint','bg-result-dawn','bg-menu-dim'])]
for filename,names in background_sources:
    src=GEN/filename; shutil.copy2(src,SHEETS/filename); im=Image.open(src).convert('RGB'); w,h=im.size
    for i,n in enumerate(names):
        im.crop((0,round(i*h/3),w,round((i+1)*h/3))).resize((1334,750),Image.Resampling.LANCZOS).save(MASTER/'01-背景'/(n+'.png'))

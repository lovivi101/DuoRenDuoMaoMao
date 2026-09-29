"""Publish image_gen masters as page-specific copies and QA contact sheets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import csv, json, shutil, sys
sys.path.insert(0,str(Path(__file__).parent))
from catalog import OUT, MASTER, ROOT, pages, categories

CAT=categories(); UI=ROOT/'素材/UI流程图/单页界面'
GROUPS=sorted(set(CAT.values()))
BASE=['panel_header_bar','panel_modal','panel_toast','back-icon','close-icon']
PAGE={
 1:'bg-splash-dorm-night game_logo_title progress_bar_frame progress_bar_fill panel_notice_board',
 2:'bg-login-dorm-gate game_logo_title button_wechat_green button_wechat_green_pressed button_phone_blue button_account_purple button_guest_ghost wechat-icon phone-icon checkbox_off checkbox_on',
 3:'bg-login-dorm-gate panel_input_field button_primary_yellow button_small_action phone-icon timer-icon',
 4:'bg-login-dorm-gate panel_input_field button_primary_yellow tab_active tab_inactive eye-open-icon eye-closed-icon lock-icon user-icon',
 5:'bg-lobby-dorm-hall panel_content_large panel_input_field button_primary_yellow dice-icon avatar-hider-red avatar-hider-orange avatar-hider-yellow avatar-hider-green avatar-hider-cyan avatar-hider-blue avatar-hider-purple avatar-hider-pink',
 6:'bg-lobby-dorm-hall panel_top_resource_bar panel_bottom_nav button_primary_yellow button_secondary_dark coin-icon gem-icon settings-icon friends-icon wardrobe-icon shop-icon record-icon task-icon avatar-hider-blue',
 7:'bg-matching-corridor panel_player_card button_secondary_dark timer-icon robot-icon avatar-empty-slot avatar-ai-bot',
 8:'bg-room-waiting-hall panel_content_large button_primary_yellow card_map_frame toggle_on toggle_off map-icon timer-icon role-hunter role-mole map-*',
 9:'bg-room-waiting-hall panel_keypad panel_room_code_cell button_primary_yellow button_small_action copy-icon',
 10:'bg-room-waiting-hall panel_player_card button_ready_green button_primary_yellow copy-icon share-icon invite-icon crown-icon check-icon avatar-empty-slot avatar-ai-bot',
 11:'bg-map-vote-blueprint card_map_frame timer-icon check-icon map-*',
 12:'bg-role-reveal-dark card_role_back card_role_front role-hunter role-hider role-mole timer-icon map-icon',
 13:'hud-joystick-base hud-joystick-knob hud-btn-main-interact hud-btn-skill-disguise hud-btn-item-slot hud-stamina-frame hud-stamina-fill hud-timer-frame hud-survivor-counter hud-minimap-frame hud-disguise-wheel hud-progress-ring sprite-hider sprite-generator sprite-generator-fixed sprite-item-box prop-* tile-* item-hider-* event-*',
 14:'hud-joystick-base hud-joystick-knob hud-btn-main-slap hud-btn-skill-flashlight hud-btn-item-slot hud-stamina-frame hud-stamina-fill hud-timer-frame hud-minimap-frame hud-edge-arrow sprite-hunter tile-* item-hunter-*',
 15:'decor-caught-burst role-ghost-guardian role-ghost-wraith avatar-ghost-guardian avatar-ghost-wraith sprite-ghost hud-btn-ghost-skill hud-cooldown-mask',
 16:'event-warning-banner event-final-30s event-blackout event-emergency-light hud-vignette-red hud-timer-frame hud-edge-arrow',
 17:'bg-result-dawn banner_victory_hider banner_victory_hunter decor-mvp-ribbon panel_score_row button_primary_yellow button_secondary_dark share-icon coin-icon trophy-icon star-icon avatar-hunter-warden',
 18:'bg-menu-dim panel_list_row panel_input_field button_small_action friends-icon add-friend-icon invite-icon search-icon wechat-icon qq-icon share-icon avatar-empty-slot',
 19:'bg-menu-dim panel_list_row slider_track slider_fill slider_knob toggle_on toggle_off sound-on-icon sound-off-icon vibration-icon settings-icon exit-icon wechat-icon phone-icon',
}

def names_for(i):
    patterns=PAGE[i].split()+(BASE if i<=12 or i>=17 else [])
    names=set()
    for pat in patterns:
        names.update(n for n in CAT if n.startswith(pat[:-1]) if pat.endswith('*')) if pat.endswith('*') else names.add(pat)
    return sorted(n for n in names if n in CAT and (MASTER/CAT[n]/(n+'.png')).exists())

def contact(dest,files,cell=156,cols=6):
    files=sorted(set(files),key=lambda p:p.stem); rows=max(1,(len(files)+cols-1)//cols)
    canvas=Image.new('RGBA',(cols*cell,rows*(cell+28)),(50,52,70,255)); d=ImageDraw.Draw(canvas)
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',11)
    for i,p in enumerate(files):
        x=(i%cols)*cell;y=(i//cols)*(cell+28)
        for cy in range(0,cell-24,16):
            for cx in range(0,cell,16):
                c=(205,205,210,255) if ((cx+cy)//16)%2 else (232,232,235,255)
                d.rectangle((x+cx,y+cy,x+cx+15,y+cy+15),fill=c)
        im=Image.open(p).convert('RGBA');im.thumbnail((cell-12,cell-36),Image.Resampling.LANCZOS)
        canvas.alpha_composite(im,(x+(cell-im.width)//2,y+(cell-32-im.height)//2))
        d.text((x+3,y+cell-22),p.stem[:24],font=font,fill=(255,255,255,255))
    dest.parent.mkdir(parents=True,exist_ok=True);canvas.convert('RGB').save(dest)

def publish():
    mapping={};counts=[]
    for i,page in enumerate(pages(),1):
        base=OUT/page;base.mkdir(exist_ok=True)
        # Delete only asset-category copies inside a verified page folder.
        for cat in GROUPS:
            target=(base/cat).resolve()
            if target.parent!=base.resolve():raise RuntimeError(f'Unsafe target: {target}')
            if target.exists():shutil.rmtree(target)
        names=names_for(i);mapping[page]=names
        for n in names:
            dest=base/CAT[n];dest.mkdir(exist_ok=True)
            shutil.copy2(MASTER/CAT[n]/(n+'.png'),dest/(n+'.png'))
        src=UI/(page+'-1334x750.png'); raw=base/'00-原始UI';raw.mkdir(exist_ok=True)
        if src.exists():shutil.copy2(src,raw/src.name)
        contact(base/'99-拆分预览'/'组件总览-透明棋盘.png',
                [MASTER/CAT[n]/(n+'.png') for n in names])
        counts.append((page,len(names)))
    with (OUT/'PAGE_ASSET_COUNTS.csv').open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.writer(f);w.writerow(['page','asset_count']);w.writerows(counts)
    lines=['# T3 页面资产映射','','母版为 `00-共享资产`，以下仅列本页使用的副本。','']
    for p,names in mapping.items():lines += [f'## {p}（{len(names)}）','',', '.join(f'`{n}`' for n in names),'']
    (OUT/'ASSET_MANIFEST.md').write_text('\n'.join(lines),encoding='utf-8')
    nine={n:([24,16,24,16] if CAT[n]=='04-按钮' else [24,24,24,24])
          for n in CAT if CAT[n] in ('03-面板','04-按钮')}
    nine.update({'hud-stamina-frame':[10,8,10,8],'event-warning-banner':[24,12,24,12]})
    (OUT/'NINE_PATCH.json').write_text(json.dumps(nine,ensure_ascii=False,indent=2),encoding='utf-8')
    qa={
      'all-transparent-assets':[p for p in MASTER.rglob('*.png') if p.parent.name not in ('01-背景','13-地图卡')],
      'icons':[p for c in ('05-图标','09-道具图标','10-事件图标') for p in (MASTER/c).glob('*.png')],
      'avatars':list((MASTER/'06-头像').glob('*.png')),
      'backgrounds':[p for c in ('01-背景','13-地图卡') for p in (MASTER/c).glob('*.png')],
      'hud':list((MASTER/'11-HUD控件').glob('*.png')),
      'sprites':list((MASTER/'12-局内精灵').glob('*.png')),
      'original-ui':list(UI.glob('*.png')),
    }
    for k,files in qa.items():contact(OUT/f'_QA-{k}-contact-sheet.png',files)
    print('published',len(mapping),'pages;',sum(c for _,c in counts),'copies')

if __name__=='__main__':publish()

"""T3 shared paths and specification. Reads the acceptance list without modifying it."""
from pathlib import Path
import re, json
ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / '素材/拆分'
OUT = ROOT / '素材/UI拆分资产'
MASTER = OUT / '00-共享资产'
DOC = ROOT / '文档/01-策划分析与素材需求.md'

def requirements():
    section = DOC.read_text(encoding='utf-8').split('## 6.')[1].split('## 7.')[0]
    result = {}
    for line in section.splitlines():
        m = re.match(r'\*\*(\d\d-[^（*]+)', line)
        if not m: continue
        category = m.group(1)
        for group in re.findall(r'`([^`]+)`', line):
            parts = group.split('|')
            result[parts[0]] = category
            if len(parts) > 1:
                # The document abbreviates the common prefix after the first pipe.
                prefix = {'06-头像':'avatar-hider-', '09-道具图标': 'item-hunter-' if group.startswith('item-hunter-') else 'item-hider-' if group.startswith('item-hider-') else 'item-frame-'}[category]
                for p in parts[1:]: result[prefix+p] = category
    return result

EXTRA = ['button_primary_yellow_pressed','button_secondary_dark_pressed','button_wechat_green_pressed']
def categories():
    result = requirements()
    result.update({n:'04-按钮' for n in EXTRA})
    result.update({n:'12-局内精灵' for n in ('tile-furniture','tile-shelf')})
    result.update({n+'_preview':'12-局内精灵' for n in list(result) if n.startswith('tile-')})
    return result

def target_size(n):
    cat = categories()[n]
    if cat == '01-背景' or n == 'hud-vignette-red': return (1334,750)
    if cat == '13-地图卡': return (640,360)
    if n == 'app_icon_1024': return (1024,1024)
    if n == 'game_logo_title': return (720,300)
    if cat in ['06-头像','07-身份徽记'] or n.startswith('crest_'): return (256,256)
    if n.startswith('tile-'): return (128,128) if n.endswith('_preview') else (32,32)
    if n in ['sprite-hider','sprite-hunter','sprite-ghost']: return (128,192)
    if cat == '12-局内精灵': return (128,128)
    if cat in ['05-图标','09-道具图标','10-事件图标'] and n!='event-warning-banner': return (128,128)
    sizes = {
      'panel_header_bar':(1000,100),'panel_content_large':(960,600),'panel_modal':(720,480),
      'panel_list_row':(800,120),'panel_input_field':(640,100),'panel_bottom_nav':(1100,120),
      'panel_top_resource_bar':(400,100),'panel_toast':(640,120),'panel_player_card':(240,320),
      'panel_score_row':(800,100),'panel_keypad':(640,480),'panel_room_code_cell':(100,120),
      'panel_notice_board':(720,480), 'button_round_icon':(128,128),'button_small_action':(240,96),
      'tab_active':(240,96),'tab_inactive':(240,96),'toggle_on':(160,80),'toggle_off':(160,80),
      'checkbox_on':(80,80),'checkbox_off':(80,80),'slider_track':(480,32),'slider_fill':(480,32),
      'slider_knob':(64,64),'card_role_back':(320,480),'card_role_front':(320,480),'card_map_frame':(656,376),
      'progress_bar_frame':(640,48),'progress_bar_fill':(624,32),
      'divider_pixel':(720,24),'decor-mvp-ribbon':(480,160),'banner_victory_hider':(720,200),
      'banner_victory_hunter':(720,200),'decor-caught-burst':(600,300),'event-warning-banner':(960,120),
      'hud-joystick-base':(256,256),'hud-joystick-knob':(128,128),
      'hud-btn-main-interact':(200,200),'hud-btn-main-slap':(200,200),
      'hud-stamina-frame':(320,40),'hud-stamina-fill':(304,24),'hud-timer-frame':(240,80),
      'hud-survivor-counter':(240,80),'hud-minimap-frame':(256,256),'hud-disguise-wheel':(400,400),
      'hud-mark-wheel':(400,400),'hud-progress-ring':(200,200),'hud-edge-arrow':(96,96),
      'hud-cooldown-mask':(140,140)}
    if n in sizes: return sizes[n]
    if n.startswith('hud-btn-'): return (140,140)
    if n.startswith('button_'): return (480,120)
    return (256,256)

def pages():
    section=DOC.read_text(encoding='utf-8').split('## 3.')[1].split('## 4.')[0]
    return [f'{m[0]}-{m[1]}' for m in re.findall(r'\| (\d\d) \| ([^|]+?) \|',section)]

if __name__ == '__main__':
    for cat in set(categories().values()): (MASTER/cat).mkdir(parents=True,exist_ok=True)
    for p in pages():
        (OUT/p/'00-原始UI').mkdir(parents=True,exist_ok=True)
        (OUT/p/'99-拆分预览').mkdir(parents=True,exist_ok=True)
    print(json.dumps({'required':len(requirements()),'with_extras':len(categories()),'pages':pages()},ensure_ascii=False))

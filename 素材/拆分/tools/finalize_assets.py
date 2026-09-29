from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import shutil, json, csv, sys
sys.path.insert(0,str(Path(__file__).parent))
from catalog import OUT, MASTER, pages, categories

ROOT=OUT.parent.parent
ORIG=ROOT/'素材'/'拆分'/'原图'

def copy_pages():
    cats=sorted({c for n,c in categories().items()})
    for p in pages():
        pd=OUT/p/'00-原始UI'; pd.mkdir(parents=True,exist_ok=True)
        src=ORIG/(p+'-1334x750.png')
        if src.exists(): shutil.copy2(src,pd/src.name)
        for cat in cats:
            files=list((MASTER/cat).glob('*.png'))
            if not files: continue
            d=OUT/p/cat; d.mkdir(parents=True,exist_ok=True)
            for f in files:
                shutil.copy2(f,d/f.name)

def contact(name, cats, cell=144, cols=8):
    files=[]
    for cat in cats: files += sorted((MASTER/cat).glob('*.png'))
    if not files: return
    rows=(len(files)+cols-1)//cols
    out=Image.new('RGBA',(cols*cell,rows*(cell+24)),(34,38,52,255))
    draw=ImageDraw.Draw(out)
    for i,f in enumerate(files):
        im=Image.open(f).convert('RGBA'); im.thumbnail((cell-12,cell-20),Image.Resampling.LANCZOS)
        x=(i%cols)*cell+(cell-im.width)//2; y=(i//cols)*(cell+24)+(cell-im.height)//2
        out.alpha_composite(im,(x,y)); draw.text(((i%cols)*cell+3,(i//cols)*(cell+24)+cell+3),f.stem[:22],fill=(255,255,255,255))
    out.convert('RGB').save(OUT/name)

def docs():
    manifest={"pages":{},"generated_categories":{},"known_gaps":[]}
    for cat in sorted({c for n,c in categories().items()}):
        fs=sorted(f.name for f in (MASTER/cat).glob('*.png'))
        if fs: manifest['generated_categories'][cat]=fs
    for p in pages(): manifest['pages'][p]=manifest['generated_categories']
    (OUT/'ASSET_MANIFEST.md').write_text('# T3 UI拆分资产清单\n\n本轮由内置 image_gen 生成的资产已写入共享目录；页面目录同步副本。\n\n## 已生成类别\n'+ '\n'.join(f'- {k}: {len(v)}' for k,v in manifest['generated_categories'].items())+'\n\n## 已知缺口\n- 01-背景、02-Logo、04-按钮、07-身份徽记、08-装饰、11-HUD控件、12-局内精灵、13-地图卡尚未完成 image_gen 出图。占位待替换目录保留未动。\n',encoding='utf-8')
    (OUT/'README.md').write_text('# T3 UI拆分资产\n\n所有本轮新增组件均来自内置 image_gen；PIL 仅用于裁切、缩放、透明边界处理、联系表与副本同步。\n\n九宫格建议：按钮左右 24、上下 16；普通面板 24；输入框 16；进度条 12。\n\n已知瑕疵：部分图标为同一 atlas 生成，仍需统筹逐项目视复核；未完成类别见 ASSET_MANIFEST.md。\n',encoding='utf-8')
    nine={k:[24,16,24,16] for k in ['button_primary_yellow','button_primary_yellow_pressed','button_secondary_dark','button_secondary_dark_pressed','button_danger_red','button_account_purple','button_guest_ghost','button_phone_blue','button_ready_green','button_small_action','button_wechat_green','button_wechat_green_pressed']}
    nine.update({'panel_modal':[24,24,24,24],'panel_content_large':[24,24,24,24],'panel_header_bar':[20,20,20,20],'progress_bar_frame':[12,12,12,12]})
    (OUT/'NINE_PATCH.json').write_text(json.dumps(nine,ensure_ascii=False,indent=2),encoding='utf-8')
    rows=[]
    for p in pages():
        rows.append([p,sum(len(list((OUT/p/c).glob('*.png'))) for c in {c for n,c in categories().items()})])
    with (OUT/'PAGE_ASSET_COUNTS.csv').open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.writer(f); w.writerow(['page','asset_count']); w.writerows(rows)

copy_pages()
contact('_QA-icons-contact-sheet.png',['05-图标'])
contact('_QA-all-transparent-assets-contact-sheet.png',['03-面板','04-按钮','05-图标','06-头像','07-身份徽记','08-装饰','09-道具图标','10-事件图标','11-HUD控件','12-局内精灵'])
contact('_QA-hud-contact-sheet.png',['11-HUD控件'])
contact('_QA-sprites-contact-sheet.png',['12-局内精灵'])
contact('_QA-backgrounds-contact-sheet.png',['01-背景','13-地图卡'])
docs()
print('finalized pages',len(pages()))

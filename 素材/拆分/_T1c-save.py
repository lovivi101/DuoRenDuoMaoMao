from PIL import Image
from pathlib import Path
import shutil, sys
root=Path(r'E:/Game_Work/AI 游戏/多人躲猫猫')
src=Path(sys.argv[1]); name=sys.argv[2]; group=sys.argv[3] if len(sys.argv)>3 else '单页界面'
target=root/'素材/UI流程图'/group/(name+'-1334x750.png')
raw=root/'素材/拆分/原图'/target.name
shutil.copy2(src,raw)
with Image.open(src) as im:
    original=im.size
    im.convert('RGB').resize((1334,750),Image.Resampling.LANCZOS).save(target,'PNG')
with Image.open(target) as im:
    assert im.format=='PNG' and im.size==(1334,750)
if group=='单页界面': shutil.copy2(target,root/'素材/UI未拆分'/target.name)
print(f'{target.name}: {original} -> 1334x750 PNG verified')

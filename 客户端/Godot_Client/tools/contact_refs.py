from PIL import Image, ImageDraw
from pathlib import Path
root=Path.cwd()
files=sorted((root/'素材/UI流程图/单页界面').glob('*.png'))+list((root/'素材/参考').glob('*.png'))[:1]
for start in range(0,len(files),6):
 group=files[start:start+6]; out=Image.new('RGB',(1000,3*306),(15,13,30)); d=ImageDraw.Draw(out)
 for n,f in enumerate(group):
  im=Image.open(f); im.thumbnail((496,280)); x=(n%2)*500; y=(n//2)*306; out.paste(im,(x,y)); d.text((x+6,y+282),f.name[:2],fill='white')
 out.save(root/'客户端/Godot_Client/docs'/('ref-%02d.jpg'%start))

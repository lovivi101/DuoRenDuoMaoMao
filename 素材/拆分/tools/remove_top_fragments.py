"""Crop isolated, visibly foreign top slivers from four image_gen outputs."""
from PIL import Image
from catalog import MASTER

CUT={
 'sprite-generator':('12-局内精灵',22),
 'sprite-generator-fixed':('12-局内精灵',22),
 'event-broadcast':('10-事件图标',20),
 'sprite-item-box':('12-局内精灵',20),
 'heart-icon':('05-图标',25),
}
for name,(cat,y) in CUT.items():
    p=MASTER/cat/(name+'.png')
    with Image.open(p) as src:im=src.convert('RGBA')
    # Only vertical crop and transparent paste; no pixels of the subject change.
    out=Image.new('RGBA',im.size)
    out.alpha_composite(im.crop((0,y,im.width,im.height)),(0,y))
    out.save(p)
    print(name,'removed top',y,'px')

name='hud-cooldown-mask';p=MASTER/'11-HUD控件'/(name+'.png')
with Image.open(p) as src:im=src.convert('RGBA')
out=Image.new('RGBA',im.size)
out.alpha_composite(im.crop((0,0,100,im.height)),(0,0))
out.save(p)
print(name,'removed detached right strip')

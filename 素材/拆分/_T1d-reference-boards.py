from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PAGES = ROOT / '素材/UI流程图/单页界面'
OUT = ROOT / '素材/拆分/流程参考'
OUT.mkdir(parents=True, exist_ok=True)

groups = {
    '01-启动与登录': [1, 2, 3, 4, 5, 6],
    '02-主界面与进房': [6, 7, 8, 9, 10],
    '03-开局流程': [10, 11, 12],
    '04-追捕期核心交互': [13, 14],
    '05-事件、被抓与幽灵': [16, 14, 15, 13],
    '06-结算与循环': [17, 10, 6, 18],
}

font_path = Path('C:/Windows/Fonts/msyh.ttc')
font = ImageFont.truetype(str(font_path), 25)
sources = {int(p.name[:2]): p for p in PAGES.glob('[0-9][0-9]-*.png')}
for name, numbers in groups.items():
    cols = min(3, len(numbers))
    rows = (len(numbers) + cols - 1) // cols
    width, height, label = 640, 360, 42
    board = Image.new('RGB', (cols * width, rows * (height + label)), '#171229')
    draw = ImageDraw.Draw(board)
    for i, number in enumerate(numbers):
        path = sources[number]
        with Image.open(path) as im:
            thumb = im.convert('RGB').resize((width, height), Image.Resampling.LANCZOS)
        x, y = i % cols * width, i // cols * (height + label)
        board.paste(thumb, (x, y))
        draw.text((x + 12, y + height + 4), path.stem.split('-1334x750')[0], font=font, fill='#FFC857')
    destination = OUT / f'{name}-参考联系板.png'
    board.save(destination)
    print(destination, board.size)

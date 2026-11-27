"""심기체연 낙관 아이콘 생성: 주홍 바탕 + 흰 心氣體緣 (오른쪽 세로줄부터: 心氣 / 體緣)."""
# 사용: pip install pillow && python3 tool/make_icons.py .   (liferpg_flutter 폴더에서)
import os, sys
from PIL import Image, ImageDraw, ImageFont

APP = sys.argv[1]  # liferpg_flutter 경로
FONT = os.path.join(APP, 'assets/fonts/NotoSerifKR-SemiBold.ttf')
RED = (0xB8, 0x43, 0x2F, 255)
INK = (0xFF, 0xF6, 0xEA, 255)
BIG = 1024
# 도장 배열: [[左上, 右上], [左下, 右下]] = [[體, 心], [緣, 氣]]
GRID = [['體', '心'], ['緣', '氣']]


def glyphs(size, box):
    """size×size 투명 캔버스의 box(정사각형 영역) 안에 2×2 한자."""
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x0, y0, w = box
    cell = w / 2
    font = ImageFont.truetype(FONT, int(cell * 0.86))
    for r in range(2):
        for c in range(2):
            ch = GRID[r][c]
            l, t, rr, b = d.textbbox((0, 0), ch, font=font)
            cx = x0 + cell * c + cell / 2
            cy = y0 + cell * r + cell / 2
            d.text((cx - (l + rr) / 2, cy - (t + b) / 2), ch, font=font, fill=INK)
    return im


def seal(size, radius_ratio, inner_ratio):
    """주홍 (둥근) 네모 + 글자. inner_ratio = 글자 영역 / 전체."""
    im = Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, BIG - 1, BIG - 1), radius=int(BIG * radius_ratio), fill=RED)
    w = BIG * inner_ratio
    im.alpha_composite(glyphs(BIG, ((BIG - w) / 2, (BIG - w) / 2, w)))
    return im.resize((size, size), Image.LANCZOS)


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print(path, im.size)


res = os.path.join(APP, 'android/app/src/main/res')
legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for dpi, px in legacy.items():
    save(seal(px, 0.16, 0.74), f'{res}/mipmap-{dpi}/ic_launcher.png')
    # 적응형 전경 (108dp): 원형으로 잘려도 네 글자 모서리가 안전 영역(지름 66dp) 원 안에 들도록 47dp 정사각형
    fg = glyphs(BIG, (BIG * 0.28, BIG * 0.28, BIG * 0.44)).resize((px * 9 // 4, px * 9 // 4), Image.LANCZOS)
    save(fg, f'{res}/mipmap-{dpi}/ic_launcher_foreground.png')

web = os.path.join(APP, 'web')
save(seal(192, 0.16, 0.74), f'{web}/icons/Icon-192.png')
save(seal(512, 0.16, 0.74), f'{web}/icons/Icon-512.png')
save(seal(192, 0.0, 0.62), f'{web}/icons/Icon-maskable-192.png')  # 가장자리까지 채움, 글자는 안전 영역(80%) 안
save(seal(512, 0.0, 0.62), f'{web}/icons/Icon-maskable-512.png')
save(seal(64, 0.16, 0.78), f'{web}/favicon.png')
save(seal(512, 0.16, 0.74), os.path.join(APP, 'assets/icon/app_icon_512.png'))

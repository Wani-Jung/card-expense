"""앱 아이콘 그리기 (2.1.1): 흰 배경 + 밝은 파랑(#2F80ED) '공감' 글자 + 카드 모양. 예전 아이콘의 원형 테두리는 없앴다.

사용:
  python tools/app_icon.py preview <out_dir>   # 시안 미리보기(512, 홈 화면 원형·둥근 사각 잘림)
  python tools/app_icon.py build               # android mipmap·적응형 전경·스토어 512 를 다시 만든다

글꼴은 Windows 의 맑은 고딕 굵게(malgunbd.ttf). 다른 PC 에선 FONT 경로를 바꾼다.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

NAVY = (31, 58, 104, 255)  # #1F3A68 (앱 포인트 네이비, 예전 아이콘 색)
COLOR = (26, 99, 209, 255)  # #1A63D1 진한 파랑 (2.1.1 사용자 결정: #2F80ED 보다 진하게. 예전 아이콘은 NAVY)
WHITE = (255, 255, 255, 255)
WEIGHT = 1.0  # 카드 굵기 (draw_symbol weight 기본값, 2.1.1 사용자 결정: 카드 선 +4px)
TEXT_WEIGHT = 0.0  # '공감' 글자 테두리 굵기 (2.1.1 사용자 결정: 글자는 예전 두께 그대로)
FONT = r'C:\Windows\Fonts\malgunbd.ttf'


def draw_symbol(size: int, scale: float = 1.0, card: str = 'outline', color=None, weight: float = None,
                text_weight: float = None) -> Image.Image:
    """투명 배경 위에 '공감' + 카드. [scale] 은 내용 크기(적응형 아이콘 안전 영역에 맞출 때 줄임)."""
    s = size / 512 * scale
    NAVY = color or COLOR
    wt = WEIGHT if weight is None else weight  # 0 = 예전 두께, 1 = 글자 테두리 4px·카드 선 +4px (512 기준)
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = size / 2
    # 내용 전체(글자 + 간격 + 카드)를 세로 가운데에 둔다
    font = ImageFont.truetype(FONT, int(170 * s))
    tb = d.textbbox((0, 0), '공감', font=font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    cw, ch = 190 * s, 122 * s
    gap = 34 * s
    top = (size - (th + gap + ch)) / 2
    sw = round(4 * (TEXT_WEIGHT if text_weight is None else text_weight) * s)
    d.text((cx - tw / 2 - tb[0], top - tb[1]), '공감', font=font, fill=NAVY, stroke_width=sw, stroke_fill=NAVY)
    y0 = top + th + gap
    x0 = cx - cw / 2
    r = 20 * s
    if card == 'fill':
        d.rounded_rectangle([x0, y0, x0 + cw, y0 + ch], radius=r, fill=NAVY)
        d.rectangle([x0, y0 + 30 * s, x0 + cw, y0 + 50 * s], fill=WHITE)
        d.rounded_rectangle([x0 + 24 * s, y0 + 78 * s, x0 + 84 * s, y0 + 94 * s], radius=6 * s, fill=WHITE)
    else:
        w = (14 + 4 * wt) * s
        e = 2 * wt * s  # 띠·'ㅡ'도 같은 만큼 두껍게
        d.rounded_rectangle([x0, y0, x0 + cw, y0 + ch], radius=r, outline=NAVY, width=round(w))
        d.rectangle([x0 + w, y0 + 36 * s - e, x0 + cw - w, y0 + 52 * s + e], fill=NAVY)
        # 카드 아래 'ㅡ' 표시는 짧게(예전 시안의 절반 길이, 사용자 결정 2.1.1)
        d.rounded_rectangle([x0 + 30 * s, y0 + 76 * s - e, x0 + 58 * s + e, y0 + 90 * s + e], radius=6 * s, fill=NAVY)
    return im


def on_white(symbol: Image.Image) -> Image.Image:
    bg = Image.new('RGBA', symbol.size, WHITE)
    bg.alpha_composite(symbol)
    return bg


def masked(im: Image.Image, shape: str) -> Image.Image:
    size = im.size[0]
    m = Image.new('L', im.size, 0)
    md = ImageDraw.Draw(m)
    if shape == 'circle':
        md.ellipse([0, 0, size - 1, size - 1], fill=255)
    else:
        md.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.23, fill=255)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), m)
    return out


def preview(out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    for card in ('outline', 'fill'):
        # 홈 화면 아이콘은 적응형 아이콘이라 안전 영역(가운데 66%) 안에 내용이 들어가야 한다 → scale 0.82 로 맞춤
        full = on_white(draw_symbol(512, scale=SCALE, card=card))
        sheet = Image.new('RGBA', (512 + 40 + 192 * 2 + 20, 512), (238, 240, 243, 255))
        sheet.paste(full, (0, 0))
        small = full.resize((192, 192), Image.LANCZOS)
        sheet.alpha_composite(masked(small, 'circle'), (552, 60))
        sheet.alpha_composite(masked(small, 'squircle'), (552 + 212, 60))
        tiny = full.resize((96, 96), Image.LANCZOS)
        sheet.alpha_composite(masked(tiny, 'circle'), (552 + 48, 320))
        sheet.alpha_composite(masked(tiny, 'squircle'), (552 + 212 + 48, 320))
        sheet.convert('RGB').save(os.path.join(out_dir, f'icon_preview_{card}.png'))
    print('ok', out_dir)


SCALE = 0.82  # 보이는 아이콘(512 또는 72dp) 대비 내용 크기
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
RES = os.path.join('android', 'app', 'src', 'main', 'res')


def build() -> None:
    """적응형 전경(108dp, 보이는 영역 72dp 에 맞춤)·옛 런처 아이콘(흰 원)·스토어 512(흰 사각)를 다시 만든다."""
    for name, k in DENSITIES.items():
        d = os.path.join(RES, f'mipmap-{name}')
        fg = round(108 * k)
        draw_symbol(fg * 4, scale=SCALE * 72 / 108).resize((fg, fg), Image.LANCZOS).save(
            os.path.join(d, 'ic_launcher_foreground.png'))
        legacy = round(48 * k)
        big = masked(on_white(draw_symbol(legacy * 4, scale=SCALE)), 'circle').resize((legacy, legacy), Image.LANCZOS)
        big.save(os.path.join(d, 'ic_launcher.png'))
        big.save(os.path.join(d, 'ic_launcher_round.png'))
    on_white(draw_symbol(512, scale=SCALE)).convert('RGB').save(os.path.join('store', 'playstore_icon_512.png'))
    print('built')


def weights(out_dir: str) -> None:
    """색·굵기 비교 (홈 화면 크기 둥근 사각): 글자·카드 같이 두껍게 한 시안들 (2.1.1 고를 때 쓴 것)"""
    opts = [('지금', '#2F80ED', 0), ('A', '#1F6FE0', 1), ('B', '#1A63D1', 1), ('C', '#1A63D1', 1.6), ('D', '#1557C0', 1.6)]
    tile, pad = 220, 28
    sheet = Image.new('RGBA', (len(opts) * (tile + pad) + pad, tile + 2 * pad + 40), (60, 60, 64, 255))
    d = ImageDraw.Draw(sheet)
    lab = ImageFont.truetype(FONT, 22)
    for i, (name, hexc, wt) in enumerate(opts):
        rgb = tuple(int(hexc[j:j + 2], 16) for j in (1, 3, 5)) + (255,)
        im = masked(on_white(draw_symbol(tile * 4, scale=SCALE, color=rgb, weight=wt, text_weight=wt)), 'squircle').resize((tile, tile), Image.LANCZOS)
        x = pad + i * (tile + pad)
        sheet.alpha_composite(im, (x, pad))
        d.text((x + tile / 2, pad + tile + 22), f'{name} {hexc}', font=lab, fill=WHITE, anchor='mm')
    os.makedirs(out_dir, exist_ok=True)
    sheet.convert('RGB').save(os.path.join(out_dir, 'icon_weights.png'))
    print('ok')


def colors(out_dir: str) -> None:
    """밝은 파랑 계열 색 비교 (홈 화면 크기 원형)"""
    opts = [('지금', '#1F3A68'), ('1', '#1E6FE0'), ('2', '#2F80ED'), ('3', '#3B9BFF'), ('4', '#1E88E5'), ('5', '#0EA5E9')]
    tile, pad = 200, 24
    sheet = Image.new('RGBA', (len(opts) * (tile + pad) + pad, tile + 2 * pad), (238, 240, 243, 255))
    for i, (_, hexc) in enumerate(opts):
        rgb = tuple(int(hexc[j:j + 2], 16) for j in (1, 3, 5)) + (255,)
        im = masked(on_white(draw_symbol(tile * 4, scale=SCALE, color=rgb)), 'circle').resize((tile, tile), Image.LANCZOS)
        sheet.alpha_composite(im, (pad + i * (tile + pad), pad))
    os.makedirs(out_dir, exist_ok=True)
    sheet.convert('RGB').save(os.path.join(out_dir, 'icon_colors.png'))
    print('ok', [o[1] for o in opts])


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == 'weights':
        weights(sys.argv[2]); sys.exit()
    if len(sys.argv) >= 3 and sys.argv[1] == 'colors':
        colors(sys.argv[2]); sys.exit()
    if len(sys.argv) >= 3 and sys.argv[1] == 'preview':
        preview(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == 'build':
        build()
    else:
        raise SystemExit(__doc__)

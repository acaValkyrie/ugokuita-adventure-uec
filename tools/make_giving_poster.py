# Giving Campaignへの応援（応援投票・寄付）をお願いする看板のポスター画像（1500x600）を作る。
# 左に告知画像、中央に呼びかけの文、右に白地のQRコードを置く。
# 素材:
#   assets/img/giving campaign twitter.jpg （告知画像。縦長で背景は青）
#   assets/img/giving campaign qr.png      （QRコード。256x256、白地に黒）
# 引数: 告知画像 QR画像 出力PNG
# フォントのパスは Debian の fonts-noto-cjk のものなので、Docker の python:3.12-slim で実行する。
# 実行例:
#   docker run --rm -e LANG=C.UTF-8 -v "D:\document\Program\Godot\ugokuita-adventure-uec:/work" -w /work python:3.12-slim sh -c \
#     "apt-get update -qq && apt-get install -y -qq fonts-noto-cjk >/dev/null && pip install -q pillow && python tools/make_giving_poster.py 'assets/img/giving campaign twitter.jpg' 'assets/img/giving campaign qr.png' assets/boards/giving_campaign_poster.png"
import sys

from PIL import Image, ImageDraw, ImageFont

BOLD = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
JP_INDEX = 0  # ttc の中の「Noto Sans CJK JP」（Monoではない）の番号

W, H = 1500, 600
BG = "#142b9d"
BORDER = "#2a44c0"
WHITE = "#ffffff"
YELLOW = "#ffc21a"

TEXT_CENTER_X = 787
TEXT_MAX_W = 570


def fit_font(draw: ImageDraw.ImageDraw, text: str, size: int) -> ImageFont.FreeTypeFont:
    # 指定サイズから始め、幅が上限を超える間 2px ずつ小さくする
    while True:
        font = ImageFont.truetype(BOLD, size, index=JP_INDEX)
        box = draw.textbbox((TEXT_CENTER_X, 0), text, font=font, anchor="mm")
        if box[2] - box[0] <= TEXT_MAX_W or size <= 8:
            return font
        size -= 2


def main() -> None:
    poster_path, qr_path, out_path = sys.argv[1:4]

    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    # 外周の枠
    draw.rectangle((0, 0, W - 1, H - 1), outline=BORDER, width=12)

    # 左: 告知画像（高さ552に縮小）
    poster = Image.open(poster_path).convert("RGB")
    ph = 552
    pw = round(poster.width * ph / poster.height)
    img.paste(poster.resize((pw, ph), Image.LANCZOS), (24, 24))

    # 右: 白い正方形の上にQRコード（ドットがにじまないよう NEAREST で拡大）
    draw.rectangle((1108, 116, 1108 + 368 - 1, 116 + 368 - 1), fill=WHITE)
    qr = Image.open(qr_path).convert("RGB").resize((336, 336), Image.NEAREST)
    img.paste(qr, (1124, 132))

    # 中央: 4行の文（中央そろえ、幅に収まるよう自動で縮小）
    lines = [
        ("Giving Campaign", 72, WHITE, 170),
        ("参加してます！", 72, WHITE, 260),
        ("応援投票または", 52, YELLOW, 380),
        ("寄付をお願いします！！", 52, YELLOW, 450),
    ]
    for text, size, color, y in lines:
        font = fit_font(draw, text, size)
        draw.text((TEXT_CENTER_X, y), text, font=font, fill=color, anchor="mm")
        box = draw.textbbox((TEXT_CENTER_X, y), text, font=font, anchor="mm")
        print(text, "size", font.size, "bbox", box)
        if box[0] < 490 or box[2] > 1084:
            print("WARNING: はみ出し:", text)

    img.save(out_path)


main()

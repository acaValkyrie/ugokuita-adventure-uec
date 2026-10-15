# 作者のGitHubを案内する看板のポスター画像（1500x600）を作る。
# アイコンは https://github.com/acaValkyrie.png 、
# マークは https://cdn.jsdelivr.net/npm/simple-icons@13.0.0/icons/github.svg から取得したものを使う。
# 実行: uv run --with pillow --with cairosvg python tools/make_link_poster.py \
#         アイコンPNGのパス GitHubマークSVGのパス assets/boards/github_poster.png
import io
import sys

import cairosvg
from PIL import Image, ImageChops, ImageDraw, ImageFont

BOLD = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
REGULAR = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
JP_INDEX = 0  # ttc の中の「Noto Sans CJK JP」（Monoではない）の番号

W, H = 1500, 600
BG = "#0d1117"
BORDER = "#30363d"
GRAY = "#8b949e"
WHITE = "#ffffff"


def circle_icon(path: str, diameter: int) -> Image.Image:
    # アンチエイリアスのため4倍で切り抜いてから縮小する
    scale = 4
    size = diameter * scale
    icon = Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    # 元画像の透明部分は透明のまま残す（マスクと掛け合わせる）
    icon.putalpha(ImageChops.multiply(icon.getchannel("A"), mask))
    return icon.resize((diameter, diameter), Image.LANCZOS)


def white_ring(center: tuple, outer_d: int, width: int) -> Image.Image:
    # 白い輪だけの透明レイヤーを4倍で描いて縮小する
    scale = 4
    size = outer_d * scale
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse(
        (0, 0, size - 1, size - 1), outline=WHITE, width=width * scale
    )
    return ring.resize((outer_d, outer_d), Image.LANCZOS)


def main() -> None:
    icon_path, svg_path, out_path = sys.argv[1:4]

    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    # 外周の枠
    draw.rectangle((0, 0, W - 1, H - 1), outline=BORDER, width=12)

    # 左: 円形のアイコンと白い輪（輪はアイコンの外側に付ける）
    center = (300, 300)
    icon_d = 440
    ring_w = 8
    ring_d = icon_d + ring_w * 2
    ring = white_ring(center, ring_d, ring_w)
    img.paste(ring, (center[0] - ring_d // 2, center[1] - ring_d // 2), ring)
    icon = circle_icon(icon_path, icon_d)
    img.paste(icon, (center[0] - icon_d // 2, center[1] - icon_d // 2), icon)

    # 右: GitHubマーク（SVGの fill を白にして PNG 化）
    svg = open(svg_path, encoding="utf-8").read().replace("<path ", '<path fill="#ffffff" ', 1)
    png = cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=140, output_height=140)
    mark = Image.open(io.BytesIO(png)).convert("RGBA")
    img.paste(mark, (580, 110), mark)

    # マークの右にタイトル（マークと縦中央をそろえる）、その下にURL
    title_font = ImageFont.truetype(BOLD, 96, index=JP_INDEX)
    url_font = ImageFont.truetype(REGULAR, 56, index=JP_INDEX)
    draw.text((750, 110 + 70), "作者のGitHub", font=title_font, fill=WHITE, anchor="lm")
    draw.text((580, 330), "github.com/acaValkyrie", font=url_font, fill=GRAY, anchor="la")

    # はみ出しの確認（内側の枠 12px より外に出ていないか）
    for name, xy, font, text, anchor in [
        ("title", (750, 180), title_font, "作者のGitHub", "lm"),
        ("url", (580, 330), url_font, "github.com/acaValkyrie", "la"),
    ]:
        box = draw.textbbox(xy, text, font=font, anchor=anchor)
        print(name, "bbox", box)
        if box[2] > W - 12 or box[3] > H - 12:
            print("WARNING: はみ出し:", name)

    img.save(out_path)


main()

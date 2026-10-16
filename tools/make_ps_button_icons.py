# PlayStation の表記（PS3 以前・PS4・PS5）で出し分ける小さいボタンの絵のうち、SELECT・SHARE・START・OPTIONS の4枚を作る。
# 入力: assets/ui/controls/button_minus.png（横長のカプセル形の小さいボタン。本体の見本）、
#       assets/fonts/noto_sans_cjk_jp_bold_ui.otf（文字用）
# 出力: assets/ui/controls/ の button_select.png・button_share.png・button_start.png・button_options.png
#       （256x256 RGBA、上書き）
# 実行: uv run --with pillow --with numpy python tools/make_ps_button_icons.py
# 見本の本体の内側の白い「−」を本体の暗い色で消し、そこに新しい記号を (242,242,242) で描く。
# 文字は本体の内側の高さの約 45%、横は内側の幅の 80% 以内。三角と線は 4 倍の大きさで描いてから縮める。
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CTRL = ROOT / "assets/ui/controls"
FONT_PATH = ROOT / "assets/fonts/noto_sans_cjk_jp_bold_ui.otf"
DARK_LEVEL = 90  # これ未満を本体の暗い画素とみなす
WHITE_LEVEL = 150  # これより明るいものを記号とみなす
MIN_BODY = 2000  # 本体とみなす連結成分の最小画素数
WHITE = 242
ERASE_MARGIN = 5  # 記号を消すときの広げ幅（MaxFilter のサイズ。周り2px）
SS = 4  # 三角と線を描くときの拡大率
TEXT_HEIGHT_RATIO = 0.45  # 文字の高さ / 内側の高さ
TEXT_WIDTH_LIMIT = 0.80  # 文字の幅 / 内側の幅の上限


def inner_region(rgba: np.ndarray) -> np.ndarray:
    """最大の暗い連結成分を穴埋めした、本体の内側のマスク。"""
    lum = rgba[..., :3].max(axis=2)
    dark = (rgba[..., 3] > 200) & (lum < DARK_LEVEL)
    ys, xs = np.nonzero(dark)
    remaining = dark.copy()
    best = None
    for y, x in zip(ys, xs):
        if not remaining[y, x]:
            continue
        img = Image.fromarray((remaining * 255).astype(np.uint8)).copy()
        ImageDraw.floodfill(img, (int(x), int(y)), 128)
        comp = np.asarray(img) == 128
        remaining &= ~comp
        if best is None or comp.sum() > best.sum():
            best = comp
    if best is None or best.sum() < MIN_BODY:
        raise RuntimeError("本体が見つからない")
    # 穴埋め: 外側（角）から塗れない部分を内側とする
    inv = Image.fromarray((~best * 255).astype(np.uint8)).copy()
    ImageDraw.floodfill(inv, (0, 0), 128)
    return np.asarray(inv) != 128


def bbox(mask: np.ndarray):
    ys, xs = np.nonzero(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def white_layer(draw_fn) -> Image.Image:
    """4倍の大きさの透明な板に draw_fn(draw, SS) で白を描き、256x256 に縮めたアルファ付きの板を返す。"""
    big = Image.new("L", (256 * SS, 256 * SS), 0)
    draw_fn(ImageDraw.Draw(big), SS)
    small = big.resize((256, 256), Image.LANCZOS)
    return Image.merge("RGBA", [Image.new("L", (256, 256), WHITE)] * 3 + [small])


def text_layer(text: str, inner_box, center) -> Image.Image:
    """内側の高さの約 45%（大文字の高さ）、横は内側の幅の 80% 以内に収めた文字の板。"""
    ix0, iy0, ix1, iy1 = inner_box
    target_h = (iy1 - iy0) * TEXT_HEIGHT_RATIO
    max_w = (ix1 - ix0) * TEXT_WIDTH_LIMIT
    # 大文字の高さが target_h になるフォントサイズを探し、横が超えるなら縮める
    size = 10.0
    for _ in range(60):
        font = ImageFont.truetype(str(FONT_PATH), max(1, round(size)))
        l, t, r, b = font.getbbox(text)
        h = b - t
        if h >= target_h:
            break
        size += 1.0
    while True:
        font = ImageFont.truetype(str(FONT_PATH), max(1, round(size)))
        l, t, r, b = font.getbbox(text)
        if (r - l) <= max_w or size <= 4:
            break
        size -= 1.0
    mask = Image.new("L", (256, 256), 0)
    draw = ImageDraw.Draw(mask)
    # 文字の外接矩形の中心を記号の中心に合わせる
    x = center[0] - (l + r) / 2
    y = center[1] - (t + b) / 2
    draw.text((x, y), text, font=font, fill=255)
    return Image.merge("RGBA", [Image.new("L", (256, 256), WHITE)] * 3 + [mask])


def main() -> None:
    src = np.asarray(Image.open(CTRL / "button_minus.png").convert("RGBA")).copy()
    inner = inner_region(src)
    lum = src[..., :3].max(axis=2)
    dark = np.median(src[inner & (lum < DARK_LEVEL)][:, :3], axis=0)
    white = inner & (lum > WHITE_LEVEL)
    wx0, wy0, wx1, wy1 = bbox(white)
    cx, cy = (wx0 + wx1) / 2, (wy0 + wy1) / 2
    line_h = wy1 - wy0  # 元の「−」の線の太さ
    inner_box = bbox(inner)
    ix0, iy0, ix1, iy1 = inner_box
    inner_h = iy1 - iy0
    print(f"inner={inner_box} minus_bbox={(wx0, wy0, wx1, wy1)} line_h={line_h}")

    # 「−」を本体の暗い色で消した本体
    erase = np.asarray(Image.fromarray((white * 255).astype(np.uint8))
                       .filter(ImageFilter.MaxFilter(ERASE_MARGIN))) > 0
    body = src.copy()
    body[erase & inner, :3] = np.round(dark).astype(np.uint8)
    base = Image.fromarray(body, "RGBA")

    def draw_triangle(d: ImageDraw.ImageDraw, k: int) -> None:
        # 右向きの塗りつぶしの三角（高さは内側の高さの 45%）
        h = inner_h * TEXT_HEIGHT_RATIO
        w = h * 0.9
        x0 = cx - w / 2
        d.polygon([(x0 * k, (cy - h / 2) * k), (x0 * k, (cy + h / 2) * k), ((x0 + w) * k, cy * k)], fill=255)

    def draw_lines(d: ImageDraw.ImageDraw, k: int) -> None:
        # 横線3本。太さは元の「−」と同じ。線の間は 4px、長さは内側の幅の 40%（内側の高さに収まる）
        gap = line_h + 4
        half = (ix1 - ix0) * 0.40 / 2
        for i in (-1, 0, 1):
            y = cy + i * gap
            d.rectangle([(cx - half) * k, (y - line_h / 2) * k, (cx + half) * k, (y + line_h / 2) * k], fill=255)

    jobs = {
        "button_select": text_layer("SELECT", inner_box, (cx, cy)),
        "button_share": text_layer("SHARE", inner_box, (cx, cy)),
        "button_start": white_layer(draw_triangle),
        "button_options": white_layer(draw_lines),
    }
    for name, layer in jobs.items():
        result = Image.alpha_composite(base, layer)
        # 記号が本体の内側からはみ出さないよう、内側の外は本体のまま使う
        out = np.asarray(result).copy()
        outside = ~inner
        out[outside] = body[outside]
        result = Image.fromarray(out, "RGBA")
        corners = [out[0, 0, 3], out[0, -1, 3], out[-1, 0, 3], out[-1, -1, 3]]
        assert all(c == 0 for c in corners), corners
        result.save(CTRL / f"{name}.png")
        print(f"{name}: size={result.size} corner_alpha={corners}")


if __name__ == "__main__":
    main()

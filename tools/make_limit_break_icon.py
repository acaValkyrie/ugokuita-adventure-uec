# パワーアップ「上限突破」のアイコンを作る。tools/icon_sources/limit_break_lines.webp（黒地に白い線のちぎれた鎖）から白い線を取り出し、ほかのパワーアップのアイコンと同じ紫の円に重ね、濃い縁取りを手前に描く。
# 実行: python tools/make_limit_break_icon.py [入力画像] [出力PNG]
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = ROOT / "tools/icon_sources/limit_break_lines.webp"
DEFAULT_OUTPUT = ROOT / "assets/ui/powerups/powerup_limit_break.png"
SS = 4
SIZE = 256
BIG_SIZE = SIZE * SS
CENTER = BIG_SIZE // 2
OUTER_RADIUS = 448
INNER_RADIUS = 388
LINE_WIDTH = 780
MAX_FILTER_SIZE = 9


def line_bbox(mask: Image.Image) -> tuple[int, int, int, int]:
    """白線の判定を alpha > 128 に統一して外接矩形を返す。"""
    bounds = mask.point(lambda alpha: 255 if alpha > 128 else 0).getbbox()
    if bounds is None:
        raise ValueError("入力画像に輝度が128を超える白線がありません。")
    return bounds


def make_icon(source: Path, destination: Path) -> None:
    with Image.open(source) as original:
        luminance = original.convert("L")
    source_bbox = line_bbox(luminance)
    cropped = luminance.crop(source_bbox)
    height = round(cropped.height * LINE_WIDTH / cropped.width)
    scaled = cropped.resize((LINE_WIDTH, height), Image.Resampling.LANCZOS)
    if max(scaled.size) + MAX_FILTER_SIZE - 1 > BIG_SIZE:
        raise ValueError("指定の幅と縦横比では白線が1024pxキャンバスに収まりません。")

    mask = Image.new("L", (BIG_SIZE, BIG_SIZE), 0)
    mask.paste(scaled, ((BIG_SIZE - scaled.width) // 2, (BIG_SIZE - scaled.height) // 2))
    mask = mask.filter(ImageFilter.MaxFilter(MAX_FILTER_SIZE))
    left, top, right, bottom = line_bbox(mask)
    centered = Image.new("L", mask.size, 0)
    # 外接矩形の中心が半画素の場合も、中心512から最大0.5pxの整数座標へ置く。
    offset = (round(CENTER - (left + right) / 2), round(CENTER - (top + bottom) / 2))
    centered.paste(mask, offset)

    canvas = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((CENTER - INNER_RADIUS, CENTER - INNER_RADIUS, CENTER + INNER_RADIUS, CENTER + INNER_RADIUS), fill="#8644C6")
    white_layer = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    white_layer.putalpha(centered)
    canvas = Image.alpha_composite(canvas, white_layer)
    ring_layer = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring_layer)
    ring_draw.ellipse((CENTER - OUTER_RADIUS, CENTER - OUTER_RADIUS, CENTER + OUTER_RADIUS, CENTER + OUTER_RADIUS), fill="#1F1F1F")
    ring_draw.ellipse((CENTER - INNER_RADIUS, CENTER - INNER_RADIUS, CENTER + INNER_RADIUS, CENTER + INNER_RADIUS), fill=(0, 0, 0, 0))
    canvas = Image.alpha_composite(canvas, ring_layer)
    result = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    # LANCZOSの微小な外側リンギングも含め、円の外側は完全に透明にする。
    pixels = result.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if (x + 0.5 - SIZE / 2) ** 2 + (y + 0.5 - SIZE / 2) ** 2 > (OUTER_RADIUS / SS) ** 2:
                pixels[x, y] = (0, 0, 0, 0)

    destination.parent.mkdir(parents=True, exist_ok=True)
    result.save(destination)


def main() -> None:
    parser = argparse.ArgumentParser(description="指定の円と白線で上限突破アイコンを合成する。")
    parser.add_argument("input", nargs="?", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    make_icon(args.input, args.output)
    print(args.output)


if __name__ == "__main__":
    main()

# ドリフトの操作説明用に、CTRL キーのアイコンと、右のショルダーボタン（バンパー）のアイコン3種を作る。
# 入力: assets/ui/controls/ の key_shift.png（CTRL キーの見本）・trigger_lt.png（バンパーの色・縁・文字の高さの見本）、
#       assets/fonts/noto_sans_cjk_jp_bold_ui.otf（文字のフォント）。
# 出力: assets/ui/controls/ の key_ctrl.png（key_shift.png と同じ 512x112）と、
#       shoulder_rb.png・shoulder_r.png・shoulder_r1.png（右のバンパー1個だけ、四方に 4px の透明な余白を付けた 178x93 RGBA）
# 実行: uv run --with pillow --with numpy python tools/make_drift_icons.py
# key_ctrl は key_shift の「SHIFT」の文字を make_glyph_swap_icons.py と同じ方法で消し、
# 同じ高さ・同じ中心に「CTRL」を (242,242,242) で描く。
# バンパーは trigger_lt から測った本体の色・縁の色と太さ・外形の幅・文字の高さに合わせ、
# 幅広の角丸の長方形（外形の幅は LT と同じ、高さはその 0.5 倍、角の半径は高さの 0.45 倍）に、
# 高さが LT の文字の 0.8 倍の白い文字を載せる。どちらも4倍で描いて LANCZOS で縮め、輪郭をなめらかにする。
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from make_glyph_swap_icons import (CTRL, DARK_LEVEL, ERASE_MARGIN, WHITE, WHITE_LEVEL, bbox,
                                   inner_region, load)

ROOT = Path(__file__).resolve().parent.parent
FONT_PATH = ROOT / "assets/fonts/noto_sans_cjk_jp_bold_ui.otf"
SS = 4  # 描画の倍率
BUMPER_HEIGHT_RATIO = 0.5  # 外形の高さ / 外形の幅
BUMPER_RADIUS_RATIO = 0.45  # 角の半径 / 外形の高さ
BUMPER_LETTER_RATIO = 0.8  # 文字の高さ / LT の文字の高さ
MARGIN = 4  # 絵の四方の透明な余白（px）

BUMPERS = [
    ("shoulder_rb", "RB"),
    ("shoulder_r", "R"),
    ("shoulder_r1", "R1"),
]


def text_mask(text: str, target_h: float, size: tuple[int, int], center: tuple[float, float]) -> Image.Image:
    """文字の外接矩形の高さが target_h px、中心が center になる、size の大きさの L マスク（4倍で描いて縮める）。"""
    probe_size = 200
    font = ImageFont.truetype(str(FONT_PATH), probe_size)
    l, t, r, b = font.getbbox(text)
    font_px = probe_size * target_h * SS / (b - t)
    font = ImageFont.truetype(str(FONT_PATH), max(1, round(font_px)))
    l, t, r, b = font.getbbox(text)
    big = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    d = ImageDraw.Draw(big)
    x = center[0] * SS - (l + r) / 2
    y = center[1] * SS - (t + b) / 2
    d.text((x, y), text, font=font, fill=255)
    return big.resize(size, Image.LANCZOS)


def white_over(base: Image.Image, mask: Image.Image) -> Image.Image:
    layer = Image.merge("RGBA", [Image.new("L", mask.size, WHITE)] * 3 + [mask])
    return Image.alpha_composite(base, layer)


def make_key_ctrl() -> None:
    k = load(CTRL / "key_shift.png")
    k_in = inner_region(k)
    k_lum = k[..., :3].max(axis=2)
    k_dark = np.median(k[k_in & (k_lum < DARK_LEVEL)][:, :3], axis=0)
    k_white = k_in & (k_lum > WHITE_LEVEL)
    x0, y0, x1, y1 = bbox(k_white)
    t_h = y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    erase = np.asarray(Image.fromarray((k_white * 255).astype(np.uint8))
                       .filter(ImageFilter.MaxFilter(ERASE_MARGIN))) > 0
    k[erase & k_in, :3] = np.round(k_dark).astype(np.uint8)
    base = Image.fromarray(k, "RGBA")
    mask = text_mask("CTRL", t_h, base.size, (cx, cy))
    result = white_over(base, mask)
    out = np.asarray(result)
    corners = [out[0, 0, 3], out[0, -1, 3], out[-1, 0, 3], out[-1, -1, 3]]
    assert all(c == 0 for c in corners), corners
    mx0, my0, mx1, my1 = bbox(np.asarray(mask) > 127)
    result.save(CTRL / "key_ctrl.png")
    print(f"key_ctrl: size={result.size} corner_alpha={corners} shift_letter_h={t_h} "
          f"shift_center=({cx},{cy}) ctrl_letter_h={my1 - my0} ctrl_center=({(mx0 + mx1) / 2},{(my0 + my1) / 2})")


def measure_trigger() -> dict:
    t = load(CTRL / "trigger_lt.png")
    t_in = inner_region(t)
    lum = t[..., :3].max(axis=2)
    body = np.round(np.median(t[t_in & (lum < DARK_LEVEL)][:, :3], axis=0)).astype(int)
    rim_px = (t[..., 3] > 200) & ~t_in
    rim = np.round(np.median(t[rim_px][:, :3], axis=0)).astype(int)
    shape = t[..., 3] > 127
    sx0, sy0, sx1, sy1 = bbox(shape)
    mid = (sy0 + sy1) // 2
    row_shape = np.nonzero(shape[mid])[0]
    row_in = np.nonzero(t_in[mid])[0]
    rim_l = row_in.min() - row_shape.min()
    rim_r = row_shape.max() - row_in.max()
    rim_t = (rim_l + rim_r) / 2
    wx0, wy0, wx1, wy1 = bbox(t_in & (lum > WHITE_LEVEL))
    return dict(body=tuple(int(v) for v in body), rim=tuple(int(v) for v in rim), rim_t=rim_t,
                outer_w=sx1 - sx0, letter_h=wy1 - wy0, mid_row=mid, rim_l=rim_l, rim_r=rim_r)


def draw_bumper_half(m: dict, label: str) -> Image.Image:
    """バンパー1個分（外形の幅は LT と同じ、四方に MARGIN の透明な余白）。縁の色の外形に、縁の太さだけ内側へ寄せた本体の色の形を重ねる。"""
    w = m["outer_w"]
    h = w * BUMPER_HEIGHT_RATIO
    size_w, size_h = int(w) + 2 * MARGIN, int(round(h)) + 2 * MARGIN
    r = h * BUMPER_RADIUS_RATIO
    rim_t = m["rim_t"]
    x0, y0 = MARGIN, MARGIN
    big = Image.new("RGBA", (size_w * SS, size_h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([x0 * SS, y0 * SS, (x0 + w) * SS - 1, (y0 + h) * SS - 1],
                        radius=r * SS, fill=m["rim"] + (255,))
    d.rounded_rectangle([(x0 + rim_t) * SS, (y0 + rim_t) * SS,
                         (x0 + w - rim_t) * SS - 1, (y0 + h - rim_t) * SS - 1],
                        radius=(r - rim_t) * SS, fill=m["body"] + (255,))
    # 縁の色が透明部分の黒と混ざらないよう、アルファ乗算済みで縮める
    arr = np.asarray(big).astype(np.float64)
    a = arr[..., 3:4] / 255.0
    chans = [Image.fromarray((arr[..., i] * a[..., 0]).astype(np.float32), "F").resize((size_w, size_h), Image.LANCZOS)
             for i in range(3)]
    alpha = Image.fromarray(arr[..., 3].astype(np.float32), "F").resize((size_w, size_h), Image.LANCZOS)
    al = np.clip(np.asarray(alpha), 0, 255)
    rgb = np.stack([np.asarray(c) for c in chans], axis=2)
    safe = np.where(al[..., None] > 0, al[..., None], 1)
    rgb = np.clip(rgb / (safe / 255.0), 0, 255)
    out = np.concatenate([rgb, al[..., None]], axis=2)
    base = Image.fromarray(np.round(out).astype(np.uint8), "RGBA")
    mask = text_mask(label, m["letter_h"] * BUMPER_LETTER_RATIO, (size_w, size_h), (size_w / 2, size_h / 2))
    return white_over(base, mask)


def make_bumpers() -> None:
    m = measure_trigger()
    print("trigger_lt measured:", m)
    for name, label in BUMPERS:
        img = draw_bumper_half(m, label)
        out = np.asarray(img)
        corners = [out[0, 0, 3], out[0, -1, 3], out[-1, 0, 3], out[-1, -1, 3]]
        assert all(c == 0 for c in corners), corners
        img.save(CTRL / f"{name}.png")
        print(f"{name}: size={img.size} corner_alpha={corners} label={label}")


def main() -> None:
    make_key_ctrl()
    make_bumpers()


if __name__ == "__main__":
    main()

# PlayStation の表記（PS3 以前・PS4・PS5）で出し分ける小さいボタンの絵を6枚作る。
# PS3 の SELECT は四角（角丸の長方形）、START は右向きの三角。
# PS4・PS5 の SHARE・CREATE・OPTIONS は縦長のカプセルで、実物と同じく本体の印をカプセルの上に描く。
#   PS4 SHARE: 「SHARE」の文字 / PS4 OPTIONS: 「OPTIONS」の文字（文字の大きさは共通）
#   PS5 OPTIONS: 横棒 3 本 / PS5 CREATE: 上向きに放射する 5 本の線
#   印は明るい色で、まわりを暗い色で縁取る（どんな背景でも読めるように）。ボタンの中には何も描かない。
# 入力: assets/ui/controls/button_minus.png（横長のカプセル形の小さいボタン。色・縁取りの太さ・大きさの見本）
#       assets/fonts/noto_sans_cjk_jp_bold_ui.otf（文字の印のフォント）
# 出力: assets/ui/controls/ の button_select.png・button_start.png・button_share.png・
#       button_create.png・button_options.png・button_options_ps4.png（256x256 RGBA、上書き、背景は透明）
# 実行: uv run --with pillow --with numpy python tools/make_ps_button_icons.py
# 作り方: 見本から外形の高さ H、縁取りの色と太さ、内側の暗い塗りの色を測る。
#       形は 4 倍の大きさで「縁取りの色で外形を塗る → 縁取りの太さだけ内側に縮めた形を暗い色で塗る」で描き、
#       アルファも 4 倍で描いてから 256x256 に LANCZOS で縮める（縁が滑らかになる）。形の中心は画像の中心。
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CTRL = ROOT / "assets/ui/controls"
FONT_PATH = ROOT / "assets/fonts/noto_sans_cjk_jp_bold_ui.otf"
CAP_H = 150.0  # 印付きのカプセルの高さ（256 単位）
CAP_RATIO = 1.9  # カプセルの高さ / 幅
MARK_GAP = 14.0  # 印とカプセルのすき間
OUTLINE = 5.0  # 印のまわりの暗い縁取り
TEXT_MAX_W = 236.0  # 文字の幅の上限（縁取り込み）
TEXT_MAX_CAP = 44.0  # 大文字の高さの上限
BAR_W_RATIO = 0.9  # 横棒の長さ / カプセルの幅
RAY_THICK = 9.0  # 横棒・放射線の太さ（横棒の間隔も同じ）
RAY_GAP = 14.0  # 放射線の始まり: C から カプセルの半幅 + この値
RAY_LEN = 30.0  # 放射線の長さ
DARK_LEVEL = 90  # これ未満を本体の暗い画素とみなす
MIN_BODY = 2000  # 本体とみなす連結成分の最小画素数
SS = 4  # 描くときの拡大率
CENTER = 128.0  # 形の中心（256x256 の中心）


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


def measure(src: np.ndarray):
    """見本から外形の幅・高さ、縁取りの色と太さ、内側の暗い色を測る。"""
    alpha = src[..., 3]
    ys, xs = np.nonzero(alpha > 0)
    w = int(xs.max()) + 1 - int(xs.min())
    h = int(ys.max()) + 1 - int(ys.min())
    inner = inner_region(src)
    lum = src[..., :3].max(axis=2)
    border = np.median(src[(alpha > 200) & ~inner][:, :3], axis=0)
    dark = np.median(src[inner & (lum < DARK_LEVEL)][:, :3], axis=0)
    # 縁取りの太さ: 真ん中の行で、外形の左端から内側の左端までの距離
    row = (int(ys.min()) + int(ys.max())) // 2
    outer_x = int(np.nonzero(alpha[row] > 0)[0].min())
    inner_x = int(np.nonzero(inner[row])[0].min())
    thick = inner_x - outer_x
    return w, h, tuple(int(round(c)) for c in border), thick, tuple(int(round(c)) for c in dark)


def capsule(d: ImageDraw.ImageDraw, w: float, h: float, shrink: float, fill, cy: float = CENTER) -> None:
    """縦長のカプセル（上下が半円）。shrink だけ内側に縮める。cy は中心の y。"""
    x0, x1 = (CENTER - w / 2 + shrink) * SS, (CENTER + w / 2 - shrink) * SS
    y0, y1 = (cy - h / 2 + shrink) * SS, (cy + h / 2 - shrink) * SS
    d.rounded_rectangle([x0, y0, x1, y1], radius=(x1 - x0) / 2, fill=fill)


def rounded_rect(d: ImageDraw.ImageDraw, w: float, h: float, radius: float, shrink: float, fill) -> None:
    """角丸の長方形。shrink だけ内側に縮める（角の丸みも同じだけ小さくなる）。"""
    x0, x1 = (CENTER - w / 2 + shrink) * SS, (CENTER + w / 2 - shrink) * SS
    y0, y1 = (CENTER - h / 2 + shrink) * SS, (CENTER + h / 2 - shrink) * SS
    d.rounded_rectangle([x0, y0, x1, y1], radius=max(radius - shrink, 0) * SS, fill=fill)


def rounded_triangle(d: ImageDraw.ImageDraw, w: float, h: float, radius: float, shrink: float, fill) -> None:
    """右向きの三角（外接矩形の中心が画像の中心）。角を radius で丸め、shrink だけ内側に縮める。
    内側に縮めた三角に半径の円を足す（ミンコフスキー和）ことで、角を丸めて描く。"""
    x0, x1 = CENTER - w / 2, CENTER + w / 2
    pts = np.array([(x0, CENTER - h / 2), (x0, CENTER + h / 2), (x1, CENTER)])
    # 内心と内接円の半径
    sides = np.array([np.linalg.norm(pts[(i + 1) % 3] - pts[(i + 2) % 3]) for i in range(3)])
    incenter = (sides[:, None] * pts).sum(axis=0) / sides.sum()
    e1, e2 = pts[1] - pts[0], pts[2] - pts[0]
    area = abs(e1[0] * e2[1] - e1[1] * e2[0]) / 2
    rho = 2 * area / sides.sum()
    grow = radius - shrink  # 丸めた外形を shrink 縮めた形 = 芯の三角に grow の円を足した形
    inset = radius if grow >= 0 else shrink
    grow = max(grow, 0)
    core = incenter + (pts - incenter) * ((rho - inset) / rho)
    k = SS
    d.polygon([(x * k, y * k) for x, y in core], fill=fill)
    if grow > 0:
        for i in range(3):
            a, b = core[i], core[(i + 1) % 3]
            d.line([a[0] * k, a[1] * k, b[0] * k, b[1] * k], fill=fill, width=int(round(2 * grow * k)))
            d.ellipse([(a[0] - grow) * k, (a[1] - grow) * k, (a[0] + grow) * k, (a[1] + grow) * k], fill=fill)


def thick_line(d: ImageDraw.ImageDraw, p0, p1, width: float, fill) -> None:
    """両端が丸い太線（256 単位の座標と太さ）。"""
    k = SS
    d.line([p0[0] * k, p0[1] * k, p1[0] * k, p1[1] * k], fill=fill, width=int(round(width * k)))
    r = width / 2
    for x, y in (p0, p1):
        d.ellipse([(x - r) * k, (y - r) * k, (x + r) * k, (y + r) * k], fill=fill)


def load_font(size_ss: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size_ss)


def pick_text_size() -> int:
    """SHARE・OPTIONS 共通の文字の大きさ（4 倍の板での px）。
    OPTIONS が縁取り込みで幅 TEXT_MAX_W に収まり、大文字の高さが TEXT_MAX_CAP 以下になる最大の値。"""
    best = 0
    for size in range(4, 400 * SS):
        font = load_font(size)
        l, t, r, b = font.getbbox("OPTIONS")
        hl, ht, hr, hb = font.getbbox("H")
        if (r - l) + 2 * OUTLINE * SS > TEXT_MAX_W * SS or (hb - ht) > TEXT_MAX_CAP * SS:
            break
        best = size
    return best


def text_mark(text: str, size_ss: int):
    """文字の印。(インクの高さ, 描く関数 fn(d, x, y, grow, fill)) を返す。x, y は 256 単位の左上。"""
    font = load_font(size_ss)
    l, t, r, b = font.getbbox(text)
    ink_w, ink_h = (r - l) / SS, (b - t) / SS

    def fn(d, cx, top, grow, fill):
        # インクの左上が (cx - ink_w/2, top) に来るように置く。grow は縁取りの太さ
        x, y = (cx - ink_w / 2) * SS - l, top * SS - t
        d.text((x, y), text, font=font, fill=fill, stroke_width=int(round(grow * SS)), stroke_fill=fill)

    return ink_h, fn


def bars_mark(cap_w: float):
    """PS5 OPTIONS: 横棒 3 本の印。"""
    bar_w = cap_w * BAR_W_RATIO
    ink_h = 3 * RAY_THICK + 2 * RAY_THICK

    def fn(d, cx, top, grow, fill):
        for i in range(3):
            cy = top + RAY_THICK / 2 + i * 2 * RAY_THICK
            thick_line(d, (cx - bar_w / 2 + RAY_THICK / 2, cy), (cx + bar_w / 2 - RAY_THICK / 2, cy),
                       RAY_THICK + 2 * grow, fill)

    return ink_h, fn


def rays_mark(cap_w: float):
    """PS5 CREATE: 上向きに放射する 5 本の線の印。
    中心 C はカプセルの上の半円の中心。ink_h は C から見た線の上端までの高さ（カプセルの上端より上の部分）。"""
    r0 = cap_w / 2 + RAY_GAP
    r1 = r0 + RAY_LEN
    angles = [math.radians(a) for a in (-60, -30, 0, 30, 60)]
    # カプセルの上端（= C から cap_w/2 上）より上に出る高さ
    top_above_c = max(r1 * math.cos(a) for a in angles) + RAY_THICK / 2
    ink_h = top_above_c - cap_w / 2

    def fn(d, cx, cy, grow, fill):
        # cy は C の y 座標
        for a in angles:
            p0 = (cx + r0 * math.sin(a), cy - r0 * math.cos(a))
            p1 = (cx + r1 * math.sin(a), cy - r1 * math.cos(a))
            thick_line(d, p0, p1, RAY_THICK + 2 * grow, fill)

    return ink_h, fn


def finish(color: Image.Image, alpha: Image.Image) -> Image.Image:
    """4 倍の色の板とアルファの板を 256x256 に縮める。"""
    # 透明部分の色が縮小で混ざらないよう、アルファで重みを付けて縮める
    a = np.asarray(alpha, dtype=np.float32) / 255
    rgb = np.asarray(color, dtype=np.float32) * a[..., None]
    small_a = np.asarray(alpha.resize((256, 256), Image.LANCZOS), dtype=np.float32) / 255
    small_rgb = np.stack(
        [np.asarray(Image.fromarray(rgb[..., c]).resize((256, 256), Image.LANCZOS)) for c in range(3)], axis=2)
    out = np.zeros((256, 256, 4), dtype=np.uint8)
    safe = np.maximum(small_a, 1e-6)[..., None]
    out[..., :3] = np.clip(small_rgb / safe, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(small_a * 255 + 0.5, 0, 255).astype(np.uint8)
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(out, "RGBA")


def render(shape_fn, border, dark, thick: float) -> Image.Image:
    """4 倍の板に、縁取りの色で外形 → 縮めた形を暗い色で描き、256x256 に縮める。"""
    size = 256 * SS
    color = Image.new("RGB", (size, size), border)
    alpha = Image.new("L", (size, size), 0)
    dark_mask = Image.new("L", (size, size), 0)
    shape_fn(ImageDraw.Draw(alpha), 0.0, 255)
    shape_fn(ImageDraw.Draw(dark_mask), thick, 255)
    color.paste(Image.new("RGB", (size, size), dark), mask=dark_mask)
    return finish(color, alpha)


def render_marked(cap_w: float, cap_h: float, mark, rays: bool, border, dark, thick: float) -> Image.Image:
    """縦長のカプセルの上に印を載せた絵。印は明るい色で、まわりを暗い色で OUTLINE だけ縁取る。
    rays=False: 印（高さ ink_h）+ すき間 MARK_GAP + カプセルを縦中央にそろえる。
    rays=True: 印の fn の第 3 引数はカプセルの上の半円の中心 C の y。カプセルと放射線の外接矩形を縦中央にそろえる。"""
    ink_h, fn = mark
    total = ink_h + (0 if rays else MARK_GAP) + cap_h
    top = CENTER - total / 2
    cap_top = top + ink_h + (0 if rays else MARK_GAP)
    cap_cy = cap_top + cap_h / 2
    mark_y = cap_top + cap_w / 2 if rays else top

    size = 256 * SS
    color = Image.new("RGB", (size, size), border)
    alpha = Image.new("L", (size, size), 0)
    dark_mask = Image.new("L", (size, size), 0)
    light_mask = Image.new("L", (size, size), 0)
    cap = lambda d, s, f: capsule(d, cap_w, cap_h, s, f, cap_cy)
    cap(ImageDraw.Draw(alpha), 0.0, 255)
    cap(ImageDraw.Draw(dark_mask), thick, 255)
    fn(ImageDraw.Draw(alpha), CENTER, mark_y, OUTLINE, 255)
    fn(ImageDraw.Draw(dark_mask), CENTER, mark_y, OUTLINE, 255)
    fn(ImageDraw.Draw(light_mask), CENTER, mark_y, 0.0, 255)
    dark_img = Image.new("RGB", (size, size), dark)
    color.paste(dark_img, mask=dark_mask)
    color.paste(Image.new("RGB", (size, size), border), mask=light_mask)
    return finish(color, alpha)


def main() -> None:
    src = np.asarray(Image.open(CTRL / "button_minus.png").convert("RGBA")).copy()
    w, h, border, thick, dark = measure(src)
    print(f"見本: W={w} H={h} 縁取りの色={border} 縁取りの太さ={thick} 内側の色={dark}")

    # 5つの形を同じ倍率で大きくする。いちばん長い辺（カプセルの高さ H×1.9）を見本の横幅 W にそろえる。
    # 縁取りの太さは変えない。
    scale = w / (h * 1.9)
    print(f"倍率={scale:.4f}")
    cap_w, cap_h = h * scale, h * 1.9 * scale
    rect_w, rect_h, rect_r = h * 1.5 * scale, h * 0.95 * scale, h * 0.15 * scale
    tri_w, tri_h, tri_r = h * 1.1 * scale, h * 1.25 * scale, h * 0.08 * scale

    # 印付きの 4 枚のカプセルは高さ CAP_H、幅 CAP_H / CAP_RATIO
    mcap_h, mcap_w = CAP_H, CAP_H / CAP_RATIO
    text_size = pick_text_size()
    print(f"文字の大きさ={text_size / SS:.2f}px（4倍の板で {text_size}）")

    jobs = {
        "button_select": lambda: render(
            lambda d, s, f: rounded_rect(d, rect_w, rect_h, rect_r, s, f), border, dark, thick),
        "button_start": lambda: render(
            lambda d, s, f: rounded_triangle(d, tri_w, tri_h, tri_r, s, f), border, dark, thick),
        "button_share": lambda: render_marked(
            mcap_w, mcap_h, text_mark("SHARE", text_size), False, border, dark, thick),
        "button_options_ps4": lambda: render_marked(
            mcap_w, mcap_h, text_mark("OPTIONS", text_size), False, border, dark, thick),
        "button_options": lambda: render_marked(
            mcap_w, mcap_h, bars_mark(mcap_w), False, border, dark, thick),
        "button_create": lambda: render_marked(
            mcap_w, mcap_h, rays_mark(mcap_w), True, border, dark, thick),
    }
    for name, make in jobs.items():
        result = make()
        a = np.asarray(result)[..., 3]
        corners = [int(a[0, 0]), int(a[0, -1]), int(a[-1, 0]), int(a[-1, -1])]
        assert all(c == 0 for c in corners), corners
        result.save(CTRL / f"{name}.png")
        print(f"{name}: size={result.size} corner_alpha={corners}")


if __name__ == "__main__":
    main()

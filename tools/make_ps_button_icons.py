# PlayStation の表記（PS3 以前・PS4・PS5）で出し分ける小さいボタンの絵を5枚作る。
# PS3 の SELECT は四角（角丸の長方形）、START は右向きの三角。
# PS4・PS5 の SHARE・CREATE・OPTIONS は縦長のカプセル。
# 実物のボタンには記号が無く、名前は本体に印刷されているので、ボタンの中には何も描かない。
# 入力: assets/ui/controls/button_minus.png（横長のカプセル形の小さいボタン。色・縁取りの太さ・大きさの見本）
# 出力: assets/ui/controls/ の button_select.png・button_start.png・button_share.png・
#       button_create.png・button_options.png（256x256 RGBA、上書き、背景は透明）
# 実行: uv run --with pillow --with numpy python tools/make_ps_button_icons.py
# 作り方: 見本から外形の高さ H、縁取りの色と太さ、内側の暗い塗りの色を測る。
#       形は 4 倍の大きさで「縁取りの色で外形を塗る → 縁取りの太さだけ内側に縮めた形を暗い色で塗る」で描き、
#       アルファも 4 倍で描いてから 256x256 に LANCZOS で縮める（縁が滑らかになる）。形の中心は画像の中心。
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
CTRL = ROOT / "assets/ui/controls"
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


def capsule(d: ImageDraw.ImageDraw, w: float, h: float, shrink: float, fill) -> None:
    """縦長のカプセル（上下が半円）。shrink だけ内側に縮める。"""
    x0, x1 = (CENTER - w / 2 + shrink) * SS, (CENTER + w / 2 - shrink) * SS
    y0, y1 = (CENTER - h / 2 + shrink) * SS, (CENTER + h / 2 - shrink) * SS
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


def render(shape_fn, border, dark, thick: float) -> Image.Image:
    """4 倍の板に、縁取りの色で外形 → 縮めた形を暗い色で描き、256x256 に縮める。"""
    size = 256 * SS
    color = Image.new("RGB", (size, size), border)
    alpha = Image.new("L", (size, size), 0)
    dark_mask = Image.new("L", (size, size), 0)
    shape_fn(ImageDraw.Draw(alpha), 0.0, 255)
    shape_fn(ImageDraw.Draw(dark_mask), thick, 255)
    color.paste(Image.new("RGB", (size, size), dark), mask=dark_mask)
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

    capsule_fn = lambda d, s, f: capsule(d, cap_w, cap_h, s, f)
    jobs = {
        "button_select": lambda d, s, f: rounded_rect(d, rect_w, rect_h, rect_r, s, f),
        "button_start": lambda d, s, f: rounded_triangle(d, tri_w, tri_h, tri_r, s, f),
        "button_share": capsule_fn,
        "button_create": capsule_fn,
        "button_options": capsule_fn,
    }
    for name, fn in jobs.items():
        result = render(fn, border, dark, thick)
        a = np.asarray(result)[..., 3]
        corners = [int(a[0, 0]), int(a[0, -1]), int(a[-1, 0]), int(a[-1, -1])]
        assert all(c == 0 for c in corners), corners
        result.save(CTRL / f"{name}.png")
        print(f"{name}: size={result.size} corner_alpha={corners}")


if __name__ == "__main__":
    main()

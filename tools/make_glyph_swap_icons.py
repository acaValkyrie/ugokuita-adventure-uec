# 操作説明のアイコンのうち、中の文字・記号の形がずれている4枚を、形のそろった見本の本体に文字だけ載せ替えて作り直す。
# 入力: assets/ui/controls/ の trigger_lt.png・stick_left.png・button_b.png（見本の本体）と、
#       文字の取り出し元4枚（trigger_rt・stick_right・button_x・button_triangle）。
#       取り出し元は最初に scratchpad の menu/glyph_src/ へ（無ければ）コピーし、以後はそこから読む。
# 出力: assets/ui/controls/ の trigger_rt.png・stick_right.png・button_x.png・button_triangle.png（256x256 RGBA、上書き）
# 実行: uv run --with pillow --with numpy python tools/make_glyph_swap_icons.py
# 見本の本体の内側（暗い画素の連結成分を穴埋めした領域）の文字を消し、取り出し元の文字（アルファ付き）を
# 見本の文字と同じ高さ・同じ中心に合わせて (242,242,242) で重ねる。
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
CTRL = ROOT / "assets/ui/controls"
SRC_DIR = Path(r"C:\Users\yadok\AppData\Local\Temp\claude\D--document-Program-Godot-ugokuita-adventure-uec"
               r"\c2d67861-ca1a-483d-8a82-b994a97449b8\scratchpad\menu\glyph_src")
DARK_LEVEL = 90  # これ未満を本体の暗い画素とみなす
WHITE_LEVEL = 150  # これより明るいものを文字とみなす
MIN_BODY = 2000  # 本体とみなす連結成分の最小画素数
WHITE = 242
ERASE_MARGIN = 5  # 文字を消すときの広げ幅（MaxFilter のサイズ。周り2px）

# (出力名, 見本, 取り出し元)
JOBS = [
    ("trigger_rt", "trigger_lt", "trigger_rt"),
    ("stick_right", "stick_left", "stick_right"),
    ("button_x", "button_b", "button_x"),
    ("button_triangle", "button_b", "button_triangle"),
]


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).copy()


def inner_region(rgba: np.ndarray) -> np.ndarray:
    """最大の暗い連結成分を穴埋めした、本体の内側のマスク。"""
    lum = rgba[..., :3].max(axis=2)
    dark = (rgba[..., 3] > 200) & (lum < DARK_LEVEL)
    ys, xs = np.nonzero(dark)
    # 文字の穴（△の内側など）に引っかからないよう、最大の連結成分を本体とする
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
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def main() -> None:
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    for _, _, g in JOBS:
        dst = SRC_DIR / f"{g}.png"
        if not dst.exists():
            shutil.copy2(CTRL / f"{g}.png", dst)

    for out_name, tmpl_name, glyph_name in JOBS:
        # 見本
        t = load(CTRL / f"{tmpl_name}.png")
        t_in = inner_region(t)
        t_lum = t[..., :3].max(axis=2)
        t_dark = np.median(t[t_in & (t_lum < DARK_LEVEL)][:, :3], axis=0)
        t_white = t_in & (t_lum > WHITE_LEVEL)
        x0, y0, x1, y1 = bbox(t_white)
        t_h = y1 - y0
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        erase = np.asarray(Image.fromarray((t_white * 255).astype(np.uint8))
                           .filter(ImageFilter.MaxFilter(ERASE_MARGIN))) > 0
        t[erase & t_in, :3] = np.round(t_dark).astype(np.uint8)

        # 取り出し元の文字
        s = load(SRC_DIR / f"{glyph_name}.png")
        s_in = inner_region(s)
        s_lum = s[..., :3].max(axis=2).astype(np.float64)
        s_dark = float(np.median(s[s_in & (s_lum < DARK_LEVEL)][:, :3].max(axis=1)))
        alpha = np.clip((s_lum - s_dark) / (WHITE - s_dark), 0, 1)
        # 白っぽい画素とその周り1px（アンチエイリアス分）だけを文字とし、暗いノイズは捨てる
        core = s_in & (s_lum > WHITE_LEVEL)
        keep = np.asarray(Image.fromarray((core * 255).astype(np.uint8))
                          .filter(ImageFilter.MaxFilter(3))) > 0
        alpha[~(keep & s_in)] = 0
        gx0, gy0, gx1, gy1 = bbox(alpha > 0)
        g_h = gy1 - gy0
        mask = Image.fromarray((alpha[gy0:gy1, gx0:gx1] * 255).astype(np.uint8))
        scale = t_h / g_h
        new_w = max(1, round(mask.width * scale))
        mask = mask.resize((new_w, t_h), Image.LANCZOS)

        # 置く
        px = round(cx - new_w / 2)
        py = round(cy - t_h / 2)
        layer = Image.new("RGBA", (256, 256), (WHITE, WHITE, WHITE, 0))
        layer.paste(Image.merge("RGBA", [Image.new("L", mask.size, WHITE)] * 3 + [mask]), (px, py))
        base = Image.fromarray(t, "RGBA")
        result = Image.alpha_composite(base, layer)
        out = np.asarray(result)
        corners = [out[0, 0, 3], out[0, -1, 3], out[-1, 0, 3], out[-1, -1, 3]]
        assert all(c == 0 for c in corners), corners
        result.save(CTRL / f"{out_name}.png")
        print(f"{out_name}: size={result.size} corner_alpha={corners} "
              f"template_h={t_h} source_h={g_h}")


if __name__ == "__main__":
    main()

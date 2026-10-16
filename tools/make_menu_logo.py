# メニュー用に、ロゴ画像の黒い背景を透明にして、ロボットの絵だけの画像と、「動く板」と「Project」の文字をまとめた画像に切り分ける。
# 入力: assets/img/ugokuita logo.jpg（黒背景。上にロボットの絵、下に「動く板」と「Project」の文字）
# 出力: assets/ui/menu/logo_robot.png、assets/ui/menu/logo_text.png（どちらもRGBA）
# 実行: uv run --with pillow --with numpy python tools/make_menu_logo.py
# 背景は alpha = max(R,G,B)/255 として色を割り戻して抜く。境目は150〜260行目で不透明画素数が最小の行（同点なら一番上）にする。
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/img/ugokuita logo.jpg"
OUT_DIR = ROOT / "assets/ui/menu"
ALPHA_CUT = 0.06  # これ未満は完全に透明（JPEGのノイズ対策）
MARGIN = 4
OPAQUE_LEVEL = 40  # 境目探しで「不透明」とみなす max(R,G,B) のしきい値
SPLIT_FROM = 150  # 境目を探す行の範囲
SPLIT_TO = 260


def to_rgba(path: Path) -> np.ndarray:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)
    alpha = rgb.max(axis=2) / 255.0
    alpha[alpha < ALPHA_CUT] = 0.0
    safe = np.where(alpha > 0, alpha, 1.0)[..., None]
    color = np.clip(np.round(rgb / safe), 0, 255)
    color[alpha == 0] = 0
    out = np.dstack([color, np.round(alpha * 255)[..., None]])
    return out.astype(np.uint8)


def find_split(path: Path) -> int:
    # 150〜260行目のうち、元画像の不透明画素数（max(R,G,B)>40）が最小の行を境目にする（同点なら一番上）
    rgb = np.asarray(Image.open(path).convert("RGB"))
    counts = (rgb.max(axis=2) > OPAQUE_LEVEL).sum(axis=1)
    window = counts[SPLIT_FROM : SPLIT_TO + 1]
    y = SPLIT_FROM + int(np.argmin(window))
    print("split row:", y, "count:", counts[y])
    return y

def crop_save(rgba: np.ndarray, y0: int, y1: int, name: str) -> None:
    part = rgba[y0:y1]
    ys, xs = np.where(part[..., 3] > 0)
    top = max(ys.min() - MARGIN, 0)
    bottom = min(ys.max() + MARGIN + 1, part.shape[0])
    left = max(xs.min() - MARGIN, 0)
    right = min(xs.max() + MARGIN + 1, part.shape[1])
    img = Image.fromarray(part[top:bottom, left:right], "RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(OUT_DIR / name)
    a = np.asarray(img)[..., 3]
    print(name, img.size, "corner alpha:", a[0, 0], a[0, -1], a[-1, 0], a[-1, -1])


def main() -> None:
    rgba = to_rgba(SRC)
    split = find_split(SRC)
    crop_save(rgba, 0, split, "logo_robot.png")
    crop_save(rgba, split, rgba.shape[0], "logo_text.png")


main()

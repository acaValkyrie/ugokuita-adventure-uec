# 割り当てを変えたキー・ボタンの絵に使う、文字の無いキー・ボタンの絵を作る。
# 入力: assets/ui/controls/ の key_r.png（256x256、1文字のキー）と key_shift.png（512x112、横長のキー）、
#       button_a.png（256x256、丸いボタン）と shoulder_rb.png（178x93、右の肩のボタン）
# 出力: assets/ui/controls/ の key_blank.png（key_r から文字を消したもの）と key_blank_wide.png（key_shift から文字を消したもの）、
#       button_blank.png（button_a から文字を消したもの）と shoulder_blank_r.png（shoulder_rb から文字を消したもの）、
#       shoulder_blank_l.png（shoulder_blank_r を左右反転したもの。左の肩のボタン）
# 実行: python tools/make_blank_key_icons.py
# キーの面は黒に近い色（RGB 25〜30 前後）、縁は明るい灰色（215 前後）、文字は白（240 前後）。
# 画素を調べて決めた「キーの面」の矩形（右端・下端は含まない）から、縁と角の丸みを避けて 10px 内側に入った矩形を
# 「内側の矩形」とし、その中の明るい画素（文字とそのにじみ）と、その周り4px（文字の暗い縁取り）を、面の色（面の画素の中央値）で塗る。縁・影・角の丸み・透明部分は変えない。
# key_r の面は x 55〜200・y 55〜196（下と右には厚みの縁と影がある）→ 内側の矩形は x 65〜190・y 65〜186（文字は x 94〜164・y 89〜169）。
# key_shift の面は x 61〜450・y 11〜94 → 内側の矩形は x 71〜440・y 21〜84（文字は x 185〜326・y 35〜72）。
# button_a の面は丸で、中心 (128, 127.5)・半径 80（x 48〜207・y 48〜206。縁の厚みは外側の5px）。丸に収まる正方形 x 68〜188・y 68〜188 を「面の矩形」として扱う
# → 内側の矩形は x 78〜178・y 78〜178。
# shoulder_rb の面は角の丸い長方形で x 10〜167・y 13〜79 → 内側の矩形は x 20〜157・y 23〜69（文字は x 55〜125・y 25〜67）。
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
CTRL = ROOT / "assets/ui/controls"
INSET = 10  # 面の矩形から内側に入る幅（縁・角の丸みに触れないため）
BRIGHT_LEVEL = 36  # 面の色（25〜30 前後）よりこれ以上明るければ、文字とそのにじみとみなす
GROW = 9  # 文字の輪郭には面より暗い縁取り（RGB 13〜20 前後）があるので、明るい画素を広げる幅（MaxFilter のサイズ。周り4px）
FACE_DARK_LEVEL = 60  # 面の色の中央値を取るときに、これ未満を面の画素とする

# (入力, 出力, 面の矩形 (x0, y0, x1, y1)。x1・y1 は含まない)
JOBS = [
    ("key_r", "key_blank", (55, 55, 200, 196)),
    ("key_shift", "key_blank_wide", (61, 11, 450, 94)),
    ("button_a", "button_blank", (68, 68, 188, 188)),
    ("shoulder_rb", "shoulder_blank_r", (10, 13, 168, 80)),
]
# 左の肩のボタン: 文字を消した右の肩のボタンを左右反転する (入力, 出力)
FLIP_JOBS = [("shoulder_blank_r", "shoulder_blank_l")]


def main() -> None:
    for src_name, out_name, face in JOBS:
        rgba = np.asarray(Image.open(CTRL / f"{src_name}.png").convert("RGBA")).copy()
        x0, y0, x1, y1 = face
        ix0, iy0, ix1, iy1 = x0 + INSET, y0 + INSET, x1 - INSET, y1 - INSET
        inner = rgba[iy0:iy1, ix0:ix1]
        lum = inner[..., :3].max(axis=2)
        face_pixels = rgba[y0:y1, x0:x1]
        face_lum = face_pixels[..., :3].max(axis=2)
        face_color = np.round(np.median(face_pixels[face_lum < FACE_DARK_LEVEL][:, :3], axis=0)).astype(np.uint8)
        bright = lum > BRIGHT_LEVEL
        grown = np.asarray(Image.fromarray((bright * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(GROW))) > 0
        inner[grown, :3] = face_color
        Image.fromarray(rgba, "RGBA").save(CTRL / f"{out_name}.png")

        # 確認: 書き出した画像を読み直して、内側の矩形に明るい画素が残っていないか調べる
        check = np.asarray(Image.open(CTRL / f"{out_name}.png").convert("RGBA"))
        remaining = int((check[iy0:iy1, ix0:ix1, :3].max(axis=2) > BRIGHT_LEVEL).sum())
        print(f"{out_name}: size={check.shape[1]}x{check.shape[0]} face_color={tuple(int(v) for v in face_color)} "
              f"inner=x{ix0}-{ix1 - 1},y{iy0}-{iy1 - 1} painted={int(grown.sum())} remaining_bright={remaining}")

    for src_name, out_name in FLIP_JOBS:
        original = np.asarray(Image.open(CTRL / f"{src_name}.png").convert("RGBA"))
        Image.fromarray(original[:, ::-1].copy(), "RGBA").save(CTRL / f"{out_name}.png")
        # 確認: 書き出した画像を読み直して、反転前の左右を入れ替えたものと一致するか調べる
        check = np.asarray(Image.open(CTRL / f"{out_name}.png").convert("RGBA"))
        print(f"{out_name}: size={check.shape[1]}x{check.shape[0]} mirrored_from={src_name} match={bool((check == original[:, ::-1]).all())}")


if __name__ == "__main__":
    main()

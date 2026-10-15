# ヒント（看板の「ウェブで開く」など）の表示用に、Noto Sans CJK JP Bold から必要な文字だけを抜き出す。
# 入力: /usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc の「Noto Sans CJK JP」（Monoではない）
# 出力: assets/fonts/noto_sans_cjk_jp_bold_ui.otf
# 実行: uv run --with fonttools python tools/make_ui_font.py
# 表示する日本語を増やすときは TEXT に足して作り直す。
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTCollection

SRC = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
OUT = Path(__file__).resolve().parent.parent / "assets/fonts/noto_sans_cjk_jp_bold_ui.otf"
FAMILY = "Noto Sans CJK JP"

# ASCIIの印字可能文字に加えて、ここに書いた文字だけを含める
TEXT = (
    "ウェブで開くタップして東西号館棟新図書国際交流会学生本プール管理体育地区食堂第0123456789ABCD"
    "BOOSTゲージ増加量UPがたまりやすくなったぞ！！二段ジャンプ空中でもう一度できるようになったぞ！！"
    "モータートルクUP坂に強くなって、スピードと加速も上がったぞ！！をてにいれた！で続ける"
    "ジャンプ力UP高くジャンプできるようになったぞ！！"
)


def main() -> None:
    # ttc の中から JP（Mono ではない）の番号を family name で探す
    collection = TTCollection(SRC)
    number = next(
        i for i, f in enumerate(collection.fonts) if f["name"].getDebugName(1) == FAMILY
    )
    print("font number:", number)

    options = subset.Options()
    options.font_number = number
    font = subset.load_font(SRC, options)
    subsetter = subset.Subsetter(options)
    chars = {chr(c) for c in range(0x20, 0x7F)} | set(TEXT)
    subsetter.populate(unicodes=[ord(c) for c in chars])
    subsetter.subset(font)
    subset.save_font(font, str(OUT), options)
    print("wrote", OUT)


main()

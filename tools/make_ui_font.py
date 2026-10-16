# ヒント（看板の「ウェブで開く」など）やメニューの表示用に、Noto Sans JP（可変フォント）から必要な文字だけを抜き出す。
# 入力: C:\Windows\Fonts\NotoSansJP-VF.ttf（wght=700 の固定インスタンスを作ってから subset する）
# 出力: assets/fonts/noto_sans_cjk_jp_bold_ui.otf
# 実行: uv run --with fonttools python tools/make_ui_font.py
# 表示する日本語を増やすときは TEXT に足して作り直す。
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

SRC = r"C:\Windows\Fonts\NotoSansJP-VF.ttf"
OUT = Path(__file__).resolve().parent.parent / "assets/fonts/noto_sans_cjk_jp_bold_ui.otf"

# ASCIIの印字可能文字に加えて、ここに書いた文字だけを含める
TEXT = (
    "ウェブで開くタップして東西号館棟新図書国際交流会学生本プール管理体育地区食堂第0123456789ABCD"
    "BOOSTゲージ増加量UPがたまりやすくなったぞ！！二段ジャンプ空中でもう一度できるようになったぞ！！"
    "モータートルクUP坂に強くなって、スピードと加速も上がったぞ！！をてにいれた！で続ける"
    "ジャンプ力UP高くジャンプできるようになったぞ！！"
    "ジェットジャンプ長押しで空を飛べるようになったぞ！！"
    "屋上到達！マップにヒントの印が付いたぞ！！"
    "音量ゲーム全体の音量を調整しますコントローラーの設定ボタンの表示形式を切り替えますロボットタイプ操作する機体を切り替えます閉じる"
)


def main() -> None:
    # 可変フォントから wght=700 の固定インスタンスを作る
    variable = TTFont(SRC)
    bold = instancer.instantiateVariableFont(variable, {"wght": 700})

    options = subset.Options()
    subsetter = subset.Subsetter(options)
    chars = {chr(c) for c in range(0x20, 0x7F)} | set(TEXT)
    subsetter.populate(unicodes=[ord(c) for c in chars])
    subsetter.subset(bold)
    subset.save_font(bold, str(OUT), options)
    print("wrote", OUT)


main()

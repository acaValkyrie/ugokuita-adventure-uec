# ヒント（看板の「ウェブで開く」など）やメニューの表示用に、Noto Sans JP（可変フォント）から必要な文字だけを抜き出す。
# 入力: C:\Windows\Fonts\NotoSansJP-VF.ttf（wght=700 の固定インスタンスを作ってから subset する）
# 出力: assets/fonts/noto_sans_cjk_jp_bold_ui.otf
# 実行: uv run --with fonttools python tools/make_ui_font.py
# 文字はコード（.gd）とシーン（.tscn）の文字列から自動で集める。文字を足したら作り直す。
import re
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

SRC = r"C:\Windows\Fonts\NotoSansJP-VF.ttf"
OUT = Path(__file__).resolve().parent.parent / "assets/fonts/noto_sans_cjk_jp_bold_ui.otf"

ROOT = Path(__file__).resolve().parent.parent

# ASCIIの印字可能文字と、コード・シーンから集めた文字に加えて、ここに書いた文字を含める。
# コードに書かれていない文字を足すときは TEXT に書く
TEXT = (
    "ウェブで開くタップして東西号館棟新図書国際交流会学生本プール管理体育地区食堂第0123456789ABCD"
    "BOOSTゲージ増加量UPがたまりやすくなったぞ！！二段ジャンプ空中でもう一度できるようになったぞ！！"
    "モータートルクUP坂に強くなって、スピードと加速も上がったぞ！！をてにいれた！で続ける"
    "ジャンプ力UP高くジャンプできるようになったぞ！！"
    "ジェットジャンプ長押しで空を飛べるようになったぞ！！"
    "屋上到達！マップにヒントの印が付いたぞ！！"
    "音量ゲーム全体の音量を調整しますコントローラーの設定ボタンの表示形式を切り替えますロボットタイプ操作する機体を切り替えます閉じる"
    "決定キャンセル"
    "決定とキャンセル標準入れ替えボタンを入れ替えます"
    "ボタンの表示形式PlayStationの表記SELECT・STARTのボタンの表記を選びますPS3以前"
    "BGM と効果音の音量を調整します。決定ボタンで試聴できます使っているコントローラーのメーカーに合わせて変更してください慣れてる方に変更してください"
)


def gd_string_chars(src: str) -> set[str]:
    """GDScript の "..." リテラルの中の文字を集める（行の # 以降のコメントは除く）。"""
    found: set[str] = set()
    for line in src.splitlines():
        i = 0
        n = len(line)
        while i < n:
            ch = line[i]
            if ch == "#":
                break
            if ch == '"':
                i += 1
                while i < n and line[i] != '"':
                    if line[i] == "\\" and i + 1 < n:
                        i += 1
                    found.add(line[i])
                    i += 1
            i += 1
    return found


def collect_chars() -> set[str]:
    found: set[str] = set()
    for p in ROOT.rglob("*.gd"):
        if "addons" in p.relative_to(ROOT).parts:
            continue
        found |= gd_string_chars(p.read_text(encoding="utf-8", errors="ignore"))
    for p in ROOT.rglob("*.tscn"):
        if "addons" in p.relative_to(ROOT).parts:
            continue
        text = p.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r'= "((?:[^"\\]|\\.)*)"', text):
            found |= set(m.group(1))
    return {c for c in found if c.isprintable() and c not in "\n\r\t"}


def main() -> None:
    # 可変フォントから wght=700 の固定インスタンスを作る
    variable = TTFont(SRC)
    bold = instancer.instantiateVariableFont(variable, {"wght": 700})

    options = subset.Options()
    subsetter = subset.Subsetter(options)
    chars = {chr(c) for c in range(0x20, 0x7F)} | set(TEXT) | collect_chars()
    chars = {c for c in chars if c.isprintable()}
    subsetter.populate(unicodes=[ord(c) for c in chars])
    subsetter.subset(bold)
    subset.save_font(bold, str(OUT), options)
    print("wrote", OUT)

    cmap = TTFont(str(OUT)).getBestCmap()
    missing = sorted(c for c in chars if ord(c) not in cmap)
    print("requested", len(chars), "chars, included", len(chars) - len(missing))
    if missing:
        print("not in font:", "".join(missing), [f"U+{ord(c):04X}" for c in missing])


main()

# ending.gd のクレジットと gomi_ending.gd の ED3 の漫画文字（「ドタ」「バタ」など）用に、Noto Sans JP から必要な文字だけを抜き出す。
# Web ビルドでは OS のフォントを使えないため、フォントを同梱する。
# 入力: C:\Windows\Fonts\NotoSansJP-VF.ttf（wght=700 の固定インスタンスを作ってから subset する）
# 出力: assets/fonts/noto_sans_jp_bold_ending.otf
# 実行: uv run --with fonttools python tools/make_ending_font.py
# 文字は ending.gd と gomi_ending.gd の文字列から自動で集める。これらの表示テキストを変更したら作り直す。
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

SRC = r"C:\Windows\Fonts\NotoSansJP-VF.ttf"
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/fonts/noto_sans_jp_bold_ending.otf"


def gd_string_chars(src: str) -> set[str]:
    """GDScript の引用符で囲まれたリテラルの文字を集める（行の # 以降のコメントは除く）。"""
    found: set[str] = set()
    for line in src.splitlines():
        i = 0
        n = len(line)
        while i < n:
            ch = line[i]
            if ch == "#":
                break
            if ch in ('"', "'"):
                quote = ch
                i += 1
                while i < n and line[i] != quote:
                    if line[i] == "\\" and i + 1 < n:
                        i += 1
                    found.add(line[i])
                    i += 1
            i += 1
    return found


def collect_chars() -> set[str]:
    found: set[str] = set()
    for name in ("ending.gd", "gomi_ending.gd"):
        found |= gd_string_chars((ROOT / name).read_text(encoding="utf-8", errors="ignore"))
    return {c for c in found if c.isprintable() and c not in "\n\r\t"}


def main() -> None:
    # 可変フォントから wght=700 の固定インスタンスを作る
    variable = TTFont(SRC)
    bold = instancer.instantiateVariableFont(variable, {"wght": 700})

    options = subset.Options()
    subsetter = subset.Subsetter(options)
    chars = {chr(c) for c in range(0x20, 0x7F)} | collect_chars()
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

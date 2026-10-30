# コードやシーンの文字列に使う文字が、表示用のサブセットフォントに入っているか調べる。
# 実行: uv run --with fonttools python tools/check_font_glyphs.py
# 文字を足して欠字になったら、表示された生成スクリプトでフォントを作り直す。
import argparse
import os
from pathlib import Path

from fontTools.ttLib import TTFont


ROOT = Path(__file__).resolve().parent.parent
EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".json"}
EXCLUDED_TOP = {
    ".godot", ".git", ".codex", "addons", "tools", "tmp", "latest", "blender", "tests"
}
EXCLUDED_ANYWHERE = {"node_modules", "__pycache__"}
ENDING_FILES = {"ending.gd", "gomi_ending.gd"}


def string_chars(source: str, gdscript: bool):
    """引用符の中の文字と行番号を取り出す（GDScript の文字列外の # はコメント）。"""
    i = 0
    line = 1
    quote = None
    while i < len(source):
        ch = source[i]
        if quote is None:
            if gdscript and ch == "#":
                end = source.find("\n", i)
                i = len(source) if end < 0 else end
                continue
            if ch in "\"'":
                # 複数行文字列でも、引用符そのものを文字として数えない。
                quote = ch * 3 if source.startswith(ch * 3, i) else ch
                i += len(quote)
                continue
        else:
            if source.startswith(quote, i):
                i += len(quote)
                quote = None
                continue
            if ch == "\\" and i + 1 < len(source):
                i += 1
                ch = source[i]
                # Unicode エスケープも、実際に表示される文字として調べる。
                digits = {"u": 4, "U": 8, "x": 2}.get(ch)
                if digits is not None:
                    encoded = source[i + 1:i + 1 + digits]
                    if (len(encoded) == digits
                            and all(c in "0123456789abcdefABCDEF" for c in encoded)
                            and int(encoded, 16) <= 0x10FFFF):
                        ch = chr(int(encoded, 16))
                        i += digits
            if ord(ch) > 0x7F and ch.isprintable():
                yield ch, line
        if source[i] == "\n":
            line += 1
        i += 1


def collect_chars(root: Path):
    ui = {}
    ending = {}
    for directory, subdirs, filenames in os.walk(root):
        relative = Path(directory).relative_to(root)
        subdirs[:] = sorted(
            name for name in subdirs
            if name not in EXCLUDED_ANYWHERE
            and not (relative == Path(".") and name in EXCLUDED_TOP)
        )
        for name in sorted(filenames):
            path = Path(directory) / name
            if path.suffix not in EXTENSIONS:
                continue
            display_path = path.relative_to(root).as_posix()
            source = path.read_text(encoding="utf-8")
            for ch, line in string_chars(source, path.suffix == ".gd"):
                location = f"{display_path}:{line}"
                ui.setdefault(ch, location)
                if name in ENDING_FILES:
                    ending.setdefault(ch, location)
    return ui, ending


def check_font(path: Path, chars: dict, generator: str) -> bool:
    # ASCII の印字可能文字は、コード中に出てこなくても両フォントに必要。
    required = {chr(code): "ASCII 必須文字" for code in range(0x20, 0x7F)}
    required.update(chars)
    try:
        with TTFont(path) as font:
            cmap = font.getBestCmap() or {}
    except Exception as error:
        print(f"{path}: フォントを読み込めません: {error}")
        print(f"再生成: uv run --with fonttools python tools/{generator}")
        return False
    missing = sorted(ch for ch in required if ord(ch) not in cmap)
    if not missing:
        return True
    print(f"{path}: {len(missing)} 文字がフォントにありません")
    for ch in missing:
        print(f"  {ch!r} U+{ord(ch):04X} {required[ch]}")
    print(f"再生成: uv run --with fonttools python tools/{generator}")
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="表示用フォントの欠字を調べる")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--ui-font", type=Path,
                        default=Path("assets/fonts/noto_sans_cjk_jp_bold_ui.otf"))
    parser.add_argument("--ending-font", type=Path,
                        default=Path("assets/fonts/noto_sans_jp_bold_ending.otf"))
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        parser.error(f"スキャンするディレクトリがありません: {root}")
    ui, ending = collect_chars(root)
    ui_ok = check_font(root / args.ui_font, ui, "make_ui_font.py")
    ending_ok = check_font(root / args.ending_font, ending, "make_ending_font.py")
    if ui_ok and ending_ok:
        print(f"フォントの欠字なし（UI: {len(ui) + 95} 文字、エンディング: {len(ending) + 95} 文字）")
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

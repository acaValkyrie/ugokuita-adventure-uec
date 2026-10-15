# 起動画面（boot splash）用の画像（1152x648）を作る。
# 黒（#000000）の地の中央に、動く板Projectのロゴを元の大きさのまま置く。
# 引数: 入力JPG 出力PNG
# 実行例:
#   uv run --with pillow python tools/make_splash.py "assets/img/ugokuita logo.jpg" assets/img/splash.png
import sys

from PIL import Image

W, H = 1152, 648


def main():
    src, dst = sys.argv[1], sys.argv[2]
    logo = Image.open(src).convert("RGB")
    img = Image.new("RGB", (W, H), "#000000")
    img.paste(logo, ((W - logo.width) // 2, (H - logo.height) // 2))
    img.save(dst, "PNG")


if __name__ == "__main__":
    main()

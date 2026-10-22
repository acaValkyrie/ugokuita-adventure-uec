# 「動く板ミュージアム」を案内する看板のポスター画像（1500x600）を作る。
# 元画像は、ブログ記事「動く板ミュージアム」のページを撮った画面写真（1209x945）。
# 左の丸い写真は記事の写真の部分から、右上のロゴはページ左上のサイトロゴから切り出す。
# Windows で次のように実行する（フォントは C:\Windows\Fonts\NotoSansJP-VF.ttf の可変フォント）:
#   python tools/make_museum_poster.py <元の画面写真> assets/boards/ugokuita_museum_poster.png
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = r"C:\Windows\Fonts\NotoSansJP-VF.ttf"

W, H = 1500, 600
BG = "#0d1117"
BORDER = "#30363d"
GRAY = "#8b949e"
LIGHT = "#c9d1d9"
WHITE = "#ffffff"

# 元画像の中の、記事の写真の部分
PHOTO_BOX = (271, 357, 940, 820)
# 丸く切り出す中心と直径（動く板が円の中に入る位置）
PHOTO_CENTER = (610, 598)
# 元画像の左上のロゴ（角丸の四角。外の緑の背景が入らないよう少し内側を取る）
LOGO_BOX = (25, 16, 100, 91)


def load_font(size: int, weight: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(FONT, size)
    font.set_variation_by_axes([weight])  # 軸は Weight のみ
    return font


def circle_photo(src: Image.Image, center: tuple, diameter: int) -> Image.Image:
    # 写真の部分からはみ出さないことを確かめる
    r = diameter // 2
    box = (center[0] - r, center[1] - r, center[0] + r, center[1] + r)
    assert (
        box[0] >= PHOTO_BOX[0] and box[1] >= PHOTO_BOX[1]
        and box[2] <= PHOTO_BOX[2] and box[3] <= PHOTO_BOX[3]
    ), f"切り出し範囲が写真からはみ出している: {box}"
    # アンチエイリアスのため4倍で切り抜いてから縮小する
    scale = 4
    size = diameter * scale
    photo = src.crop(box).convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    photo.putalpha(mask)
    return photo.resize((diameter, diameter), Image.LANCZOS)


def white_ring(outer_d: int, width: int) -> Image.Image:
    # 白い輪だけの透明レイヤーを4倍で描いて縮小する
    scale = 4
    size = outer_d * scale
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse(
        (0, 0, size - 1, size - 1), outline=WHITE, width=width * scale
    )
    return ring.resize((outer_d, outer_d), Image.LANCZOS)


def rounded_logo(src: Image.Image, height: int, radius: int) -> Image.Image:
    # ロゴを切り出して拡大し、角を丸く切り抜く（4倍で作って縮小）
    scale = 4
    size = height * scale
    logo = src.crop(LOGO_BOX).convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius * scale, fill=255
    )
    logo.putalpha(mask)
    return logo.resize((height, height), Image.LANCZOS)


def main() -> None:
    src_path, out_path = sys.argv[1:3]
    src = Image.open(src_path).convert("RGB")

    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    # 外周の枠
    draw.rectangle((0, 0, W - 1, H - 1), outline=BORDER, width=12)

    # 左: 円形の写真と白い輪（輪は写真の外側に付ける）
    center = (300, 300)
    photo_d = 440
    ring_w = 8
    ring_d = photo_d + ring_w * 2
    ring = white_ring(ring_d, ring_w)
    img.paste(ring, (center[0] - ring_d // 2, center[1] - ring_d // 2), ring)
    photo = circle_photo(src, PHOTO_CENTER, photo_d)
    img.paste(photo, (center[0] - photo_d // 2, center[1] - photo_d // 2), photo)

    # 右: ロゴ、タイトル、説明、URL
    title_font = load_font(80, 700)
    desc_font = load_font(40, 400)
    url_font = load_font(56, 400)
    title = "動く板ミュージアム"
    desc = "動く板の秘蔵資料（主にハードウェア関連）"
    url_text = "yae.wiki"

    logo_h = 120
    x = 580
    title_x = 730
    gap_desc = 40  # ロゴ（タイトル）の下から説明まで
    gap_url = 30  # 説明の下からURLまで
    # 説明とURLの文字の高さを測り、3行のまとまり全体を縦中央（y = 300）にそろえる
    desc_h = draw.textbbox((0, 0), desc, font=desc_font, anchor="la")[3]
    url_h = draw.textbbox((0, 0), url_text, font=url_font, anchor="la")[3]
    group_h = logo_h + gap_desc + desc_h + gap_url + url_h
    top = center[1] - group_h // 2
    desc_y = top + logo_h + gap_desc
    url_y = desc_y + desc_h + gap_url

    logo = rounded_logo(src, logo_h, 28)
    img.paste(logo, (x, top), logo)
    title_xy = (title_x, top + logo_h // 2)
    draw.text(title_xy, title, font=title_font, fill=WHITE, anchor="lm")
    draw.text((x, desc_y), desc, font=desc_font, fill=LIGHT, anchor="la")
    draw.text((x, url_y), url_text, font=url_font, fill=GRAY, anchor="la")

    # はみ出しの確認（内側の枠 12px より外に出ていないか）
    for name, xy, font, text, anchor in [
        ("title", title_xy, title_font, title, "lm"),
        ("desc", (x, desc_y), desc_font, desc, "la"),
        ("url", (x, url_y), url_font, url_text, "la"),
    ]:
        box = draw.textbbox(xy, text, font=font, anchor=anchor)
        print(name, "bbox", box)
        if box[2] > W - 12 or box[3] > H - 12:
            print("WARNING: はみ出し:", name)

    img.save(out_path)
    print("saved", out_path, img.size)


main()

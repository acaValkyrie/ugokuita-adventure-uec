class_name UiStyle
extends RefCounted
# 画面 UI 共通のスタイル（一時停止メニューの見た目に揃える）。色・寸法の定数と、部品を作る static 関数だけを持つ。

const FONT := preload("res://assets/fonts/noto_sans_cjk_jp_bold_ui.otf")
# パネル（HUD は少し透かす、ポップアップは不透明）
const PANEL_COLOR := Color(0.07, 0.07, 0.08, 0.86)
const PANEL_SOLID_COLOR := Color(0.07, 0.07, 0.08, 1.0)
const PANEL_RADIUS := 12
# パネルの縁（明るい灰色の細い線）
const BORDER_COLOR := Color(1, 1, 1, 0.16)
const BORDER_WIDTH := 1
# 区切り線
const LINE_COLOR := Color(1, 1, 1, 0.14)
# 文字
const TEXT_COLOR := Color(0.95, 0.95, 0.95)
const TEXT_DIM_COLOR := Color(0.62, 0.62, 0.62)
# アクセントの赤
const ACCENT_COLOR := Color("#e0182d")
const ACCENT_DARK_COLOR := Color("#4a0b12")
# 暗幕
const DIMMER_COLOR := Color(0, 0, 0, 0.55)
# 3D の画面の上に直接置く文字の縁取り（パネルに載せない文字だけに使う）
const OUTLINE_COLOR := Color(0, 0, 0, 0.75)
# タッチ操作の端末で、押すボタンを大きくする倍率
const TOUCH_BUTTON_SCALE := 2.0


# タッチ操作の端末か
static func is_touch_device() -> bool:
    return OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


# 押すボタンの大きさの倍率（タッチ操作の端末だけ大きくする）
static func button_scale() -> float:
    return TOUCH_BUTTON_SCALE if is_touch_device() else 1.0


# パネルの背景。content_margin は付けないので、呼ぶ側で設定する
static func make_panel_style(solid: bool = false, radius: int = PANEL_RADIUS, border: bool = true) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_SOLID_COLOR if solid else PANEL_COLOR
    if border:
        style.border_color = BORDER_COLOR
        style.set_border_width_all(BORDER_WIDTH)
    style.set_corner_radius_all(radius)
    style.anti_aliasing = true
    return style


# 共通のフォント・大きさ・色を付けた Label
static func make_label(text: String, size: int, color: Color = TEXT_COLOR) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_override("font", FONT)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label


# ボタンの見た目を、メニューの「選んでいる行」（赤い面）に寄せる
static func make_accent_button_styles(button: Button) -> void:
    var normal := _make_accent_box(ACCENT_COLOR)
    var hover := _make_accent_box(ACCENT_COLOR.lightened(0.12))
    var pressed := _make_accent_box(ACCENT_COLOR.darkened(0.2))
    var focus := _make_accent_box(ACCENT_COLOR)
    focus.border_color = Color.WHITE
    focus.set_border_width_all(2)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", focus)
    button.add_theme_stylebox_override("disabled", _make_accent_box(ACCENT_COLOR))
    for name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(name, TEXT_COLOR)


static func _make_accent_box(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(8)
    style.content_margin_left = 24
    style.content_margin_right = 24
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    style.anti_aliasing = true
    return style

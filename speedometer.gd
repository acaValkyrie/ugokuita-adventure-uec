extends CanvasLayer
# 機体の今の速さを時速（km/h）で画面右上に表示する。

const MARGIN := 16  # 画面端からの余白（px）
const FONT_SIZE := 28
const OUTLINE_SIZE := 8
# touch_controls.gd のリセットボタンの幅（タッチ端末では右上に表示される）
const RESET_BUTTON_WIDTH := 72
const GAP := 12

var _label: Label


func _ready() -> void:
    layer = 10
    _label = Label.new()
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _label.add_theme_font_size_override("font_size", FONT_SIZE)
    _label.add_theme_color_override("font_color", Color.WHITE)
    _label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
    _label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
    _label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _label.offset_top = MARGIN
    _label.offset_right = -MARGIN
    var has_touch := OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    if has_touch:
        # リセットボタンと重ならないように左へずらす
        _label.offset_right = -(MARGIN + RESET_BUTTON_WIDTH + GAP)
    add_child(_label)


func _process(_delta: float) -> void:
    var car := get_tree().get_first_node_in_group("player") as RigidBody3D
    _label.visible = car != null
    if car:
        _label.text = "%d km/h" % roundi(car.linear_velocity.length() * 3.6)

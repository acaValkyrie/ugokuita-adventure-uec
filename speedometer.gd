extends CanvasLayer
# 機体の今の速さを時速（km/h）で画面右上に表示する。

const MARGIN := 16  # 画面端からの余白（px）
const NUMBER_SIZE := 26
const UNIT_SIZE := 15
const NUMBER_MIN_WIDTH := 48
# touch_controls.gd のリセットボタンの幅（タッチ端末では右上に表示される）
const RESET_BUTTON_WIDTH := 72
const GAP := 12

var _panel: PanelContainer
var _number: Label


func _ready() -> void:
    layer = 10
    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := UiStyle.make_panel_style(false, 10)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    _panel.add_theme_stylebox_override("panel", style)
    _panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _panel.offset_top = MARGIN
    _panel.offset_right = -MARGIN
    var has_touch := OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    if has_touch:
        # リセットボタンと重ならないように左へずらす
        _panel.offset_right = -(MARGIN + RESET_BUTTON_WIDTH + GAP)
    add_child(_panel)

    var hbox := HBoxContainer.new()
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.alignment = BoxContainer.ALIGNMENT_END
    hbox.add_theme_constant_override("separation", 6)
    _panel.add_child(hbox)

    _number = UiStyle.make_label("0", NUMBER_SIZE)
    _number.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _number.custom_minimum_size.x = NUMBER_MIN_WIDTH
    # 単位と下端をそろえる
    _number.size_flags_vertical = Control.SIZE_SHRINK_END
    hbox.add_child(_number)

    var unit := UiStyle.make_label("km/h", UNIT_SIZE, UiStyle.TEXT_DIM_COLOR)
    unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
    unit.size_flags_vertical = Control.SIZE_SHRINK_END
    hbox.add_child(unit)


func _process(_delta: float) -> void:
    var car := get_tree().get_first_node_in_group("player") as RigidBody3D
    _panel.visible = car != null
    if car:
        _number.text = "%d" % roundi(car.linear_velocity.length() * 3.6)
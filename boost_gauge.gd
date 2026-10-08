extends CanvasLayer
# ブーストのゲージを画面右下に丸く表示する。満タンになるとオレンジ色で点滅する。
# タッチ端末ではゲージがそのままブーストボタンになる（アクション boost）。

# リングの中心線の半径（px）
const RADIUS := 40.0
const RING_WIDTH := 8.0
# 画面端からの余白（px）
const MARGIN := 16.0
const FONT_SIZE := 14
# 文字の縁取りの太さ（px）
const OUTLINE_SIZE := 6
const COLOR_BACK := Color(0, 0, 0, 0.35)
const COLOR_CHARGING := Color(1, 1, 1, 0.85)
const COLOR_FULL := Color(1.0, 0.6, 0.1)

var _view: Control
var _gauge := 0.0
var _touch_enabled := false


func _ready() -> void:
    layer = 10
    _view = Control.new()
    _view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _view.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    var diameter := 2.0 * (RADIUS + RING_WIDTH / 2.0)
    _view.offset_right = -MARGIN
    _view.offset_bottom = -MARGIN
    _view.offset_left = -(MARGIN + diameter)
    _view.offset_top = -(MARGIN + diameter)
    _view.draw.connect(_on_view_draw)
    add_child(_view)
    _touch_enabled = OS.has_feature("web_android") or OS.has_feature("web_ios") \
            or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _process(_delta: float) -> void:
    var car := get_tree().get_first_node_in_group("player")
    _view.visible = car != null
    if car:
        _gauge = car.boost_gauge
    _view.queue_redraw()


func _on_view_draw() -> void:
    var center := _view.size / 2.0
    _view.draw_arc(center, RADIUS, 0.0, TAU, 64, COLOR_BACK, RING_WIDTH, true)
    var full := _gauge >= 1.0
    if full:
        var color := COLOR_FULL
        color.a = 0.7 + 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0))
        _view.draw_arc(center, RADIUS, 0.0, TAU, 64, color, RING_WIDTH, true)
    elif _gauge > 0.0:
        _view.draw_arc(center, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * _gauge, 64, COLOR_CHARGING, RING_WIDTH, true)
    # 文字を中央に置く（横は文字幅、縦は ascent / descent から決める）
    var font := ThemeDB.fallback_font
    var text := "BOOST"
    var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
    var ascent := font.get_ascent(FONT_SIZE)
    var descent := font.get_descent(FONT_SIZE)
    var pos := Vector2(center.x - size.x / 2.0, center.y + (ascent - descent) / 2.0)
    _view.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, Color(0, 0, 0, 0.8))
    _view.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_FULL if full else Color.WHITE)


# タッチ操作で運転に使わない領域（touch_controls.gd から参照）
func get_button_rect() -> Rect2:
    if _touch_enabled and _view.visible:
        return _view.get_global_rect()
    return Rect2()


func _input(event: InputEvent) -> void:
    if not _touch_enabled:
        return
    if event is InputEventScreenTouch and event.pressed \
            and event.position.distance_to(_view.get_global_rect().get_center()) <= RADIUS + RING_WIDTH:
        _press_boost()
        get_viewport().set_input_as_handled()


func _press_boost() -> void:
    # 次のフレームで離して is_action_just_pressed を成立させる
    Input.action_press("boost")
    await get_tree().process_frame
    Input.action_release("boost")

extends CanvasLayer
# ブーストのゲージを画面右下に丸く表示する。満タンになると赤で点滅する。
# タッチ端末ではゲージがそのままブーストボタンになる（アクション boost）。

# リングの中心線の半径（px）
const RADIUS := 40.0
const RING_WIDTH := 8.0
# 画面端からの余白（px）
const MARGIN := 16.0
# ゲージの横に出すボタンのアイコンの高さ [px]
const HINT_HEIGHT := 44.0
# SHIFT キーの絵は上下の余白を切ってあるので、キーの高さを他のキーとそろえるための倍率
const SHIFT_HINT_SCALE := 0.716
const HINT_GAP := 8.0
const FONT_SIZE := 13
const COLOR_BACK := Color(1, 1, 1, 0.15)
const COLOR_CHARGING := UiStyle.TEXT_COLOR
const COLOR_FULL := UiStyle.ACCENT_COLOR

var _view: Control
var _hint: TextureRect
var _gauge := 0.0
var _touch_enabled := false
# 押すボタンの倍率をかけた、リングの半径・太さと文字の大きさ
var _radius := RADIUS
var _ring_width := RING_WIDTH
var _font_size := FONT_SIZE


func _ready() -> void:
    layer = 10
    var button_scale := UiStyle.button_scale()
    _radius = RADIUS * button_scale
    _ring_width = RING_WIDTH * button_scale
    _font_size = roundi(FONT_SIZE * button_scale)
    _view = Control.new()
    _view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _view.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    var diameter := 2.0 * get_outer_radius()
    _view.offset_right = -MARGIN
    _view.offset_bottom = -MARGIN
    _view.offset_left = -(MARGIN + diameter)
    _view.offset_top = -(MARGIN + diameter)
    _view.draw.connect(_on_view_draw)
    add_child(_view)
    # ブーストのボタンのアイコン（入力方式とコントローラの表記に合わせる）
    _hint = TextureRect.new()
    _hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    add_child(_hint)
    _touch_enabled = UiStyle.is_touch_device()


func _process(_delta: float) -> void:
    var car := get_tree().get_first_node_in_group("player")
    _view.visible = car != null
    if car:
        _gauge = car.boost_gauge
    var icon: Texture2D = ControlsHelp.get_boost_icon() if car != null else null
    _hint.visible = icon != null
    if icon:
        _hint.texture = icon
        var height := HINT_HEIGHT * (SHIFT_HINT_SCALE if icon == ControlsHelp.ICON_KEY_SHIFT else 1.0)
        # リングの左に、「BOOST」の文字（リングの中心）と縦の中心をそろえて置く
        var width := height * icon.get_width() / icon.get_height()
        var diameter := 2.0 * get_outer_radius()
        _hint.offset_right = -(MARGIN + diameter + HINT_GAP)
        _hint.offset_left = _hint.offset_right - width
        _hint.offset_bottom = -(MARGIN + (diameter - height) / 2.0)
        _hint.offset_top = _hint.offset_bottom - height
        # ゲージが満タンになるまでは薄くして、まだ使えないことを示す
        _hint.modulate.a = 1.0 if _gauge >= 1.0 else 0.4
    _view.queue_redraw()


func _on_view_draw() -> void:
    var center := _view.size / 2.0
    # リングの中を塗る
    _view.draw_circle(center, get_outer_radius(), UiStyle.PANEL_COLOR)
    _view.draw_arc(center, _radius, 0.0, TAU, 64, COLOR_BACK, _ring_width, true)
    var full := _gauge >= 1.0
    if full:
        var color := COLOR_FULL
        color.a = 0.7 + 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0))
        _view.draw_arc(center, _radius, 0.0, TAU, 64, color, _ring_width, true)
    elif _gauge > 0.0:
        _view.draw_arc(center, _radius, -PI / 2.0, -PI / 2.0 + TAU * _gauge, 64, COLOR_CHARGING, _ring_width, true)
    # 文字を中央に置く（横は文字幅、縦は ascent / descent から決める）
    var font := UiStyle.FONT
    var text := "BOOST"
    var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size)
    var ascent := font.get_ascent(_font_size)
    var descent := font.get_descent(_font_size)
    var pos := Vector2(center.x - size.x / 2.0, center.y + (ascent - descent) / 2.0)
    _view.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, UiStyle.ACCENT_COLOR.lightened(0.25) if full else UiStyle.TEXT_COLOR)


# リングの外側の半径（px。タッチ端末では倍率をかけた値）
func get_outer_radius() -> float:
    return _radius + _ring_width / 2.0


# タッチ操作で運転に使わない領域（touch_controls.gd から参照）
func get_button_rect() -> Rect2:
    if _touch_enabled and _view.visible:
        return _view.get_global_rect()
    return Rect2()


func _input(event: InputEvent) -> void:
    if not _touch_enabled:
        return
    if event is InputEventScreenTouch and event.pressed \
            and event.position.distance_to(_view.get_global_rect().get_center()) <= _radius + _ring_width:
        _press_boost()
        get_viewport().set_input_as_handled()


func _press_boost() -> void:
    # 次のフレームで離して is_action_just_pressed を成立させる
    Input.action_press("boost")
    await get_tree().process_frame
    Input.action_release("boost")

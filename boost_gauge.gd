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
const HINT_GAP := 8.0
const FONT_SIZE := 13
const COLOR_BACK := Color(1, 1, 1, 0.15)
const COLOR_CHARGING := UiStyle.TEXT_COLOR
const COLOR_FULL := UiStyle.ACCENT_COLOR

var _view: Control
# ブーストのボタンの絵を入れる枠（絵は ControlsHelp が作る Control で、入力方式やキーの割り当てが変わったときだけ入れ替える）
var _hint: Control
# 枠に入れている絵の印（ControlsHelp.get_icon_token）。まだ入れていなければ null
var _hint_token: Variant = null
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
    _hint = Control.new()
    _hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    add_child(_hint)
    _touch_enabled = UiStyle.is_touch_device()


func _process(_delta: float) -> void:
    var car := get_tree().get_first_node_in_group("player")
    _view.visible = car != null
    if car:
        _gauge = car.boost_gauge
    # 絵は印が変わったときだけ作り直す（タッチは絵が無いので空の印）
    var token := ControlsHelp.get_icon_token("boost") if car != null else ""
    if token != _hint_token:
        _hint_token = token
        ControlsHelp.set_icon_slot(_hint, ControlsHelp.make_boost_icon(HINT_HEIGHT) if token != "" else null)
    _hint.visible = token != ""
    if token != "":
        # 横長のキーはキーの高さをそろえるため、絵は低くなる。枠は絵の大きさに合わせる
        var height := _hint.custom_minimum_size.y
        var width := _hint.custom_minimum_size.x
        # リングの左に、「BOOST」の文字（リングの中心）と縦の中心をそろえて置く
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
        var r := _hit_radius()
        var center := _view.get_global_rect().get_center()
        return Rect2(center - Vector2(r, r), Vector2(2.0 * r, 2.0 * r))
    return Rect2()


# タッチの当たり判定の半径（px）
# 元の作りで、押しやすいよう見た目（get_outer_radius）より少し大きくしている
func _hit_radius() -> float:
    return _radius + _ring_width


func _input(event: InputEvent) -> void:
    if not _touch_enabled:
        return
    if event is InputEventScreenTouch and event.pressed \
            and event.position.distance_to(_view.get_global_rect().get_center()) <= _hit_radius():
        _press_boost()
        get_viewport().set_input_as_handled()


func _press_boost() -> void:
    # 次のフレームで離して is_action_just_pressed を成立させる
    Input.action_press("boost")
    await get_tree().process_frame
    Input.action_release("boost")

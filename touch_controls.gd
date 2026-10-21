extends CanvasLayer
# スマホ用タッチ操作。
# 一本指スワイプで運転（既存アクション up/down/left/right）、
# 二本指スワイプで視点移動（既存アクション view_*）、
# 右下の JUMP / DRIFT ボタンを押している間、ジャンプ / ドリフト（アクション jump / drift）を押し続ける。

# この距離（px）ドラッグしたときの強さが1.0
@export var STICK_RADIUS: float = 80.0
# 各軸のデッドゾーン（以下は0、超えた分を0〜1に再スケール）
@export var DEADZONE: float = 0.15
# 表示用のノブの半径（px）
@export var KNOB_RADIUS: float = 30.0

const RESET_ICON := preload("res://assets/ui/controls/reset.png")

# JUMP / DRIFT ボタンの半径と、ブーストのゲージとの隙間（px）
const BUTTON_RADIUS := 34.0
const BUTTON_GAP := 12.0
const BUTTON_FONT_SIZE := 13
const BUTTON_COLOR_BACK := Color(1, 1, 1, 0.15)
# JUMP / DRIFT ボタンのリングの太さと、ボタンの縁から内側へのずらし（px）
const BUTTON_RING_WIDTH := 6.0
const BUTTON_RING_INSET := 4.0
# 右上のリセットボタンの一辺（px）
const RESET_BUTTON_SIZE := 72.0

enum Mode { NONE, DRIVE, VIEW, LOCKED }

const DRIVE_ACTIONS := ["up", "down", "left", "right"]
const VIEW_ACTIONS := ["view_up", "view_down", "view_left", "view_right"]

# 押下中の指: index -> 現在位置
var _touches: Dictionary = {}
var _mode: Mode = Mode.NONE
var _origin: Vector2 = Vector2.ZERO
# VIEW の中点計算に使っている2本の指のindex
var _pair: Array = []
var _overlay: Control
var _reset_button: TextureButton
# ボタンの上で始まった指のindex（運転に使わない）
var _button_touches: Dictionary = {}
# JUMP / DRIFT ボタンを押している指: index -> アクション名
var _held_buttons: Dictionary = {}
# タッチのスティックで押しているアクション（自分で押したものだけ離し、コントローラーやキーボードの入力を消さないため）
var _pressed_actions: Dictionary = {}
# タッチ端末か（JUMP / DRIFT とリセットのボタンを出す）
var _touch_enabled := false


func _ready() -> void:
    _overlay = Control.new()
    _overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.draw.connect(_on_overlay_draw)
    add_child(_overlay)
    _setup_reset_button()
    set_touch_enabled(UiStyle.is_touch_device())


func _process(_delta: float) -> void:
    # 車の有無でボタンの表示が変わるので、毎フレーム描き直す
    _overlay.queue_redraw()
    # メニューとエンディングの間はリセットを使わないので隠す（パネルを上から始められるように）
    _update_reset_visible()


# リセットボタンの見え方を決める（一時停止中は _process が動かないので、通知からも呼ぶ）
func _update_reset_visible() -> void:
    if not _reset_button:
        return
    var paused := is_inside_tree() and get_tree().paused
    _reset_button.visible = _touch_enabled and not paused \
            and not GameMenu.is_open and not Ending.is_shown()


# タッチ端末向けの表示を切り替える（テスト用にも使う）
func set_touch_enabled(on: bool) -> void:
    _touch_enabled = on
    if not on:
        _release_held_buttons()
    _update_reset_visible()


# JUMP / DRIFT ボタンを出すか（タッチ端末で、操作する車がいるとき）
func _buttons_visible() -> bool:
    return _touch_enabled and get_tree().get_first_node_in_group("player") != null


# JUMP / DRIFT ボタンの中心（アクション名 -> 位置）。画面右下のブーストのゲージを基準に並べる
func _button_centers() -> Dictionary:
    var view_size := get_viewport().get_visible_rect().size
    var boost_radius := BoostGauge.get_outer_radius()
    var button_radius := _button_radius()
    var boost_center := view_size - Vector2.ONE * (BoostGauge.MARGIN + boost_radius)
    return {
        # ブーストの左（下端はブーストと同じ）
        "jump": boost_center - Vector2(boost_radius + BUTTON_GAP + button_radius, 0.0),
        # ブーストの真上
        "drift": boost_center - Vector2(0.0, boost_radius + BUTTON_GAP + button_radius),
    }


# JUMP / DRIFT ボタンの半径（タッチ端末では倍率をかけた値）
func _button_radius() -> float:
    return BUTTON_RADIUS * UiStyle.button_scale()


# JUMP / DRIFT ボタンの一番上の端の y。ボタンが出ていないときは画面の高さ（ミニマップの大きさを決めるのに使う）
func get_buttons_top() -> float:
    if not _buttons_visible():
        return get_viewport().get_visible_rect().size.y
    var top := INF
    var centers := _button_centers()
    for action in centers:
        top = minf(top, centers[action].y - _button_radius())
    return top


# リセットボタンの一辺（タッチ端末では倍率をかけた値）
func get_reset_button_size() -> float:
    return RESET_BUTTON_SIZE * UiStyle.button_scale()


# 位置にあるボタンのアクション名（無ければ空文字）
func _button_action_at(pos: Vector2) -> String:
    if not _buttons_visible():
        return ""
    var centers := _button_centers()
    for action in centers:
        if pos.distance_to(centers[action]) <= _button_radius():
            return action
    return ""


# 右上のリセットボタン（タッチ端末のみ表示）
func _setup_reset_button() -> void:
    _reset_button = TextureButton.new()
    _reset_button.texture_normal = RESET_ICON
    _reset_button.ignore_texture_size = true
    _reset_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    _reset_button.mouse_filter = Control.MOUSE_FILTER_PASS
    # クリック後にフォーカスが残ると、Space などの決定でもう一度働いてしまうので受け取らない
    _reset_button.focus_mode = Control.FOCUS_NONE
    _reset_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    var reset_size := get_reset_button_size()
    _reset_button.offset_left = -16 - reset_size
    _reset_button.offset_right = -16
    _reset_button.offset_top = 16
    _reset_button.offset_bottom = 16 + reset_size
    _reset_button.visible = false
    _reset_button.pressed.connect(_on_reset_pressed)
    add_child(_reset_button)


func _on_reset_pressed() -> void:
    # 次のフレームで離して is_action_just_pressed を成立させる
    Input.action_press("respawn")
    await get_tree().process_frame
    Input.action_release("respawn")


# 押している JUMP / DRIFT ボタンをすべて離す
func _release_held_buttons() -> void:
    for action in _held_buttons.values():
        Input.action_release(action)
    _held_buttons.clear()


func _notification(what: int) -> void:
    # フォーカス喪失や一時停止のときは全部離す
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
            or what == NOTIFICATION_PAUSED:
        _reset()
    # 一時停止中は _process が動かないので、ここでリセットボタンの見え方を決める
    if what == NOTIFICATION_PAUSED and _reset_button:
        _reset_button.visible = false
    elif what == NOTIFICATION_UNPAUSED:
        _update_reset_visible()


# 指がボタンの上にあるか（リセット／JUMP・DRIFT／メニュー／ブースト／看板のヒント／エンディング）
func _is_on_button(pos: Vector2) -> bool:
    if _reset_button.visible and _reset_button.get_global_rect().has_point(pos):
        return true
    if _button_action_at(pos) != "":
        return true
    if BoostGauge.get_button_rect().has_point(pos):
        return true
    if LinkBoard.get_prompt_rect().has_point(pos):
        return true
    if GameMenu.get_button_rect().has_point(pos):
        return true
    if Map.get_button_rect().has_point(pos):
        return true
    if MiniMap.get_rect().has_point(pos):
        return true
    return Ending.get_button_rect().has_point(pos)


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            var action := _button_action_at(event.position)
            if action != "":
                # 指を離すまでジャンプ / ドリフトを押したままにする
                _held_buttons[event.index] = action
                Input.action_press(action)
                _button_touches[event.index] = true
                return
            if _is_on_button(event.position):
                _button_touches[event.index] = true
                return
            _touches[event.index] = event.position
        else:
            if _held_buttons.has(event.index):
                var released_action: String = _held_buttons[event.index]
                _held_buttons.erase(event.index)
                # 同じボタンを別の指がまだ押していれば、押したままにする
                if not _held_buttons.values().has(released_action):
                    Input.action_release(released_action)
            if _button_touches.erase(event.index):
                return
            _touches.erase(event.index)
    elif event is InputEventScreenDrag:
        if _button_touches.has(event.index) or not _touches.has(event.index):
            return
        _touches[event.index] = event.position
    else:
        return
    _update_mode()
    _update_actions()
    _overlay.queue_redraw()


# 指の本数に応じてモードを遷移させる
func _update_mode() -> void:
    var count := _touches.size()
    if count == 0:
        _release_all()
        _mode = Mode.NONE
        _pair = []
        return
    match _mode:
        Mode.NONE:
            if count >= 2:
                _enter_view()
            else:
                _mode = Mode.DRIVE
                _origin = _touches.values()[0]
        Mode.DRIVE:
            if count >= 2:
                _release_actions(DRIVE_ACTIONS)
                _enter_view()
        Mode.VIEW:
            if count < 2:
                _release_actions(VIEW_ACTIONS)
                _mode = Mode.LOCKED
                _pair = []
            else:
                var keys := _touches.keys()
                var new_pair := [keys[0], keys[1]]
                if new_pair != _pair:
                    # 中点に使う指が変わったら基準点をリセット（ジャンプ防止）
                    _pair = new_pair
                    _origin = _pair_center()


func _enter_view() -> void:
    var keys := _touches.keys()
    _pair = [keys[0], keys[1]]
    _origin = _pair_center()
    _mode = Mode.VIEW


func _pair_center() -> Vector2:
    return (_touches[_pair[0]] + _touches[_pair[1]]) * 0.5


# 現在のスティック位置（モードごと）
func _stick_position() -> Vector2:
    if _mode == Mode.DRIVE:
        return _touches.values()[0]
    return _pair_center()


# 長さ1にクランプしたスティックベクトル
func _clamped_vector() -> Vector2:
    return ((_stick_position() - _origin) / STICK_RADIUS).limit_length(1.0)


# デッドゾーンを超えた分を0〜1に再スケール
func _apply_deadzone(value: float) -> float:
    var a := absf(value)
    if a <= DEADZONE:
        return 0.0
    return signf(value) * (a - DEADZONE) / (1.0 - DEADZONE)


func _update_actions() -> void:
    if _mode != Mode.DRIVE and _mode != Mode.VIEW:
        return
    var v := _clamped_vector()
    var x := _apply_deadzone(v.x)
    var y := _apply_deadzone(v.y)
    var names: Array = DRIVE_ACTIONS if _mode == Mode.DRIVE else VIEW_ACTIONS
    # names の順: up, down, left, right（view_* も同じ並び）
    _set_action(names[0], maxf(-y, 0.0))
    _set_action(names[1], maxf(y, 0.0))
    _set_action(names[2], maxf(-x, 0.0))
    _set_action(names[3], maxf(x, 0.0))


func _set_action(action: String, strength: float) -> void:
    if strength <= 0.0:
        _release_action(action)
    else:
        Input.action_press(action, strength)
        _pressed_actions[action] = true


func _release_actions(actions: Array) -> void:
    for a in actions:
        _release_action(a)


# 自分で押していたときだけ離す
func _release_action(action: String) -> void:
    if _pressed_actions.erase(action):
        Input.action_release(action)


func _release_all() -> void:
    _release_actions(DRIVE_ACTIONS)
    _release_actions(VIEW_ACTIONS)


# フォーカス喪失時など：全指と全アクションをリセット
func _reset() -> void:
    _touches.clear()
    _button_touches.clear()
    _release_held_buttons()
    _pair = []
    _mode = Mode.NONE
    _release_all()
    if _overlay:
        _overlay.queue_redraw()


func _on_overlay_draw() -> void:
    _draw_buttons()
    if _mode != Mode.DRIVE and _mode != Mode.VIEW:
        return
    _overlay.draw_circle(_origin, STICK_RADIUS, Color(1, 1, 1, 0.25))
    _overlay.draw_circle(_origin + _clamped_vector() * STICK_RADIUS, KNOB_RADIUS, Color(1, 1, 1, 0.5))


# JUMP / DRIFT ボタンを、ブーストのゲージと同じ見た目で描く（押している間はリングを赤にする）
func _draw_buttons() -> void:
    if not _buttons_visible():
        return
    var centers := _button_centers()
    var button_scale := UiStyle.button_scale()
    var button_radius := _button_radius()
    var font_size := roundi(BUTTON_FONT_SIZE * button_scale)
    var font := UiStyle.FONT
    var ascent := font.get_ascent(font_size)
    var descent := font.get_descent(font_size)
    for action in centers:
        var center: Vector2 = centers[action]
        var held := _held_buttons.values().has(action)
        _overlay.draw_circle(center, button_radius, UiStyle.PANEL_COLOR)
        _overlay.draw_arc(center, button_radius - BUTTON_RING_INSET * button_scale, 0.0, TAU, 64,
            UiStyle.ACCENT_COLOR if held else BUTTON_COLOR_BACK, BUTTON_RING_WIDTH * button_scale, true)
        # 文字を中央に置く（横は文字幅、縦は ascent / descent から決める）
        var text: String = action.to_upper()
        var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
        var pos := Vector2(center.x - size.x / 2.0, center.y + (ascent - descent) / 2.0)
        _overlay.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.TEXT_COLOR)
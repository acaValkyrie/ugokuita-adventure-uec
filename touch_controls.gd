extends CanvasLayer
# スマホ用タッチ操作。
# 一本指スワイプで運転（既存アクション up/down/left/right）、
# 二本指スワイプで視点移動（既存アクション view_*）を行う。

# この距離（px）ドラッグしたときの強さが1.0
@export var STICK_RADIUS: float = 80.0
# 各軸のデッドゾーン（以下は0、超えた分を0〜1に再スケール）
@export var DEADZONE: float = 0.15
# 表示用のノブの半径（px）
@export var KNOB_RADIUS: float = 30.0

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


func _ready() -> void:
    _overlay = Control.new()
    _overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.draw.connect(_on_overlay_draw)
    add_child(_overlay)


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _reset()


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touches[event.index] = event.position
        else:
            _touches.erase(event.index)
    elif event is InputEventScreenDrag:
        if not _touches.has(event.index):
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
        Input.action_release(action)
    else:
        Input.action_press(action, strength)


func _release_actions(actions: Array) -> void:
    for a in actions:
        Input.action_release(a)


func _release_all() -> void:
    _release_actions(DRIVE_ACTIONS)
    _release_actions(VIEW_ACTIONS)


# フォーカス喪失時など：全指と全アクションをリセット
func _reset() -> void:
    _touches.clear()
    _pair = []
    _mode = Mode.NONE
    _release_all()
    if _overlay:
        _overlay.queue_redraw()


func _on_overlay_draw() -> void:
    if _mode != Mode.DRIVE and _mode != Mode.VIEW:
        return
    _overlay.draw_circle(_origin, STICK_RADIUS, Color(1, 1, 1, 0.25))
    _overlay.draw_circle(_origin + _clamped_vector() * STICK_RADIUS, KNOB_RADIUS, Color(1, 1, 1, 0.5))

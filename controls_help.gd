extends CanvasLayer
# 最後に使った入力方式に合わせた操作説明を画面左下に表示する。
# キーボード・コントローラ・タッチの3モードを入力イベントで自動切替する。

enum Mode { KEYBOARD, GAMEPAD, TOUCH }

const TEXTS := {
    Mode.KEYBOARD: "W / S : Accelerate / Reverse\nA / D : Steer\nArrow keys : Camera",
    Mode.GAMEPAD: "RT / LT : Accelerate / Reverse\nLeft stick : Drive & Steer\nRight stick : Camera",
    Mode.TOUCH: "Swipe with 1 finger : Drive\nSwipe with 2 fingers : Camera",
}

# 画面端からの余白（px）
const MARGIN := 16

var _mode: Mode = Mode.KEYBOARD
var _label: Label


func _ready() -> void:
    layer = 10
    if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
        _mode = Mode.TOUCH

    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # 左下に固定し、内容に合わせて上方向へ伸ばす
    panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
    panel.offset_left = MARGIN
    panel.offset_bottom = -MARGIN

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.5)
    style.set_corner_radius_all(6)
    style.set_content_margin_all(10)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    _label = Label.new()
    _label.add_theme_font_size_override("font_size", 16)
    _label.add_theme_color_override("font_color", Color.WHITE)
    _label.text = TEXTS[_mode]
    panel.add_child(_label)


func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        if event.pressed and not event.echo:
            _set_mode(Mode.KEYBOARD)
    elif event is InputEventJoypadButton:
        if event.pressed and _has_joypad():
            _set_mode(Mode.GAMEPAD)
    elif event is InputEventJoypadMotion:
        if absf(event.axis_value) > 0.5 and _has_joypad():
            _set_mode(Mode.GAMEPAD)
    elif event is InputEventScreenTouch:
        if event.pressed:
            _set_mode(Mode.TOUCH)
    # マウスイベントはタッチのエミュレーションで誤切替するため無視する


func _has_joypad() -> bool:
    return Input.get_connected_joypads().size() > 0


# モードが変わったときだけ表示を更新する
func _set_mode(mode: Mode) -> void:
    if mode == _mode:
        return
    _mode = mode
    _label.text = TEXTS[_mode]

extends CanvasLayer
# 最後に使った入力方式に合わせた操作説明を、アイコン付きで画面左下に表示する。
# キーボード・コントローラ・タッチの3モードを入力イベントで自動切替する。

enum Mode { KEYBOARD, GAMEPAD, TOUCH }

const ICON_KEYS_WASD := preload("res://assets/ui/controls/keys_wasd.png")
const ICON_KEYS_ARROWS := preload("res://assets/ui/controls/keys_arrows.png")
const ICON_STICK_LEFT := preload("res://assets/ui/controls/stick_left.png")
const ICON_STICK_RIGHT := preload("res://assets/ui/controls/stick_right.png")
const ICON_TRIGGER_LT := preload("res://assets/ui/controls/trigger_lt.png")
const ICON_TRIGGER_RT := preload("res://assets/ui/controls/trigger_rt.png")
const ICON_SWIPE_ONE := preload("res://assets/ui/controls/swipe_one_finger.png")
const ICON_SWIPE_TWO := preload("res://assets/ui/controls/swipe_two_fingers.png")
const ICON_KEY_R := preload("res://assets/ui/controls/key_r.png")
const ICON_BUTTON_BACK := preload("res://assets/ui/controls/button_back.png")
const ICON_KEY_SPACE := preload("res://assets/ui/controls/key_space.png")
const ICON_BUTTON_A := preload("res://assets/ui/controls/button_a.png")
const ICON_DOUBLE_TAP := preload("res://assets/ui/controls/double_tap.png")
const ICON_KEY_SHIFT := preload("res://assets/ui/controls/key_shift.png")
const ICON_BUTTON_X := preload("res://assets/ui/controls/button_x.png")

# モードごとの表示項目 [アイコン, ラベル, アイコンの拡大率（省略時1.0）]
const ITEMS := {
    Mode.KEYBOARD: [
        [ICON_KEYS_WASD, "Drive"],
        [ICON_KEYS_ARROWS, "Camera"],
        [ICON_KEY_SPACE, "Jump", 0.6],
        [ICON_KEY_SHIFT, "Boost", 0.6],
        [ICON_KEY_R, "Reset", 0.6],
    ],
    Mode.GAMEPAD: [
        [ICON_STICK_LEFT, "Steer"],
        [ICON_TRIGGER_RT, "Accelerate"],
        [ICON_TRIGGER_LT, "Reverse"],
        [ICON_STICK_RIGHT, "Camera"],
        [ICON_BUTTON_A, "Jump", 0.8],
        [ICON_BUTTON_X, "Boost", 0.8],
        [ICON_BUTTON_BACK, "Reset", 0.8],
    ],
    Mode.TOUCH: [
        [ICON_SWIPE_ONE, "Drive"],
        [ICON_SWIPE_TWO, "Camera"],
        [ICON_DOUBLE_TAP, "Jump"],
    ],
}

# 画面端からの余白（px）
const MARGIN := 16
# アイコンの表示高さ（px）。幅は元画像の縦横比から決める
const ICON_HEIGHT := 72
# ラベルの文字サイズ
const FONT_SIZE := 16
# ラベルの縁取りの太さ（px）
const OUTLINE_SIZE := 6

var _mode: Mode = Mode.KEYBOARD
var _hbox: HBoxContainer


func _ready() -> void:
    layer = 10
    if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
        _mode = Mode.TOUCH

    _hbox = HBoxContainer.new()
    _hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hbox.add_theme_constant_override("separation", 20)
    # 左下に固定し、内容に合わせて上・右方向へ伸ばす
    _hbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _hbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _hbox.offset_left = MARGIN
    _hbox.offset_bottom = -MARGIN
    add_child(_hbox)

    _rebuild()


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
    _rebuild()


# 現在のモードの項目で HBox の中身を作り直す
func _rebuild() -> void:
    for child in _hbox.get_children():
        _hbox.remove_child(child)
        child.queue_free()
    for item in ITEMS[_mode]:
        var icon_scale: float = item[2] if item.size() > 2 else 1.0
        _hbox.add_child(_make_item(item[0], item[1], icon_scale))


# アイコンとラベルを縦に並べた1項目を作る（下端を揃えてラベルを同じ高さにする）
func _make_item(icon: Texture2D, text: String, icon_scale: float) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.alignment = BoxContainer.ALIGNMENT_END
    box.add_theme_constant_override("separation", 2)

    var rect := TextureRect.new()
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.texture = icon
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var aspect := float(icon.get_width()) / float(icon.get_height())
    var height := roundf(ICON_HEIGHT * icon_scale)
    rect.custom_minimum_size = Vector2(roundf(height * aspect), height)
    box.add_child(rect)

    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", FONT_SIZE)
    label.add_theme_color_override("font_color", Color.WHITE)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
    box.add_child(label)
    return box

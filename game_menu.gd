extends CanvasLayer
# 左上のメニューボタンと、ESC/STARTで開く一時停止メニュー。
# メニュー内で全体音量と、操作説明に出すコントローラのボタン表記（Nintendo / PlayStation / Xbox）、操作する機体の見た目（Neo / Classic）を選べる。

signal pad_layout_changed(layout: String)
signal robot_model_changed(model: String)

# Master バスの既定音量（default_bus_layout.tres）
const BASE_DB := -6.0206
const SETTINGS_PATH := "user://settings.cfg"
const BUTTON_SIZE := 72
const MARGIN := 16
# ボタンの色（操作説明のアイコンに合わせる）
const RING_COLOR := Color(0.12, 0.12, 0.12)
const FACE_COLOR := Color(0.94, 0.94, 0.93)
const BUMP_SOUND := preload("res://assets/audio/bump/bump_a.ogg")
# 操作説明に出すコントローラのボタン表記（設定ファイルに保存する値）
const PAD_LAYOUTS := ["nintendo", "playstation", "xbox"]
const PAD_LAYOUT_NAMES := ["Nintendo", "PlayStation", "Xbox"]
# 操作する機体の見た目（設定ファイルに保存する値）
const ROBOT_MODELS := ["neo", "classic"]
const ROBOT_MODEL_NAMES := ["Ugokuita Neo", "Ugokuita Classic"]

var is_open: bool = false
var pad_layout: String = "nintendo"
var robot_model: String = "neo"
var _volume: int = 100
var _menu_button: Button
var _dimmer: ColorRect
var _slider: HSlider
var _volume_label: Label
var _pad_buttons: Array[Button] = []
var _robot_buttons: Array[Button] = []
var _player: AudioStreamPlayer
# メニューを閉じたときの物理フレーム番号
var _closed_physics_frame: int = -100


func _ready() -> void:
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_settings()
    _apply_pad_buttons()
    _apply_volume()
    _build_button()
    _build_menu()
    # 起動時の初期表示では保存を走らせない
    _slider.set_value_no_signal(_volume)
    _volume_label.text = "%d%%" % _volume
    _pad_buttons[PAD_LAYOUTS.find(pad_layout)].set_pressed_no_signal(true)
    _robot_buttons[ROBOT_MODELS.find(robot_model)].set_pressed_no_signal(true)


func get_button_rect() -> Rect2:
    return _menu_button.get_global_rect()


func open() -> void:
    if is_open:
        return
    is_open = true
    _dimmer.visible = true
    get_tree().paused = true
    # ゲームパッドやキーボードの左右で音量を調整できるようにする
    _slider.grab_focus()


func close() -> void:
    if not is_open:
        return
    is_open = false
    _dimmer.visible = false
    get_tree().paused = false
    _closed_physics_frame = Engine.get_physics_frames()


func toggle() -> void:
    if is_open:
        close()
    else:
        open()


# 閉じた直後か。閉じるのに使ったボタンがジャンプ・ブーストと同じとき、再開した瞬間に発動させないために使う
func is_just_closed() -> bool:
    return Engine.get_physics_frames() - _closed_physics_frame <= 1


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("menu") and not event.is_echo():
        toggle()
        get_viewport().set_input_as_handled()
    # ESC は上の menu で処理済み。コントローラはキャンセルのボタン（表記ごとに違う）で閉じる
    elif is_open and event.is_action_pressed("ui_cancel"):
        close()
        get_viewport().set_input_as_handled()


# 左上のメニューボタン（三本線アイコン）
func _build_button() -> void:
    _menu_button = Button.new()
    _menu_button.focus_mode = Control.FOCUS_NONE
    _menu_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _menu_button.offset_left = MARGIN
    _menu_button.offset_right = MARGIN + BUTTON_SIZE
    _menu_button.offset_top = MARGIN
    _menu_button.offset_bottom = MARGIN + BUTTON_SIZE
    # 見た目はアイコン側で描くので、ボタン自体の枠は空にする
    var empty := StyleBoxEmpty.new()
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        _menu_button.add_theme_stylebox_override(state, empty)
    _menu_button.pressed.connect(toggle)
    add_child(_menu_button)

    var icon := Control.new()
    icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.draw.connect(_on_icon_draw.bind(icon))
    _menu_button.add_child(icon)

    # 押している間は少し暗くする
    _menu_button.button_down.connect(func() -> void: icon.modulate = Color(0.8, 0.8, 0.8))
    _menu_button.button_up.connect(func() -> void: icon.modulate = Color.WHITE)


func _on_icon_draw(icon: Control) -> void:
    var center := icon.size * 0.5
    # 角を丸めた四角（操作説明のキーアイコンに合わせる）
    var face := StyleBoxFlat.new()
    face.bg_color = FACE_COLOR
    face.border_color = RING_COLOR
    face.set_border_width_all(6)
    face.set_corner_radius_all(14)
    face.anti_aliasing = true
    icon.draw_style_box(face, Rect2(Vector2(2.0, 2.0), icon.size - Vector2(4.0, 4.0)))
    # 三本線（両端は丸める）
    for i in range(-1, 2):
        var y := center.y + i * 10.0
        var from := Vector2(center.x - 14.0, y)
        var to := Vector2(center.x + 14.0, y)
        icon.draw_line(from, to, RING_COLOR, 6.0, true)
        icon.draw_circle(from, 3.0, RING_COLOR, true, -1.0, true)
        icon.draw_circle(to, 3.0, RING_COLOR, true, -1.0, true)


func _make_style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    return style


# 一時停止メニュー本体
func _build_menu() -> void:
    _dimmer = ColorRect.new()
    _dimmer.color = Color(0, 0, 0, 0.5)
    _dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
    _dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    _dimmer.visible = false
    add_child(_dimmer)

    var panel := PanelContainer.new()
    var style := _make_style(Color(0.12, 0.12, 0.14, 0.95), 16)
    style.set_content_margin_all(24)
    panel.add_theme_stylebox_override("panel", style)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    _dimmer.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 16)
    panel.add_child(vbox)

    var title := Label.new()
    title.text = "Menu"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    vbox.add_child(title)

    var volume_title := Label.new()
    volume_title.text = "Volume"
    volume_title.add_theme_font_size_override("font_size", 20)
    vbox.add_child(volume_title)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    vbox.add_child(row)

    _slider = HSlider.new()
    _slider.min_value = 0
    _slider.max_value = 100
    # キーボード・ゲームパッドで1回押すごとに5%ずつ動かす
    _slider.step = 5
    _slider.custom_minimum_size = Vector2(320, 0)
    _slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _slider.value_changed.connect(_on_volume_changed)
    row.add_child(_slider)

    _volume_label = Label.new()
    _volume_label.add_theme_font_size_override("font_size", 20)
    _volume_label.custom_minimum_size = Vector2(64, 0)
    _volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(_volume_label)

    var test_button := Button.new()
    test_button.text = "Test"
    test_button.add_theme_font_size_override("font_size", 20)
    test_button.pressed.connect(_on_test_pressed)
    row.add_child(test_button)

    var pad_title := Label.new()
    pad_title.text = "Controller"
    pad_title.add_theme_font_size_override("font_size", 20)
    vbox.add_child(pad_title)

    var pad_row := HBoxContainer.new()
    pad_row.add_theme_constant_override("separation", 12)
    vbox.add_child(pad_row)

    var pad_group := ButtonGroup.new()
    for i in PAD_LAYOUTS.size():
        var pad_button := Button.new()
        pad_button.text = PAD_LAYOUT_NAMES[i]
        pad_button.toggle_mode = true
        pad_button.button_group = pad_group
        pad_button.add_theme_font_size_override("font_size", 20)
        pad_button.pressed.connect(_on_pad_layout_pressed.bind(PAD_LAYOUTS[i]))
        pad_row.add_child(pad_button)
        _pad_buttons.append(pad_button)

    var robot_title := Label.new()
    robot_title.text = "Robot"
    robot_title.add_theme_font_size_override("font_size", 20)
    vbox.add_child(robot_title)

    var robot_row := HBoxContainer.new()
    robot_row.add_theme_constant_override("separation", 12)
    vbox.add_child(robot_row)

    var robot_group := ButtonGroup.new()
    for i in ROBOT_MODELS.size():
        var robot_button := Button.new()
        robot_button.text = ROBOT_MODEL_NAMES[i]
        robot_button.toggle_mode = true
        robot_button.button_group = robot_group
        robot_button.add_theme_font_size_override("font_size", 20)
        robot_button.pressed.connect(_on_robot_model_pressed.bind(ROBOT_MODELS[i]))
        robot_row.add_child(robot_button)
        _robot_buttons.append(robot_button)

    var close_button := Button.new()
    close_button.text = "Close"
    close_button.add_theme_font_size_override("font_size", 20)
    close_button.pressed.connect(close)
    vbox.add_child(close_button)

    # 一時停止中も鳴らすため、このノードの PROCESS_MODE_ALWAYS を継承させる
    _player = AudioStreamPlayer.new()
    _player.bus = "Master"
    _player.stream = BUMP_SOUND
    add_child(_player)


func _on_test_pressed() -> void:
    _player.stop()
    _player.play()


func _on_pad_layout_pressed(layout: String) -> void:
    if layout == pad_layout:
        return
    pad_layout = layout
    _apply_pad_buttons()
    _save_settings()
    pad_layout_changed.emit(pad_layout)


func _on_robot_model_pressed(model: String) -> void:
    if model == robot_model:
        return
    robot_model = model
    _save_settings()
    robot_model_changed.emit(robot_model)


# 決定・キャンセルのボタンを表記に合わせる（任天堂・PSは右が決定で下がキャンセル、Xboxは下が決定で右がキャンセル）
func _apply_pad_buttons() -> void:
    var confirm := JOY_BUTTON_A if pad_layout == "xbox" else JOY_BUTTON_B
    var cancel := JOY_BUTTON_B if pad_layout == "xbox" else JOY_BUTTON_A
    _set_joy_button("ui_accept", confirm)
    _set_joy_button("ui_cancel", cancel)


# アクションのゲームパッドのボタン割り当てを1つに置き換える（キーボードの割り当ては残す）
func _set_joy_button(action: StringName, button: JoyButton) -> void:
    for event in InputMap.action_get_events(action):
        if event is InputEventJoypadButton:
            InputMap.action_erase_event(action, event)
    var joy := InputEventJoypadButton.new()
    joy.device = -1
    joy.button_index = button
    InputMap.action_add_event(action, joy)


func _on_volume_changed(value: float) -> void:
    _volume = int(value)
    _apply_volume()
    _volume_label.text = "%d%%" % _volume
    _save_settings()


# 0% はミュート、それ以外は既定音量からの比率で下げる
func _apply_volume() -> void:
    var ratio := _volume / 100.0
    if ratio <= 0.0:
        AudioServer.set_bus_mute(0, true)
    else:
        AudioServer.set_bus_mute(0, false)
        AudioServer.set_bus_volume_db(0, BASE_DB + linear_to_db(ratio))


func _load_settings() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        return
    _volume = clampi(int(config.get_value("audio", "volume", 100)), 0, 100)
    var layout := str(config.get_value("controls", "pad_layout", "nintendo"))
    if layout in PAD_LAYOUTS:
        pad_layout = layout
    var model := str(config.get_value("robot", "model", "neo"))
    if model in ROBOT_MODELS:
        robot_model = model


func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "volume", _volume)
    config.set_value("controls", "pad_layout", pad_layout)
    config.set_value("robot", "model", robot_model)
    config.save(SETTINGS_PATH)

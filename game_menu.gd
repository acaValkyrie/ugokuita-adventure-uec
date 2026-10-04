extends CanvasLayer
# 右上のメニューボタンと、ESC/STARTで開く一時停止メニュー。
# メニュー内で全体音量を調整できる。

# Master バスの既定音量（default_bus_layout.tres）
const BASE_DB := -6.0206
const SETTINGS_PATH := "user://settings.cfg"
const BUTTON_SIZE := 72
const MARGIN := 16
const BUMP_SOUND := preload("res://assets/audio/bump/bump_a.ogg")

var is_open: bool = false
var _volume: int = 100
var _menu_button: Button
var _dimmer: ColorRect
var _slider: HSlider
var _volume_label: Label
var _player: AudioStreamPlayer


func _ready() -> void:
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_settings()
    _apply_volume()
    _build_button()
    _build_menu()
    # 起動時の初期表示では保存を走らせない
    _slider.set_value_no_signal(_volume)
    _volume_label.text = "%d%%" % _volume


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


func toggle() -> void:
    if is_open:
        close()
    else:
        open()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("menu") and not event.is_echo():
        toggle()
        get_viewport().set_input_as_handled()
    # ESC は上の menu で処理済み。コントローラは B ボタンでも閉じる
    elif is_open and (event.is_action_pressed("ui_cancel") \
            or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)):
        close()
        get_viewport().set_input_as_handled()


# 右上のメニューボタン（三本線アイコン）
func _build_button() -> void:
    _menu_button = Button.new()
    _menu_button.focus_mode = Control.FOCUS_NONE
    _menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _menu_button.offset_left = -MARGIN - BUTTON_SIZE
    _menu_button.offset_right = -MARGIN
    _menu_button.offset_top = MARGIN
    _menu_button.offset_bottom = MARGIN + BUTTON_SIZE
    _menu_button.add_theme_stylebox_override("normal", _make_style(Color(0, 0, 0, 0.45), 12))
    _menu_button.add_theme_stylebox_override("hover", _make_style(Color(0, 0, 0, 0.6), 12))
    _menu_button.add_theme_stylebox_override("pressed", _make_style(Color(0, 0, 0, 0.75), 12))
    _menu_button.pressed.connect(toggle)
    add_child(_menu_button)

    var icon := Control.new()
    icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.draw.connect(_on_icon_draw.bind(icon))
    _menu_button.add_child(icon)


func _on_icon_draw(icon: Control) -> void:
    var center := icon.size * 0.5
    for i in range(-1, 2):
        var y := center.y + i * 15.0
        icon.draw_line(Vector2(center.x - 18.0, y), Vector2(center.x + 18.0, y), Color.WHITE, 5.0)


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


func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "volume", _volume)
    config.save(SETTINGS_PATH)

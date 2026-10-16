extends CanvasLayer
# 左上のメニューボタンと、ESC/STARTで開く一時停止メニュー。
# メニュー内で全体音量と、操作説明に出すコントローラのボタン表記（Nintendo / PlayStation / Xbox）、操作する機体（Neo / Classic）を選べる。
# 画面は左に項目（音量・コントローラーの設定・ロボットタイプ・閉じる）、右に選んでいる項目の詳細を出す。

signal pad_layout_changed(layout: String)
signal robot_model_changed(model: String)

# Master バスの既定音量（default_bus_layout.tres）
const BASE_DB := -6.0206
const SETTINGS_PATH := "user://settings.cfg"
const BUTTON_SIZE := 72
const MARGIN := 16
# ボタンの色（操作説明のアイコンに合わせる）
const RING_COLOR := UiStyle.TEXT_COLOR
const FACE_COLOR := UiStyle.PANEL_COLOR
const BUMP_SOUND := preload("res://assets/audio/bump/bump_a.ogg")
# 操作説明に出すコントローラのボタン表記（設定ファイルに保存する値）
const PAD_LAYOUTS := ["nintendo", "playstation", "xbox"]
const PAD_LAYOUT_NAMES := ["Nintendo", "PlayStation", "Xbox"]
# 操作する機体（設定ファイルに保存する値）
const ROBOT_MODELS := ["neo", "classic"]
const ROBOT_MODEL_NAMES := ["Ugokuita Neo", "Ugokuita Classic"]
# デバッグ欄に出すパワーアップの名前
const DEBUG_POWER_UP_NAMES := {
    "boost_charge": "Boost Charge",
    "double_jump": "Double Jump",
    "torque": "Torque",
    "jump_up": "Jump Up",
    "jet": "Jet",
}
# デバッグ欄に出すヒントの名前
const DEBUG_HINT_NAMES := {
    "hint1": "Hint 1",
    "hint2": "Hint 2",
}
# デバッグ欄を出すか。false なら debug ビルドでも出さない
const SHOW_DEBUG_PANEL := false

# メニューの素材
const MENU_FONT := preload("res://assets/fonts/noto_sans_cjk_jp_bold_ui.otf")
const LOGO_ROBOT := preload("res://assets/ui/menu/logo_robot.png")
const LOGO_TEXT := preload("res://assets/ui/menu/logo_text.png")
# PAD_LAYOUTS の順
const PAD_TEXTURES := [
    preload("res://assets/ui/menu/controller_nintendo.png"),
    preload("res://assets/ui/menu/controller_playstation.png"),
    preload("res://assets/ui/menu/controller_xbox.png"),
]
const ITEM_ICONS := [
    preload("res://assets/ui/menu/icon_volume.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
    preload("res://assets/ui/menu/icon_robot.png"),
]
# ROBOT_MODELS の順
const ROBOT_SCENES := [
    preload("res://assets/ugokuita-neo.glb"),
    preload("res://assets/ugokuita-classic.fbx"),
]
# 左の項目（0: 音量、1: コントローラーの設定、2: ロボットタイプ）
const ITEM_NAMES := ["音量", "コントローラーの設定", "ロボットタイプ"]
const ITEM_DESCRIPTIONS := [
    "ゲーム全体の音量を調整します",
    "ボタンの表示形式を切り替えます",
    "操作する機体を切り替えます",
]
const ITEM_VOLUME := 0
const ITEM_PAD := 1
const ITEM_ROBOT := 2

# 色
const DIMMER_COLOR := Color(0, 0, 0, 0.55)
const PANEL_COLOR := Color(0.07, 0.07, 0.08, 1.0)
const LINE_COLOR := Color(1, 1, 1, 0.14)
const TEXT_BODY := Color(0.95, 0.95, 0.95)
const TEXT_DIM := Color(0.62, 0.62, 0.62)
const ACCENT_COLOR := Color("#e0182d")
const DOT_OFF_COLOR := Color(0.35, 0.35, 0.35)
# 寸法
const PANEL_MAX_WIDTH := 1000.0
const PANEL_TOP := 96.0
const PANEL_BOTTOM := 24.0
const LEFT_COLUMN_WIDTH := 430.0
const ROBOT_ROT_SPEED := 35.0
# 機体シーン（car.tscn・car_classic.tscn）と同じモデルの姿勢
const ROBOT_MODEL_TRANSFORM := "Transform3D(-4.37114e-08, 0, -1, 0, 1, 0, 1, 0, -4.37114e-08, 0, 0, 0)"

var is_open: bool = false
var pad_layout: String = "nintendo"
var robot_model: String = "neo"
var _volume: int = 100
var _menu_button: Button
var _dimmer: ColorRect
var _panel: PanelContainer
var _slider: HSlider
# 左の列の音量の行の「30%」
var _volume_label: Label
# 右の列（音量の中身）の「30%」
var _volume_big_label: Label
# 左の項目の行（Button）、背景、白い縦帯、「>」の山形
var _rows: Array[Button] = []
var _row_backgrounds: Array[Control] = []
var _row_stripes: Array[Control] = []
var _row_chevrons: Array[Control] = []
var _close_button: Button
var _close_label: Label
var _close_hint_box: HBoxContainer
var _close_hint_mark: Control
# 閉じるの印を作ったときの入力方式とボタン表記
var _close_hint_mode: int = -1
var _close_hint_layout: String = ""
var _current_item: int = ITEM_VOLUME
# 右の列
var _header_name: Label
var _header_line: ColorRect
var _header_desc: Label
var _contents: Array[Control] = []
var _pad_texture_rect: TextureRect
var _pad_name_label: Label
var _pad_dots: Array[ColorRect] = []
var _robot_name_label: Label
var _robot_dots: Array[ColorRect] = []
# 機体の3D表示
var _robot_pivot: Node3D
var _robot_camera: Camera3D
var _robot_model_node: Node3D
# いま3Dに出している機体（まだ出していなければ空）
var _robot_shown: String = ""
# デバッグ欄のトグル（パワーアップのキー → ボタン）
var _debug_buttons := {}
# デバッグ欄のヒントのトグル（ヒントのキー → ボタン）
var _debug_hint_buttons := {}
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
    # 起動時の初期表示では保存や音を走らせない
    _slider.set_value_no_signal(_volume)
    _refresh_volume_labels()
    _refresh_pad()
    _refresh_robot_names()
    _set_current_item(ITEM_VOLUME, true)


func _process(delta: float) -> void:
    if not is_open:
        return
    # 入力方式かボタン表記が変わったときだけ、閉じるの印を作り直す
    if ControlsHelp.get_mode() != _close_hint_mode or pad_layout != _close_hint_layout:
        _rebuild_close_hint()
    # ロボットタイプを見ているときだけ機体を回す（一時停止中も動く）
    if _current_item == ITEM_ROBOT and _robot_pivot != null:
        _robot_pivot.rotate_y(deg_to_rad(ROBOT_ROT_SPEED) * delta)


func get_button_rect() -> Rect2:
    return _menu_button.get_global_rect()


func open() -> void:
    if is_open:
        return
    is_open = true
    # デバッグ欄のトグルを、いま取っている状態に合わせる（シグナルは出さない）
    for key in _debug_buttons:
        _debug_buttons[key].set_pressed_no_signal(PowerUps.has(key))
    for id in _debug_hint_buttons:
        _debug_hint_buttons[id].set_pressed_no_signal(PowerUps.is_hint_used(id))
    _dimmer.visible = true
    get_tree().paused = true
    _layout_panel()
    _rebuild_close_hint()
    # 今の項目を音量に戻し、ゲームパッドやキーボードの左右で音量を調整できるようにする
    _set_current_item(ITEM_VOLUME, true)
    _rows[ITEM_VOLUME].grab_focus()


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
    face.border_color = UiStyle.BORDER_COLOR
    face.set_border_width_all(2)
    face.set_corner_radius_all(UiStyle.PANEL_RADIUS)
    face.anti_aliasing = true
    icon.draw_style_box(face, Rect2(Vector2.ZERO, icon.size))
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


# ---- 部品を作る小さな関数 ----

func _make_label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label


# 高さを決めて、縦横比を保つ絵
func _make_icon(texture: Texture2D, height: float) -> TextureRect:
    var rect := TextureRect.new()
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.texture = texture
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var aspect := float(texture.get_width()) / float(texture.get_height())
    rect.custom_minimum_size = Vector2(roundf(height * aspect), height)
    return rect


# 太さ 1px の区切り線（縦にしたいときは自分で最小サイズを変える）
func _make_line() -> ColorRect:
    var line := ColorRect.new()
    line.color = LINE_COLOR
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    line.custom_minimum_size = Vector2(0, 1)
    return line


func _make_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
    var margin := MarginContainer.new()
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", left)
    margin.add_theme_constant_override("margin_top", top)
    margin.add_theme_constant_override("margin_right", right)
    margin.add_theme_constant_override("margin_bottom", bottom)
    return margin


func _make_spacer(width: float, height: float) -> Control:
    var spacer := Control.new()
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    spacer.custom_minimum_size = Vector2(width, height)
    return spacer


# 見た目を持たない flat なボタン（フォーカス枠も出さない）
func _make_flat_button(height: float, focus: Control.FocusMode) -> Button:
    var button := Button.new()
    button.flat = true
    button.focus_mode = focus
    button.custom_minimum_size = Vector2(0, height)
    var empty := StyleBoxEmpty.new()
    for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
        button.add_theme_stylebox_override(state, empty)
    return button


# ---- 一時停止メニュー本体 ----

func _build_menu() -> void:
    _dimmer = ColorRect.new()
    _dimmer.color = DIMMER_COLOR
    _dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
    _dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    _dimmer.visible = false
    _dimmer.resized.connect(_layout_panel)
    add_child(_dimmer)

    _panel = PanelContainer.new()
    var style := _make_style(PANEL_COLOR, 14)
    style.set_content_margin_all(0)
    _panel.add_theme_stylebox_override("panel", style)
    # メニューの中の文字はすべてこのフォントにする
    var theme := Theme.new()
    theme.default_font = MENU_FONT
    _panel.theme = theme
    _dimmer.add_child(_panel)

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 0)
    _panel.add_child(columns)

    columns.add_child(_build_left_column())

    # 縦の区切り線（上下 28px あける）
    var divider_margin := _make_margin(0, 28, 0, 28)
    var divider := _make_line()
    divider.custom_minimum_size = Vector2(1, 0)
    divider_margin.add_child(divider)
    columns.add_child(divider_margin)

    columns.add_child(_build_right_column())

    # 行の上下の移動と、左右でフォーカスが動かないようにする設定（全部ツリーに入ってから）
    var order: Array[Button] = _rows.duplicate()
    order.append(_close_button)
    for i in order.size():
        var button := order[i]
        button.focus_neighbor_top = button.get_path_to(order[maxi(i - 1, 0)])
        button.focus_neighbor_bottom = button.get_path_to(order[mini(i + 1, order.size() - 1)])
        button.focus_neighbor_left = button.get_path_to(button)
        button.focus_neighbor_right = button.get_path_to(button)

    # 一時停止中も鳴らすため、このノードの PROCESS_MODE_ALWAYS を継承させる
    _player = AudioStreamPlayer.new()
    _player.bus = "Master"
    _player.stream = BUMP_SOUND
    add_child(_player)


# 画面の大きさに合わせてパネルの位置と大きさを決める
func _layout_panel() -> void:
    if _panel == null:
        return
    var screen := _dimmer.size
    var width := minf(PANEL_MAX_WIDTH, screen.x - 32.0)
    _panel.position = Vector2((screen.x - width) * 0.5, PANEL_TOP)
    _panel.size = Vector2(width, maxf(screen.y - PANEL_TOP - PANEL_BOTTOM, 0.0))


# ---- 左の列 ----

func _build_left_column() -> Control:
    var margin := _make_margin(28, 24, 20, 16)
    margin.custom_minimum_size = Vector2(LEFT_COLUMN_WIDTH, 0)
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 0)
    margin.add_child(vbox)

    # ロゴ
    var logo_row := HBoxContainer.new()
    logo_row.add_theme_constant_override("separation", 12)
    logo_row.add_child(_make_icon(LOGO_ROBOT, 52))
    logo_row.add_child(_make_icon(LOGO_TEXT, 52))
    vbox.add_child(logo_row)
    var logo_line_margin := _make_margin(0, 14, 0, 14)
    logo_line_margin.add_child(_make_line())
    vbox.add_child(logo_line_margin)

    # 項目の行
    var rows_box := VBoxContainer.new()
    rows_box.add_theme_constant_override("separation", 6)
    vbox.add_child(rows_box)
    for i in ITEM_NAMES.size():
        rows_box.add_child(_build_item_row(i))

    # デバッグ用: パワーアップを1つずつ ON/OFF（SHOW_DEBUG_PANEL が false のときと、release の書き出しでは作らない）
    if SHOW_DEBUG_PANEL and OS.is_debug_build():
        _build_debug_panel(vbox)

    # 余白（伸びる）
    var spacer := Control.new()
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(spacer)

    vbox.add_child(_make_line())
    vbox.add_child(_build_close_row())
    return margin


# 項目の行。文字は持たせず、中に背景・縦帯・アイコン・項目名・右側の部品を置く
func _build_item_row(index: int) -> Button:
    var row := _make_flat_button(58, Control.FOCUS_ALL)
    _rows.append(row)

    # 選んでいる行の背景（左から右へ赤いグラデーション）
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([Color("#c8102e"), Color("#4a0b12")])
    gradient.offsets = PackedFloat32Array([0.0, 1.0])
    var gradient_texture := GradientTexture2D.new()
    gradient_texture.gradient = gradient
    gradient_texture.fill_from = Vector2(0, 0)
    gradient_texture.fill_to = Vector2(1, 0)
    gradient_texture.width = 256
    gradient_texture.height = 8
    var background := TextureRect.new()
    background.texture = gradient_texture
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_SCALE
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.add_child(background)
    _row_backgrounds.append(background)

    # 左端の白い縦帯
    var stripe := ColorRect.new()
    stripe.color = TEXT_BODY
    stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    stripe.offset_left = 0
    stripe.offset_right = 5
    row.add_child(stripe)
    _row_stripes.append(stripe)

    var margin := _make_margin(22, 0, 18, 0)
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.add_child(margin)
    var hbox := HBoxContainer.new()
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 22)
    margin.add_child(hbox)

    var icon := _make_icon(ITEM_ICONS[index], 30)
    icon.custom_minimum_size = Vector2(30, 30)
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hbox.add_child(icon)

    var name_label := _make_label(ITEM_NAMES[index], 21, TEXT_BODY)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(name_label)

    if index == ITEM_VOLUME:
        _slider = _make_volume_slider()
        hbox.add_child(_slider)
        _volume_label = _make_label("", 19, TEXT_DIM)
        _volume_label.custom_minimum_size = Vector2(52, 0)
        _volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        hbox.add_child(_volume_label)
    else:
        # 右端の「>」の山形
        var chevron := Control.new()
        chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
        chevron.custom_minimum_size = Vector2(9, 16)
        chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        chevron.draw.connect(_on_chevron_draw.bind(chevron, index))
        hbox.add_child(chevron)
        _row_chevrons.append(chevron)

    row.focus_entered.connect(_set_current_item.bind(index, false))
    row.mouse_entered.connect(_on_row_mouse_entered.bind(index))
    row.gui_input.connect(_on_row_gui_input.bind(index))
    return row


# 音量バー（マウス・タッチでドラッグできる。つまみは見せない）
func _make_volume_slider() -> HSlider:
    var slider := HSlider.new()
    slider.min_value = 0
    slider.max_value = 100
    # キーボード・ゲームパッドで1回押すごとに5%ずつ動かす
    slider.step = 5
    slider.focus_mode = Control.FOCUS_NONE
    slider.custom_minimum_size = Vector2(140, 20)
    slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    # 溝と埋まった部分（高さ 6px）
    var groove := _make_style(Color(1, 1, 1, 0.18), 3)
    groove.content_margin_top = 3
    groove.content_margin_bottom = 3
    var fill := _make_style(Color(0.88, 0.88, 0.88), 3)
    fill.content_margin_top = 3
    fill.content_margin_bottom = 3
    slider.add_theme_stylebox_override("slider", groove)
    slider.add_theme_stylebox_override("grabber_area", fill)
    slider.add_theme_stylebox_override("grabber_area_highlight", fill)
    # つまみの絵は透明な 1px にして見せない
    var blank := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
    slider.add_theme_icon_override("grabber", blank)
    slider.add_theme_icon_override("grabber_highlight", blank)
    slider.add_theme_icon_override("grabber_disabled", blank)
    slider.value_changed.connect(_on_volume_changed)
    return slider


func _on_chevron_draw(chevron: Control, index: int) -> void:
    var color := TEXT_BODY if index == _current_item else TEXT_DIM
    chevron.draw_polyline(PackedVector2Array([Vector2(1, 1), Vector2(8, 8), Vector2(1, 15)]), color, 2.5, true)


# 「閉じる」の行
func _build_close_row() -> Control:
    _close_button = _make_flat_button(44, Control.FOCUS_ALL)
    _close_button.pressed.connect(close)
    _close_button.focus_entered.connect(_update_close_color)
    _close_button.focus_exited.connect(_update_close_color)

    var margin := _make_margin(22, 0, 18, 0)
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    _close_button.add_child(margin)
    _close_hint_box = HBoxContainer.new()
    _close_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _close_hint_box.alignment = BoxContainer.ALIGNMENT_BEGIN
    _close_hint_box.add_theme_constant_override("separation", 12)
    margin.add_child(_close_hint_box)

    _close_label = _make_label("閉じる", 17, TEXT_DIM)
    _close_hint_box.add_child(_close_label)
    _rebuild_close_hint()
    return _close_button


func _update_close_color() -> void:
    _close_label.add_theme_color_override("font_color", TEXT_BODY if _close_button.has_focus() else TEXT_DIM)


# 入力方式の印（キーボードは Esc の箱、コントローラはキャンセルのボタン、タッチは無し）を作り直す
func _rebuild_close_hint() -> void:
    if _close_hint_mark != null:
        _close_hint_box.remove_child(_close_hint_mark)
        _close_hint_mark.queue_free()
        _close_hint_mark = null
    _close_hint_mode = ControlsHelp.get_mode()
    _close_hint_layout = pad_layout
    match _close_hint_mode:
        ControlsHelp.Mode.KEYBOARD:
            var box := PanelContainer.new()
            box.mouse_filter = Control.MOUSE_FILTER_IGNORE
            box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            var frame := StyleBoxFlat.new()
            frame.draw_center = false
            frame.border_color = Color(0.85, 0.85, 0.85)
            frame.set_border_width_all(2)
            frame.set_corner_radius_all(4)
            frame.content_margin_left = 6
            frame.content_margin_right = 6
            frame.content_margin_top = 1
            frame.content_margin_bottom = 1
            box.add_theme_stylebox_override("panel", frame)
            box.add_child(_make_label("Esc", 15, TEXT_BODY))
            _close_hint_mark = box
        ControlsHelp.Mode.GAMEPAD:
            var icon := ControlsHelp.get_cancel_icon()
            if icon != null:
                var rect := _make_icon(icon, 40)
                rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                _close_hint_mark = rect
    if _close_hint_mark != null:
        _close_hint_box.add_child(_close_hint_mark)
        _close_hint_box.move_child(_close_hint_mark, 0)


# デバッグ用の欄（左の列の項目の下）
func _build_debug_panel(vbox: VBoxContainer) -> void:
    var debug_title := _make_label("Power-ups (debug)", 20, TEXT_BODY)
    vbox.add_child(debug_title)

    var debug_grid := GridContainer.new()
    # 7個を2行に収めて、800x450 の画面に入るようにする
    debug_grid.columns = 4
    debug_grid.add_theme_constant_override("h_separation", 12)
    debug_grid.add_theme_constant_override("v_separation", 12)
    vbox.add_child(debug_grid)

    for key in PowerUps.ITEMS:
        var debug_button := Button.new()
        debug_button.text = DEBUG_POWER_UP_NAMES[key]
        debug_button.toggle_mode = true
        debug_button.add_theme_font_size_override("font_size", 20)
        debug_button.toggled.connect(_on_debug_power_up_toggled.bind(key))
        debug_grid.add_child(debug_button)
        _debug_buttons[key] = debug_button
    # ヒントも同じ並びに（使ったヒントのキー → ボタン）
    for hint_id in DEBUG_HINT_NAMES:
        var hint_button := Button.new()
        hint_button.text = DEBUG_HINT_NAMES[hint_id]
        hint_button.toggle_mode = true
        hint_button.add_theme_font_size_override("font_size", 20)
        hint_button.toggled.connect(_on_debug_hint_toggled.bind(hint_id))
        debug_grid.add_child(hint_button)
        _debug_hint_buttons[hint_id] = hint_button


# ---- 右の列 ----

func _build_right_column() -> Control:
    var margin := _make_margin(36, 30, 36, 24)
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 0)
    margin.add_child(vbox)

    # 見出し（赤い縦帯と項目名、その下の線）
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 16)
    vbox.add_child(header)
    var bar := ColorRect.new()
    bar.color = ACCENT_COLOR
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.custom_minimum_size = Vector2(6, 40)
    bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    header.add_child(bar)
    var header_text := VBoxContainer.new()
    header_text.add_theme_constant_override("separation", 0)
    header.add_child(header_text)
    _header_name = _make_label("", 26, TEXT_BODY)
    header_text.add_child(_header_name)
    var line_margin := _make_margin(0, 8, 0, 0)
    _header_line = _make_line()
    line_margin.add_child(_header_line)
    header_text.add_child(line_margin)

    var desc_margin := _make_margin(0, 10, 0, 0)
    _header_desc = _make_label("", 15, TEXT_DIM)
    desc_margin.add_child(_header_desc)
    vbox.add_child(desc_margin)

    # 中身（項目ごとに作っておき、今の項目のものだけ出す）
    var holder := Control.new()
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(holder)
    var contents: Array[Control] = [_build_volume_content(), _build_pad_content(), _build_robot_content()]
    for content in contents:
        content.set_anchors_preset(Control.PRESET_FULL_RECT)
        content.visible = false
        holder.add_child(content)
        _contents.append(content)
    return margin


func _build_volume_content() -> Control:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var icon := _make_icon(ITEM_ICONS[ITEM_VOLUME], 96)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    icon.modulate = Color(1, 1, 1, 0.35)
    box.add_child(icon)
    _volume_big_label = _make_label("", 44, TEXT_BODY)
    _volume_big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_volume_big_label)
    return box


func _build_pad_content() -> Control:
    _pad_texture_rect = TextureRect.new()
    _pad_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _pad_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _pad_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _pad_texture_rect.custom_minimum_size = Vector2(0, 250)
    var parts := _build_selector(_pad_texture_rect, PAD_LAYOUTS.size(), _step_pad)
    _pad_name_label = parts.name_label
    _pad_dots = parts.dots
    return parts.box


func _build_robot_content() -> Control:
    var container := SubViewportContainer.new()
    container.stretch = true
    container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    container.custom_minimum_size = Vector2(0, 250)
    var viewport := SubViewport.new()
    viewport.own_world_3d = true
    viewport.transparent_bg = true
    viewport.msaa_3d = Viewport.MSAA_4X
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    container.add_child(viewport)

    _robot_camera = Camera3D.new()
    _robot_camera.fov = 30.0
    viewport.add_child(_robot_camera)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-50, -30, 0)
    light.light_energy = 1.2
    viewport.add_child(light)
    var environment := Environment.new()
    environment.background_mode = Environment.BG_CLEAR_COLOR
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.6, 0.6, 0.65)
    environment.ambient_light_energy = 0.6
    var world_environment := WorldEnvironment.new()
    world_environment.environment = environment
    viewport.add_child(world_environment)
    _robot_pivot = Node3D.new()
    viewport.add_child(_robot_pivot)

    var parts := _build_selector(container, ROBOT_MODELS.size(), _step_robot)
    _robot_name_label = parts.name_label
    _robot_dots = parts.dots
    return parts.box


# 「<」ボタン・中央の絵・「>」ボタン、その下の名前と点を並べた部品。{box, name_label, dots} を返す
func _build_selector(center: Control, count: int, step: Callable) -> Dictionary:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(row)
    row.add_child(_make_arrow_button(-1, step))
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(center)
    row.add_child(_make_arrow_button(1, step))

    var name_label := _make_label("", 22, TEXT_BODY)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(name_label)

    var dots_row := HBoxContainer.new()
    dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
    dots_row.add_theme_constant_override("separation", 10)
    dots_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(dots_row)
    var dots: Array[ColorRect] = []
    for i in count:
        var dot := ColorRect.new()
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        dot.custom_minimum_size = Vector2(26, 5)
        dots_row.add_child(dot)
        dots.append(dot)
    return {"box": box, "name_label": name_label, "dots": dots}


# 48×48 の flat なボタンに山形を描いた矢印（direction が -1 なら「<」、1 なら「>」）
func _make_arrow_button(direction: int, step: Callable) -> Button:
    var button := _make_flat_button(48, Control.FOCUS_NONE)
    button.custom_minimum_size = Vector2(48, 48)
    button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    button.pressed.connect(step.bind(direction))
    var mark := Control.new()
    mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mark.set_anchors_preset(Control.PRESET_FULL_RECT)
    mark.draw.connect(_on_arrow_draw.bind(mark, button, direction))
    button.add_child(mark)
    button.mouse_entered.connect(mark.queue_redraw)
    button.mouse_exited.connect(mark.queue_redraw)
    return button


func _on_arrow_draw(mark: Control, button: Button, direction: int) -> void:
    var color := TEXT_BODY if button.is_hovered() else TEXT_DIM
    var origin := (mark.size - Vector2(14, 28)) * 0.5
    var points: PackedVector2Array
    if direction > 0:
        points = PackedVector2Array([Vector2(0, 0), Vector2(14, 14), Vector2(0, 28)])
    else:
        points = PackedVector2Array([Vector2(14, 0), Vector2(0, 14), Vector2(14, 28)])
    for i in points.size():
        points[i] += origin
    mark.draw_polyline(points, color, 3.0, true)


# ---- 今の項目 ----

# 今の項目を切り替えて、行の見た目と右の列を合わせる（force なら同じ項目でも作り直す）
func _set_current_item(index: int, force: bool) -> void:
    if index == _current_item and not force:
        return
    _current_item = index
    for i in _rows.size():
        _row_backgrounds[i].visible = i == index
        _row_stripes[i].visible = i == index
    for chevron in _row_chevrons:
        chevron.queue_redraw()
    _header_name.text = ITEM_NAMES[index]
    _header_desc.text = ITEM_DESCRIPTIONS[index]
    # 見出しの線は、文字の幅 + 40px
    _header_line.custom_minimum_size = Vector2(_header_name.get_minimum_size().x + 40.0, 1)
    for i in _contents.size():
        _contents[i].visible = i == index
    if index == ITEM_ROBOT:
        _refresh_robot()


func _on_row_mouse_entered(index: int) -> void:
    _rows[index].grab_focus()
    _set_current_item(index, false)


# 行での左右・決定の操作
func _on_row_gui_input(event: InputEvent, index: int) -> void:
    if event.is_action_pressed("ui_left", true):
        _step_row(index, -1)
        _rows[index].accept_event()
    elif event.is_action_pressed("ui_right", true):
        _step_row(index, 1)
        _rows[index].accept_event()
    elif event.is_action_pressed("ui_accept") and index != ITEM_VOLUME:
        _step_row(index, 1)
        _rows[index].accept_event()


# 音量は 5 ずつ、それ以外は前・次に切り替える
func _step_row(index: int, direction: int) -> void:
    match index:
        ITEM_VOLUME:
            _slider.value += 5.0 * direction
        ITEM_PAD:
            _step_pad(direction)
        ITEM_ROBOT:
            _step_robot(direction)


func _step_pad(direction: int) -> void:
    var count := PAD_LAYOUTS.size()
    var next := (PAD_LAYOUTS.find(pad_layout) + direction + count) % count
    _on_pad_layout_pressed(PAD_LAYOUTS[next])
    _refresh_pad()


func _step_robot(direction: int) -> void:
    var count := ROBOT_MODELS.size()
    var next := (ROBOT_MODELS.find(robot_model) + direction + count) % count
    _on_robot_model_pressed(ROBOT_MODELS[next])
    _refresh_robot()


func _set_dots(dots: Array[ColorRect], active: int) -> void:
    for i in dots.size():
        dots[i].color = ACCENT_COLOR if i == active else DOT_OFF_COLOR


func _refresh_volume_labels() -> void:
    var text := "%d%%" % _volume
    _volume_label.text = text
    _volume_big_label.text = text


func _refresh_pad() -> void:
    var index := PAD_LAYOUTS.find(pad_layout)
    _pad_texture_rect.texture = PAD_TEXTURES[index]
    _pad_name_label.text = PAD_LAYOUT_NAMES[index]
    _set_dots(_pad_dots, index)


func _refresh_robot_names() -> void:
    var index := ROBOT_MODELS.find(robot_model)
    _robot_name_label.text = ROBOT_MODEL_NAMES[index]
    _set_dots(_robot_dots, index)


# 名前・点を合わせ、3D に出している機体が違うときだけ作り直す（最初に見るときまで instantiate しない）
func _refresh_robot() -> void:
    _refresh_robot_names()
    if _robot_shown == robot_model:
        return
    _robot_shown = robot_model
    if _robot_model_node != null:
        _robot_model_node.queue_free()
        _robot_model_node = null
    var scene: PackedScene = ROBOT_SCENES[ROBOT_MODELS.find(robot_model)]
    var model := scene.instantiate() as Node3D
    # 機体シーン（car.tscn・car_classic.tscn）と同じ姿勢
    var pose: Transform3D = str_to_var(ROBOT_MODEL_TRANSFORM)
    model.transform = Transform3D(pose.basis, Vector3.ZERO)
    _robot_pivot.rotation = Vector3.ZERO
    _robot_pivot.add_child(model)
    _robot_model_node = model

    # 全部の見た目の AABB を合わせ、その中心が原点に来るようにずらす
    var bounds := AABB()
    var found := false
    for visual in _collect_visuals(model):
        var box: AABB = visual.global_transform * visual.get_aabb()
        bounds = box if not found else bounds.merge(box)
        found = true
    if not found:
        return
    model.position = -bounds.get_center()
    # 斜め上（仰角 22°）から原点を見る。距離は AABB の半径 × 3.3
    var distance := bounds.size.length() * 0.5 * 3.3
    var elevation := deg_to_rad(22.0)
    var offset := Vector3(0.0, sin(elevation), cos(elevation)) * distance
    _robot_camera.look_at_from_position(offset, Vector3.ZERO)


func _collect_visuals(node: Node) -> Array[VisualInstance3D]:
    var result: Array[VisualInstance3D] = []
    if node is VisualInstance3D:
        result.append(node)
    for child in node.get_children():
        result.append_array(_collect_visuals(child))
    return result


func _on_pad_layout_pressed(layout: String) -> void:
    if layout == pad_layout:
        return
    pad_layout = layout
    _apply_pad_buttons()
    _save_settings()
    pad_layout_changed.emit(pad_layout)


func _on_debug_power_up_toggled(on: bool, key: String) -> void:
    PowerUps.set_acquired(key, on)


func _on_debug_hint_toggled(on: bool, id: String) -> void:
    PowerUps.set_hint_used(id, on)


func _on_robot_model_pressed(model: String) -> void:
    if model == robot_model:
        return
    robot_model = model
    _save_settings()
    robot_model_changed.emit(robot_model)


# 決定・キャンセル（と看板を開く）のボタンを表記に合わせる（任天堂・PSは右が決定で下がキャンセル、Xboxは下が決定で右がキャンセル）
func _apply_pad_buttons() -> void:
    var confirm := JOY_BUTTON_A if pad_layout == "xbox" else JOY_BUTTON_B
    var cancel := JOY_BUTTON_B if pad_layout == "xbox" else JOY_BUTTON_A
    _set_joy_button("ui_accept", confirm)
    _set_joy_button("ui_cancel", cancel)
    # 看板を開くボタンは決定と同じ（Nintendo は A、PS は ○、Xbox は A）
    _set_joy_button("interact", confirm)


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
    _refresh_volume_labels()
    _save_settings()
    # 音量の確認用に、bump の音を鳴らし直す
    _player.stop()
    _player.play()


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

extends CanvasLayer
# 左上のメニューボタンと、ESC/STARTで開く一時停止メニュー。
# メニュー内でBGM と効果音の音量と、操作説明に出すコントローラのボタン表記（Nintendo / PlayStation / Xbox）、操作する機体（Neo / Classic）を選べる。
# 決定とキャンセルのボタンを入れ替える設定もある。
# PlayStation の SELECT・START のボタンの表記（PS3 以前・PS4・PS5）も選べる。
# 画面は左に項目（音量・コントローラーの設定［下に ボタンの表示形式・決定とキャンセル・PlayStation の表記］・ロボットタイプ・閉じる）、右に選んでいる項目の詳細を出す。
# 操作は階層で進める。TOP（親の項目を上下で選ぶ）→ SUB（コントローラーの設定の中の項目を選ぶ）→ EDIT（右の列を左右で切り替える）。決定で入り、キャンセルで戻る。キーボードは Esc で1つ戻る（TOP では閉じる）。

signal pad_layout_changed(layout: String)
signal robot_model_changed(model: String)
signal swap_confirm_changed(swapped: bool)
signal ps_generation_changed(generation: String)

# Master バスの既定音量（default_bus_layout.tres）
const BASE_DB := -6.0206
const SETTINGS_PATH := "user://settings.cfg"
const BUTTON_SIZE := 40
# ボタンの角丸の半径
const BUTTON_RADIUS := 10
const MARGIN := 16
# ボタンの色（操作説明のアイコンに合わせる）
const RING_COLOR := UiStyle.TEXT_COLOR
const FACE_COLOR := UiStyle.PANEL_COLOR
const BUMP_SOUND := preload("res://assets/audio/bump/bump_a.ogg")
# BGM の試聴に流す曲（エンディング1の曲。ending.gd の BGM と同じ）
const BGM_PREVIEW_SOUND := preload("res://assets/audio/bgm/これにてお開き、また来週！.mp3")
# 音量バーの埋まった部分の色（EDIT のカーソルがあるときは ACCENT_COLOR）
const VOLUME_FILL_COLOR := Color(0.88, 0.88, 0.88)
# 操作説明に出すコントローラのボタン表記（設定ファイルに保存する値）
const PAD_LAYOUTS := ["nintendo", "playstation", "xbox"]
const PAD_LAYOUT_NAMES := ["Nintendo", "PlayStation", "Xbox"]
# PlayStation の SELECT・START のボタンの表記（設定ファイルに保存する値）
const PS_GENERATIONS := ["ps3", "ps4", "ps5"]
const PS_GENERATION_NAMES := ["PS3 以前", "PS4", "PS5"]
# PS_GENERATIONS の順に、左右の小さいボタンの名前
const PS_BACK_LABELS := ["SELECT", "SHARE", "CREATE"]
const PS_START_LABELS := ["START", "OPTIONS", "OPTIONS"]
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
    preload("res://assets/ui/menu/icon_controller.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
    preload("res://assets/ui/menu/icon_robot.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
]
# 左の列の「コントローラーの設定」の行
const CONTROLLER_HEADING := "コントローラーの設定"
const CONTROLLER_HEADING_ICON := preload("res://assets/ui/menu/icon_controller.png")
# コントローラーの設定の下に字下げして並べる項目
const CHILD_ITEMS := [1, 2, 3]
# 子の行の字下げ（px）
const CHILD_INDENT := 30
# ROBOT_MODELS の順
const ROBOT_SCENES := [
    preload("res://assets/ugokuita-neo.glb"),
    preload("res://assets/ugokuita-classic.fbx"),
]
# 左の項目（0: 音量、1: ボタンの表示形式、2: 決定とキャンセル、3: PlayStation の表記、4: ロボットタイプ、5: コントローラーの設定）
const ITEM_NAMES := ["音量", "ボタンの表示形式", "決定とキャンセル", "PlayStation の表記", "ロボットタイプ", CONTROLLER_HEADING]
const ITEM_DESCRIPTIONS := [
    "BGM と効果音の音量を調整します。決定ボタンで試聴できます",
    "使っているコントローラーのメーカーに合わせて変更してください",
    "慣れてる方に変更してください",
    "SELECT・START のボタンの表記を選びます",
    "操作する機体を切り替えます",
    "ボタンの表示形式、決定とキャンセル、PlayStation の表記を設定します",
]
const ITEM_VOLUME := 0
const ITEM_PAD := 1
const ITEM_CONFIRM := 2
const ITEM_PS := 3
const ITEM_ROBOT := 4
const ITEM_CONTROLLER := 5
# 左の列に並べる順（項目の番号）
const ROW_ORDER := [ITEM_VOLUME, ITEM_CONTROLLER, ITEM_PAD, ITEM_CONFIRM, ITEM_PS, ITEM_ROBOT]
# カーソルが「閉じる」にあるときの番号
const CURSOR_CLOSE := -1
# TOP でカーソルが動く順
const TOP_CURSORS := [ITEM_VOLUME, ITEM_CONTROLLER, ITEM_ROBOT, CURSOR_CLOSE]
# 階層。TOP: 親の項目を選ぶ、SUB: コントローラーの設定の中の項目を選ぶ、EDIT: 右の列を左右で切り替える
enum Level { TOP, SUB, EDIT }
# 決定とキャンセルの選択肢の名前（SWAP_CONFIRM_VALUES の順）
const SWAP_CONFIRM_NAMES := ["標準", "入れ替え"]
const SWAP_CONFIRM_VALUES := [false, true]

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
const PANEL_TOP := 72.0
const PANEL_BOTTOM := 24.0
const LEFT_COLUMN_WIDTH := 430.0
# パネルの幅がこれより狭いと、左右に並べると右の列がはみ出すので上下に並べる
const NARROW_WIDTH := LEFT_COLUMN_WIDTH + 500.0
const ROBOT_ROT_SPEED := 35.0
# 機体シーン（car.tscn・car_classic.tscn）と同じモデルの姿勢
const ROBOT_MODEL_TRANSFORM := "Transform3D(-4.37114e-08, 0, -1, 0, 1, 0, 1, 0, -4.37114e-08, 0, 0, 0)"

var is_open: bool = false
var pad_layout: String = "nintendo"
var robot_model: String = "neo"
# true なら決定とキャンセルのボタンを標準から入れ替える
var swap_confirm: bool = false
# PlayStation の SELECT・START のボタンの表記（PS_GENERATIONS のどれか）
var ps_generation: String = "ps5"
# BGM と効果音の音量（0〜100）
var _bgm_volume: int = 100
var _se_volume: int = 100
var _menu_button: Button
# メニューボタンの一辺（px。タッチ端末では倍率をかけた値）。マップのボタンも同じ大きさにする
var button_size: float = BUTTON_SIZE * UiStyle.button_scale()
var _dimmer: ColorRect
var _panel: PanelContainer
# 左右（狭いときは上下）に並べる列と、その中身
var _columns: BoxContainer
var _left_column: Control
var _right_column: Control
var _divider_margin: MarginContainer
var _divider: ColorRect
# 今、列を上下に並べているか
var _stacked: bool = false
# 右の列（音量の中身）の BGM・SE の行（HBoxContainer）、名前、バー、バーの埋まった部分のスタイル、「30%」、試聴ボタン、ボタンの中の印
var _bgm_row: HBoxContainer
var _bgm_name_label: Label
var _bgm_slider: HSlider
var _bgm_fill: StyleBoxFlat
var _bgm_percent_label: Label
var _bgm_preview_button: Button
var _bgm_preview_mark: Control
var _se_row: HBoxContainer
var _se_name_label: Label
var _se_slider: HSlider
var _se_fill: StyleBoxFlat
var _se_percent_label: Label
var _se_preview_button: Button
var _se_preview_mark: Control
# BGM の試聴用
var _preview_player: AudioStreamPlayer
# 左の項目の行（Button）、背景、白い縦帯、項目名（いずれも項目の番号で引く）、右端の山形
var _rows: Array[Button] = []
var _row_backgrounds: Array[Control] = []
var _row_stripes: Array[Control] = []
var _row_name_labels: Array[Label] = []
var _row_chevrons: Array[Control] = []
# 右の列の「<」「>」の矢印の絵
var _arrow_marks: Array[Control] = []
var _close_button: Button
var _close_label: Label
var _close_hint_box: HBoxContainer
var _close_hint_mark: Control
# 閉じるの印を作ったときの入力方式とボタン表記
var _close_hint_mode: int = -1
var _close_hint_layout: String = ""
var _close_hint_swap: bool = false
# 右の列に出している項目
var _current_item: int = ITEM_VOLUME
# 階層と、カーソルの位置（項目の番号か CURSOR_CLOSE）
var _level: Level = Level.TOP
var _cursor: int = ITEM_VOLUME
# EDIT に入る前の階層
var _edit_return: Level = Level.TOP
# 右の列の操作部品（項目の番号 → 部品の配列）。部品は {"node": 印を付ける Control, "step": 左右の処理（Callable か null）, "accept": 決定の処理（Callable か null）}
var _edit_controls: Array = []
# EDIT で今指している部品（_edit_controls[_cursor] の中の位置）
var _edit_index: int = 0
# 右の列
var _header_name: Label
var _header_line: ColorRect
var _header_desc: Label
var _contents: Array[Control] = []
var _pad_texture_rect: TextureRect
var _pad_name_label: Label
var _pad_confirm_icon: TextureRect
var _pad_cancel_icon: TextureRect
var _pad_dots: Array[ColorRect] = []
var _confirm_name_label: Label
var _confirm_dots: Array[ColorRect] = []
var _confirm_icon: TextureRect
var _confirm_cancel_icon: TextureRect
var _ps_name_label: Label
var _ps_dots: Array[ColorRect] = []
var _ps_back_icon: TextureRect
var _ps_start_icon: TextureRect
var _ps_back_label: Label
var _ps_start_label: Label
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
    _bgm_slider.set_value_no_signal(_bgm_volume)
    _se_slider.set_value_no_signal(_se_volume)
    _refresh_volume_labels()
    _refresh_pad()
    _refresh_confirm()
    _refresh_ps()
    _refresh_robot_names()
    _set_cursor(Level.TOP, ITEM_VOLUME)


func _process(delta: float) -> void:
    if not is_open:
        return
    # 入力方式かボタン表記、決定とキャンセルの入れ替えが変わったときだけ、閉じるの印を作り直す
    if ControlsHelp.get_mode() != _close_hint_mode or pad_layout != _close_hint_layout or swap_confirm != _close_hint_swap:
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
    # 階層とカーソルを最初（TOP の音量）に戻す
    _set_cursor(Level.TOP, ITEM_VOLUME)


func close() -> void:
    if not is_open:
        return
    is_open = false
    _stop_bgm_preview()
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
    # キーボードの Esc は、menu より先に見て1つ前の階層に戻る（TOP では _cancel() が閉じる）
    if is_open and event is InputEventKey and event.is_action_pressed("ui_cancel") and not event.is_echo():
        _cancel()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("menu") and not event.is_echo():
        toggle()
        get_viewport().set_input_as_handled()
        return
    if not is_open:
        return
    # 開いているあいだのキーボード・ゲームパッドの操作はここでまとめて処理する（Godot のフォーカスは使わない）。
    # キーボードの Esc は上で処理済み。コントローラのキャンセルのボタンは表記ごとに違う
    if event.is_action_pressed("ui_up", true):
        _move_cursor(-1)
    elif event.is_action_pressed("ui_down", true):
        _move_cursor(1)
    elif event.is_action_pressed("ui_left", true):
        _edit_step(-1)
    elif event.is_action_pressed("ui_right", true):
        _edit_step(1)
    elif event.is_action_pressed("ui_accept"):
        _activate()
    elif event.is_action_pressed("ui_cancel"):
        _cancel()
    else:
        return
    get_viewport().set_input_as_handled()


# 左上のメニューボタン（三本線アイコン）
func _build_button() -> void:
    _menu_button = Button.new()
    _menu_button.focus_mode = Control.FOCUS_NONE
    _menu_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _menu_button.offset_left = MARGIN
    _menu_button.offset_right = MARGIN + button_size
    _menu_button.offset_top = MARGIN
    _menu_button.offset_bottom = MARGIN + button_size
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
    # 絵の寸法は72pxのボタンを基準に、ボタンの大きさに合わせて縮める
    var k := icon.size.x / 72.0
    # 角を丸めた四角（操作説明のキーアイコンに合わせる）
    var face := StyleBoxFlat.new()
    face.bg_color = FACE_COLOR
    face.border_color = UiStyle.BORDER_COLOR
    face.set_border_width_all(2)
    face.set_corner_radius_all(BUTTON_RADIUS)
    face.anti_aliasing = true
    icon.draw_style_box(face, Rect2(Vector2.ZERO, icon.size))
    # 三本線（両端は丸める）
    for i in range(-1, 2):
        var y := center.y + i * 10.0 * k
        var from := Vector2(center.x - 14.0 * k, y)
        var to := Vector2(center.x + 14.0 * k, y)
        icon.draw_line(from, to, RING_COLOR, 6.0 * k, true)
        icon.draw_circle(from, 3.0 * k, RING_COLOR, true, -1.0, true)
        icon.draw_circle(to, 3.0 * k, RING_COLOR, true, -1.0, true)


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

    _columns = BoxContainer.new()
    _columns.add_theme_constant_override("separation", 0)
    _panel.add_child(_columns)

    _left_column = _build_left_column()
    _columns.add_child(_left_column)

    # 縦の区切り線（上下 28px あける。上下に並べるときは _set_stacked で横線にする）
    _divider_margin = _make_margin(0, 28, 0, 28)
    _divider = _make_line()
    _divider.custom_minimum_size = Vector2(1, 0)
    _divider_margin.add_child(_divider)
    _columns.add_child(_divider_margin)

    _right_column = _build_right_column()
    _columns.add_child(_right_column)

    # 一時停止中も鳴らすため、このノードの PROCESS_MODE_ALWAYS を継承させる
    _player = AudioStreamPlayer.new()
    _player.bus = "SE"
    _player.stream = BUMP_SOUND
    add_child(_player)

    # BGM の試聴用（これも一時停止中に鳴らす）。最後まで流れたら印を再生に戻す
    _preview_player = AudioStreamPlayer.new()
    _preview_player.bus = "BGM"
    # ファイルにループ設定があっても繰り返さない
    var preview_stream := BGM_PREVIEW_SOUND.duplicate() as AudioStreamMP3
    preview_stream.loop = false
    _preview_player.stream = preview_stream
    _preview_player.finished.connect(_refresh_preview_marks)
    add_child(_preview_player)


# 画面の大きさに合わせてパネルの位置と大きさを決める
func _layout_panel() -> void:
    if _panel == null or _columns == null:
        return
    var screen := _dimmer.size
    var width := minf(PANEL_MAX_WIDTH, screen.x - 32.0)
    # 並びを先に切り替える。左右並びのままだと最小幅に押し広げられ、狭い幅に設定し直せない
    var stacked := width < NARROW_WIDTH
    var changed := stacked != _stacked
    if changed:
        _set_stacked(stacked)
    _panel.position = Vector2((screen.x - width) * 0.5, PANEL_TOP)
    _panel.size = Vector2(width, maxf(screen.y - PANEL_TOP - PANEL_BOTTOM, 0.0))
    if changed:
        # 並びを変えた直後は最小サイズが更新されていないことがあるので、次のフレームでもう一度決める
        # （2回目は並びが変わらないので繰り返さない）
        _layout_panel.call_deferred()


# 左右の列を、上下に並べる（true）か左右に並べる（false）か切り替える
func _set_stacked(stacked: bool) -> void:
    _stacked = stacked
    _columns.vertical = stacked
    if stacked:
        # 左の列の中の伸びる余白がつぶれて、「閉じる」が項目の一覧のすぐ下に来る
        _left_column.custom_minimum_size.x = 0.0
        _left_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        _divider.custom_minimum_size = Vector2(0, 1)
        _divider_margin.add_theme_constant_override("margin_left", 28)
        _divider_margin.add_theme_constant_override("margin_right", 28)
        _divider_margin.add_theme_constant_override("margin_top", 0)
        _divider_margin.add_theme_constant_override("margin_bottom", 0)
        _right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    else:
        _left_column.custom_minimum_size.x = LEFT_COLUMN_WIDTH
        _left_column.size_flags_vertical = Control.SIZE_FILL
        _divider.custom_minimum_size = Vector2(1, 0)
        _divider_margin.add_theme_constant_override("margin_left", 0)
        _divider_margin.add_theme_constant_override("margin_right", 0)
        _divider_margin.add_theme_constant_override("margin_top", 28)
        _divider_margin.add_theme_constant_override("margin_bottom", 28)
        _right_column.size_flags_vertical = Control.SIZE_FILL
        _right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL


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
    # 行の配列は項目の番号で引くので、先に枠を作っておく
    _rows.resize(ITEM_NAMES.size())
    _row_backgrounds.resize(ITEM_NAMES.size())
    _row_stripes.resize(ITEM_NAMES.size())
    _row_name_labels.resize(ITEM_NAMES.size())
    for i in ROW_ORDER:
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
    # 子の行は高さ 48・字下げ・アイコン無し・文字 18px
    var is_child := index in CHILD_ITEMS
    var indent := CHILD_INDENT if is_child else 0
    var row := _make_flat_button(48 if is_child else 58, Control.FOCUS_NONE)
    _rows[index] = row

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
    background.offset_left = indent
    row.add_child(background)
    _row_backgrounds[index] = background

    # 左端の白い縦帯
    var stripe := ColorRect.new()
    stripe.color = TEXT_BODY
    stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    stripe.offset_left = indent
    stripe.offset_right = indent + 5
    row.add_child(stripe)
    _row_stripes[index] = stripe

    # 子の行の左の余白は、親のアイコン（30）と間（22）の分まで深くする
    var margin := _make_margin(22 + indent, 0, 18, 0)
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.add_child(margin)
    var hbox := HBoxContainer.new()
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.add_theme_constant_override("separation", 22)
    margin.add_child(hbox)

    if not is_child:
        var icon := _make_icon(ITEM_ICONS[index], 30)
        icon.custom_minimum_size = Vector2(30, 30)
        icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        hbox.add_child(icon)

    var name_label := _make_label(ITEM_NAMES[index], 18 if is_child else 21, TEXT_BODY)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(name_label)
    _row_name_labels[index] = name_label

    # 右端の「>」の山形（コントローラーの設定は下向きの「∨」）
    var chevron := Control.new()
    chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chevron.custom_minimum_size = Vector2(9, 16)
    chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    chevron.draw.connect(_on_chevron_draw.bind(chevron, index))
    hbox.add_child(chevron)
    _row_chevrons.append(chevron)

    row.mouse_entered.connect(_on_row_mouse_entered.bind(index))
    row.pressed.connect(_on_row_pressed.bind(index))
    return row


# 音量バー（マウス・タッチでドラッグできる。つまみは見せない）
func _make_volume_slider(fill: StyleBoxFlat, on_changed: Callable) -> HSlider:
    var slider := HSlider.new()
    slider.min_value = 0
    slider.max_value = 100
    # キーボード・ゲームパッドで1回押すごとに5%ずつ動かす
    slider.step = 5
    slider.focus_mode = Control.FOCUS_NONE
    slider.custom_minimum_size = Vector2(260, 24)
    slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    # 溝と埋まった部分（高さ 8px）
    var groove := _make_style(Color(1, 1, 1, 0.18), 4)
    groove.content_margin_top = 4
    groove.content_margin_bottom = 4
    # 埋まった部分の色は、その行に EDIT のカーソルがあるあいだだけ ACCENT_COLOR にする（_update_cursor_visuals）
    fill.bg_color = VOLUME_FILL_COLOR
    fill.set_corner_radius_all(4)
    fill.content_margin_top = 4
    fill.content_margin_bottom = 4
    slider.add_theme_stylebox_override("slider", groove)
    slider.add_theme_stylebox_override("grabber_area", fill)
    slider.add_theme_stylebox_override("grabber_area_highlight", fill)
    # つまみの絵は透明な 1px にして見せない
    var blank := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
    slider.add_theme_icon_override("grabber", blank)
    slider.add_theme_icon_override("grabber_highlight", blank)
    slider.add_theme_icon_override("grabber_disabled", blank)
    slider.value_changed.connect(on_changed)
    return slider


func _on_chevron_draw(chevron: Control, index: int) -> void:
    var color := TEXT_BODY if index == _cursor else TEXT_DIM
    if index == ITEM_CONTROLLER:
        # 下向きの「∨」（幅 14・高さ 8 を 9×16 の枠の中央に置く）
        chevron.draw_polyline(PackedVector2Array([Vector2(-2.5, 4), Vector2(4.5, 12), Vector2(11.5, 4)]), color, 2.5, true)
    else:
        chevron.draw_polyline(PackedVector2Array([Vector2(1, 1), Vector2(8, 8), Vector2(1, 15)]), color, 2.5, true)


# 「閉じる」の行
func _build_close_row() -> Control:
    _close_button = _make_flat_button(44, Control.FOCUS_NONE)
    _close_button.pressed.connect(_on_close_pressed)
    _close_button.mouse_entered.connect(_on_close_mouse_entered)

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
    _close_label.add_theme_color_override("font_color", TEXT_BODY if _cursor == CURSOR_CLOSE else TEXT_DIM)


# 入力方式の印（キーボードは Esc の箱、コントローラはキャンセルのボタン、タッチは無し）を作り直す
func _rebuild_close_hint() -> void:
    if _close_hint_mark != null:
        _close_hint_box.remove_child(_close_hint_mark)
        _close_hint_mark.queue_free()
        _close_hint_mark = null
    _close_hint_mode = ControlsHelp.get_mode()
    _close_hint_layout = pad_layout
    _close_hint_swap = swap_confirm
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
    _edit_controls.resize(ITEM_NAMES.size())
    for i in _edit_controls.size():
        _edit_controls[i] = []
    var contents: Array[Control] = [_build_volume_content(), _build_pad_content(), _build_confirm_content(), _build_ps_content(), _build_robot_content(), _build_controller_content()]
    for content in contents:
        content.set_anchors_preset(Control.PRESET_FULL_RECT)
        content.visible = false
        holder.add_child(content)
        _contents.append(content)
    return margin


func _build_volume_content() -> Control:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 18)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var icon := _make_icon(ITEM_ICONS[ITEM_VOLUME], 72)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    icon.modulate = Color(1, 1, 1, 0.35)
    box.add_child(icon)

    # BGM の行
    _bgm_fill = StyleBoxFlat.new()
    _bgm_row = HBoxContainer.new()
    _bgm_name_label = _make_label("BGM", 20, TEXT_BODY)
    _bgm_slider = _make_volume_slider(_bgm_fill, _on_bgm_volume_changed)
    _bgm_percent_label = _make_label("", 19, TEXT_DIM)
    _bgm_preview_button = _make_preview_button()
    _bgm_preview_mark = _make_preview_mark(_bgm_preview_button, _bgm_row, true)
    _fill_volume_row(_bgm_row, _bgm_name_label, _bgm_slider, _bgm_percent_label, _bgm_preview_button)
    _bgm_preview_button.pressed.connect(_toggle_bgm_preview)
    box.add_child(_bgm_row)
    _add_edit_control(ITEM_VOLUME, _bgm_row, _step_bgm_volume, _toggle_bgm_preview)

    # SE の行
    _se_fill = StyleBoxFlat.new()
    _se_row = HBoxContainer.new()
    _se_name_label = _make_label("SE", 20, TEXT_BODY)
    _se_slider = _make_volume_slider(_se_fill, _on_se_volume_changed)
    _se_percent_label = _make_label("", 19, TEXT_DIM)
    _se_preview_button = _make_preview_button()
    _se_preview_mark = _make_preview_mark(_se_preview_button, _se_row, false)
    _fill_volume_row(_se_row, _se_name_label, _se_slider, _se_percent_label, _se_preview_button)
    _se_preview_button.pressed.connect(_play_se_preview)
    box.add_child(_se_row)
    _add_edit_control(ITEM_VOLUME, _se_row, _step_se_volume, _play_se_preview)
    return box


# 音量の1行（名前・バー・%・試聴ボタンを左から並べる）
func _fill_volume_row(row: HBoxContainer, name_label: Label, slider: HSlider, percent_label: Label, preview_button: Button) -> void:
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 14)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_label.custom_minimum_size = Vector2(56, 0)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    row.add_child(name_label)
    row.add_child(slider)
    percent_label.custom_minimum_size = Vector2(56, 0)
    percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(percent_label)
    row.add_child(preview_button)


# 44×40 の試聴ボタン（印は _make_preview_mark で中に描く）
func _make_preview_button() -> Button:
    var button := _make_flat_button(40, Control.FOCUS_NONE)
    button.custom_minimum_size = Vector2(44, 40)
    button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    return button


# 試聴ボタンの中に再生「▶」/停止「■」の印を描く Control を足す
func _make_preview_mark(button: Button, row: Control, is_bgm: bool) -> Control:
    var mark := Control.new()
    mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mark.set_anchors_preset(Control.PRESET_FULL_RECT)
    mark.draw.connect(_on_preview_mark_draw.bind(mark, button, row, is_bgm))
    button.add_child(mark)
    button.mouse_entered.connect(mark.queue_redraw)
    button.mouse_exited.connect(mark.queue_redraw)
    return mark


func _on_preview_mark_draw(mark: Control, button: Button, row: Control, is_bgm: bool) -> void:
    # その行が EDIT のカーソルを持っているか、マウスが乗っているときは白にする
    var color := TEXT_BODY if _has_edit_cursor(row) or button.is_hovered() else TEXT_DIM
    var center := mark.size * 0.5
    if is_bgm and _preview_player != null and _preview_player.playing:
        # 停止「■」（12×12）
        mark.draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color)
    else:
        # 再生「▶」（幅 12・高さ 14）
        var points := PackedVector2Array([Vector2(-5, -7), Vector2(7, 0), Vector2(-5, 7)])
        for i in points.size():
            points[i] += center
        mark.draw_colored_polygon(points, color)


# コントローラーの設定。音量の中身と同じ作りで、アイコンを薄く中央に出すだけ
func _build_controller_content() -> Control:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var icon := _make_icon(CONTROLLER_HEADING_ICON, 96)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    icon.modulate = Color(1, 1, 1, 0.35)
    box.add_child(icon)
    return box


func _build_pad_content() -> Control:
    _pad_texture_rect = TextureRect.new()
    _pad_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _pad_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _pad_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _pad_texture_rect.custom_minimum_size = Vector2(0, 250)
    var parts := _build_selector(_pad_texture_rect, PAD_LAYOUTS.size(), _step_pad, ITEM_PAD)
    _pad_name_label = parts.name_label
    _pad_dots = parts.dots
    parts.box.add_child(_build_pad_buttons_row())
    return parts.box


# 名前と点の下に、今の表記での決定・キャンセルのボタンを並べた1行（点との間は 14）
func _build_pad_buttons_row() -> Control:
    var margin := MarginContainer.new()
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # 縦の並びの間（12）に足して 14 にする
    margin.add_theme_constant_override("margin_top", 2)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 10)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(row)
    _pad_confirm_icon = _make_pad_button_icon()
    row.add_child(_pad_confirm_icon)
    row.add_child(_make_pad_button_text("決定"))
    var gap := Control.new()
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gap.custom_minimum_size = Vector2(28 - 10 * 2, 0)
    row.add_child(gap)
    _pad_cancel_icon = _make_pad_button_icon()
    row.add_child(_pad_cancel_icon)
    row.add_child(_make_pad_button_text("キャンセル"))
    return margin


func _make_pad_button_icon() -> TextureRect:
    var icon := TextureRect.new()
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.custom_minimum_size = Vector2(0, 28)
    return icon


func _make_pad_button_text(text: String) -> Label:
    var label := UiStyle.make_label(text, 15, UiStyle.TEXT_DIM_COLOR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label


# 決定とキャンセル。中央に、決定とキャンセルのボタンのアイコンと名前を横に並べる
func _build_confirm_content() -> Control:
    var center := HBoxContainer.new()
    center.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_theme_constant_override("separation", 40)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.custom_minimum_size = Vector2(0, 250)
    _confirm_icon = _make_confirm_icon_rect()
    center.add_child(_make_confirm_column(_confirm_icon, "決定"))
    _confirm_cancel_icon = _make_confirm_icon_rect()
    center.add_child(_make_confirm_column(_confirm_cancel_icon, "キャンセル"))
    var parts := _build_selector(center, SWAP_CONFIRM_VALUES.size(), _step_confirm, ITEM_CONFIRM)
    _confirm_name_label = parts.name_label
    _confirm_dots = parts.dots
    return parts.box


# アイコン（高さ 72）の下に名前（17px）を置いた縦の並び
func _make_confirm_column(icon: TextureRect, text: String) -> Control:
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 8)
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(icon)
    var label := _make_label(text, 17, UiStyle.TEXT_COLOR)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(label)
    return column


func _make_confirm_icon_rect() -> TextureRect:
    var icon := TextureRect.new()
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.custom_minimum_size = Vector2(0, 72)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    return icon


# PlayStation の表記。中央に、左の小さいボタン（SELECT など）と右の小さいボタン（START など）のアイコンと名前を横に並べる
func _build_ps_content() -> Control:
    var center := HBoxContainer.new()
    center.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_theme_constant_override("separation", 40)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.custom_minimum_size = Vector2(0, 250)
    _ps_back_icon = _make_confirm_icon_rect()
    var back_column := _make_confirm_column(_ps_back_icon, "")
    _ps_back_label = back_column.get_child(1) as Label
    center.add_child(back_column)
    _ps_start_icon = _make_confirm_icon_rect()
    var start_column := _make_confirm_column(_ps_start_icon, "")
    _ps_start_label = start_column.get_child(1) as Label
    center.add_child(start_column)
    var parts := _build_selector(center, PS_GENERATIONS.size(), _step_ps, ITEM_PS)
    _ps_name_label = parts.name_label
    _ps_dots = parts.dots
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

    var parts := _build_selector(container, ROBOT_MODELS.size(), _step_robot, ITEM_ROBOT)
    _robot_name_label = parts.name_label
    _robot_dots = parts.dots
    return parts.box


# 項目の操作部品を登録する（step・accept は無ければ空の Callable）
func _add_edit_control(item: int, node: Control, step: Callable, accept: Callable) -> void:
    _edit_controls[item].append({
        "node": node,
        "step": step if step.is_valid() else null,
        "accept": accept if accept.is_valid() else null,
    })


# 「<」ボタン・中央の絵・「>」ボタン、その下の名前と点を並べた部品。{box, name_label, dots} を返す。
# 「< 絵 >」の並びを item の操作部品として登録する
func _build_selector(center: Control, count: int, step: Callable, item: int) -> Dictionary:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(row)
    row.add_child(_make_arrow_button(-1, step, row))
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(center)
    row.add_child(_make_arrow_button(1, step, row))
    _add_edit_control(item, row, step, Callable())

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
func _make_arrow_button(direction: int, step: Callable, target: Control) -> Button:
    var button := _make_flat_button(48, Control.FOCUS_NONE)
    button.custom_minimum_size = Vector2(48, 48)
    button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    button.pressed.connect(step.bind(direction))
    var mark := Control.new()
    mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mark.set_anchors_preset(Control.PRESET_FULL_RECT)
    mark.draw.connect(_on_arrow_draw.bind(mark, button, direction, target))
    button.add_child(mark)
    _arrow_marks.append(mark)
    button.mouse_entered.connect(mark.queue_redraw)
    button.mouse_exited.connect(mark.queue_redraw)
    return button


func _on_arrow_draw(mark: Control, button: Button, direction: int, target: Control) -> void:
    # この部品が EDIT のカーソルを持っているあいだは、マウスが乗っていなくても白にする
    var color := TEXT_BODY if _has_edit_cursor(target) or button.is_hovered() else TEXT_DIM
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

# 階層とカーソルを変えて、見た目をすべて合わせる（index は項目の番号か CURSOR_CLOSE）
func _set_cursor(level: Level, index: int) -> void:
    _level = level
    _cursor = index
    # 「閉じる」にカーソルがあるときの右の列は、直前の項目のまま
    if index != CURSOR_CLOSE:
        _set_current_item(index, true)
    _update_cursor_visuals()


# カーソルと階層に合わせて、左の列・右の矢印・音量バーの見た目を更新する
func _update_cursor_visuals() -> void:
    var background_alpha := 0.45 if _level == Level.EDIT else 1.0
    for i in _rows.size():
        _row_backgrounds[i].visible = i == _cursor
        _row_backgrounds[i].modulate = Color(1, 1, 1, background_alpha)
        _row_stripes[i].visible = i == _cursor
    # TOP のあいだ、子の行の項目名は暗くする
    for i in CHILD_ITEMS:
        _row_name_labels[i].add_theme_color_override("font_color", TEXT_DIM if _level == Level.TOP else TEXT_BODY)
    for chevron in _row_chevrons:
        chevron.queue_redraw()
    for mark in _arrow_marks:
        mark.queue_redraw()
    _bgm_fill.bg_color = ACCENT_COLOR if _has_edit_cursor(_bgm_row) else VOLUME_FILL_COLOR
    _se_fill.bg_color = ACCENT_COLOR if _has_edit_cursor(_se_row) else VOLUME_FILL_COLOR
    # EDIT の音量から出たら、BGM の試聴は止める
    if _level != Level.EDIT or _cursor != ITEM_VOLUME:
        _stop_bgm_preview()
    _refresh_preview_marks()
    _update_close_color()


# 今の EDIT で、この部品がカーソルを持っているか
func _has_edit_cursor(node: Control) -> bool:
    if _level != Level.EDIT or _cursor < 0:
        return false
    var controls: Array = _edit_controls[_cursor]
    return _edit_index < controls.size() and controls[_edit_index]["node"] == node


# 右の列に出す項目を切り替える（force なら同じ項目でも作り直す）
func _set_current_item(index: int, force: bool) -> void:
    if index == _current_item and not force:
        return
    _current_item = index
    _header_name.text = ITEM_NAMES[index]
    _header_desc.text = ITEM_DESCRIPTIONS[index]
    # 見出しの線は、文字の幅 + 40px
    _header_line.custom_minimum_size = Vector2(_header_name.get_minimum_size().x + 40.0, 1)
    for i in _contents.size():
        _contents[i].visible = i == index
    if index == ITEM_ROBOT:
        _refresh_robot()


# 項目の行が属する階層（子の3項目なら SUB、それ以外は TOP）
func _level_of_item(index: int) -> Level:
    return Level.SUB if index in CHILD_ITEMS else Level.TOP


# マウスが乗った行にカーソルを移す（EDIT 中でも移る）
func _on_row_mouse_entered(index: int) -> void:
    _set_cursor(_level_of_item(index), index)


# クリック・タップ。その行にカーソルを移して、決定と同じ動きをする
func _on_row_pressed(index: int) -> void:
    _set_cursor(_level_of_item(index), index)
    _activate()


func _on_close_mouse_entered() -> void:
    _set_cursor(Level.TOP, CURSOR_CLOSE)


func _on_close_pressed() -> void:
    _set_cursor(Level.TOP, CURSOR_CLOSE)
    _activate()


# 上下でカーソルを動かす（端で止まる。EDIT では何もしない）
func _move_cursor(direction: int) -> void:
    var cursors: Array
    match _level:
        Level.TOP:
            cursors = TOP_CURSORS
        Level.SUB:
            cursors = CHILD_ITEMS
        _:
            _move_edit(direction)
            return
    var position := cursors.find(_cursor)
    var next := clampi(position + direction, 0, cursors.size() - 1)
    if next != position:
        _set_cursor(_level, cursors[next])


# EDIT で部品のあいだを上下に移る（端で止まる）
func _move_edit(direction: int) -> void:
    var count: int = _edit_controls[_cursor].size()
    var next := clampi(_edit_index + direction, 0, count - 1)
    if next != _edit_index:
        _edit_index = next
        _update_cursor_visuals()


# 今の EDIT の部品（無ければ空の Dictionary）
func _current_edit_control() -> Dictionary:
    var controls: Array = _edit_controls[_cursor]
    if _edit_index < controls.size():
        return controls[_edit_index]
    return {}


# 左右で値を切り替える（EDIT で、今の部品に step があるときだけ）
func _edit_step(direction: int) -> void:
    if _level != Level.EDIT:
        return
    var step: Variant = _current_edit_control().get("step")
    if step != null:
        step.call(direction)


# 決定
func _activate() -> void:
    match _level:
        Level.TOP:
            if _cursor == CURSOR_CLOSE:
                close()
            elif _cursor == ITEM_CONTROLLER:
                _set_cursor(Level.SUB, ITEM_PAD)
            else:
                _enter_edit()
        Level.SUB:
            _enter_edit()
        Level.EDIT:
            # 今の部品に accept があれば呼ぶ（EDIT からは戻らない）
            var accept: Variant = _current_edit_control().get("accept")
            if accept != null:
                accept.call()


# キャンセル
func _cancel() -> void:
    match _level:
        Level.TOP:
            close()
        Level.SUB:
            _set_cursor(Level.TOP, ITEM_CONTROLLER)
        Level.EDIT:
            _exit_edit()


func _enter_edit() -> void:
    # 操作部品の無い項目には入らない
    if _edit_controls[_cursor].is_empty():
        return
    _edit_return = _level
    _edit_index = 0
    _set_cursor(Level.EDIT, _cursor)


# 入る前の階層に戻る（カーソルは同じ項目のまま）
func _exit_edit() -> void:
    _set_cursor(_edit_return, _cursor)


# 音量は 5 ずつ動かす
func _step_bgm_volume(direction: int) -> void:
    _bgm_slider.value += 5.0 * direction


func _step_se_volume(direction: int) -> void:
    _se_slider.value += 5.0 * direction


# BGM の試聴。止まっていれば頭から再生、再生中なら止める
func _toggle_bgm_preview() -> void:
    if _preview_player.playing:
        _preview_player.stop()
    else:
        _preview_player.play()
    _refresh_preview_marks()


func _stop_bgm_preview() -> void:
    if _preview_player != null and _preview_player.playing:
        _preview_player.stop()
        _refresh_preview_marks()


# SE の試聴。確認音を鳴らし直す
func _play_se_preview() -> void:
    _player.stop()
    _player.play()


# 試聴ボタンの印（再生/停止、色）を描き直す
func _refresh_preview_marks() -> void:
    if _bgm_preview_mark != null:
        _bgm_preview_mark.queue_redraw()
    if _se_preview_mark != null:
        _se_preview_mark.queue_redraw()


func _step_pad(direction: int) -> void:
    var count := PAD_LAYOUTS.size()
    var next := (PAD_LAYOUTS.find(pad_layout) + direction + count) % count
    _on_pad_layout_pressed(PAD_LAYOUTS[next])
    _refresh_pad()
    # 決定とキャンセルの項目の絵も表記に合わせる
    _refresh_confirm()


# 選択肢は2つなので、どちらの向きでも交互に切り替わる
func _step_confirm(_direction: int) -> void:
    swap_confirm = not swap_confirm
    _apply_pad_buttons()
    _save_settings()
    swap_confirm_changed.emit(swap_confirm)
    _refresh_confirm()
    # コントローラーの設定の中の「決定・キャンセル」の行も追従させる
    _refresh_pad()


func _step_ps(direction: int) -> void:
    var count := PS_GENERATIONS.size()
    var next := (PS_GENERATIONS.find(ps_generation) + direction + count) % count
    ps_generation = PS_GENERATIONS[next]
    _save_settings()
    ps_generation_changed.emit(ps_generation)
    _refresh_ps()


func _step_robot(direction: int) -> void:
    var count := ROBOT_MODELS.size()
    var next := (ROBOT_MODELS.find(robot_model) + direction + count) % count
    _on_robot_model_pressed(ROBOT_MODELS[next])
    _refresh_robot()


func _set_dots(dots: Array[ColorRect], active: int) -> void:
    for i in dots.size():
        dots[i].color = ACCENT_COLOR if i == active else DOT_OFF_COLOR


func _refresh_volume_labels() -> void:
    _bgm_percent_label.text = "%d%%" % _bgm_volume
    _se_percent_label.text = "%d%%" % _se_volume


func _refresh_pad() -> void:
    var index := PAD_LAYOUTS.find(pad_layout)
    _pad_texture_rect.texture = PAD_TEXTURES[index]
    _pad_name_label.text = PAD_LAYOUT_NAMES[index]
    _set_dots(_pad_dots, index)
    _pad_confirm_icon.texture = ControlsHelp.get_confirm_icon_for(pad_layout)
    _pad_cancel_icon.texture = ControlsHelp.get_cancel_icon_for(pad_layout)


func _refresh_confirm() -> void:
    var index := SWAP_CONFIRM_VALUES.find(swap_confirm)
    _confirm_name_label.text = SWAP_CONFIRM_NAMES[index]
    _set_dots(_confirm_dots, index)
    _confirm_icon.texture = ControlsHelp.get_confirm_icon_for(pad_layout)
    _confirm_cancel_icon.texture = ControlsHelp.get_cancel_icon_for(pad_layout)


func _refresh_ps() -> void:
    var index := PS_GENERATIONS.find(ps_generation)
    _ps_name_label.text = PS_GENERATION_NAMES[index]
    _set_dots(_ps_dots, index)
    _ps_back_icon.texture = ControlsHelp.get_ps_back_icon(ps_generation)
    _ps_start_icon.texture = ControlsHelp.get_ps_start_icon(ps_generation)
    _ps_back_label.text = PS_BACK_LABELS[index]
    _ps_start_label.text = PS_START_LABELS[index]


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


# 決定・キャンセル（と看板を開く）のボタンを表記に合わせる。
# 標準は Nintendo が A（右）で決定・B（下）でキャンセル、PlayStation が ×（下）で決定・○（右）でキャンセル、Xbox が A（下）で決定・B（右）でキャンセル。
# swap_confirm が true なら決定とキャンセルを入れ替える
func _apply_pad_buttons() -> void:
    var confirm := JOY_BUTTON_B if pad_layout == "nintendo" else JOY_BUTTON_A
    var cancel := JOY_BUTTON_A if pad_layout == "nintendo" else JOY_BUTTON_B
    if swap_confirm:
        var swapped := confirm
        confirm = cancel
        cancel = swapped
    _set_joy_button("ui_accept", confirm)
    _set_joy_button("ui_cancel", cancel)
    # 看板を開くボタンは決定と同じ
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


func _on_bgm_volume_changed(value: float) -> void:
    _bgm_volume = int(value)
    _apply_volume()
    _refresh_volume_labels()
    _save_settings()
    # BGM のバーは音を鳴らさない（試聴中なら音量がそのまま反映される）


func _on_se_volume_changed(value: float) -> void:
    _se_volume = int(value)
    _apply_volume()
    _refresh_volume_labels()
    _save_settings()
    # 音量の確認用に、bump の音を鳴らし直す
    _play_se_preview()


# 看板のリンクを開く前に、すべての音を消す。フォーカスが戻ったら _notification で音量を戻す
func mute_all() -> void:
    AudioServer.set_bus_mute(0, true)


# 音量を設定どおりに戻す（リンクを開いてもフォーカスが外れなかったとき用）
func restore_volume() -> void:
    _apply_volume()


# Web 版で走行中に看板のリンクを開くと、別のタブが前に出てゲームが止まり、走行音が鳴りっぱなしになる。
# ゲームの画面からフォーカスが外れている間は音を消し、戻ったら音量の設定どおりに戻す（0% ならミュートのまま）
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        AudioServer.set_bus_mute(0, true)
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        _apply_volume()


# Master は既定音量に固定してミュートも外し、BGM・SE のバスに設定の音量をかける
func _apply_volume() -> void:
    AudioServer.set_bus_mute(0, false)
    AudioServer.set_bus_volume_db(0, BASE_DB)
    _apply_bus_volume("BGM", _bgm_volume)
    _apply_bus_volume("SE", _se_volume)


# 0% はミュート、それ以外はミュートを外して比率で下げる
func _apply_bus_volume(bus_name: String, volume: int) -> void:
    var bus := AudioServer.get_bus_index(bus_name)
    if bus < 0:
        return
    var ratio := volume / 100.0
    if ratio <= 0.0:
        AudioServer.set_bus_mute(bus, true)
    else:
        AudioServer.set_bus_mute(bus, false)
        AudioServer.set_bus_volume_db(bus, linear_to_db(ratio))


func _load_settings() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        return
    # 古い設定ファイルの audio/volume は、BGM・SE の初期値に引き継ぐ
    var legacy_volume := clampi(int(config.get_value("audio", "volume", 100)), 0, 100)
    _bgm_volume = clampi(int(config.get_value("audio", "bgm_volume", legacy_volume)), 0, 100)
    _se_volume = clampi(int(config.get_value("audio", "se_volume", legacy_volume)), 0, 100)
    var layout := str(config.get_value("controls", "pad_layout", "nintendo"))
    if layout in PAD_LAYOUTS:
        pad_layout = layout
    swap_confirm = bool(config.get_value("controls", "swap_confirm", false))
    var generation := str(config.get_value("controls", "ps_generation", "ps5"))
    if generation in PS_GENERATIONS:
        ps_generation = generation
    var model := str(config.get_value("robot", "model", "neo"))
    if model in ROBOT_MODELS:
        robot_model = model


func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "bgm_volume", _bgm_volume)
    config.set_value("audio", "se_volume", _se_volume)
    config.set_value("controls", "pad_layout", pad_layout)
    config.set_value("controls", "swap_confirm", swap_confirm)
    config.set_value("controls", "ps_generation", ps_generation)
    config.set_value("robot", "model", robot_model)
    config.save(SETTINGS_PATH)

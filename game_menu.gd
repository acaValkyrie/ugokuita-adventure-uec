extends CanvasLayer
# 左上のメニューボタンと、ESC/STARTで開く一時停止メニュー。
# メニュー内でBGM と効果音の音量と、操作説明に出すコントローラのボタン表記（Nintendo / Xbox / DualShock 3 / DualShock 4 / DualSense）、操作する機体（Neo / Classic）を選べる。
# 決定とキャンセルのボタンを入れ替える設定もある。
# PlayStation の SELECT・START などの表記（PS3 以前・PS4・PS5）は、選んだ機種（DualShock 3・DualShock 4・DualSense）から決まる。
# カメラ操作の左右・上下の反転も選べる。
# キーボードのキーの割り当ても変えられる（KeyBindings。操作の行にカーソルを合わせて、使いたいキーを長押しする）。
# ゲームパッドのボタンの割り当ても同じやり方で変えられる（操作の行にカーソルを合わせて、使いたいボタンを長押しする）。
# 画面は左に項目（音量・操作の設定［下に ボタンの表示形式・決定とキャンセル・カメラの操作・キーの割り当て・ボタンの割り当て］・ロボットタイプ・セーブデータ・閉じる）、右に選んでいる項目の詳細を出す。
# 操作は階層で進める。TOP（親の項目を上下で選ぶ）→ SUB（操作の設定の中の項目を選ぶ）→ EDIT（右の列を左右で切り替える）。決定で入り、キャンセルで戻る。キーボードは Esc で1つ戻る（TOP では閉じる）。
# 中分類（ボタンの表示形式・決定とキャンセル・カメラの操作・キーの割り当て・ボタンの割り当て）の行は、操作の設定に入ったときだけ開き、それ以外ではたたんでおく。

signal pad_layout_changed(layout: String)
signal robot_model_changed(model: String)
signal swap_confirm_changed(swapped: bool)
signal key_bindings_changed
signal pad_bindings_changed

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
const PAD_LAYOUTS := ["nintendo", "xbox", "ds3", "ds4", "dualsense"]
const PAD_LAYOUT_NAMES := ["Nintendo", "Xbox", "DualShock 3", "DualShock 4", "DualSense"]
# PlayStation の機種と、SELECT・START などの表記の世代の対応
const PS_LAYOUT_GENERATIONS := {"ds3": "ps3", "ds4": "ps4", "dualsense": "ps5"}
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
    preload("res://assets/ui/menu/controller_xbox.png"),
    preload("res://assets/ui/menu/controller_ds3.png"),
    preload("res://assets/ui/menu/controller_ds4.png"),
    preload("res://assets/ui/menu/controller_dualsense.png"),
]
const ITEM_ICONS := [
    preload("res://assets/ui/menu/icon_volume.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
    preload("res://assets/ui/menu/icon_robot.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
    preload("res://assets/ui/menu/icon_save.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
    preload("res://assets/ui/menu/icon_controller.png"),
]
# 左の列の「操作の設定」の行
const CONTROLLER_HEADING := "操作の設定"
const CONTROLLER_HEADING_ICON := preload("res://assets/ui/menu/icon_controller.png")
# 操作の設定の下に字下げして並べる項目
const CHILD_ITEMS := [1, 2, 6, 7, 8]
# 子の行の字下げ（px）
const CHILD_INDENT := 30
# ROBOT_MODELS の順
const ROBOT_SCENES := [
    preload("res://assets/ugokuita-neo.glb"),
    preload("res://assets/ugokuita-classic.fbx"),
]
# 左の項目（0: 音量、1: ボタンの表示形式、2: 決定とキャンセル、3: ロボットタイプ、4: 操作の設定、5: セーブデータ、6: カメラの操作、7: キーの割り当て、8: ボタンの割り当て）
const ITEM_NAMES := ["音量", "ボタンの表示形式", "決定とキャンセル", "ロボットタイプ", CONTROLLER_HEADING, "セーブデータ", "カメラの操作", "キーの割り当て", "ボタンの割り当て"]
const ITEM_DESCRIPTIONS := [
    "BGM と効果音の音量を調整します。決定ボタンで試聴できます",
    "使っているコントローラーに合わせて変更してください",
    "慣れてる方に変更してください",
    "操作する機体を切り替えます",
    "ボタンの表示形式、決定とキャンセル、カメラの操作、キーとボタンの割り当てを設定します",
    "集めたアイテムとヒントの記録をリセットします",
    "カメラを動かす向きを、左右・上下それぞれで反転できます",
    "カーソルを合わせて、使いたいキーを長押ししてください",
    "カーソルを合わせて、使いたいボタンを長押ししてください",
]
const ITEM_VOLUME := 0
const ITEM_PAD := 1
const ITEM_CONFIRM := 2
const ITEM_ROBOT := 3
const ITEM_CONTROLLER := 4
const ITEM_DATA := 5
const ITEM_CAMERA := 6
const ITEM_KEYS := 7
const ITEM_PAD_BUTTONS := 8
# 左の列に並べる順（項目の番号）
const ROW_ORDER := [ITEM_VOLUME, ITEM_CONTROLLER, ITEM_PAD, ITEM_CONFIRM, ITEM_CAMERA, ITEM_KEYS, ITEM_PAD_BUTTONS, ITEM_ROBOT, ITEM_DATA]
# 使えないキー・ボタンを押したときに、行の状態として出す文
const KEY_REJECT_MESSAGE := "このキーは使えません"
const BUTTON_REJECT_MESSAGE := "このボタンは使えません"
# 使えないキー・ボタンの文を出しておく時間 [s]
const REJECT_SHOW_TIME := 1.5
# 長押し中（キー・ボタン共通）に、行の状態として出す文
const HOLD_MESSAGE := "そのまま押し続けてください"
# 割り当てるキー・ボタンを押し続ける時間 [s]。うっかり押したキーで変わらないように
const BIND_HOLD_TIME := 0.6
# 長押しの対象のキー・ボタンでも、使えないものが押されたときはメニューの操作として通す入力
const MENU_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel", "menu"]
# カーソルが「閉じる」にあるときの番号
const CURSOR_CLOSE := -1
# TOP でカーソルが動く順
const TOP_CURSORS := [ITEM_VOLUME, ITEM_CONTROLLER, ITEM_ROBOT, ITEM_DATA, CURSOR_CLOSE]
# 階層。TOP: 親の項目を選ぶ、SUB: 操作の設定の中の項目を選ぶ、EDIT: 右の列を左右で切り替える
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
# カメラ操作の左右・上下を反転するか。キーボード・ゲームパッド・タッチのどれにも効く
var invert_camera_x: bool = false
var invert_camera_y: bool = false
# BGM と効果音の音量（0〜100）
var _bgm_volume: int = 100
var _se_volume: int = 100
var _menu_button: Button
# メニューボタンの一辺（px。タッチ端末では倍率をかけた値）。マップのボタンも同じ大きさにする
var button_size: float = BUTTON_SIZE * UiStyle.button_scale()
var _dimmer: ColorRect
# EDIT で操作している部品の左に出す赤い縦帯
var _edit_bar: ColorRect
var _panel: PanelContainer
# 左右（狭いときは上下）に並べる列と、その中身
var _columns: BoxContainer
# 列をまとめて縦にスクロールさせる枠（上下に並べるときの全体のスクロール。画面の高さが低くても全項目に届くように）
var _scroll: ScrollContainer
# 左右に並べるときに、左の列・右の列を別々に縦にスクロールさせる枠（上下に並べるときは縦スクロールを切って、_scroll に任せる）
var _left_scroll: ScrollContainer
var _right_scroll: ScrollContainer
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
var _row_backgrounds: Array[TextureRect] = []
# 行の背景の絵（TOP・SUB は赤、EDIT は灰色のグラデーション）
var _row_red_texture: GradientTexture2D
var _row_gray_texture: GradientTexture2D
var _row_stripes: Array[Control] = []
var _row_name_labels: Array[Label] = []
var _row_chevrons: Array[Control] = []
# 右の列の「<」「>」の矢印の絵
var _arrow_marks: Array[Control] = []
var _close_button: Button
var _close_label: Label
# 閉じるにカーソルがあるときの赤い背景と白い縦帯
var _close_background: TextureRect
var _close_stripe: Control
var _close_hint_box: HBoxContainer
var _close_hint_mark: Control
# キーボードのときの Esc の箱の枠と中の文字（色を _update_close_color で変える）
var _close_hint_frame: StyleBoxFlat
var _close_hint_text: Label
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
# 操作の設定の中分類（CHILD_ITEMS の行）を開いているか
var _children_expanded := false
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
var _camera_x_value: Label
var _camera_y_value: Label
# キーの割り当ての項目（KeyBindings.ACTIONS の順の、行のボタン・キーの絵を入れる枠・状態の文字。初期設定に戻すボタンと、その枠線のスタイル）
var _key_rows: Array[Button] = []
var _key_icon_slots: Array[Control] = []
var _key_status_labels: Array[Label] = []
var _keys_reset_button: Button
var _keys_reset_style: StyleBoxFlat
# 状態の部分を出している行の位置（出していなければ -1）と、そこに出す文。長押し中か、使えないキーを押した直後に出す
var _key_status_index: int = -1
var _key_status_message := ""
# 使えないキーの文を消す時刻 [ms]（出していなければ 0）
var _key_reject_until_msec: int = 0
# 長押し中のキー（長押ししていなければ KEY_NONE）と、押し始めの時刻 [ms]、押したときのイベント（短く離したらメニューの操作として戻す）。各行の状態の文の下に、進み具合のバーを置く
var _hold_key: Key = KEY_NONE
var _hold_key_start_msec: int = 0
var _hold_key_event: InputEvent = null
var _key_hold_bars: Array[ColorRect] = []
# 各行の名前の部分（右に初期設定のキーを添える）
var _key_name_boxes: Array[HBoxContainer] = []
# ボタンの割り当ての項目（KeyBindings.PAD_ACTIONS の順の、行のボタン・ボタンの絵を入れる枠・状態の文字。初期設定に戻すボタンと、その枠線のスタイル）
var _button_rows: Array[Button] = []
var _button_icon_slots: Array[Control] = []
var _button_status_labels: Array[Label] = []
var _buttons_reset_button: Button
var _buttons_reset_style: StyleBoxFlat
# ボタンの割り当ての状態の部分（キーと同じ作り。キーの割り当てとは同時にならない）
var _button_status_index: int = -1
var _button_status_message := ""
var _button_reject_until_msec: int = 0
# 長押し中のボタン（長押ししていなければ JOY_BUTTON_INVALID）と、押し始めの時刻 [ms]、押したときのイベント、各行の進み具合のバー
var _hold_button: JoyButton = JOY_BUTTON_INVALID
var _hold_button_start_msec: int = 0
var _hold_button_event: InputEvent = null
var _button_hold_bars: Array[ColorRect] = []
# 各行の名前の部分（右に初期設定のボタンを添える）
var _button_name_boxes: Array[HBoxContainer] = []
var _robot_name_label: Label
var _robot_dots: Array[ColorRect] = []
# セーブデータの項目（持っているアイテムの切り替え、リセットのボタンと中の文字）。リセットは2回押して確定する
var _data_selector_box: Control
var _data_arrow_row: HBoxContainer
var _data_dots_row: HBoxContainer
var _data_dots: Array[ColorRect] = []
var _data_item_icon: TextureRect
var _data_item_name: Label
var _data_item_desc: Label
var _data_empty_label: Label
var _data_note_label: Label
var _data_item_index: int = 0
var _data_reset_button: Button
var _data_reset_label: Label
var _data_reset_style: StyleBoxFlat
var _data_reset_armed: bool = false
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
    key_bindings_changed.connect(_refresh_keys)
    # ボタンの行の絵は、ボタンの割り当てのほか、機種（PlayStation の世代も機種で決まる）が変わったときにも作り直す
    pad_bindings_changed.connect(_refresh_buttons)
    pad_layout_changed.connect(_refresh_buttons.unbind(1))
    # 起動時の初期表示では保存や音を走らせない
    _bgm_slider.set_value_no_signal(_bgm_volume)
    _se_slider.set_value_no_signal(_se_volume)
    _refresh_volume_labels()
    _refresh_pad()
    _refresh_confirm()
    _refresh_camera()
    _refresh_robot_names()
    _set_cursor(Level.TOP, ITEM_VOLUME)


func _process(delta: float) -> void:
    if not is_open:
        return
    # 入力方式かボタン表記、決定とキャンセルの入れ替えが変わったときだけ、閉じるの印を作り直す
    if ControlsHelp.get_mode() != _close_hint_mode or pad_layout != _close_hint_layout or swap_confirm != _close_hint_swap:
        _rebuild_close_hint()
    _update_edit_bar()
    # ロボットタイプを見ているときだけ機体を回す（一時停止中も動く）
    if _current_item == ITEM_ROBOT and _robot_pivot != null:
        _robot_pivot.rotate_y(deg_to_rad(ROBOT_ROT_SPEED) * delta)
    # 割り当てるキー・ボタンの長押しを進める（一時停止中も進むよう、時刻は Time で見る）
    _update_key_hold()
    _update_button_hold()


# その機種が PlayStation か（DualShock 3・DualShock 4・DualSense）
func is_playstation_layout(layout: String) -> bool:
    return PS_LAYOUT_GENERATIONS.has(layout)


# 今の機種での PlayStation の表記の世代（ps3・ps4・ps5）。PlayStation の機種でなければ ps5
func get_ps_generation() -> String:
    return PS_LAYOUT_GENERATIONS.get(pad_layout, "ps5")


func get_button_rect() -> Rect2:
    return _menu_button.get_global_rect()


func open() -> void:
    # 起動時の読み込み中は開かない（終わったときの pause 解除で開いたまま動いてしまうため）
    if is_open or ShaderWarmup.is_loading():
        return
    is_open = true
    # デバッグ欄のトグルを、いま取っている状態に合わせる（シグナルは出さない）
    for key in _debug_buttons:
        _debug_buttons[key].set_pressed_no_signal(PowerUps.has(key))
    for id in _debug_hint_buttons:
        _debug_hint_buttons[id].set_pressed_no_signal(PowerUps.is_hint_used(id))
    _dimmer.visible = true
    get_tree().paused = true
    _data_reset_armed = false
    _data_item_index = 0
    _children_expanded = false
    _scroll.scroll_vertical = 0
    _left_scroll.scroll_vertical = 0
    _right_scroll.scroll_vertical = 0
    _layout_panel()
    _rebuild_close_hint()
    # 階層とカーソルを最初（TOP の音量）に戻す
    _set_cursor(Level.TOP, ITEM_VOLUME)


func close() -> void:
    if not is_open:
        return
    is_open = false
    _stop_bgm_preview()
    _stop_key_hold()
    _stop_button_hold()
    _dimmer.visible = false
    _edit_bar.visible = false
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
    if not is_open:
        if event.is_action_pressed("menu") and not event.is_echo():
            toggle()
            get_viewport().set_input_as_handled()
        return
    # 割り当ての行にカーソルがあるときは、キー・ボタンの長押しを先に見る（短く離したときだけメニューの操作になる）
    if _input_bind_hold(event) or _handle_menu_input(event):
        get_viewport().set_input_as_handled()


# 開いているあいだのキーボード・ゲームパッドの操作をここでまとめて処理する（Godot のフォーカスは使わない）。
# 処理したら true を返す。割り当ての長押しが短く離されたときは、覚えておいた押下のイベントをここに渡す
func _handle_menu_input(event: InputEvent) -> bool:
    # キーボードの Esc は、menu より先に見て1つ前の階層に戻る（TOP では _cancel() が閉じる）
    if event is InputEventKey and event.is_action_pressed("ui_cancel") and not event.is_echo():
        _cancel()
        return true
    if event.is_action_pressed("menu") and not event.is_echo():
        toggle()
        return true
    # コントローラのキャンセルのボタンは表記ごとに違う
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
        return false
    return true


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
    # ボタンの上でもホイールやタッチのドラッグがスクロールに届くようにする
    button.mouse_filter = Control.MOUSE_FILTER_PASS
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

    # 右の列で操作している部品の左に出す赤い縦帯（パネルより前に描くため、後から足す。位置は _update_edit_bar で決める）
    _edit_bar = ColorRect.new()
    _edit_bar.color = ACCENT_COLOR
    _edit_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _edit_bar.visible = false
    _dimmer.add_child(_edit_bar)

    # 高さが足りないときは縦にスクロールする。中身が短いときは今までどおりパネルいっぱいに広がる。
    # 左右に並べるときは左の列・右の列がそれぞれスクロールし、上下に並べるときはこの外側の枠が全体をスクロールする
    _scroll = ScrollContainer.new()
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _panel.add_child(_scroll)

    _columns = BoxContainer.new()
    _columns.add_theme_constant_override("separation", 0)
    _columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.add_child(_columns)

    _left_scroll = _make_column_scroll()
    _left_column = _build_left_column()
    _left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _left_scroll.add_child(_left_column)
    _columns.add_child(_left_scroll)

    # 縦の区切り線（上下 28px あける。上下に並べるときは _set_stacked で横線にする）
    _divider_margin = _make_margin(0, 28, 0, 28)
    _divider = _make_line()
    _divider.custom_minimum_size = Vector2(1, 0)
    _divider_margin.add_child(_divider)
    _columns.add_child(_divider_margin)

    # 右の列は見出しと説明をスクロールさせず、その下の中身だけを _right_scroll（_build_right_column の中で作る）でスクロールさせる
    _right_column = _build_right_column()
    _columns.add_child(_right_column)
    # 並びの値（左の列の最小幅など）は _set_stacked で決めるので、最初の並び（左右）でも一度当てておく
    _set_stacked(_stacked)

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


# メニューやエンディングのパネルを置く上端 [px]
# 左上のメニュー・マップのボタンの下に余白を足した位置
# 右上のリセットボタンはメニューとエンディングの間は隠すので考えない
# PC では 16 + 40 + 16 = 72 で、これまでの決め打ちと同じになる
func get_content_top() -> float:
    return MARGIN + button_size + 16.0


# 1列ぶんの縦スクロール枠（横は切る。縦のモードは _set_stacked で並びに合わせて切り替える）
func _make_column_scroll() -> ScrollContainer:
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    return scroll


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
    var top := get_content_top()
    _panel.position = Vector2((screen.x - width) * 0.5, top)
    _panel.size = Vector2(width, maxf(screen.y - top - PANEL_BOTTOM, 0.0))
    if changed:
        # 並びを変えた直後は最小サイズが更新されていないことがあるので、次のフレームでもう一度決める
        # （2回目は並びが変わらないので繰り返さない）
        _layout_panel.call_deferred()


# 左右の列を、上下に並べる（true）か左右に並べる（false）か切り替える
func _set_stacked(stacked: bool) -> void:
    _stacked = stacked
    _columns.vertical = stacked
    if stacked:
        # 各列のスクロールは切って、中身の高さをそのまま最小サイズにする（スクロールは外側の _scroll が全体で行う）
        _left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        _right_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        # 左の列の中の伸びる余白がつぶれて、「閉じる」が項目の一覧のすぐ下に来る
        _left_scroll.custom_minimum_size.x = 0.0
        _left_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        _divider.custom_minimum_size = Vector2(0, 1)
        _divider_margin.add_theme_constant_override("margin_left", 28)
        _divider_margin.add_theme_constant_override("margin_right", 28)
        _divider_margin.add_theme_constant_override("margin_top", 0)
        _divider_margin.add_theme_constant_override("margin_bottom", 0)
        _right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    else:
        # 左右に並べるときは、それぞれの列だけがスクロールする（最小の高さは 0 になり、外側の _scroll は動かない）
        _left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        _right_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        _left_scroll.custom_minimum_size.x = LEFT_COLUMN_WIDTH
        _left_scroll.size_flags_vertical = Control.SIZE_FILL
        _divider.custom_minimum_size = Vector2(1, 0)
        _divider_margin.add_theme_constant_override("margin_left", 0)
        _divider_margin.add_theme_constant_override("margin_right", 0)
        _divider_margin.add_theme_constant_override("margin_top", 28)
        _divider_margin.add_theme_constant_override("margin_bottom", 28)
        _right_column.size_flags_vertical = Control.SIZE_FILL
        _right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ---- 左の列 ----

func _build_left_column() -> Control:
    # 行の背景の絵は2つだけ作り、全部の行（と閉じる）で共有する
    _row_red_texture = _make_gradient_texture(Color("#c8102e"), Color("#4a0b12"))
    _row_gray_texture = _make_gradient_texture(Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.04))
    var margin := _make_margin(28, 24, 20, 16)
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


# 左から右へ色が変わる横長のグラデーションの絵
func _make_gradient_texture(from: Color, to: Color) -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([from, to])
    gradient.offsets = PackedFloat32Array([0.0, 1.0])
    var gradient_texture := GradientTexture2D.new()
    gradient_texture.gradient = gradient
    gradient_texture.fill_from = Vector2(0, 0)
    gradient_texture.fill_to = Vector2(1, 0)
    gradient_texture.width = 256
    gradient_texture.height = 8
    return gradient_texture


# 行の背景（左から右へ赤いグラデーションを全面に出す）。項目の行と「閉じる」で同じものを使う
func _make_row_background() -> TextureRect:
    var background := TextureRect.new()
    background.texture = _row_red_texture
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_SCALE
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    return background


# 行の左端の白い縦帯（幅 5。offset_left を決めて使う）
func _make_row_stripe() -> ColorRect:
    var stripe := ColorRect.new()
    stripe.color = TEXT_BODY
    stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    stripe.offset_right = 5
    return stripe


# 項目の行。文字は持たせず、中に背景・縦帯・アイコン・項目名・右側の部品を置く
func _build_item_row(index: int) -> Button:
    # 子の行は高さ 48・字下げ・アイコン無し・文字 18px
    var is_child := index in CHILD_ITEMS
    var indent := CHILD_INDENT if is_child else 0
    var row := _make_flat_button(48 if is_child else 58, Control.FOCUS_NONE)
    _rows[index] = row

    # 選んでいる行の背景（左から右へ赤いグラデーション）
    var background := _make_row_background()
    background.offset_left = indent
    row.add_child(background)
    _row_backgrounds[index] = background

    # 左端の白い縦帯
    var stripe := _make_row_stripe()
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

    # 右端の「>」の山形（操作の設定は下向きの「∨」）
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
    var color := _row_text_color(index)
    if index == ITEM_CONTROLLER:
        # 「∨」「∧」（幅 14・高さ 8 を 9×16 の枠の中央に置く）
        # たたんでいるときは下向き「∨」、開いているときは上向き「∧」
        var points := PackedVector2Array([Vector2(-2.5, 4), Vector2(4.5, 12), Vector2(11.5, 4)])
        if _children_expanded:
            points = PackedVector2Array([Vector2(-2.5, 12), Vector2(4.5, 4), Vector2(11.5, 12)])
        chevron.draw_polyline(points, color, 2.5, true)
    else:
        chevron.draw_polyline(PackedVector2Array([Vector2(1, 1), Vector2(8, 8), Vector2(1, 15)]), color, 2.5, true)


# 「閉じる」の行
func _build_close_row() -> Control:
    _close_button = _make_flat_button(44, Control.FOCUS_NONE)
    _close_button.pressed.connect(_on_close_pressed)
    _close_button.mouse_entered.connect(_on_close_mouse_entered)

    # 文字の後ろに描くため、背景と縦帯は余白より先に足す（カーソルが閉じるにあるときだけ出す）
    _close_background = _make_row_background()
    _close_button.add_child(_close_background)
    _close_stripe = _make_row_stripe()
    _close_button.add_child(_close_stripe)

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


# 「閉じる」の文字と Esc の箱の色。TOP か、カーソルが閉じるにあるときは白、それ以外は灰
func _update_close_color() -> void:
    var color := TEXT_BODY if _level == Level.TOP or _cursor == CURSOR_CLOSE else TEXT_DIM
    _close_label.add_theme_color_override("font_color", color)
    if _close_hint_frame != null:
        _close_hint_frame.border_color = color
    if _close_hint_text != null:
        _close_hint_text.add_theme_color_override("font_color", color)


# 入力方式の印（キーボードは Esc の箱、コントローラはキャンセルのボタン、タッチは無し）を作り直す
func _rebuild_close_hint() -> void:
    if _close_hint_mark != null:
        _close_hint_box.remove_child(_close_hint_mark)
        _close_hint_mark.queue_free()
        _close_hint_mark = null
    _close_hint_frame = null
    _close_hint_text = null
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
            _close_hint_text = _make_label("Esc", 15, TEXT_BODY)
            box.add_child(_close_hint_text)
            _close_hint_frame = frame
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
    # 作り直した Esc の箱も、今の階層に合わせた色にする
    _update_close_color()


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

    # 中身だけをスクロールさせる枠（見出しと説明はこの上に固定される。縦のモードは _set_stacked で並びに合わせて切り替える）
    _right_scroll = _make_column_scroll()
    _right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(_right_scroll)

    # 中身（項目ごとに作っておき、今の項目のものだけ出す）。MarginContainer にして、出している中身の高さを右の列に伝える（上下に並べたときにスクロールで届くように）
    var holder := MarginContainer.new()
    holder.add_theme_constant_override("margin_left", 0)
    holder.add_theme_constant_override("margin_top", 0)
    holder.add_theme_constant_override("margin_right", 0)
    holder.add_theme_constant_override("margin_bottom", 0)
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _right_scroll.add_child(holder)
    _edit_controls.resize(ITEM_NAMES.size())
    for i in _edit_controls.size():
        _edit_controls[i] = []
    var contents: Array[Control] = [_build_volume_content(), _build_pad_content(), _build_confirm_content(), _build_robot_content(), _build_controller_content(), _build_data_content(), _build_camera_content(), _build_keys_content(), _build_buttons_content()]
    for content in contents:
        content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content.size_flags_vertical = Control.SIZE_EXPAND_FILL
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


# 操作の設定。音量の中身と同じ作りで、アイコンを薄く中央に出すだけ
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


# 持っているアイテムを PowerUps.ITEMS の順に並べる（取った順ではない）
func _owned_items() -> Array:
    var owned := []
    for key in PowerUps.ITEMS:
        if PowerUps.has(key):
            owned.append(key)
    return owned


# セーブデータ。持っているアイテムを切り替えて見せる部品・リセットのボタン・注意書きを縦に並べる
# （何も持っていないときは切り替え部品の代わりに文を出す）
func _build_data_content() -> Control:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 18)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var center := VBoxContainer.new()
    center.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_theme_constant_override("separation", 10)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.custom_minimum_size.y = 170
    _data_item_icon = TextureRect.new()
    _data_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _data_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _data_item_icon.custom_minimum_size = Vector2(96, 96)
    _data_item_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _data_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(_data_item_icon)
    _data_item_name = _make_label("", 26, TEXT_BODY)
    _data_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.add_child(_data_item_name)
    _data_item_desc = _make_label("", 16, TEXT_BODY)
    _data_item_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    # 16px なら PC の幅では1行に収まる。狭い画面では矢印の間の幅で折り返す
    _data_item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    center.add_child(_data_item_desc)

    # 点の数は持っている数で変わるので、count = 0 で作って _refresh_data で合わせる。名前は中央に出すので使わない
    var parts := _build_selector(center, 0, _step_data_item, ITEM_DATA)
    parts.name_label.visible = false
    _data_selector_box = parts.box
    _data_arrow_row = parts.box.get_child(0)
    _data_dots_row = parts.box.get_child(2)
    box.add_child(_data_selector_box)

    _data_empty_label = _make_label("まだアイテムを持っていません", 20, TEXT_DIM)
    _data_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_data_empty_label)

    # リセットのボタン（枠線の色は _refresh_data で、カーソルかマウスが乗っているときに変える）
    _data_reset_button = _make_flat_button(52, Control.FOCUS_NONE)
    _data_reset_button.custom_minimum_size = Vector2(320, 52)
    _data_reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _data_reset_style = _make_style(Color(1, 1, 1, 0.08), 10)
    _data_reset_style.border_color = LINE_COLOR
    _data_reset_style.set_border_width_all(2)
    var background := Panel.new()
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.add_theme_stylebox_override("panel", _data_reset_style)
    _data_reset_button.add_child(background)
    _data_reset_label = _make_label("", 19, TEXT_BODY)
    _data_reset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _data_reset_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _data_reset_button.add_child(_data_reset_label)
    _data_reset_button.pressed.connect(_press_data_reset)
    _data_reset_button.mouse_entered.connect(_refresh_data)
    _data_reset_button.mouse_exited.connect(_refresh_data)
    box.add_child(_data_reset_button)
    _add_edit_control(ITEM_DATA, _data_reset_button, Callable(), _press_data_reset)

    _data_note_label = _make_label("リセットすると、スタート地点からやり直します", 15, TEXT_DIM)
    _data_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_data_note_label)
    return box


# リセットのボタン。1回目は確認に切り替えるだけで、2回目で取得状態を消してシーンを読み込み直す
func _press_data_reset() -> void:
    if not _data_reset_armed:
        _data_reset_armed = true
        _refresh_data()
        return
    _data_reset_armed = false
    PowerUps.reset_progress()
    close()
    get_tree().reload_current_scene()


func _refresh_data() -> void:
    if _data_reset_button == null:
        return
    # 持っているアイテムの数に合わせて、切り替え部品と点の数を整える
    var owned := _owned_items()
    var count := owned.size()
    _data_item_index = clampi(_data_item_index, 0, maxi(count - 1, 0))
    _data_selector_box.visible = count > 0
    _data_empty_label.visible = count == 0
    if count > 0:
        var item: Dictionary = PowerUps.ITEMS[owned[_data_item_index]]
        _data_item_icon.texture = item["icon"]
        _data_item_name.text = item["name"]
        _data_item_desc.text = item["description"]
    var several := count >= 2
    _data_arrow_row.get_child(0).visible = several
    _data_arrow_row.get_child(_data_arrow_row.get_child_count() - 1).visible = several
    _data_dots_row.visible = several
    while _data_dots.size() < count:
        var dot := ColorRect.new()
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        dot.custom_minimum_size = Vector2(26, 5)
        _data_dots_row.add_child(dot)
        _data_dots.append(dot)
    while _data_dots.size() > count:
        _data_dots.pop_back().queue_free()
    _set_dots(_data_dots, _data_item_index)
    _data_reset_label.text = "もう一度押すとリセットします" if _data_reset_armed else "アイテムの取得状態をリセット"
    # 確認中は背景を赤みにする（文字の色は _apply_right_text_color が決める）
    _data_reset_style.bg_color = Color(ACCENT_COLOR, 0.25) if _data_reset_armed else Color(1, 1, 1, 0.08)
    var active := _has_edit_cursor(_data_reset_button) or _data_reset_button.is_hovered()
    _data_reset_style.border_color = ACCENT_COLOR if active else LINE_COLOR


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


# カメラの操作。左右・上下それぞれに「名前 < 値 >」の行を並べる
func _build_camera_content() -> Control:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 24)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _camera_x_value = _add_camera_row(box, "左右", _step_invert_x)
    _camera_y_value = _add_camera_row(box, "上下", _step_invert_y)
    return box


# カメラの操作の1行（名前・「<」・値・「>」を左から並べる）。値の Label を返す
func _add_camera_row(box: VBoxContainer, title: String, step: Callable) -> Label:
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var name_label := _make_label(title, 20, TEXT_BODY)
    name_label.custom_minimum_size = Vector2(120, 0)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    row.add_child(name_label)
    row.add_child(_make_arrow_button(-1, step, row))
    var value_label := _make_label("", 22, TEXT_BODY)
    value_label.custom_minimum_size = Vector2(140, 0)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    row.add_child(value_label)
    row.add_child(_make_arrow_button(1, step, row))
    box.add_child(row)
    # 決定でも切り替えられるよう、accept にも同じ切り替えを渡す
    _add_edit_control(ITEM_CAMERA, row, step, step.bind(1))
    return value_label


# キーの割り当て。操作ごとに「名前・今のキーの絵・状態」の行を並べ、最後に初期設定に戻すボタンを置く。
# 行にカーソルを合わせて使いたいキーを長押しすると、その行の操作に割り当てる（決定を押しても何も起きない）
func _build_keys_content() -> Control:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_BEGIN
    box.add_theme_constant_override("separation", 6)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for action in KeyBindings.ACTIONS:
        var parts := _make_binding_row(KeyBindings.ACTION_NAMES[action], _on_key_row_pressed.bind(action))
        box.add_child(parts.row)
        _key_rows.append(parts.row)
        _key_icon_slots.append(parts.slot)
        _key_status_labels.append(parts.status)
        _key_hold_bars.append(parts.bar)
        _key_name_boxes.append(parts.name_box)
        _add_edit_control(ITEM_KEYS, parts.row, Callable(), Callable())

    var reset := _make_reset_button(_on_keys_reset_pressed, _refresh_keys_reset_style)
    _keys_reset_button = reset.button
    _keys_reset_style = reset.style
    box.add_child(reset.margin)
    _add_edit_control(ITEM_KEYS, _keys_reset_button, Callable(), _reset_keys)
    return box


# ボタンの割り当て。キーの割り当てと同じ作りで、操作ごとに「名前・今のボタンの絵・状態」の行を並べ、最後に初期設定に戻すボタンを置く。
# 行にカーソルを合わせて使いたいボタンを長押しすると、その行の操作に割り当てる（決定を押しても何も起きない）
func _build_buttons_content() -> Control:
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_BEGIN
    box.add_theme_constant_override("separation", 6)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for action in KeyBindings.PAD_ACTIONS:
        var parts := _make_binding_row(KeyBindings.ACTION_NAMES[action], _on_button_row_pressed.bind(action))
        box.add_child(parts.row)
        _button_rows.append(parts.row)
        _button_icon_slots.append(parts.slot)
        _button_status_labels.append(parts.status)
        _button_hold_bars.append(parts.bar)
        _button_name_boxes.append(parts.name_box)
        _add_edit_control(ITEM_PAD_BUTTONS, parts.row, Callable(), Callable())

    var reset := _make_reset_button(_on_buttons_reset_pressed, _refresh_buttons_reset_style)
    _buttons_reset_button = reset.button
    _buttons_reset_style = reset.style
    box.add_child(reset.margin)
    _add_edit_control(ITEM_PAD_BUTTONS, _buttons_reset_button, Callable(), _reset_buttons)
    return box


# 初期設定に戻すボタン（見た目はセーブデータのリセットのボタンと同じ。1回で戻す）。
# {button, style（枠線のスタイル）, margin（行との間をあけて包んだもの。これを並べに足す）} を返す。
# refresh_style はカーソル・マウスで枠線の色を変える処理
func _make_reset_button(on_pressed: Callable, refresh_style: Callable) -> Dictionary:
    var button := _make_flat_button(52, Control.FOCUS_NONE)
    button.custom_minimum_size = Vector2(320, 52)
    button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var style := _make_style(Color(1, 1, 1, 0.08), 10)
    style.border_color = LINE_COLOR
    style.set_border_width_all(2)
    var background := Panel.new()
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.add_theme_stylebox_override("panel", style)
    button.add_child(background)
    var reset_label := _make_label("初期設定に戻す", 19, TEXT_BODY)
    reset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    reset_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    button.add_child(reset_label)
    button.pressed.connect(on_pressed)
    button.mouse_entered.connect(refresh_style)
    button.mouse_exited.connect(refresh_style)
    # 行との間にあける（縦の並びの間 6 に足して 18）
    var margin := _make_margin(0, 12, 0, 0)
    margin.add_child(button)
    return {"button": button, "style": style, "margin": margin}


# 割り当ての1行（操作の名前、そのあとに、今のキーかボタンの絵を入れる枠か、状態の部分のどちらかを並べる）。行全体がボタン。
# {row, slot, status, bar, name_box} を返す。絵は _refresh_keys・_refresh_buttons で入れる。長押し中・使えないキーを押した直後は絵の枠を隠し、同じ場所に状態の部分を出す。
# status は状態の文、bar はその下の長押しの進み具合のバー（幅は状態の文の幅 × 進み具合）。status の親が状態の部分（VBoxContainer）
func _make_binding_row(title: String, on_pressed: Callable) -> Dictionary:
    var row := _make_flat_button(44, Control.FOCUS_NONE)
    row.pressed.connect(on_pressed)
    var margin := _make_margin(8, 0, 8, 0)
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.add_child(margin)
    var hbox := HBoxContainer.new()
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
    hbox.add_theme_constant_override("separation", 16)
    margin.add_child(hbox)

    # 名前の部分。名前の右に、初期設定と違うときだけ「（デフォルト 〇）」を足す（足す中身は _refresh_default_hint で作る）
    var name_box := HBoxContainer.new()
    name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_box.alignment = BoxContainer.ALIGNMENT_BEGIN
    name_box.custom_minimum_size = Vector2(280, 0)
    name_box.add_theme_constant_override("separation", 4)
    hbox.add_child(name_box)
    var name_label := _make_label(title, 18, TEXT_BODY)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    name_box.add_child(name_label)

    var slot := Control.new()
    slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hbox.add_child(slot)

    # 状態の部分。今の割り当ての絵と同じ場所に、長押し中・使えないキーを押した直後だけ絵の代わりに出す（上に状態の文、下に長押しのバー）
    var status_box := VBoxContainer.new()
    status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status_box.alignment = BoxContainer.ALIGNMENT_CENTER
    status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_box.add_theme_constant_override("separation", 2)
    status_box.visible = false
    hbox.add_child(status_box)

    # 文が長くても行からはみ出さないよう、1行で切る
    var status_label := _make_label("", 14, TEXT_DIM)
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    status_label.clip_text = true
    status_box.add_child(status_label)

    var bar := ColorRect.new()
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.color = ACCENT_COLOR
    bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    bar.custom_minimum_size = Vector2(0, 4)
    status_box.add_child(bar)
    return {"row": row, "slot": slot, "status": status_label, "bar": bar, "name_box": name_box}


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
    # カーソルのある行が見える位置までスクロールする（レイアウトが確定してから効かせる）
    if _scroll != null and is_open:
        var target: Control = _close_button if index == CURSOR_CLOSE else _rows[index]
        # 左右並びなら左の列が、上下並びなら全体がスクロールする（動かない方は何もしない）
        _left_scroll.ensure_control_visible.call_deferred(target)
        _scroll.ensure_control_visible.call_deferred(target)


# カーソルと階層に合わせて、左の列・右の矢印・音量バーの見た目を更新する
func _update_cursor_visuals() -> void:
    # キーの割り当ての EDIT から出たり、カーソルが別の行に動いたりしたら、長押しや「使えません」の表示は取り消す
    if _key_status_index != -1 and (_level != Level.EDIT or _cursor != ITEM_KEYS or _edit_index != _key_status_index):
        _stop_key_hold()
    # ボタンの割り当ても同じ
    if _button_status_index != -1 and (_level != Level.EDIT or _cursor != ITEM_PAD_BUTTONS or _edit_index != _button_status_index):
        _stop_button_hold()
    # 右の列を操作している間は、選んでいる行の赤を灰色のグラデーションに替える
    var background_texture := _row_gray_texture if _level == Level.EDIT else _row_red_texture
    for i in _rows.size():
        _row_backgrounds[i].visible = i == _cursor
        _row_backgrounds[i].texture = background_texture
        _row_stripes[i].visible = i == _cursor
    # 項目名の色は、今選べる行は白、選べない行は灰
    for i in ROW_ORDER:
        _row_name_labels[i].add_theme_color_override("font_color", _row_text_color(i))
    # 中分類の行は、操作の設定に入っているあいだだけ出す
    for i in CHILD_ITEMS:
        _rows[i].visible = _children_expanded
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
    _close_background.visible = _cursor == CURSOR_CLOSE
    _close_stripe.visible = _cursor == CURSOR_CLOSE
    _update_close_color()
    _apply_right_text_color()
    _refresh_data()
    _refresh_keys_reset_style()
    _refresh_buttons_reset_style()
    # EDIT で操作している部品が見える位置までスクロールする（右の列と全体の両方。動かない方は何もしない）
    if is_open and _level == Level.EDIT:
        var control := _current_edit_control()
        if not control.is_empty():
            var node: Control = control["node"]
            _right_scroll.ensure_control_visible.call_deferred(node)
            _scroll.ensure_control_visible.call_deferred(node)


# 左の列の行の文字（項目名と山形）の色。今選べる階層の行は白、そうでなければ灰。
# TOP・SUB でカーソルのある行は背景が赤なので白、EDIT ではカーソルのある行も灰
func _row_text_color(index: int) -> Color:
    if _level != Level.EDIT and index == _cursor:
        return TEXT_BODY
    var selectable := Level.SUB if index in CHILD_ITEMS else Level.TOP
    return TEXT_BODY if _level == selectable else TEXT_DIM


# 右の列の文字の色。EDIT のあいだは白、それ以外は灰。説明・セーブデータの注意書き・「持っていません」はいつも灰
func _apply_right_text_color() -> void:
    if _right_column == null:
        return
    var color := TEXT_BODY if _level == Level.EDIT else TEXT_DIM
    _set_label_colors(_right_column, color)


func _set_label_colors(node: Node, color: Color) -> void:
    for child in node.get_children():
        if child is Label:
            var always_dim: bool = child == _header_desc or child == _data_note_label or child == _data_empty_label
            child.add_theme_color_override("font_color", TEXT_DIM if always_dim else color)
        _set_label_colors(child, color)


# EDIT で操作している部品の左に赤い縦帯を出す。スクロールで動くので毎フレーム合わせる。
# 音量の行は中身が中央に寄っているので、行全体ではなく表示されている中身の左端に付ける
func _update_edit_bar() -> void:
    _edit_bar.visible = false
    if _level != Level.EDIT:
        return
    var control := _current_edit_control()
    if control.is_empty():
        return
    var node: Control = control["node"]
    if not node.is_visible_in_tree():
        return
    var rect := node.get_global_rect()
    if node is BoxContainer:
        var found := false
        for child in node.get_children():
            if child is Control and child.is_visible_in_tree():
                var child_rect: Rect2 = child.get_global_rect()
                rect = child_rect if not found else rect.merge(child_rect)
                found = true
    # 部品の左 12px の余白の中に、幅 4 の縦帯を置く。上下には 6px ずつはみ出させる
    var top := rect.position.y - 6.0
    var bottom := rect.end.y + 6.0
    # スクロールの見える範囲からはみ出すところは切り詰める（完全に外れたら隠す）
    var view := _scroll.get_global_rect().intersection(_right_scroll.get_global_rect())
    top = maxf(top, view.position.y)
    bottom = minf(bottom, view.end.y)
    if bottom <= top:
        return
    _edit_bar.global_position = Vector2(rect.position.x - 12.0 - 4.0, top)
    _edit_bar.size = Vector2(4.0, bottom - top)
    _edit_bar.visible = true


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
    # セーブデータ以外の項目に移ったら、リセットの確認は取り消す
    if index != ITEM_DATA:
        _data_reset_armed = false
    if index == ITEM_ROBOT:
        _refresh_robot()
    elif index == ITEM_DATA:
        _refresh_data()
    elif index == ITEM_KEYS:
        _refresh_keys()
    elif index == ITEM_PAD_BUTTONS:
        _refresh_buttons()


# 項目の行が属する階層（子の項目なら SUB、それ以外は TOP）
func _level_of_item(index: int) -> Level:
    return Level.SUB if index in CHILD_ITEMS else Level.TOP


# マウスが乗った行にカーソルを移す（EDIT 中でも移る）
func _on_row_mouse_entered(index: int) -> void:
    _set_cursor(_level_of_item(index), index)


# クリック・タップ。その行にカーソルを移して、決定と同じ動きをする
func _on_row_pressed(index: int) -> void:
    # 親の行（操作の設定以外）を押したら中分類はたたむ。操作の設定は _activate で開く
    if index != ITEM_CONTROLLER and index not in CHILD_ITEMS:
        _children_expanded = false
    _set_cursor(_level_of_item(index), index)
    _activate()


func _on_close_mouse_entered() -> void:
    _set_cursor(Level.TOP, CURSOR_CLOSE)


func _on_close_pressed() -> void:
    _children_expanded = false
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
        # TOP で上下に動かしたら中分類はたたむ（マウスが乗っただけでは変えない。行がずれてカーソルが飛ぶため）
        if _level == Level.TOP:
            _children_expanded = false
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
                _children_expanded = true
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
            _children_expanded = false
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
    _data_reset_armed = false
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
    # 操作の設定の中の「決定・キャンセル」の行も追従させる
    _refresh_pad()


# 選択肢は2つなので、どちらの向きでも交互に切り替わる
func _step_invert_x(_direction: int) -> void:
    invert_camera_x = not invert_camera_x
    _save_settings()
    _refresh_camera()


func _step_invert_y(_direction: int) -> void:
    invert_camera_y = not invert_camera_y
    _save_settings()
    _refresh_camera()


func _step_robot(direction: int) -> void:
    var count := ROBOT_MODELS.size()
    var next := (ROBOT_MODELS.find(robot_model) + direction + count) % count
    _on_robot_model_pressed(ROBOT_MODELS[next])
    _refresh_robot()


func _step_data_item(direction: int) -> void:
    var count := _owned_items().size()
    if count < 2:
        return
    _data_item_index = (_data_item_index + direction + count) % count
    _refresh_data()


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


func _refresh_camera() -> void:
    _camera_x_value.text = "反転" if invert_camera_x else "通常"
    _camera_y_value.text = "反転" if invert_camera_y else "通常"


# キーの割り当ての行の表示を作り直す（今のキーの絵を入れ直し、状態を出す行は絵を隠して状態の文を出す）
func _refresh_keys() -> void:
    for i in KeyBindings.ACTIONS.size():
        var action: String = KeyBindings.ACTIONS[i]
        var showing_status := i == _key_status_index
        ControlsHelp.set_icon_slot(_key_icon_slots[i], ControlsHelp.make_key_icon(KeyBindings.get_key(action), 56.0))
        _key_icon_slots[i].visible = not showing_status
        _key_status_labels[i].get_parent().visible = showing_status
        _key_status_labels[i].text = _key_status_message if showing_status else ""
        _set_hold_bar(_key_hold_bars[i], _key_status_labels[i], 0.0)
        _refresh_default_hint(_key_name_boxes[i], KeyBindings.get_key(action) != KeyBindings.get_default_key(action), ControlsHelp.make_key_icon.bind(KeyBindings.get_default_key(action), 44.0))


# 初期設定に戻すボタンの枠線の色（カーソルかマウスが乗っているときだけ赤）
func _refresh_keys_reset_style() -> void:
    if _keys_reset_button == null:
        return
    var active := _has_edit_cursor(_keys_reset_button) or _keys_reset_button.is_hovered()
    _keys_reset_style.border_color = ACCENT_COLOR if active else LINE_COLOR


# 行をクリックしたとき。カーソルをキーの割り当ての EDIT のその行に移すだけ（割り当ては長押しで決める）
func _on_key_row_pressed(action: String) -> void:
    if _cursor != ITEM_KEYS or _level == Level.TOP:
        _children_expanded = true
        _set_cursor(Level.SUB, ITEM_KEYS)
    if _level != Level.EDIT:
        _enter_edit()
    _edit_index = KeyBindings.ACTIONS.find(action)
    _update_cursor_visuals()


# 長押し（かその表示）をやめて、行の表示を元に戻す（何も出していなければ何もしない）
func _stop_key_hold() -> void:
    if _key_status_index == -1 and _hold_key == KEY_NONE:
        return
    _key_status_index = -1
    _key_status_message = ""
    _key_reject_until_msec = 0
    _hold_key = KEY_NONE
    _hold_key_event = null
    _refresh_keys()


# EDIT でカーソルが割り当ての行にあるときの、入力の長押しの処理。キーボードのキーだけが対象（ほかの機器の入力はメニューの操作として通す）。
# 使えるキーが押されたらメニューの操作はせず、長押しを始める（長押し中に別の使えるキーが押されたら、そちらで始め直す）。
# 長押し中のキーが短く離されたら、押したときのイベントをメニューの操作として処理する。
# 使えないキーは、メニューの操作に当たるならそのまま通し（Esc で戻るなど）、当たらないなら「使えません」を出す。
# 扱った入力は true を返し、メニューの操作には流さない
func _input_bind_hold(event: InputEvent) -> bool:
    if _level != Level.EDIT:
        return false
    if _cursor == ITEM_KEYS and event is InputEventKey and _edit_index < KeyBindings.ACTIONS.size():
        return _input_key_hold(event)
    if _cursor == ITEM_PAD_BUTTONS and event is InputEventJoypadButton and _edit_index < KeyBindings.PAD_ACTIONS.size():
        return _input_button_hold(event)
    return false


# 押された入力がメニューの操作（上下左右・決定・キャンセル・menu）に当たるか
func _is_menu_input(event: InputEvent) -> bool:
    for menu_action in MENU_ACTIONS:
        if event.is_action_pressed(menu_action):
            return true
    return false


func _input_key_hold(event: InputEventKey) -> bool:
    var physical: Key = event.physical_keycode
    if not event.pressed:
        if _hold_key == KEY_NONE or physical != _hold_key:
            return false
        if float(Time.get_ticks_msec() - _hold_key_start_msec) / 1000.0 >= BIND_HOLD_TIME:
            _finish_key_hold()
        else:
            # 届く前に離したので、押したときのイベントをふつうのメニューの操作として処理する
            var pressed_event := _hold_key_event
            _stop_key_hold()
            _handle_menu_input(pressed_event)
        return true
    # 押しっぱなしで行が流れないよう、echo は捨てる
    if event.is_echo():
        return true
    if not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed) and KeyBindings.is_allowed(physical):
        _hold_key = physical
        _hold_key_event = event
        _hold_key_start_msec = Time.get_ticks_msec()
        _key_reject_until_msec = 0
        _key_status_index = _edit_index
        _key_status_message = HOLD_MESSAGE
        _refresh_keys()
        return true
    if _is_menu_input(event):
        return false
    # 長押し中に使えないキーが押されても、長押しは続ける
    if _hold_key == KEY_NONE:
        _key_status_index = _edit_index
        _key_status_message = KEY_REJECT_MESSAGE
        _key_reject_until_msec = Time.get_ticks_msec() + int(REJECT_SHOW_TIME * 1000.0)
        _refresh_keys()
    return true


# 長押しが BIND_HOLD_TIME に達したので、覚えていた行の操作にキーを割り当てる
func _finish_key_hold() -> void:
    var action: String = KeyBindings.ACTIONS[_key_status_index]
    var physical := _hold_key
    _key_status_index = -1
    _key_status_message = ""
    _hold_key = KEY_NONE
    _hold_key_event = null
    KeyBindings.set_key(action, physical)
    _save_settings()
    key_bindings_changed.emit()


# キーの長押しの進み具合のバーを更新し、BIND_HOLD_TIME に達したらキーを割り当てる。使えないキーの文は時間が来たら消す
func _update_key_hold() -> void:
    if _hold_key != KEY_NONE:
        var progress := float(Time.get_ticks_msec() - _hold_key_start_msec) / 1000.0 / BIND_HOLD_TIME
        if progress < 1.0:
            _set_hold_bar(_key_hold_bars[_key_status_index], _key_status_labels[_key_status_index], progress)
        else:
            _finish_key_hold()
    elif _key_reject_until_msec > 0 and Time.get_ticks_msec() >= _key_reject_until_msec:
        _stop_key_hold()


# 行の名前の部分の「（デフォルト 〇）」を作り直す（名前のラベルだけ残して消す）。
# differs（今の割り当てが初期設定と違うか）のときだけ、「（デフォルト 」・初期設定の絵（make_icon で作る）・「）」を足す
func _refresh_default_hint(name_box: HBoxContainer, differs: bool, make_icon: Callable) -> void:
    while name_box.get_child_count() > 1:
        var child := name_box.get_child(1)
        name_box.remove_child(child)
        child.queue_free()
    if not differs:
        return
    name_box.add_child(_make_label("（デフォルト ", 18, TEXT_BODY))
    var icon: Control = make_icon.call()
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_box.add_child(icon)
    name_box.add_child(_make_label("）", 18, TEXT_BODY))
    # 作り直したラベルの色を、右の列の文字の色（EDIT のあいだは白、それ以外は灰）に合わせる
    _apply_right_text_color()


# 長押しの進み具合のバーの幅を合わせる（progress は 0〜1。幅は状態の文の幅 × 進み具合）
func _set_hold_bar(bar: ColorRect, status_label: Label, progress: float) -> void:
    bar.custom_minimum_size.x = status_label.size.x * clampf(progress, 0.0, 1.0)
    bar.size.x = bar.custom_minimum_size.x


func _on_keys_reset_pressed() -> void:
    # クリックのときも、カーソルをこのボタンに移してから戻す
    if _cursor != ITEM_KEYS or _level == Level.TOP:
        _children_expanded = true
        _set_cursor(Level.SUB, ITEM_KEYS)
    if _level != Level.EDIT:
        _enter_edit()
    _edit_index = _edit_controls[ITEM_KEYS].size() - 1
    _update_cursor_visuals()
    _reset_keys()


# すべてのキーを初期の割り当てに戻す（1回で戻す）
func _reset_keys() -> void:
    _stop_key_hold()
    KeyBindings.reset_keys()
    _save_settings()
    key_bindings_changed.emit()


# ボタンの割り当ての行の表示を作り直す（今のボタンの絵を入れ直し、状態を出す行は絵を隠して状態の文を出す）
func _refresh_buttons() -> void:
    for i in KeyBindings.PAD_ACTIONS.size():
        var action: String = KeyBindings.PAD_ACTIONS[i]
        var showing_status := i == _button_status_index
        ControlsHelp.set_icon_slot(_button_icon_slots[i], ControlsHelp.make_button_icon(KeyBindings.get_button(action), 56.0))
        _button_icon_slots[i].visible = not showing_status
        _button_status_labels[i].get_parent().visible = showing_status
        _button_status_labels[i].text = _button_status_message if showing_status else ""
        _set_hold_bar(_button_hold_bars[i], _button_status_labels[i], 0.0)
        _refresh_default_hint(_button_name_boxes[i], KeyBindings.get_button(action) != KeyBindings.get_default_button(action), ControlsHelp.make_button_icon.bind(KeyBindings.get_default_button(action), 44.0))


# 初期設定に戻すボタンの枠線の色（カーソルかマウスが乗っているときだけ赤）
func _refresh_buttons_reset_style() -> void:
    if _buttons_reset_button == null:
        return
    var active := _has_edit_cursor(_buttons_reset_button) or _buttons_reset_button.is_hovered()
    _buttons_reset_style.border_color = ACCENT_COLOR if active else LINE_COLOR


# 行をクリックしたとき。カーソルをボタンの割り当ての EDIT のその行に移すだけ（割り当ては長押しで決める）
func _on_button_row_pressed(action: String) -> void:
    if _cursor != ITEM_PAD_BUTTONS or _level == Level.TOP:
        _children_expanded = true
        _set_cursor(Level.SUB, ITEM_PAD_BUTTONS)
    if _level != Level.EDIT:
        _enter_edit()
    _edit_index = KeyBindings.PAD_ACTIONS.find(action)
    _update_cursor_visuals()


# 長押し（かその表示）をやめて、行の表示を元に戻す（何も出していなければ何もしない）
func _stop_button_hold() -> void:
    if _button_status_index == -1 and _hold_button == JOY_BUTTON_INVALID:
        return
    _button_status_index = -1
    _button_status_message = ""
    _button_reject_until_msec = 0
    _hold_button = JOY_BUTTON_INVALID
    _hold_button_event = null
    _refresh_buttons()


# ボタンの長押しの処理（_input_bind_hold から呼ぶ。考え方はキーの _input_key_hold と同じで、対象はゲームパッドのボタンだけ）
func _input_button_hold(event: InputEventJoypadButton) -> bool:
    var button: JoyButton = event.button_index
    if not event.pressed:
        if _hold_button == JOY_BUTTON_INVALID or button != _hold_button:
            return false
        if float(Time.get_ticks_msec() - _hold_button_start_msec) / 1000.0 >= BIND_HOLD_TIME:
            _finish_button_hold()
        else:
            # 届く前に離したので、押したときのイベントをふつうのメニューの操作として処理する
            var pressed_event := _hold_button_event
            _stop_button_hold()
            _handle_menu_input(pressed_event)
        return true
    # ゲームパッドのボタンのイベントには echo のプロパティが無いので is_echo() で見る
    if event.is_echo():
        return true
    if KeyBindings.is_button_allowed(button):
        _hold_button = button
        _hold_button_event = event
        _hold_button_start_msec = Time.get_ticks_msec()
        _button_reject_until_msec = 0
        _button_status_index = _edit_index
        _button_status_message = HOLD_MESSAGE
        _refresh_buttons()
        return true
    if _is_menu_input(event):
        return false
    # 長押し中に使えないボタンが押されても、長押しは続ける
    if _hold_button == JOY_BUTTON_INVALID:
        _button_status_index = _edit_index
        _button_status_message = BUTTON_REJECT_MESSAGE
        _button_reject_until_msec = Time.get_ticks_msec() + int(REJECT_SHOW_TIME * 1000.0)
        _refresh_buttons()
    return true


# 長押しが BIND_HOLD_TIME に達したので、覚えていた行の操作にボタンを割り当てる
func _finish_button_hold() -> void:
    var action: String = KeyBindings.PAD_ACTIONS[_button_status_index]
    var button := _hold_button
    _button_status_index = -1
    _button_status_message = ""
    _hold_button = JOY_BUTTON_INVALID
    _hold_button_event = null
    KeyBindings.set_button(action, button)
    _save_settings()
    pad_bindings_changed.emit()


# ボタンの長押しの進み具合のバーを更新し、BIND_HOLD_TIME に達したらボタンを割り当てる。使えないボタンの文は時間が来たら消す
func _update_button_hold() -> void:
    if _hold_button != JOY_BUTTON_INVALID:
        var progress := float(Time.get_ticks_msec() - _hold_button_start_msec) / 1000.0 / BIND_HOLD_TIME
        if progress < 1.0:
            _set_hold_bar(_button_hold_bars[_button_status_index], _button_status_labels[_button_status_index], progress)
        else:
            _finish_button_hold()
    elif _button_reject_until_msec > 0 and Time.get_ticks_msec() >= _button_reject_until_msec:
        _stop_button_hold()


func _on_buttons_reset_pressed() -> void:
    # クリックのときも、カーソルをこのボタンに移してから戻す
    if _cursor != ITEM_PAD_BUTTONS or _level == Level.TOP:
        _children_expanded = true
        _set_cursor(Level.SUB, ITEM_PAD_BUTTONS)
    if _level != Level.EDIT:
        _enter_edit()
    _edit_index = _edit_controls[ITEM_PAD_BUTTONS].size() - 1
    _update_cursor_visuals()
    _reset_buttons()


# すべてのボタンを初期の割り当てに戻す（1回で戻す）
func _reset_buttons() -> void:
    _stop_button_hold()
    KeyBindings.reset_buttons()
    _save_settings()
    pad_bindings_changed.emit()


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
    elif layout == "playstation":
        # 古い設定からの引き継ぎ。PlayStation は世代を別に保存していたので、その世代の機種にする
        var generation := str(config.get_value("controls", "ps_generation", "ps5"))
        match generation:
            "ps3":
                pad_layout = "ds3"
            "ps4":
                pad_layout = "ds4"
            _:
                pad_layout = "dualsense"
    swap_confirm = bool(config.get_value("controls", "swap_confirm", false))
    invert_camera_x = bool(config.get_value("camera", "invert_x", false))
    invert_camera_y = bool(config.get_value("camera", "invert_y", false))
    var model := str(config.get_value("robot", "model", "neo"))
    if model in ROBOT_MODELS:
        robot_model = model
    KeyBindings.load_from(config)


func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "bgm_volume", _bgm_volume)
    config.set_value("audio", "se_volume", _se_volume)
    config.set_value("controls", "pad_layout", pad_layout)
    config.set_value("controls", "swap_confirm", swap_confirm)
    config.set_value("camera", "invert_x", invert_camera_x)
    config.set_value("camera", "invert_y", invert_camera_y)
    config.set_value("robot", "model", robot_model)
    KeyBindings.save_to(config)
    config.save(SETTINGS_PATH)

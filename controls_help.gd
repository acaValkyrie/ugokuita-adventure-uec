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
const ICON_KEY_E := preload("res://assets/ui/controls/key_e.png")
const ICON_BUTTON_BACK := preload("res://assets/ui/controls/button_back.png")
const ICON_KEY_SPACE := preload("res://assets/ui/controls/key_space.png")
const ICON_BUTTON_A := preload("res://assets/ui/controls/button_a.png")
const ICON_KEY_SHIFT := preload("res://assets/ui/controls/key_shift.png")
const ICON_BUTTON_X := preload("res://assets/ui/controls/button_x.png")
const ICON_BUTTON_B := preload("res://assets/ui/controls/button_b.png")
const ICON_BUTTON_Y := preload("res://assets/ui/controls/button_y.png")
const ICON_TRIGGER_ZR := preload("res://assets/ui/controls/trigger_zr.png")
const ICON_TRIGGER_ZL := preload("res://assets/ui/controls/trigger_zl.png")
const ICON_BUTTON_MINUS := preload("res://assets/ui/controls/button_minus.png")
const ICON_BUTTON_CROSS := preload("res://assets/ui/controls/button_cross.png")
const ICON_BUTTON_CIRCLE := preload("res://assets/ui/controls/button_circle.png")
const ICON_BUTTON_SQUARE := preload("res://assets/ui/controls/button_square.png")
const ICON_TRIGGER_R2 := preload("res://assets/ui/controls/trigger_r2.png")
const ICON_TRIGGER_L2 := preload("res://assets/ui/controls/trigger_l2.png")
const ICON_BUTTON_CREATE := preload("res://assets/ui/controls/button_create.png")
const ICON_KEY_M := preload("res://assets/ui/controls/key_m.png")
const ICON_BUTTON_TRIANGLE := preload("res://assets/ui/controls/button_triangle.png")
const ICON_BUTTON_SELECT := preload("res://assets/ui/controls/button_select.png")
const ICON_BUTTON_SHARE := preload("res://assets/ui/controls/button_share.png")
const ICON_BUTTON_START := preload("res://assets/ui/controls/button_start.png")
const ICON_BUTTON_OPTIONS := preload("res://assets/ui/controls/button_options.png")
const ICON_BUTTON_OPTIONS_PS4 := preload("res://assets/ui/controls/button_options_ps4.png")
const ICON_KEY_SLASH := preload("res://assets/ui/controls/key_slash.png")
const ICON_SHOULDER_RB := preload("res://assets/ui/controls/shoulder_rb.png")
const ICON_SHOULDER_R := preload("res://assets/ui/controls/shoulder_r.png")
const ICON_SHOULDER_R1 := preload("res://assets/ui/controls/shoulder_r1.png")

# モードごとの表示項目 [アイコン, ラベル, アイコンの拡大率（省略時1.0）]
const ITEMS := {
    Mode.KEYBOARD: [
        [ICON_KEYS_WASD, "Drive"],
        [ICON_KEYS_ARROWS, "Camera"],
        [ICON_KEY_SPACE, "Jump", 0.4375],  # 絵の上下の余白を切ってあるので、キーの高さが R・M のキー（倍率 0.6）とそろう倍率
        [ICON_KEY_SLASH, "Drift", 0.6],  # 1文字のキーの絵なので R・M と同じ倍率。右手で押せるよう「/」（JIS の「・」）にした（Ctrl だと Web 版で Ctrl+W がタブを閉じる）
        [ICON_KEY_R, "Recover", 0.6],
        [ICON_KEY_M, "Map", 0.6],
    ],
    Mode.TOUCH: [
        [ICON_SWIPE_ONE, "Drive"],
        [ICON_SWIPE_TWO, "Camera"],
    ],
}

# 絵の中で、ほかの項目と縦の位置をそろえる基準のキーの中心（上端から、絵の高さに対する割合）。ここに無い絵は 0.5（絵の中央）
const ICON_ALIGN := {
    ICON_KEYS_WASD: 0.6875,
    ICON_KEYS_ARROWS: 0.6875,
}

# コントローラのボタン表記ごとのアイコン。
# Godot のボタン番号は位置で決まるため（下のボタン＝ジャンプ、左のボタン＝ブースト、
# 左側の小さいボタン＝リセット、上のボタン＝マップ）、表記が変わっても操作は同じでアイコンだけが変わる。
# ドリフトは右のショルダーボタン。
# ただし "interact"（看板を開く）と "cancel" は例外で、表記ごとの標準の決定・キャンセルのボタン
# （game_menu.gd の _apply_pad_buttons。Nintendo は A・B、PlayStation は ×・○、Xbox は A・B）なので、
# 割り当ても表記で変わる。決定とキャンセルを入れ替える設定は get_confirm_icon_for / get_cancel_icon_for で反映する。
const PAD_ICONS := {
    "nintendo": {
        "rt": ICON_TRIGGER_ZR, "lt": ICON_TRIGGER_ZL,
        "jump": ICON_BUTTON_B, "boost": ICON_BUTTON_Y, "reset": ICON_BUTTON_MINUS,
        "interact": ICON_BUTTON_A, "map": ICON_BUTTON_X, "cancel": ICON_BUTTON_B,
        "drift": ICON_SHOULDER_R,
    },
    "playstation": {
        "rt": ICON_TRIGGER_R2, "lt": ICON_TRIGGER_L2,
        "jump": ICON_BUTTON_CROSS, "boost": ICON_BUTTON_SQUARE, "reset": ICON_BUTTON_CREATE,
        "interact": ICON_BUTTON_CROSS, "map": ICON_BUTTON_TRIANGLE, "cancel": ICON_BUTTON_CIRCLE,
        "drift": ICON_SHOULDER_R1,
    },
    "xbox": {
        "rt": ICON_TRIGGER_RT, "lt": ICON_TRIGGER_LT,
        "jump": ICON_BUTTON_A, "boost": ICON_BUTTON_X, "reset": ICON_BUTTON_BACK,
        "interact": ICON_BUTTON_A, "map": ICON_BUTTON_Y, "cancel": ICON_BUTTON_B,
        "drift": ICON_SHOULDER_RB,
    },
}

# PlayStation の世代（GameMenu.ps_generation）ごとの、左側の小さいボタン（SELECT・SHARE・CREATE）と右側の小さいボタン（START・OPTIONS）のアイコン。
# リセットは左側のボタンに割り当てている
const PS_BACK_ICONS := {
    "ps3": ICON_BUTTON_SELECT,
    "ps4": ICON_BUTTON_SHARE,
    "ps5": ICON_BUTTON_CREATE,
}
const PS_START_ICONS := {
    "ps3": ICON_BUTTON_START,
    "ps4": ICON_BUTTON_OPTIONS_PS4,
    "ps5": ICON_BUTTON_OPTIONS,
}

# 画面端からの余白（px）
const MARGIN := 16
# アイコンの表示高さ（px）。幅は元画像の縦横比から決める
const ICON_HEIGHT := 72
# アイコンとラベルの間（px）。キーの中心が、右下のブーストの「BOOST」の文字と同じ高さになる値
const ICON_LABEL_GAP := 4.5
# ラベルの文字サイズ
const FONT_SIZE := 14
# ラベルの縁取りの太さ（px）
const LABEL_OUTLINE_SIZE := 4
# 右下のブーストのゲージと、その横のブーストのボタンのアイコンのためにあける幅（px）
const RIGHT_RESERVE := 240.0

var _mode: Mode = Mode.KEYBOARD
var _hbox: HBoxContainer


func _ready() -> void:
    layer = 10
    if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
        _mode = Mode.TOUCH

    # 左下に固定し、内容に合わせて上・右方向へ伸ばす
    _hbox = HBoxContainer.new()
    _hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hbox.add_theme_constant_override("separation", 18)
    _hbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _hbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _hbox.offset_left = MARGIN
    _hbox.offset_bottom = -MARGIN
    add_child(_hbox)
    get_viewport().size_changed.connect(_fit_to_width)

    _rebuild()
    # GameMenu はこのノードより後に追加される Autoload なので、全 Autoload の準備後に接続する
    _connect_menu.call_deferred()


func _connect_menu() -> void:
    GameMenu.pad_layout_changed.connect(_on_pad_layout_changed)
    GameMenu.swap_confirm_changed.connect(_on_swap_confirm_changed)
    GameMenu.ps_generation_changed.connect(_on_ps_generation_changed)
    # 読み込んだ設定を反映する
    _rebuild()


func _on_pad_layout_changed(_layout: String) -> void:
    _rebuild()


func _on_ps_generation_changed(_generation: String) -> void:
    _rebuild()


func _on_swap_confirm_changed(_swapped: bool) -> void:
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


# モードごとの表示項目を返す。コントローラは選択中のボタン表記で組み立てる
func _items_for(mode: Mode) -> Array:
    if mode != Mode.GAMEPAD:
        return ITEMS[mode]
    var icons: Dictionary = PAD_ICONS[GameMenu.pad_layout].duplicate()
    # PlayStation のリセットは、選んだ世代の左側の小さいボタンにする
    if GameMenu.pad_layout == "playstation":
        icons["reset"] = get_ps_back_icon(GameMenu.ps_generation)
    return [
        [ICON_STICK_LEFT, "Steer"],
        # コントローラの実際の左右の位置に合わせて、LT（左）を RT（右）より先に並べる
        [icons.lt, "Reverse"],
        [icons.rt, "Accelerate"],
        [ICON_STICK_RIGHT, "Camera"],
        [icons.jump, "Jump", 0.8],
        [icons.drift, "Drift", 0.45],  # 余白を切った絵なので、ショルダーボタンの高さがほかのボタンとそろう倍率
        [icons.reset, "Recover", 0.8],
        [icons.map, "Map", 0.8],
    ]


# ブーストのボタンのアイコン（ブーストのゲージの横に出す）。タッチはゲージ自体がボタンなので null
func get_boost_icon() -> Texture2D:
    match _mode:
        Mode.KEYBOARD:
            return ICON_KEY_SHIFT
        Mode.GAMEPAD:
            return PAD_ICONS[GameMenu.pad_layout]["boost"]
    return null


# 看板を開くボタンのアイコン（看板のヒントに出す）。タッチはボタンが無いので null
func get_interact_icon() -> Texture2D:
    match _mode:
        Mode.KEYBOARD:
            return ICON_KEY_E
        Mode.GAMEPAD:
            return get_confirm_icon_for(GameMenu.pad_layout)
    return null


# いまの入力方式
func get_mode() -> Mode:
    return _mode


# キャンセルのボタンのアイコン（メニューの「閉じる」に出す）。コントローラ以外は null
func get_cancel_icon() -> Texture2D:
    if _mode == Mode.GAMEPAD:
        return get_cancel_icon_for(GameMenu.pad_layout)
    return null


# 指定した表記での決定のボタンのアイコン。入れ替えの設定が有効ならキャンセルのボタンのアイコンを返す
func get_confirm_icon_for(layout: String) -> Texture2D:
    return PAD_ICONS[layout]["cancel" if GameMenu.swap_confirm else "interact"]


# 指定した表記でのキャンセルのボタンのアイコン。入れ替えの設定が有効なら決定のボタンのアイコンを返す
func get_cancel_icon_for(layout: String) -> Texture2D:
    return PAD_ICONS[layout]["interact" if GameMenu.swap_confirm else "cancel"]


# PlayStation の指定した世代での、左の小さいボタン（SELECT・SHARE・CREATE）のアイコン
func get_ps_back_icon(generation: String) -> Texture2D:
    return PS_BACK_ICONS[generation]


# PlayStation の指定した世代での、右の小さいボタン（START・OPTIONS）のアイコン
func get_ps_start_icon(generation: String) -> Texture2D:
    return PS_START_ICONS[generation]


# 現在のモードの項目で HBox の中身を作り直す
func _rebuild() -> void:
    for child in _hbox.get_children():
        _hbox.remove_child(child)
        child.queue_free()
    var items := _items_for(_mode)
    # 基準のキーの中心から、アイコンの下端までの長さの最大値（これに合わせて他の項目に隙間を入れる）
    var max_below := 0.0
    for item in items:
        var icon_scale: float = item[2] if item.size() > 2 else 1.0
        max_below = maxf(max_below, _below_center(item[0], icon_scale))
    for item in items:
        var icon_scale: float = item[2] if item.size() > 2 else 1.0
        var spacer_height := max_below - _below_center(item[0], icon_scale)
        _hbox.add_child(_make_item(item[0], item[1], icon_scale, spacer_height))
    # 項目を並べ直したあとに最小サイズが決まるので、縮めるのは次のフレームにする
    _fit_to_width.call_deferred()


# 入りきらないときは、左下を動かさずに HBox 全体を縮めて、画面の幅に収める
func _fit_to_width() -> void:
    var min_size := _hbox.get_combined_minimum_size()
    var available := get_viewport().get_visible_rect().size.x - MARGIN - RIGHT_RESERVE
    if min_size.x > available and available > 0.0:
        _hbox.scale = Vector2.ONE * (available / min_size.x)
    else:
        _hbox.scale = Vector2.ONE
    _hbox.pivot_offset = Vector2(0, min_size.y)


# アイコンの表示の高さ（px）
func _icon_height(icon_scale: float) -> float:
    return roundf(ICON_HEIGHT * icon_scale)


# 基準のキーの中心から、アイコンの下端までの長さ（px）
func _below_center(icon: Texture2D, icon_scale: float) -> float:
    return (1.0 - ICON_ALIGN.get(icon, 0.5)) * _icon_height(icon_scale)


# アイコンとラベルを縦に並べた1項目を作る（下端を揃えてラベルを同じ高さにする）。
# アイコンとラベルの間に spacer_height の隙間を入れて、基準のキーの中心を項目どうしでそろえる
func _make_item(icon: Texture2D, text: String, icon_scale: float, spacer_height: float) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.alignment = BoxContainer.ALIGNMENT_END
    box.add_theme_constant_override("separation", 0)

    var rect := TextureRect.new()
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.texture = icon
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var aspect := float(icon.get_width()) / float(icon.get_height())
    var height := _icon_height(icon_scale)
    rect.custom_minimum_size = Vector2(roundf(height * aspect), height)
    box.add_child(rect)

    var spacer := Control.new()
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    spacer.custom_minimum_size.y = spacer_height + ICON_LABEL_GAP
    box.add_child(spacer)

    # パネルが無いので、地面の上でも読めるよう縁取りを付ける
    var label := UiStyle.make_label(text, FONT_SIZE, UiStyle.TEXT_COLOR)
    label.add_theme_constant_override("outline_size", LABEL_OUTLINE_SIZE)
    label.add_theme_color_override("font_outline_color", UiStyle.OUTLINE_COLOR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(label)
    return box

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
# 文字の無いキーの絵（tools/make_blank_key_icons.py で作ったもの）。割り当てを変えたキーは、この上に文字を重ねて描く
const ICON_KEY_BLANK := preload("res://assets/ui/controls/key_blank.png")
const ICON_KEY_BLANK_WIDE := preload("res://assets/ui/controls/key_blank_wide.png")
# 文字の無いボタンの絵（同じスクリプトで作ったもの）。割り当てたスティックの押し込み・左の肩のボタンは、この上に文字を重ねて描く
const ICON_BUTTON_BLANK := preload("res://assets/ui/controls/button_blank.png")
const ICON_SHOULDER_BLANK_L := preload("res://assets/ui/controls/shoulder_blank_l.png")

# 専用の絵があるキー（physical_keycode → [絵, 絵に描いてある文字。KeyBindings.key_label と同じ表記]）。
# キー配列が違って、そのキーの位置に別の文字が書いてあるときは、絵を使わず文字を重ねて描く
const KEY_ICONS := {
    KEY_R: [ICON_KEY_R, "R"],
    KEY_M: [ICON_KEY_M, "M"],
    KEY_E: [ICON_KEY_E, "E"],
    KEY_SPACE: [ICON_KEY_SPACE, "Space"],
    KEY_SHIFT: [ICON_KEY_SHIFT, "Shift"],
    KEY_SLASH: [ICON_KEY_SLASH, "Slash"],
}
# 矢印のキー（絵に三角の矢印を描く）と、その向き（上向きの三角を回す角度 [rad]）
const ARROW_KEYS := {
    KEY_UP: 0.0,
    KEY_RIGHT: PI / 2.0,
    KEY_DOWN: PI,
    KEY_LEFT: -PI / 2.0,
}
# 文字を重ねる絵の中の、キーの面（縁と影を除いた黒い部分）の位置。絵の大きさに対する割合（tools/make_blank_key_icons.py で調べた矩形）
const KEY_FACE_SQUARE := Rect2(55.0 / 256.0, 55.0 / 256.0, 145.0 / 256.0, 141.0 / 256.0)
const KEY_FACE_WIDE := Rect2(61.0 / 512.0, 11.0 / 112.0, 389.0 / 512.0, 83.0 / 112.0)
# 文字を重ねるボタンの絵の中の、文字を置く面の位置（同じく割合）。丸いボタンは、丸（中心 (128, 128)・半径 80）に収まる正方形 x 68〜188・y 68〜188。
# 肩のボタンは角の丸い長方形の面 x 10〜167・y 10〜82（左右反転しても同じ位置）
const BUTTON_FACE_ROUND := Rect2(68.0 / 256.0, 68.0 / 256.0, 120.0 / 256.0, 120.0 / 256.0)
const BUTTON_FACE_SHOULDER := Rect2(10.0 / 178.0, 10.0 / 93.0, 158.0 / 178.0, 73.0 / 93.0)
# 肩のボタンの文字の大きさ（絵の高さに対する割合）。面が低くて横に長いので、丸いボタンより大きくする
const SHOULDER_TEXT_SCALE := 0.5
# 肩のボタンの絵の高さの倍率（丸いボタンの絵の高さに対して）。余白を切った絵なので、丸いボタンと高さがそろう倍率
const SHOULDER_HEIGHT_SCALE := 0.5625
# 横長のキーの絵は上下の余白を切ってあるので、キーの高さを正方形のキーとそろえるための、絵の高さの倍率
const WIDE_KEY_HEIGHT_SCALE := 0.72
# キーに重ねる文字の色と、大きさ（絵の高さに対する割合。横長のキーは面に収まるよう縮める）
const KEY_TEXT_COLOR := Color("#f0f0f0")
const KEY_TEXT_SCALE := 0.4
# 日本語フォントの大文字の高さ（文字の大きさに対する割合）。文字の縦の中央を、キーの面の中央に合わせるために使う
const KEY_TEXT_CAP_HEIGHT := 0.73
# 矢印の三角の大きさ（絵の高さに対する割合）
const KEY_ARROW_SCALE := 0.17
# 十字キーの絵の形（絵の高さに対する割合）。腕の太さ、十字全体の長さ、縁の太さ。角の丸みは腕の太さに対する割合
const DPAD_ARM_SCALE := 0.30
const DPAD_LENGTH_SCALE := 0.80
const DPAD_EDGE_SCALE := 0.03
const DPAD_CORNER_SCALE := 0.15
# 角の丸みを折れ線にするときの分割数
const DPAD_CORNER_STEPS := 4
# 十字キーの色。面は文字の無いキーの絵の面の色、縁は明るい灰色、押す向きの腕の面は文字と同じ明るい色
const DPAD_FACE_COLOR := Color("#1b1b1e")
const DPAD_EDGE_COLOR := Color("#d8d8d8")
const DPAD_PRESSED_COLOR := KEY_TEXT_COLOR
# 4つのキーを並べた絵で、キーの面どうしの間（px）
const KEY_CLUSTER_GAP := 3.0

# 動けなくなっていそうなとき、アイコンに縁取りを付ける項目のラベル
const RECOVER_LABEL := "Recover"
# 縁取りの点滅の周期 [s]
const RECOVER_BLINK_PERIOD := 0.8

# キーボード以外のモードごとの表示項目 [アイコン, ラベル, アイコンの拡大率（省略時1.0）]。
# キーボードは割り当てを変えられるので、_keyboard_items で毎回組み立てる
const ITEMS := {
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
# Godot のボタン番号は位置で決まるため（0＝下、1＝右、2＝左、3＝上のボタン。4＝左側の小さいボタン、10＝右のショルダーボタン）、
# 表記が変わっても操作は同じでアイコンだけが変わる。どの操作にどのボタンを割り当てるかは KeyBindings で決まり、
# 絵は make_button_icon でボタン番号から引く（"face" は番号 0〜3 の順、"back" は番号 4、"shoulder_r" は番号 10 の絵。PlayStation の "back" は世代ごとに違うので get_ps_back_icon で引く）。
# ただし "interact"（看板を開く）と "cancel" は例外で、表記ごとの標準の決定・キャンセルのボタン
# （game_menu.gd の _apply_pad_buttons。Nintendo は A・B、PlayStation は ×・○、Xbox は A・B）なので、
# 割り当ても表記で変わる。決定とキャンセルを入れ替える設定は get_confirm_icon_for / get_cancel_icon_for で反映する。
const PAD_ICONS := {
    "nintendo": {
        "rt": ICON_TRIGGER_ZR, "lt": ICON_TRIGGER_ZL,
        "face": [ICON_BUTTON_B, ICON_BUTTON_A, ICON_BUTTON_Y, ICON_BUTTON_X], "back": ICON_BUTTON_MINUS,
        "interact": ICON_BUTTON_A, "cancel": ICON_BUTTON_B,
        "shoulder_r": ICON_SHOULDER_R,
    },
    "playstation": {
        "rt": ICON_TRIGGER_R2, "lt": ICON_TRIGGER_L2,
        "face": [ICON_BUTTON_CROSS, ICON_BUTTON_CIRCLE, ICON_BUTTON_SQUARE, ICON_BUTTON_TRIANGLE], "back": ICON_BUTTON_CREATE,
        "interact": ICON_BUTTON_CROSS, "cancel": ICON_BUTTON_CIRCLE,
        "shoulder_r": ICON_SHOULDER_R1,
    },
    "xbox": {
        "rt": ICON_TRIGGER_RT, "lt": ICON_TRIGGER_LT,
        "face": [ICON_BUTTON_A, ICON_BUTTON_B, ICON_BUTTON_X, ICON_BUTTON_Y], "back": ICON_BUTTON_BACK,
        "interact": ICON_BUTTON_A, "cancel": ICON_BUTTON_B,
        "shoulder_r": ICON_SHOULDER_RB,
    },
}
# 専用の絵が無いボタンに重ねる文字（表記ごと）。左の肩のボタンと、左右のスティックの押し込み
const PAD_SHOULDER_L_LABELS := {"nintendo": "L", "xbox": "LB", "playstation": "L1"}
# START（メニュー）のボタンの専用の絵が無い表記で、文字の無いボタンの絵に重ねる文字。PlayStation は世代ごとの絵（get_ps_start_icon）を使う
const PAD_START_LABELS := {"nintendo": "+", "xbox": "≡"}
const PAD_STICK_LABELS := {
    "nintendo": {JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS"},
    "xbox": {JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS"},
    "playstation": {JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"},
}
# 十字キーの絵に描く三角の向き（上向きの三角を回す角度 [rad]。ARROW_KEYS と同じ）
const PAD_ARROWS := {
    JOY_BUTTON_DPAD_UP: 0.0,
    JOY_BUTTON_DPAD_RIGHT: PI / 2.0,
    JOY_BUTTON_DPAD_DOWN: PI,
    JOY_BUTTON_DPAD_LEFT: -PI / 2.0,
}

# PlayStation の世代（選んだ機種から決まる。GameMenu.get_ps_generation）ごとの、左側の小さいボタン（SELECT・SHARE・CREATE）と右側の小さいボタン（START・OPTIONS）のアイコン。
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
# Recover のアイコンに付ける金色の縁取り（_rebuild のたびに作り直す）と、動けなくなっていそうか
var _recover_ring: Control
var _stuck := false
# ED3 の再生中か。再生中は一時停止・スキップ・メニューの操作だけを出す
var _salvage_playback := false


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


# 動けなくなっていそうかを見て、変わったときだけ Recover の縁取りを出し入れする（一時停止中は判定も止まる）
func _process(_delta: float) -> void:
    var stuck := false
    var player := get_tree().get_first_node_in_group("player")
    if player != null:
        var respawn := player.get_node_or_null("Respawn")
        if respawn != null:
            stuck = respawn.is_stuck()
    if stuck != _stuck:
        _stuck = stuck
        if _recover_ring != null:
            _recover_ring.visible = stuck
        TouchControls.set_recover_highlight(stuck)
    # 縁取りは点滅させる（出ている間だけ更新する）
    if _recover_ring != null and _recover_ring.visible:
        _recover_ring.modulate.a = recover_ring_alpha()


func _connect_menu() -> void:
    GameMenu.pad_layout_changed.connect(_on_pad_layout_changed)
    GameMenu.swap_confirm_changed.connect(_on_swap_confirm_changed)
    GameMenu.key_bindings_changed.connect(_on_key_bindings_changed)
    GameMenu.pad_bindings_changed.connect(_on_pad_bindings_changed)
    # 読み込んだ設定を反映する
    _rebuild()


func _on_pad_layout_changed(_layout: String) -> void:
    _rebuild()


func _on_swap_confirm_changed(_swapped: bool) -> void:
    _rebuild()


func _on_key_bindings_changed() -> void:
    _rebuild()


func _on_pad_bindings_changed() -> void:
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
    if _salvage_playback:
        return _salvage_items(mode)
    if mode == Mode.KEYBOARD:
        return _keyboard_items()
    if mode != Mode.GAMEPAD:
        return ITEMS[mode]
    var icons: Dictionary = PAD_ICONS[_icon_family(GameMenu.pad_layout)]
    # ボタンの絵は、割り当てたボタンに合わせて毎回作る（make_button_icon）。肩のボタンは絵の高さを自分で縮める
    var button_height := _icon_height(0.8)
    return [
        [ICON_STICK_LEFT, "Steer"],
        # コントローラの実際の左右の位置に合わせて、LT（左）を RT（右）より先に並べる
        [icons.lt, "Reverse"],
        [icons.rt, "Accelerate"],
        [ICON_STICK_RIGHT, "Camera"],
        [make_button_icon(KeyBindings.get_button("jump"), button_height), "Jump"],
        [make_button_icon(KeyBindings.get_button("drift"), button_height), "Drift"],
        [make_button_icon(KeyBindings.get_button("respawn"), button_height), RECOVER_LABEL],
        [make_button_icon(KeyBindings.get_button("map"), button_height), "Map"],
    ]


# ED3 の再生中の表示項目。一時停止とスキップは同じボタン（短く押すと一時停止、長押しでスキップ）。
# タッチは一時停止のボタンが無いので何も出さない
func _salvage_items(mode: Mode) -> Array:
    match mode:
        Mode.KEYBOARD:
            var key_height := _icon_height(0.6)
            return [
                [make_key_icon(KEY_SPACE, key_height), "Pause"],
                [make_key_icon(KEY_SPACE, key_height), "Hold to Skip"],
                [make_key_icon(KEY_ESCAPE, key_height), "Menu"],
            ]
        Mode.GAMEPAD:
            var button_height := _icon_height(0.8)
            return [
                [_make_texture_icon(get_cancel_icon_for(GameMenu.pad_layout), button_height), "Pause"],
                [_make_texture_icon(get_cancel_icon_for(GameMenu.pad_layout), button_height), "Hold to Skip"],
                [make_button_icon(JOY_BUTTON_START, button_height), "Menu"],
            ]
    return []


# ED3 の再生の始まりと終わりに、表示項目を切り替える
func set_salvage_playback(active: bool) -> void:
    if active == _salvage_playback:
        return
    _salvage_playback = active
    _rebuild()


func is_salvage_playback() -> bool:
    return _salvage_playback


# キーボードのときの表示項目。割り当てたキーに合わせて、キーの絵（Control）を毎回作る。
# 運転・カメラは、4つのキーがすべて初期のままなら WASD・矢印キーの絵（Texture2D）、変わっていれば4つのキーを並べた絵にする。
# ドリフトは、右手で押せるよう「/」（JIS の「・」）にしてある（Ctrl だと Web 版で Ctrl+W がタブを閉じる）
func _keyboard_items() -> Array:
    var key_height := _icon_height(0.6)
    return [
        [_make_direction_icon(["up", "left", "down", "right"], ICON_KEYS_WASD, key_height), "Drive"],
        [_make_direction_icon(["view_up", "view_left", "view_down", "view_right"], ICON_KEYS_ARROWS, key_height), "Camera"],
        [make_key_icon(KeyBindings.get_key("jump"), key_height), "Jump"],
        [make_key_icon(KeyBindings.get_key("drift"), key_height), "Drift"],
        [make_key_icon(KeyBindings.get_key("respawn"), key_height), RECOVER_LABEL],
        [make_key_icon(KeyBindings.get_key("map"), key_height), "Map"],
    ]


# 運転・カメラの絵。actions は上・左・下・右の順。すべて初期のままなら default_icon（Texture2D）、そうでなければ4つのキーを並べた Control
func _make_direction_icon(actions: Array, default_icon: Texture2D, key_height: float) -> Variant:
    var keys: Array[Key] = []
    var changed := false
    for action in actions:
        keys.append(KeyBindings.get_key(action))
        if KeyBindings.get_key(action) != KeyBindings.get_default_key(action):
            changed = true
    if not changed:
        return default_icon
    return _make_keys_cluster(keys, key_height)


# ブーストのボタンのアイコン（ブーストのゲージの横に出す）を作る。height は正方形のキー・ボタンの絵の高さ。
# キーボードは割り当てたキー、コントローラは表記に合わせたボタン。タッチはゲージ自体がボタンなので null
func make_boost_icon(height: float) -> Control:
    return _make_action_icon("boost", height)


# 看板を開くボタンのアイコン（看板のヒントに出す）を作る。タッチはボタンが無いので null
func make_interact_icon(height: float) -> Control:
    return _make_action_icon("interact", height)


# 操作（boost・interact）のボタンのアイコンを今の入力方式で作る。作れなければ null
func _make_action_icon(action: String, height: float) -> Control:
    match _mode:
        Mode.KEYBOARD:
            return make_key_icon(KeyBindings.get_key(action), height)
        Mode.GAMEPAD:
            # 看板を開くボタンは決定と同じ（表記と入れ替えの設定で決まる）。それ以外は割り当てたボタン
            if action == "interact":
                return _make_texture_icon(get_confirm_icon_for(GameMenu.pad_layout), height)
            return make_button_icon(KeyBindings.get_button(action), height)
    return null


# make_boost_icon・make_interact_icon の絵が変わったかを調べるための印。同じ印なら絵を作り直さなくてよい（絵は Control で、毎フレーム作ると重いため）。
# 絵が出ないとき（タッチ）は空の文字列
func get_icon_token(action: String) -> String:
    match _mode:
        Mode.KEYBOARD:
            return "key:%d" % KeyBindings.get_key(action)
        Mode.GAMEPAD:
            if action == "interact":
                return "pad:%s" % get_confirm_icon_for(GameMenu.pad_layout).resource_path
            # ボタンの絵は、割り当てたボタンと機種・PlayStation の世代（左側の小さいボタンの絵が変わる）で決まる
            return "pad:%d:%s:%s" % [KeyBindings.get_button(action), _icon_family(GameMenu.pad_layout), GameMenu.get_ps_generation()]
    return ""


# 絵を入れる枠（slot）の中身を icon に入れ替えて、枠の最小サイズを絵に合わせる（icon が null なら空にする）
func set_icon_slot(slot: Control, icon: Control) -> void:
    for child in slot.get_children():
        slot.remove_child(child)
        child.queue_free()
    slot.custom_minimum_size = Vector2.ZERO
    if icon == null:
        return
    icon.size = icon.custom_minimum_size
    slot.add_child(icon)
    slot.custom_minimum_size = icon.custom_minimum_size


# 高さを決めて、縦横比を保つ絵（ボタン・キーの絵そのまま）
func _make_texture_icon(texture: Texture2D, height: float) -> TextureRect:
    var rect := TextureRect.new()
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.texture = texture
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var aspect := float(texture.get_width()) / float(texture.get_height())
    rect.custom_minimum_size = Vector2(roundf(height * aspect), height)
    rect.set_meta("texture", texture)
    return rect


# そのキーの絵の元になる Texture2D。専用の絵があればそれ、なければ文字の無いキー（1文字か矢印は正方形、2文字以上は横長）
func key_icon_texture(physical: Key) -> Texture2D:
    var label := KeyBindings.key_label(physical)
    if KEY_ICONS.has(physical) and KEY_ICONS[physical][1] == label:
        return KEY_ICONS[physical][0]
    if ARROW_KEYS.has(physical) or label.length() <= 1:
        return ICON_KEY_BLANK
    return ICON_KEY_BLANK_WIDE


# キーの絵を作る。height は正方形のキーの絵の高さ（横長のキーは、キーの高さがそろうよう WIDE_KEY_HEIGHT_SCALE をかける）。
# 専用の絵が無いキーは、文字の無いキーの絵の面の中央に、文字（矢印は三角）を重ねて描く。
# 絵の中の縦の基準（ICON_ALIGN の代わり）は絵の中央なので、align のメタデータは付けない
func make_key_icon(physical: Key, height: float) -> Control:
    var texture := key_icon_texture(physical)
    var wide := texture.get_width() > texture.get_height()
    var icon := _make_texture_icon(texture, roundf(height * WIDE_KEY_HEIGHT_SCALE) if wide else height)
    if texture == ICON_KEY_BLANK or texture == ICON_KEY_BLANK_WIDE:
        var overlay := Control.new()
        overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        overlay.draw.connect(_draw_key_overlay.bind(overlay, physical, wide))
        icon.add_child(overlay)
    return icon


# ゲームパッドのボタンの絵を作る。ボタン番号と、今のボタン表記（機種）で絵が決まる。height は丸いボタンの絵の高さ
# （肩のボタンは余白を切った絵なので、SHOULDER_HEIGHT_SCALE をかけて、丸いボタンと高さをそろえる）。
# 0〜3 は位置で決まる絵、4 は左側の小さいボタン（PlayStation は世代ごと）、10 は右の肩のボタン。 6（START）は PlayStation は世代ごとの絵、ほかは文字を重ねる。
# 専用の絵が無い 9（左の肩）・7・8（スティックの押し込み）は、文字の無いボタンの絵の面に文字を重ねて描く。11〜14（十字キー）は _make_dpad_icon で十字の形を描く。
# 絵の中の縦の基準は絵の中央なので、align のメタデータは付けない
func make_button_icon(button: JoyButton, height: float) -> Control:
    var family := _icon_family(GameMenu.pad_layout)
    var icons: Dictionary = PAD_ICONS[family]
    var texture: Texture2D = ICON_BUTTON_BLANK
    var icon_height := height
    var face := BUTTON_FACE_ROUND
    var text := ""
    var text_scale := KEY_TEXT_SCALE
    match button:
        JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
            texture = icons["face"][button]
        JOY_BUTTON_BACK:
            texture = get_ps_back_icon(GameMenu.get_ps_generation()) if family == "playstation" else icons["back"]
        JOY_BUTTON_START:
            if family == "playstation":
                texture = get_ps_start_icon(GameMenu.get_ps_generation())
            else:
                text = PAD_START_LABELS[family]
        JOY_BUTTON_RIGHT_SHOULDER:
            texture = icons["shoulder_r"]
            icon_height = roundf(height * SHOULDER_HEIGHT_SCALE)
        JOY_BUTTON_LEFT_SHOULDER:
            texture = ICON_SHOULDER_BLANK_L
            icon_height = roundf(height * SHOULDER_HEIGHT_SCALE)
            face = BUTTON_FACE_SHOULDER
            text = PAD_SHOULDER_L_LABELS[family]
            text_scale = SHOULDER_TEXT_SCALE
        JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK:
            text = PAD_STICK_LABELS[family][button]
        JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
            # 十字キーは丸いボタンではなく、十字の形を描く絵にする
            return _make_dpad_icon(PAD_ARROWS[button], height)
        _:
            # 割り当てられない番号（設定ファイルが壊れていたとき用）は、番号をそのまま出す
            text = str(int(button))
    var icon := _make_texture_icon(texture, icon_height)
    if texture == ICON_BUTTON_BLANK or texture == ICON_SHOULDER_BLANK_L:
        var overlay := Control.new()
        overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        overlay.draw.connect(_draw_face_overlay.bind(overlay, face, text, NAN, text_scale))
        icon.add_child(overlay)
    return icon


# 十字キーの絵を作る。大きさは丸いボタンの絵と同じ（height 四方）。押す向き（angle は上向きを回す角度 [rad]）の腕だけ面を明るくした十字を、その場で描く。
# texture のメタデータは付けない（Recover の縁取りは、texture が無いと絵の範囲全体を囲む）。絵の中の縦の基準は絵の中央なので、align も付けない
func _make_dpad_icon(angle: float, height: float) -> Control:
    var icon := Control.new()
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    icon.custom_minimum_size = Vector2(height, height)
    icon.draw.connect(_draw_dpad.bind(icon, angle))
    return icon


# 十字キーの形を描く。面は暗い色、縁は明るい灰色で、押す向きの腕の面だけ明るい色で塗る
func _draw_dpad(icon: Control, angle: float) -> void:
    var center := icon.size / 2.0
    var thickness := icon.size.y * DPAD_ARM_SCALE
    var half_length := icon.size.y * DPAD_LENGTH_SCALE / 2.0
    var half := thickness / 2.0
    var radius := thickness * DPAD_CORNER_SCALE
    # 上の腕を先頭にして、時計回りに並べた十字の輪郭（中心が原点）
    var outline := [
        Vector2(-half, -half_length), Vector2(half, -half_length), Vector2(half, -half),
        Vector2(half_length, -half), Vector2(half_length, half), Vector2(half, half),
        Vector2(half, half_length), Vector2(-half, half_length), Vector2(-half, half),
        Vector2(-half_length, half), Vector2(-half_length, -half), Vector2(-half, -half),
    ]
    var outline_radii := []
    outline_radii.resize(outline.size())
    outline_radii.fill(radius)
    # 押す向きの腕（上向きの腕の、中央の正方形を除いた部分。先の2つの角だけ丸める）
    var arm := [Vector2(-half, -half_length), Vector2(half, -half_length), Vector2(half, -half), Vector2(-half, -half)]
    var arm_radii := [radius, radius, 0.0, 0.0]
    var body := _rounded_polygon(outline, outline_radii)
    var arm_body := _rounded_polygon(arm, arm_radii)
    for i in body.size():
        body[i] = center + body[i]
    for i in arm_body.size():
        arm_body[i] = center + arm_body[i].rotated(angle)
    icon.draw_colored_polygon(body, DPAD_FACE_COLOR)
    icon.draw_colored_polygon(arm_body, DPAD_PRESSED_COLOR)
    body.append(body[0])
    icon.draw_polyline(body, DPAD_EDGE_COLOR, icon.size.y * DPAD_EDGE_SCALE, true)


# 多角形の各頂点を、半径 radii[i] で丸める（頂点の手前から奥へ、頂点を制御点にした曲線でつなぐ）
func _rounded_polygon(points: Array, radii: Array) -> PackedVector2Array:
    var result := PackedVector2Array()
    var count := points.size()
    for i in count:
        var point: Vector2 = points[i]
        var previous: Vector2 = points[(i - 1 + count) % count]
        var next: Vector2 = points[(i + 1) % count]
        var r: float = radii[i]
        if r <= 0.0:
            result.append(point)
            continue
        # 隣の頂点との中間より先へは食い込まない
        var start := point + (previous - point).normalized() * minf(r, point.distance_to(previous) / 2.0)
        var end := point + (next - point).normalized() * minf(r, point.distance_to(next) / 2.0)
        for step in DPAD_CORNER_STEPS + 1:
            var t := float(step) / DPAD_CORNER_STEPS
            result.append(start.lerp(point, t).lerp(point.lerp(end, t), t))
    return result


# キーの絵の中の、キーの面の位置（px）。絵は icon の全体に広がっているものとして計算する
func _key_face(icon: Control) -> Rect2:
    var texture: Texture2D = icon.get_meta("texture")
    var fraction := KEY_FACE_WIDE if texture.get_width() > texture.get_height() else KEY_FACE_SQUARE
    var size := icon.custom_minimum_size
    return Rect2(fraction.position * size, fraction.size * size)


# 文字の無いキーの絵の上に、文字（矢印のキーは三角）を面の中央に描く
func _draw_key_overlay(overlay: Control, physical: Key, wide: bool) -> void:
    var fraction := KEY_FACE_WIDE if wide else KEY_FACE_SQUARE
    var arrow: float = ARROW_KEYS.get(physical, NAN)
    _draw_face_overlay(overlay, fraction, KeyBindings.key_label(physical), arrow, KEY_TEXT_SCALE)


# 文字の無い絵の上に、文字を面（fraction は絵に対する割合）の中央に描く。arrow_angle が NAN でなければ、文字の代わりに三角の矢印を描く。
# 文字の大きさは絵の高さの text_scale 倍で、面に収まらないときは縮める。キーとボタンで共通
func _draw_face_overlay(overlay: Control, fraction: Rect2, text: String, arrow_angle: float, text_scale: float) -> void:
    var face := Rect2(fraction.position * overlay.size, fraction.size * overlay.size)
    var center := face.get_center()
    if not is_nan(arrow_angle):
        # 上向きの三角を、向きに合わせて回す。外接する矩形の中心を面の中央に合わせる
        var radius := overlay.size.y * KEY_ARROW_SCALE
        var points := PackedVector2Array()
        for point in [Vector2(0.0, -radius), Vector2(radius * 0.95, radius * 0.75), Vector2(-radius * 0.95, radius * 0.75)]:
            points.append(center + (point + Vector2(0.0, radius * 0.125)).rotated(arrow_angle))
        overlay.draw_colored_polygon(points, KEY_TEXT_COLOR)
        return
    var font_size := roundi(overlay.size.y * text_scale)
    var text_width := UiStyle.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    # 面に収まらないときは縮める（面の幅の 88% まで）
    var max_width := face.size.x * 0.88
    if text_width > max_width:
        font_size = maxi(floori(font_size * max_width / text_width), 1)
        text_width = UiStyle.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    var position := Vector2(center.x - text_width / 2.0, center.y + font_size * KEY_TEXT_CAP_HEIGHT / 2.0)
    overlay.draw_string(UiStyle.FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, KEY_TEXT_COLOR)


# 4つのキー（上・左・下・右の順）を、上の段に上のキー、下の段に左・下・右のキーで並べた絵。上のキーは下の段の真ん中の真上に置く。
# キーの面どうしを KEY_CLUSTER_GAP あけて並べるので、絵の余白は切る。縦の基準は下の段のキーの中心（align のメタデータ）
func _make_keys_cluster(keys: Array[Key], key_height: float) -> Control:
    var icons: Array[Control] = []
    var faces: Array[Rect2] = []
    var row_height := 0.0
    for key in keys:
        var icon := make_key_icon(key, key_height)
        icon.size = icon.custom_minimum_size
        icons.append(icon)
        var face := _key_face(icon)
        faces.append(face)
        row_height = maxf(row_height, face.size.y)
    var cluster := Control.new()
    cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cluster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    # 下の段（左・下・右 = 添字 1・2・3）は左から順に、上のキー（添字 0）は下の段の真ん中の中央に
    var left_x := [0.0, 0.0, 0.0, 0.0]
    var x := 0.0
    for i in [1, 2, 3]:
        left_x[i] = x
        x += faces[i].size.x + KEY_CLUSTER_GAP
    left_x[0] = left_x[2] + (faces[2].size.x - faces[0].size.x) / 2.0
    var top_y := [0.0, row_height + KEY_CLUSTER_GAP, row_height + KEY_CLUSTER_GAP, row_height + KEY_CLUSTER_GAP]
    for i in 4:
        # 面が (left_x, 段の中央) に来るよう、絵を面の左上の分だけずらして置く
        var y: float = top_y[i] + (row_height - faces[i].size.y) / 2.0
        icons[i].position = Vector2(left_x[i], y) - faces[i].position
        cluster.add_child(icons[i])
    var total := Vector2(x - KEY_CLUSTER_GAP, 2.0 * row_height + KEY_CLUSTER_GAP)
    cluster.custom_minimum_size = total
    cluster.set_meta("align", (total.y - row_height / 2.0) / total.y)
    return cluster


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
    return PAD_ICONS[_icon_family(layout)]["cancel" if GameMenu.swap_confirm else "interact"]


# 指定した表記でのキャンセルのボタンのアイコン。入れ替えの設定が有効なら決定のボタンのアイコンを返す
func get_cancel_icon_for(layout: String) -> Texture2D:
    return PAD_ICONS[_icon_family(layout)]["interact" if GameMenu.swap_confirm else "cancel"]


# アイコンの表を引くための機種の分類。PlayStation の3機種（DualShock 3・4・DualSense）は "playstation" にまとめる
func _icon_family(layout: String) -> String:
    if GameMenu.is_playstation_layout(layout):
        return "playstation"
    return layout


# PlayStation の指定した世代での、左の小さいボタン（SELECT・SHARE・CREATE）のアイコン
func get_ps_back_icon(generation: String) -> Texture2D:
    return PS_BACK_ICONS[generation]


# PlayStation の指定した世代での、右の小さいボタン（START・OPTIONS）のアイコン
func get_ps_start_icon(generation: String) -> Texture2D:
    return PS_START_ICONS[generation]


# 現在のモードの項目で HBox の中身を作り直す
func _rebuild() -> void:
    _recover_ring = null
    for child in _hbox.get_children():
        _hbox.remove_child(child)
        child.queue_free()
    # アイコン（item[0]）は Texture2D か、作った絵の Control（キーボード）
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


# 基準のキーの中心から、アイコンの下端までの長さ（px）。
# Control の絵は自分で高さを持ち、基準が絵の中央でなければ align のメタデータ（上端から、絵の高さに対する割合）を持つ
func _below_center(icon: Variant, icon_scale: float) -> float:
    if icon is Control:
        return (1.0 - icon.get_meta("align", 0.5)) * icon.custom_minimum_size.y
    return (1.0 - ICON_ALIGN.get(icon, 0.5)) * _icon_height(icon_scale)


# 縁取りの点滅の不透明度。周期 RECOVER_BLINK_PERIOD で 1.0〜0.2 の間をなめらかに行き来する
static func recover_ring_alpha() -> float:
    var t := Time.get_ticks_msec() / 1000.0
    return 0.6 + 0.4 * cos(TAU * t / RECOVER_BLINK_PERIOD)


# Recover のアイコンに金色の縁取りを描く（マップボタンのヒントの縁取りと同じ見た目）。
# 絵には透明な余白があるので、control（絵を表示している範囲）の中で絵の見えている部分に沿わせる。
# 角の丸みは見えている範囲の短い辺 × round_ratio（縁取りの張り出しを足す）
func draw_recover_ring(control: Control, texture: Texture2D, round_ratio: float) -> void:
    var area := Rect2(Vector2.ZERO, control.size)
    # texture が無い絵（十字キー）は、絵の範囲全体を囲む
    var tex_size := texture.get_size() if texture != null else Vector2.ZERO
    var image := texture.get_image() if texture != null else null
    if image != null and tex_size.x > 0.0 and tex_size.y > 0.0:
        var used := image.get_used_rect()
        if used.size.x > 0 and used.size.y > 0:
            # TextureRect は縦横比を保って中央に置くので、その倍率と位置で絵の画素の座標を表示の座標に直す
            var k := minf(control.size.x / tex_size.x, control.size.y / tex_size.y)
            var origin := (control.size - tex_size * k) * 0.5
            area = Rect2(origin + Vector2(used.position) * k, Vector2(used.size) * k)
    var outset := Map.BUTTON_HINT_RING_OUTSET
    var ring := StyleBoxFlat.new()
    ring.draw_center = false
    ring.border_color = Map.HINT_MARK_COLOR
    ring.set_border_width_all(Map.BUTTON_HINT_RING_WIDTH)
    ring.set_corner_radius_all(roundi(minf(area.size.x, area.size.y) * round_ratio + outset))
    ring.anti_aliasing = true
    control.draw_style_box(ring, area.grow(outset))


# アイコンとラベルを縦に並べた1項目を作る（下端を揃えてラベルを同じ高さにする）。
# アイコンとラベルの間に spacer_height の隙間を入れて、基準のキーの中心を項目どうしでそろえる
func _make_item(icon: Variant, text: String, icon_scale: float, spacer_height: float) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.alignment = BoxContainer.ALIGNMENT_END
    box.add_theme_constant_override("separation", 0)

    # Control の絵（キーボード）は大きさが決まっているのでそのまま入れる。Texture2D は高さを決めて縦横比を保つ
    var rect: Control
    var texture: Texture2D
    if icon is Control:
        rect = icon
        # default が null だと、無いときにエラーを出すので has_meta で確かめる
        texture = icon.get_meta("texture") if icon.has_meta("texture") else null
    else:
        texture = icon
        rect = _make_texture_icon(texture, _icon_height(icon_scale))
    box.add_child(rect)

    if text == RECOVER_LABEL:
        # キーボードは角の丸いキー、コントローラは丸いボタンに沿わせる
        var round_ratio := 0.2 if _mode == Mode.KEYBOARD else 0.5
        _recover_ring = Control.new()
        _recover_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
        _recover_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _recover_ring.visible = _stuck
        _recover_ring.draw.connect(draw_recover_ring.bind(_recover_ring, texture, round_ratio))
        rect.add_child(_recover_ring)

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

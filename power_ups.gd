extends CanvasLayer
# パワーアップアイテム。取った種類を覚えて機体の効果に反映し、取ったときは一時停止して名前と説明のポップアップを出す。
# シーンが変わったら（Back to Start など）取った効果を空に戻す。

const FONT := preload("res://assets/fonts/noto_sans_cjk_jp_bold_ui.otf")
const ITEM_SCRIPT := preload("res://power_up_item.gd")
# アイテムを取ったときのファンファーレ。Fantasy Musica (Beau Buckley)「Fanfare 02」CC-BY-SA 4.0。クレジットは assets/audio/CREDITS.md
const FANFARE := preload("res://assets/audio/fanfare/fanfare_02.ogg")

# 種類のキー: 名前・説明・アイコン
const ITEMS := {
    "boost_charge": {
        "name": "BOOSTゲージ増加量UP",
        "description": "BOOSTゲージがたまりやすくなったぞ！！",
        "icon": preload("res://assets/ui/powerups/powerup_boost_charge.png"),
    },
    "double_jump": {
        "name": "二段ジャンプ",
        "description": "空中でもう一度ジャンプできるようになったぞ！！",
        "icon": preload("res://assets/ui/powerups/powerup_double_jump.png"),
    },
    "torque": {
        "name": "モータートルクUP",
        "description": "坂に強くなって、スピードと加速も上がったぞ！！",
        "icon": preload("res://assets/ui/powerups/powerup_torque.png"),
    },
    "jump_up": {
        "name": "ジャンプ力UP",
        "description": "高くジャンプできるようになったぞ！！",
        "icon": preload("res://assets/ui/powerups/powerup_jump_up.png"),
    },
    "jet": {
        "name": "ジェット",
        "description": "ジャンプ長押しで空を飛べるようになったぞ！！",
        "icon": preload("res://assets/ui/powerups/powerup_jet.png"),
    },
}

# 効果の倍率
const BOOST_CHARGE_MULTIPLIER := 2.0
const TORQUE_POWER_MULTIPLIER := 1.5
const TORQUE_SPEED_MULTIPLIER := 1.3
# ジャンプの初速の倍率。1回のジャンプで約4.0m、二段ジャンプを最高点で使うと約7.8m 上がる。
# 東3号館の非常階段の一番上（高さ約37.2m）から屋上（約42.5m）へ、二段ジャンプと空中のBOOSTを合わせると
# 余裕をもって届き、二段ジャンプなしでは届かない高さ
const JUMP_UP_MULTIPLIER := 2.16

# メダルを置く場所（ユーザーが実際に機体を置いて決めた場所。高さは機体の基準点 + SPAWN_HEIGHT）
const ITEM_PLACEMENTS := {
    # 西11号館前
    "jump_up": Vector3(-187.11, 0.63, -160.23),
    # 東3号館（高層棟。モデル上は hi_東図書館A）の非常階段 7階の踊り場、ドアの目の前
    "double_jump": Vector3(79.32, 26.18, -158.80),
    # 学生会館前（サークル棟。モデル上は hi_東課外活動施設）
    "boost_charge": Vector3(74.02, 0.63, -293.62),
    # 100周年記念キャンパス前（UECポート アライアンスセンターの北側）
    "torque": Vector3(-225.60, 0.63, 44.51),
    # 東3号館（高層棟。モデル上は hi_東図書館A）の屋上（高さ 42.5m）の中央。非常階段の一番上から約10m 先
    "jet": Vector3(81.0, 43.13, -148.0),
}

# 本番の配置は ITEM_PLACEMENTS。デバッグ用に機体の手前にも4つ並べるときだけ true
const DEBUG_SPAWN_ITEMS := false
# 機体の前へ [m]、横へ [m]、機体の位置からの高さ [m]
const SPAWN_FORWARD := 6.0
const SPAWN_SIDE := 2.5
# メダルの高さ（機体の基準点から [m]）。中心が地面から約0.6m で、走っていけば取れそうに見える高さ
const SPAWN_HEIGHT := 0.4
const SPAWN_KEYS := ["boost_charge", "double_jump", "torque", "jump_up"]
# 一時的なデバッグ用。true のとき、スタート地点を東3号館（高層棟。モデル上は hi_東図書館A）の非常階段の
# 一番上の踊り場にし、メダルもすべてそこに置く。終わったら false に戻す
const DEBUG_START_AT_E3_STAIRS := false
# 踊り場の上、+Z 向き＝屋上の方向。踊り場は高さ 37.2m、平らなのは x 79〜82・z −160.5〜−158.5、屋上 42.5m は z −158.25 から +Z 側
const E3_STAIRS_START := Transform3D(Basis.IDENTITY, Vector3(80.5, 37.6, -160.0))
# 踊り場に置くメダルの位置（SPAWN_KEYS と同じ順）
const E3_STAIRS_ITEM_POSITIONS := [
    Vector3(79.4, 37.83, -159.2),
    Vector3(80.1, 37.83, -159.2),
    Vector3(80.8, 37.83, -159.2),
    Vector3(81.5, 37.83, -159.2),
]
# 一時的なデバッグ用（宇宙の空の調整中）。true のとき、スタート地点（とリセットの戻り先）を東3号館（高層棟）の屋上にする。終わったら false に戻す
const DEBUG_START_ON_E3_ROOF := true
# 一時的なデバッグ用。true のとき、すべての種類のメダルを屋上（E3_ROOF_ITEM_POSITIONS）に並べ、ITEM_PLACEMENTS には置かない。false ならいつもの場所に置く
const DEBUG_ITEMS_ON_E3_ROOF := false
# 屋上（高さ 42.5m、高層棟は x 74〜88・z −156〜−140）の南寄り、+Z 向き
const E3_ROOF_START := Transform3D(Basis.IDENTITY, Vector3(81.0, 42.9, -154.0))
# DEBUG_ITEMS_ON_E3_ROOF が true のときに屋上に並べるメダルの位置（ITEMS のキーの順）。機体の 3m 先に横一列
const E3_ROOF_ITEM_POSITIONS := [
    Vector3(78.6, 43.13, -151.0),
    Vector3(79.8, 43.13, -151.0),
    Vector3(81.0, 43.13, -151.0),
    Vector3(82.2, 43.13, -151.0),
    Vector3(83.4, 43.13, -151.0),
]
# ポップアップを開いてから、閉じる操作を受け付けるまでの時間 [ms]（開いた押下で閉じないため）
const CLOSE_DELAY_MSEC := 300

var is_open: bool = false

# 取った種類
var _acquired := {}
# 出すのを待っているポップアップ（種類のキー）
var _queue: Array[String] = []
var _shown_scene: Node = null
var _need_spawn := false
var _opened_msec := 0
# ポップアップを閉じたときの物理フレーム番号
var _closed_physics_frame: int = -100

var _root: Control
var _icon: TextureRect
var _name_label: Label
var _desc_label: Label
var _hint_icon: TextureRect
var _hint_label: Label
var _fanfare_player: AudioStreamPlayer


func _ready() -> void:
    # メニュー（layer 20）より下、マップ（layer 18）より上に描く
    layer = 19
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_popup()
    # ファンファーレ用のプレイヤー。一時停止中も鳴らす。ファイルにループ設定があっても繰り返さない
    var stream := FANFARE.duplicate() as AudioStreamOggVorbis
    stream.loop = false
    _fanfare_player = AudioStreamPlayer.new()
    _fanfare_player.stream = stream
    _fanfare_player.bus = "Master"
    _fanfare_player.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_fanfare_player)


func has(key: String) -> bool:
    return _acquired.has(key)


# 取った種類を覚えて、ポップアップを出す（出ているときは順番待ちにする）
func acquire(key: String) -> void:
    if not ITEMS.has(key):
        push_warning("パワーアップの種類が不明: %s" % key)
        return
    # すでに持っているときは何もしない（同じ種類を2つ取ってもポップアップを重ねて出さない）
    if _acquired.has(key):
        return
    _acquired[key] = true
    _queue.append(key)
    if not is_open:
        _open_next()


# 閉じた直後か。閉じるのに使ったボタンがジャンプ・ブースト・看板と同じとき、再開した瞬間に発動させないために使う
func is_just_closed() -> bool:
    return Engine.get_physics_frames() - _closed_physics_frame <= 1


func _process(_delta: float) -> void:
    var scene := get_tree().current_scene
    if scene != null and scene != _shown_scene:
        _shown_scene = scene
        _reset()
        _place_items()
        _need_spawn = DEBUG_SPAWN_ITEMS or DEBUG_START_ON_E3_ROOF
    if _need_spawn:
        _spawn_debug_items()
    if is_open:
        _update_hint()


# シーンが変わったので、取った効果とポップアップを初めに戻す
func _reset() -> void:
    _acquired.clear()
    _queue.clear()
    _fanfare_player.stop()
    if is_open:
        is_open = false
        _root.visible = false
        get_tree().paused = false


# ITEM_PLACEMENTS の場所に、それぞれの種類のメダルを置く（機体を待たずに置く）
func _place_items() -> void:
    if DEBUG_ITEMS_ON_E3_ROOF:
        return
    for key in ITEM_PLACEMENTS:
        var item = ITEM_SCRIPT.new()  # power_up_item.gd のノード（型は付けられない）
        item.kind = key
        _shown_scene.add_child(item)
        item.global_position = ITEM_PLACEMENTS[key]


# 機体の前にメダルを4つ並べる（中央をはさんで左右対称）。機体がまだ無ければ次のフレームで試す
func _spawn_debug_items() -> void:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player == null:
        return
    _need_spawn = false
    if DEBUG_START_ON_E3_ROOF:
        _move_player_to(player, E3_ROOF_START)
        if DEBUG_ITEMS_ON_E3_ROOF:
            var roof_keys := ITEMS.keys()
            for i in roof_keys.size():
                var roof_item = ITEM_SCRIPT.new()  # power_up_item.gd のノード（型は付けられない）
                roof_item.kind = roof_keys[i]
                _shown_scene.add_child(roof_item)
                roof_item.global_position = E3_ROOF_ITEM_POSITIONS[i]
        return
    if DEBUG_START_AT_E3_STAIRS:
        _move_player_to(player, E3_STAIRS_START)
        for i in SPAWN_KEYS.size():
            var stairs_item = ITEM_SCRIPT.new()  # power_up_item.gd のノード（型は付けられない）
            stairs_item.kind = SPAWN_KEYS[i]
            _shown_scene.add_child(stairs_item)
            stairs_item.global_position = E3_STAIRS_ITEM_POSITIONS[i]
        return
    var forward := player.global_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var side := forward.cross(Vector3.UP).normalized()
    for i in SPAWN_KEYS.size():
        var item = ITEM_SCRIPT.new()  # power_up_item.gd のノード（型は付けられない）
        item.kind = SPAWN_KEYS[i]
        _shown_scene.add_child(item)
        item.global_position = player.global_position + forward * SPAWN_FORWARD \
                + side * SPAWN_SIDE * (i - (SPAWN_KEYS.size() - 1) / 2.0) + Vector3.UP * SPAWN_HEIGHT


# 機体を start の位置に移し、リセットの戻り先もそこにする（デバッグ用）
func _move_player_to(player: Node3D, start: Transform3D) -> void:
    var rid := (player as VehicleBody3D).get_rid()
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, start)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
    player.global_transform = start
    player._prev_velocity = Vector3.ZERO
    var respawn := player.get_node_or_null("Respawn")
    if respawn != null:
        # _points は型付き配列なので、置き換えずに中身を入れ替える
        respawn._points.clear()
        respawn._points.append(start)


func _open_next() -> void:
    var key: String = _queue.pop_front()
    var item: Dictionary = ITEMS[key]
    _icon.texture = item["icon"]
    _name_label.text = "%sをてにいれた！" % item["name"]
    _desc_label.text = item["description"]
    _opened_msec = Time.get_ticks_msec()
    is_open = true
    _root.visible = true
    get_tree().paused = true
    _fanfare_player.play()
    _update_hint()


func _close() -> void:
    _closed_physics_frame = Engine.get_physics_frames()
    if _queue.is_empty():
        is_open = false
        _root.visible = false
        get_tree().paused = false
    else:
        _open_next()


func _input(event: InputEvent) -> void:
    if not is_open:
        return
    # 開いている間の入力は他に流さない（menu でメニューが開かないようにする）
    get_viewport().set_input_as_handled()
    if Time.get_ticks_msec() - _opened_msec < CLOSE_DELAY_MSEC:
        return
    var pressed := false
    if event.is_action_pressed("interact") and not event.is_echo():
        pressed = true
    elif event is InputEventScreenTouch and event.pressed:
        pressed = true
    # タッチから作られたマウスの入力は、タッチ側で処理済みなので無視する
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
            and event.device != InputEvent.DEVICE_ID_EMULATION:
        pressed = true
    if pressed:
        _close()


# 続け方の行。ボタンの種類は入力の切り替えで変わるので、毎フレーム合わせる
func _update_hint() -> void:
    var icon := ControlsHelp.get_interact_icon()
    _hint_icon.visible = icon != null
    if icon != null:
        _hint_icon.texture = icon
        # 高さ40pxに合わせて、幅は画像の縦横比から決める
        _hint_icon.custom_minimum_size.x = 40.0 * icon.get_width() / icon.get_height()
        _hint_label.text = "で続ける"
    else:
        _hint_label.text = "タップして続ける"


func _build_popup() -> void:
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.visible = false
    add_child(_root)

    var dimmer := ColorRect.new()
    dimmer.color = Color(0, 0, 0, 0.5)
    dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(dimmer)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(center)

    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.1, 0.1, 0.15, 0.92)
    style.set_corner_radius_all(16)
    style.set_content_margin_all(24)
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var box := VBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_theme_constant_override("separation", 12)
    panel.add_child(box)

    _icon = TextureRect.new()
    _icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _icon.custom_minimum_size = Vector2(96, 96)
    _icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    box.add_child(_icon)

    _name_label = _make_label(32, Color.WHITE)
    box.add_child(_name_label)
    _desc_label = _make_label(24, Color("#ffd54f"))
    box.add_child(_desc_label)

    var hint_row := HBoxContainer.new()
    hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
    hint_row.add_theme_constant_override("separation", 8)
    box.add_child(hint_row)

    _hint_icon = TextureRect.new()
    _hint_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hint_icon.custom_minimum_size = Vector2(0, 40)
    _hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _hint_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hint_row.add_child(_hint_icon)

    _hint_label = _make_label(22, Color.WHITE)
    _hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hint_row.add_child(_hint_label)


# 黒縁つきの中央ぞろえのラベル
func _make_label(font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_override("font", FONT)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", 6)
    return label

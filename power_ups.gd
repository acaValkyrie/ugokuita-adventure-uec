extends CanvasLayer
# パワーアップアイテム。取った種類を覚えて機体の効果に反映し、取ったときは一時停止して名前と説明のポップアップを出す。
# シーンが変わっても（Back to Start など）取った効果は残す。取った種類のメダルは置き直さない。

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
    # 東3号館（高層棟。モデル上は hi_東図書館A）の屋上の上にある、斜めの屋根（北東へ約27°で上がる）の先端。先端の面の高さは約51.95m
    "jet": Vector3(93.1, 52.58, -124.35),
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
const DEBUG_START_ON_E3_ROOF := false
# 一時的なデバッグ用。true のとき、ジェットだけは ITEM_PLACEMENTS の場所（斜めの屋根の先端）に置き、残りの種類のメダルを屋上（E3_ROOF_ITEM_POSITIONS）に並べる。false ならすべていつもの場所に置く
const DEBUG_ITEMS_ON_E3_ROOF := false
# 屋上（高さ 42.5m、高層棟は x 74〜88・z −156〜−140）の南寄り、+Z 向き
const E3_ROOF_START := Transform3D(Basis.IDENTITY, Vector3(81.0, 42.9, -154.0))
# DEBUG_ITEMS_ON_E3_ROOF が true のときに屋上に並べる、ジェット以外のメダルの位置（ITEMS のキーの順、ジェットを除く）。機体の 3m 先に横一列
const E3_ROOF_ITEM_POSITIONS := [
    Vector3(79.2, 43.13, -151.0),
    Vector3(80.4, 43.13, -151.0),
    Vector3(81.6, 43.13, -151.0),
    Vector3(82.8, 43.13, -151.0),
]
# ポップアップを開いてから、閉じる操作を受け付けるまでの時間 [ms]（開いた押下で閉じないため）
const CLOSE_DELAY_MSEC := 300

# ヒントの種類: 印を付けるパワーアップのキー。ヒント1はジャンプ力UPと二段ジャンプ、ヒント2はジェット（図書館の屋上の上）
const HINTS := {
    "hint1": {"keys": ["jump_up", "double_jump"]},
    "hint2": {"keys": ["jet"]},
}
# ヒントのメダルを置く場所（キーは場所のID、"hint" は HINTS のキー）。
# ヒント1の場所でも、ジャンプ系を両方持っていればヒント2を出す（choose_hint）
# 置く位置の高さの決め方は ITEM_PLACEMENTS と同じ（機体の基準点 + 0.4m）
const HINT_PLACEMENTS := {
    "w11_s": {"position": Vector3(-179.75, 22.83, -152.14), "hint": "hint1"},  # 西11号館 南の非常階段
    "w4_e": {"position": Vector3(-181.39, 22.60, -103.25), "hint": "hint1"},  # 西4号館 東の非常階段
    "w4_e2": {"position": Vector3(-198.76, 23.37, -107.95), "hint": "hint2"},  # 西4号館 東の非常階段（南隣）
    "w6_w": {"position": Vector3(-134.33, 24.93, -130.39), "hint": "hint2"},  # 西6号館 西の非常階段
    "w6_w2": {"position": Vector3(-138.36, 28.83, -133.16), "hint": "hint1"},  # 西6号館 もう1つの非常階段
    "w8_e": {"position": Vector3(-153.61, 27.83, 9.10), "hint": "hint1"},  # 西8号館 東の非常階段
    "w9_n": {"position": Vector3(-210.49, 27.23, -36.81), "hint": "hint1"},  # 西9号館 北の非常階段
    "port_ac_e": {"position": Vector3(-197.84, 18.13, 66.57), "hint": "hint1"},  # UECポートアライアンスセンター 東の非常階段
    "e_lissajous_w": {"position": Vector3(57.37, 13.03, 75.69), "hint": "hint1"},  # 東リサージュ 西の非常階段
    "e_intl_n": {"position": Vector3(117.73, 9.92, -336.11), "hint": "hint1"},  # 東国際交流会館 北の非常階段
    "e9_n": {"position": Vector3(147.75, 11.99, -250.99), "hint": "hint1"},  # 東9号館 北の非常階段
    "e8_e": {"position": Vector3(158.17, 13.35, -222.21), "hint": "hint1"},  # 東8号館 東の非常階段
    "e11": {"position": Vector3(18.55, 8.59, -196.69), "hint": "hint1"},  # 東11号館
}

var is_open: bool = false
# 取った種類
var _acquired := {}
# 使ったヒント（HINTS のキー）。取った種類と同じく、シーンが変わっても残す
var _used_hints := {}
# 触れたヒントのメダルの場所（HINT_PLACEMENTS のキー）。シーンが変わっても残し、置き直さない
var _used_hint_places := {}
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
    _fanfare_player.bus = "BGM"
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


# デバッグ用。ポップアップを出さずに、取った状態を直接切り替える
func set_acquired(key: String, on: bool) -> void:
    if not ITEMS.has(key):
        push_warning("パワーアップの種類が不明: %s" % key)
        return
    if on:
        _acquired[key] = true
    else:
        _acquired.erase(key)


# 場所のヒントのメダルに触れたときに出すヒントを決める。ヒント1の場所でも、ジャンプ系を両方持っていればヒント2にする
func choose_hint(place_id: String) -> String:
    var hint: String = HINT_PLACEMENTS[place_id]["hint"]
    if hint == "hint1" and has("jump_up") and has("double_jump"):
        return "hint2"
    return hint


# 場所のヒントのメダルに触れたことを覚えて、その場所のヒントを使う
func use_hint_place(place_id: String) -> void:
    if not HINT_PLACEMENTS.has(place_id):
        push_warning("ヒントの場所が不明: %s" % place_id)
        return
    _used_hint_places[place_id] = true
    use_hint(choose_hint(place_id))


# ヒントを使ったことを覚えて、マップに印を付ける（使ったヒントでも、別の場所で触れたら毎回印を付ける）
func use_hint(id: String) -> void:
    if not HINTS.has(id):
        push_warning("ヒントの種類が不明: %s" % id)
        return
    _used_hints[id] = true
    Map.reveal_hints(HINTS[id]["keys"])


# デバッグ用。使った状態を直接切り替える
func set_hint_used(id: String, on: bool) -> void:
    if not HINTS.has(id):
        push_warning("ヒントの種類が不明: %s" % id)
        return
    if on:
        _used_hints[id] = true
        Map.reveal_hints(HINTS[id]["keys"])
    else:
        _used_hints.erase(id)
        Map.hide_hints(HINTS[id]["keys"])


func is_hint_used(id: String) -> bool:
    return _used_hints.has(id)


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


# シーンが変わったので、ポップアップを初めに戻す（取った効果は残す）
func _reset() -> void:
    _queue.clear()
    _fanfare_player.stop()
    if is_open:
        is_open = false
        _root.visible = false
        get_tree().paused = false


# ITEM_PLACEMENTS の場所に、それぞれの種類のメダルを置く（機体を待たずに置く。取った種類は置かない）。HINT_PLACEMENTS の場所にヒントのメダルも置く（触れた場所は置かない）
func _place_items() -> void:
    # ヒントのメダル（触れていない場所だけ）
    for place_id in HINT_PLACEMENTS:
        if _used_hint_places.has(place_id):
            continue
        var hint_item = ITEM_SCRIPT.new()  # power_up_item.gd のノード（型は付けられない）
        hint_item.hint_place = place_id
        _shown_scene.add_child(hint_item)
        hint_item.global_position = HINT_PLACEMENTS[place_id]["position"]
    if DEBUG_ITEMS_ON_E3_ROOF:
        return
    for key in ITEM_PLACEMENTS:
        if _acquired.has(key):
            continue
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
            # ジェットは斜めの屋根の先端に置き、残りの種類を屋上に並べる
            var roof_keys := ITEMS.keys()
            roof_keys.erase("jet")
            for i in roof_keys.size():
                if _acquired.has(roof_keys[i]):
                    continue
                var roof_item = ITEM_SCRIPT.new()  # power_up_item.gd のノード（型は付けられない）
                roof_item.kind = roof_keys[i]
                _shown_scene.add_child(roof_item)
                roof_item.global_position = E3_ROOF_ITEM_POSITIONS[i]
            if not _acquired.has("jet"):
                var jet_item = ITEM_SCRIPT.new()  # power_up_item.gd のノード（型は付けられない）
                jet_item.kind = "jet"
                _shown_scene.add_child(jet_item)
                jet_item.global_position = ITEM_PLACEMENTS["jet"]
        return
    if DEBUG_START_AT_E3_STAIRS:
        _move_player_to(player, E3_STAIRS_START)
        for i in SPAWN_KEYS.size():
            if _acquired.has(SPAWN_KEYS[i]):
                continue
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
        if _acquired.has(SPAWN_KEYS[i]):
            continue
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
        # 高さ36pxに合わせて、幅は画像の縦横比から決める
        _hint_icon.custom_minimum_size.x = 36.0 * icon.get_width() / icon.get_height()
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
    dimmer.color = UiStyle.DIMMER_COLOR
    dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(dimmer)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(center)

    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.custom_minimum_size.x = 520
    var style := UiStyle.make_panel_style(true, 14, true)
    style.content_margin_left = 40
    style.content_margin_right = 40
    style.content_margin_top = 28
    style.content_margin_bottom = 24
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

    # 名前の左に赤い縦帯を置き、帯と名前の組を中央に寄せる
    var name_row := HBoxContainer.new()
    name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_row.alignment = BoxContainer.ALIGNMENT_CENTER
    name_row.add_theme_constant_override("separation", 14)
    box.add_child(name_row)

    var accent_bar := ColorRect.new()
    accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    accent_bar.color = UiStyle.ACCENT_COLOR
    accent_bar.custom_minimum_size = Vector2(6, 34)
    accent_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_row.add_child(accent_bar)

    _name_label = _make_label(28, UiStyle.TEXT_COLOR)
    name_row.add_child(_name_label)

    # 区切り線（パネルの内側いっぱい、上下 6）
    var divider_margin := MarginContainer.new()
    divider_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    divider_margin.add_theme_constant_override("margin_top", 6)
    divider_margin.add_theme_constant_override("margin_bottom", 6)
    box.add_child(divider_margin)

    var divider := ColorRect.new()
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    divider.color = UiStyle.LINE_COLOR
    divider.custom_minimum_size = Vector2(0, 1)
    divider_margin.add_child(divider)

    _desc_label = _make_label(19, UiStyle.TEXT_COLOR)
    box.add_child(_desc_label)

    var hint_row := HBoxContainer.new()
    hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
    hint_row.add_theme_constant_override("separation", 8)
    box.add_child(hint_row)

    _hint_icon = TextureRect.new()
    _hint_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hint_icon.custom_minimum_size = Vector2(0, 36)
    _hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _hint_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hint_row.add_child(_hint_icon)

    _hint_label = _make_label(17, UiStyle.TEXT_DIM_COLOR)
    _hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hint_row.add_child(_hint_label)


# 縁取りなしの中央ぞろえのラベル
func _make_label(font_size: int, color: Color) -> Label:
    var label := UiStyle.make_label("", font_size, color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return label

extends CanvasLayer
# パワーアップアイテム。取った種類を覚えて機体の効果に反映し、取ったときは一時停止して名前と説明のポップアップを出す。
# シーンが変わったら（Back to Start など）取った効果を空に戻す。

const FONT := preload("res://assets/fonts/noto_sans_cjk_jp_bold_ui.otf")
const ITEM_SCRIPT := preload("res://power_up_item.gd")

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
}

# 効果の倍率
const BOOST_CHARGE_MULTIPLIER := 2.0
const TORQUE_POWER_MULTIPLIER := 1.5
const TORQUE_SPEED_MULTIPLIER := 1.3

# true のとき、シーンが始まったら機体の前にメダルを3つ置く（デバッグ用）
const DEBUG_SPAWN_ITEMS := true
# 機体の前へ [m]、横へ [m]、機体の位置からの高さ [m]
const SPAWN_FORWARD := 6.0
const SPAWN_SIDE := 2.5
const SPAWN_HEIGHT := 1.0
const SPAWN_KEYS := ["boost_charge", "double_jump", "torque"]
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


func _ready() -> void:
    # メニュー（layer 20）より下、マップ（layer 18）より上に描く
    layer = 19
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_popup()


func has(key: String) -> bool:
    return _acquired.has(key)


# 取った種類を覚えて、ポップアップを出す（出ているときは順番待ちにする）
func acquire(key: String) -> void:
    if not ITEMS.has(key):
        push_warning("パワーアップの種類が不明: %s" % key)
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
        _need_spawn = DEBUG_SPAWN_ITEMS
    if _need_spawn:
        _spawn_debug_items()
    if is_open:
        _update_hint()


# シーンが変わったので、取った効果とポップアップを初めに戻す
func _reset() -> void:
    _acquired.clear()
    _queue.clear()
    if is_open:
        is_open = false
        _root.visible = false
        get_tree().paused = false


# 機体の前にメダルを3つ並べる。機体がまだ無ければ次のフレームで試す
func _spawn_debug_items() -> void:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player == null:
        return
    _need_spawn = false
    var forward := player.global_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var side := forward.cross(Vector3.UP).normalized()
    for i in SPAWN_KEYS.size():
        var item = ITEM_SCRIPT.new()  # power_up_item.gd のノード（型は付けられない）
        item.kind = SPAWN_KEYS[i]
        _shown_scene.add_child(item)
        item.global_position = player.global_position + forward * SPAWN_FORWARD \
                + side * SPAWN_SIDE * (i - 1) + Vector3.UP * SPAWN_HEIGHT


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

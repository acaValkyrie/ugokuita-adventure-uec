class_name LinkBoard
extends Node3D
## 近づくとジャンプのボタンでURLをブラウザで開く看板。
## ノードの +Z 方向が看板の表（プレイヤーが立つ側）、ノード原点がポスターの中心。

const FONT := preload("res://assets/fonts/noto_sans_cjk_jp_bold_ui.otf")

@export var url: String = "https://github.com/acaValkyrie"
@export var poster: Texture2D
## ポスターの大きさ [m]
@export var poster_size := Vector2(4.5, 1.8)
## 看板の左右方向に、この範囲内にいると「近い」[m]
@export var trigger_half_width := 2.75
## 看板の表側に、この距離まで「近い」[m]
@export var trigger_depth := 3.0
## 看板の上下方向に、この範囲内にいると「近い」[m]
@export var trigger_half_height := 2.5

# プレイヤーが近くにいる看板
static var _active: LinkBoard = null

var _layer: CanvasLayer
var _panel: PanelContainer
var _icon: TextureRect
var _label: Label


# 看板の近くにいるか（車のジャンプを止めるのに使う）
static func is_player_near() -> bool:
    return _active != null


# ヒントのパネルの画面上の矩形（表示中でないときは空）。タッチ運転の除外領域に使う
static func get_prompt_rect() -> Rect2:
    if _active != null and _active._layer.visible:
        return _active._panel.get_global_rect()
    return Rect2()


func _ready() -> void:
    # ポスター（QuadMesh の表は +Z なのでそのまま向ける）
    var quad := QuadMesh.new()
    quad.size = poster_size
    var material := StandardMaterial3D.new()
    material.albedo_texture = poster
    material.roughness = 0.8
    quad.material = material
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = quad
    add_child(mesh_instance)

    # ヒントのUI（画面下中央）
    _layer = CanvasLayer.new()
    _layer.layer = 10
    _layer.visible = false
    add_child(_layer)

    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.6)
    style.set_corner_radius_all(12)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    _panel.add_theme_stylebox_override("panel", style)
    _panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _panel.offset_bottom = -150.0
    _layer.add_child(_panel)

    var box := HBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    _panel.add_child(box)

    _icon = TextureRect.new()
    _icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _icon.custom_minimum_size = Vector2(0, 48)
    _icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    box.add_child(_icon)

    _label = Label.new()
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _label.add_theme_font_override("font", FONT)
    _label.add_theme_font_size_override("font_size", 28)
    _label.add_theme_color_override("font_color", Color.WHITE)
    _label.add_theme_color_override("font_outline_color", Color.BLACK)
    _label.add_theme_constant_override("outline_size", 6)
    box.add_child(_label)


func _physics_process(_delta: float) -> void:
    var near := false
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player != null:
        var local := global_transform.affine_inverse() * player.global_position
        near = (
            absf(local.x) <= trigger_half_width
            and local.z >= 0.0 and local.z <= trigger_depth
            and absf(local.y) <= trigger_half_height
        )

    if near:
        _active = self
    elif _active == self:
        _active = null
    _layer.visible = near

    if near and Input.is_action_just_pressed("jump") \
            and not GameMenu.is_open and not GameMenu.is_just_closed():
        _open()


func _process(_delta: float) -> void:
    if not _layer.visible:
        return
    # ボタンの種類は入力の切り替えで変わるので、毎フレーム合わせる
    var icon := ControlsHelp.get_jump_icon()
    _icon.visible = icon != null
    if icon != null:
        _icon.texture = icon
        # 高さ48pxに合わせて、幅は画像の縦横比から決める
        _icon.custom_minimum_size.x = 48.0 * icon.get_width() / icon.get_height()
        _label.text = "ウェブで開く"
    else:
        _label.text = "タップしてウェブで開く"


func _input(event: InputEvent) -> void:
    if not _layer.visible:
        return
    if event is InputEventScreenTouch and event.pressed \
            and _panel.get_global_rect().has_point(event.position):
        _open()
        get_viewport().set_input_as_handled()


# Web版では新しいタブで開く（ポップアップブロックを避けるため、必ずボタン操作の中で呼ぶ）
func _open() -> void:
    OS.shell_open(url)


func _exit_tree() -> void:
    if _active == self:
        _active = null

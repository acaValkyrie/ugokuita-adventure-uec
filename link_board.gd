class_name LinkBoard
extends Node3D
## 近づくと看板を開くボタン（interact。キーボードは E、コントローラは決定ボタン）でURLをブラウザで開く看板。
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
## 選択中の看板のポスターを縁取る白枠の太さ（ポスターの内側）[m]
@export var outline_width := 0.06

# リンクを開く操作をしてから、音を消して実際に開くまでの時間 [秒]。Web 版で、消した状態の音が出力に行き渡るのを待つ
const OPEN_DELAY_SEC := 0.1
# 開いてから、まだゲームにフォーカスがあるか確かめるまでの時間 [秒]
const RESTORE_CHECK_SEC := 0.5

# シーン内のすべての看板
static var _boards: Array[LinkBoard] = []
# プレイヤーの近くにいて、いちばん近い（選択中の）看板
static var _active: LinkBoard = null
# 選択を最後に更新した物理フレーム
static var _selected_frame := -1

var _layer: CanvasLayer
var _panel: PanelContainer
var _icon: TextureRect
var _label: Label
var _outline: Node3D
# リンクを開いている途中か（二重に開かない）
var _opening := false


# 看板の近くにいるか（車のジャンプを止めるのに使う）
static func is_player_near() -> bool:
    return _active != null


# ヒントのパネルの画面上の矩形（表示中でないときは空）。タッチ運転の除外領域に使う
static func get_prompt_rect() -> Rect2:
    if _active != null and _active._layer.visible and _active._panel.visible:
        return _active._panel.get_global_rect()
    return Rect2()


# 起動時のシェーダーの先読み（shader_warmup.gd）の間だけ、全看板の白枠とヒントを出して一度描かせる。
# 終えたら隠す（次の物理フレームで選択に合わせて出し直される）
static func set_warmup(on: bool) -> void:
    for board in _boards:
        board._outline.visible = on
        board._layer.visible = on
        if on:
            # 「ウェブで開く」の文字も含むので、両方の文言の字形がそろう
            board._label.text = "タップしてウェブで開く"


func _enter_tree() -> void:
    _boards.append(self)


# 近くにいる看板のうち、プレイヤーにいちばん近い1枚を選ぶ
static func _select_active() -> void:
    _active = null
    if _boards.is_empty():
        return
    var player := _boards[0].get_tree().get_first_node_in_group("player") as Node3D
    if player == null:
        return
    var best := INF
    for board in _boards:
        var distance := board._player_distance(player)
        if distance < best:
            best = distance
            _active = board


# プレイヤーまでの水平距離（近くにいないときは INF）
func _player_distance(player: Node3D) -> float:
    var local := global_transform.affine_inverse() * player.global_position
    var near := (
        absf(local.x) <= trigger_half_width
        and local.z >= 0.0 and local.z <= trigger_depth
        and absf(local.y) <= trigger_half_height
    )
    if not near:
        return INF
    return Vector2(local.x, local.z).length()


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

    # 選択中の白枠（ポスターの内側に四辺を重ねる）
    _outline = Node3D.new()
    _outline.visible = false
    add_child(_outline)
    var outline_material := StandardMaterial3D.new()
    outline_material.albedo_color = Color.WHITE
    outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var horizontal_size := Vector2(poster_size.x, outline_width)
    var vertical_size := Vector2(outline_width, poster_size.y - 2.0 * outline_width)
    var offset_y := (poster_size.y - outline_width) / 2.0
    var offset_x := (poster_size.x - outline_width) / 2.0
    _add_outline_bar(horizontal_size, Vector3(0.0, offset_y, 0.005), outline_material)
    _add_outline_bar(horizontal_size, Vector3(0.0, -offset_y, 0.005), outline_material)
    _add_outline_bar(vertical_size, Vector3(-offset_x, 0.0, 0.005), outline_material)
    _add_outline_bar(vertical_size, Vector3(offset_x, 0.0, 0.005), outline_material)

    # ヒントのUI（ポスターの下に追従させる）
    _layer = CanvasLayer.new()
    _layer.layer = 10
    _layer.visible = false
    add_child(_layer)

    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := UiStyle.make_panel_style(false, 10)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    _panel.add_theme_stylebox_override("panel", style)
    _layer.add_child(_panel)

    var box := HBoxContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    _panel.add_child(box)

    _icon = TextureRect.new()
    _icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _icon.custom_minimum_size = Vector2(0, 40)
    _icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    box.add_child(_icon)

    _label = UiStyle.make_label("", 22)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    box.add_child(_label)


func _add_outline_bar(bar_size: Vector2, bar_position: Vector3, material: Material) -> void:
    var quad := QuadMesh.new()
    quad.size = bar_size
    quad.material = material
    var bar := MeshInstance3D.new()
    bar.mesh = quad
    bar.position = bar_position
    _outline.add_child(bar)


func _physics_process(_delta: float) -> void:
    # 選択は全看板で1回だけ、そのフレームで最初に処理された看板が更新する
    if Engine.get_physics_frames() != _selected_frame:
        _selected_frame = Engine.get_physics_frames()
        _select_active()

    var selected := _active == self
    _layer.visible = selected
    _outline.visible = selected

    if selected and Input.is_action_just_pressed("interact") \
            and not GameMenu.is_open and not GameMenu.is_just_closed() \
            and not PowerUps.is_just_closed():
        _open()


func _process(_delta: float) -> void:
    if not _layer.visible:
        return
    # ボタンの種類は入力の切り替えで変わるので、毎フレーム合わせる
    var icon := ControlsHelp.get_interact_icon()
    _icon.visible = icon != null
    if icon != null:
        _icon.texture = icon
        # 高さ40pxに合わせて、幅は画像の縦横比から決める
        _icon.custom_minimum_size.x = 40.0 * icon.get_width() / icon.get_height()
        _label.text = "ウェブで開く"
    else:
        _label.text = "タップしてウェブで開く"

    # ポスターの下辺の中央の少し下を画面に投影し、パネルの上辺の中央をそこに置く
    var camera := get_viewport().get_camera_3d()
    var point := global_transform * Vector3(0.0, -poster_size.y / 2.0 - 0.15, 0.0)
    if camera == null or camera.is_position_behind(point):
        _panel.visible = false
        return
    _panel.visible = true
    # 文言が変わるとサイズも変わるので、位置の前に合わせ直す
    _panel.reset_size()
    var screen_point := camera.unproject_position(point)
    var viewport_size := get_viewport().get_visible_rect().size
    var margin := 16.0
    var target := screen_point - Vector2(_panel.size.x / 2.0, 0.0)
    # 画面からはみ出さないようにする
    target.x = clampf(target.x, margin, viewport_size.x - _panel.size.x - margin)
    target.y = clampf(target.y, margin, viewport_size.y - _panel.size.y - margin)
    _panel.position = target


func _input(event: InputEvent) -> void:
    if not _layer.visible:
        return
    if event is InputEventScreenTouch and event.pressed and _panel.visible \
            and _panel.get_global_rect().has_point(event.position):
        _open()
        get_viewport().set_input_as_handled()


# Web版では新しいタブで開く（ポップアップブロックを避けるため、必ずボタン操作の中で呼ぶ。少し待つのはブラウザが許す範囲）。
# 開く前にすべての音を消す。Web 版では別のタブが前に出るとゲームが止まり、そのとき鳴っていた音が鳴りっぱなしになるため
func _open() -> void:
    if _opening:
        return
    _opening = true
    GameMenu.mute_all()
    await get_tree().create_timer(OPEN_DELAY_SEC, true).timeout
    OS.shell_open(url)
    # 開いたあともゲームにフォーカスがある（開けなかったなど）ときは音を戻す。別のタブやブラウザが前に出ていれば、戻ったときに GameMenu._notification で戻る
    await get_tree().create_timer(RESTORE_CHECK_SEC, true).timeout
    _opening = false
    if DisplayServer.window_is_focused():
        GameMenu.restore_volume()


func _exit_tree() -> void:
    _boards.erase(self)
    if _active == self:
        _active = null

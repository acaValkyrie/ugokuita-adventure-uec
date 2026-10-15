extends CanvasLayer
# 全体マップ。左上のマップボタン、Mキー、コントローラの上のボタンで開閉する。
# 開いている間はゲームを一時停止し、ステージを真上から撮った画像の上に、
# 自分の位置と向き、号館の名前、看板の場所を重ねて表示する。

# マップ画像が写しているワールドの x・z の範囲（x が右、z が下＝地図の上が北の -Z）
const WORLD_RECT := Rect2(-316.0, -370.0, 536.0, 516.0)
const MAP_TEXTURE := preload("res://assets/map/campus_map.png")
const LABEL_FONT := preload("res://assets/fonts/noto_sans_cjk_jp_bold_ui.otf")
# 画面の端から地図までの余白
const SCREEN_MARGIN := 48.0
# マップボタンとメニューボタンの間隔
const BUTTON_GAP := 12
# 号館の名前のノード名の接頭辞と、当たり判定用ノードの接尾辞
const BUILDING_PREFIX := "hi_"
const COLLISION_SUFFIX := "_col"
const LABEL_FONT_SIZE := 14
const LABEL_OUTLINE_SIZE := 4
# 看板のマーカー
const BOARD_COLOR := Color("#ff9800")
const BOARD_RADIUS := 7.0
const OUTLINE_COLOR := Color.WHITE
const OUTLINE_WIDTH := 2.0
# 自分の矢印
const PLAYER_COLOR := Color("#e53935")
const ARROW_LENGTH := 22.0
const ARROW_WIDTH := 16.0

var is_open: bool = false
var _button: Button
var _overlay: Control
var _texture_rect: TextureRect
var _label_root: Control
var _marker_layer: Control
# 地図の画像を表示している画面上の矩形
var _map_rect := Rect2()
# 閉じたときの物理フレーム番号
var _closed_physics_frame: int = -100


func _ready() -> void:
    layer = 18
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_overlay()
    _build_button()
    get_viewport().size_changed.connect(_layout)


# 左上のマップボタンの画面上の矩形（タッチ運転の除外領域に使う）
func get_button_rect() -> Rect2:
    return _button.get_global_rect()


func open() -> void:
    if is_open:
        return
    is_open = true
    _layout()
    _rebuild_labels()
    _overlay.visible = true
    get_tree().paused = true


# unpause を false にすると、一時停止を解除せずに閉じる（メニューが開いたとき用）
func close(unpause: bool = true) -> void:
    if not is_open:
        return
    is_open = false
    _overlay.visible = false
    if unpause:
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


func _process(_delta: float) -> void:
    if not is_open:
        return
    # メニューが開いたらマップは閉じる（一時停止はメニュー側が持つ）
    if GameMenu.is_open:
        close(false)
        return
    _marker_layer.queue_redraw()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("map") and not event.is_echo():
        # メニューが開いているときは開かない
        if is_open or not GameMenu.is_open:
            toggle()
            get_viewport().set_input_as_handled()
        return
    if not is_open:
        return
    # 開いている間は、メニューのボタンでも閉じる（メニューまで開かないよう、ここで処理済みにする）
    if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
        close()
        get_viewport().set_input_as_handled()
    # タッチでは、画面のどこをタップしても閉じる
    elif event is InputEventScreenTouch and event.pressed:
        close()
        get_viewport().set_input_as_handled()


# 背景、地図画像、号館の名前、看板・自分のマーカーを重ねた画面
func _build_overlay() -> void:
    _overlay = Control.new()
    _overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.visible = false
    add_child(_overlay)

    var dimmer := ColorRect.new()
    dimmer.color = Color(0, 0, 0, 0.75)
    dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.add_child(dimmer)

    _texture_rect = TextureRect.new()
    _texture_rect.texture = MAP_TEXTURE
    _texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
    _texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.add_child(_texture_rect)

    _label_root = Control.new()
    _label_root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _label_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.add_child(_label_root)

    _marker_layer = Control.new()
    _marker_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    _marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _marker_layer.draw.connect(_on_marker_draw)
    _overlay.add_child(_marker_layer)


# 左上のマップボタン（メニューボタンの右隣）。地図が開いても押せるよう、画面より後に追加する
func _build_button() -> void:
    _button = Button.new()
    _button.focus_mode = Control.FOCUS_NONE
    _button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    var left := GameMenu.MARGIN + GameMenu.BUTTON_SIZE + BUTTON_GAP
    _button.offset_left = left
    _button.offset_right = left + GameMenu.BUTTON_SIZE
    _button.offset_top = GameMenu.MARGIN
    _button.offset_bottom = GameMenu.MARGIN + GameMenu.BUTTON_SIZE
    # 見た目はアイコン側で描くので、ボタン自体の枠は空にする
    var empty := StyleBoxEmpty.new()
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        _button.add_theme_stylebox_override(state, empty)
    _button.pressed.connect(toggle)
    add_child(_button)

    var icon := Control.new()
    icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.draw.connect(_on_icon_draw.bind(icon))
    _button.add_child(icon)

    # 押している間は少し暗くする
    _button.button_down.connect(func() -> void: icon.modulate = Color(0.8, 0.8, 0.8))
    _button.button_up.connect(func() -> void: icon.modulate = Color.WHITE)


# ボタンの見た目（メニューボタンと同じ角丸の枠と、折りたたんだ地図のアイコン）
func _on_icon_draw(icon: Control) -> void:
    var center := icon.size * 0.5
    var face := StyleBoxFlat.new()
    face.bg_color = GameMenu.FACE_COLOR
    face.border_color = GameMenu.RING_COLOR
    face.set_border_width_all(6)
    face.set_corner_radius_all(14)
    face.anti_aliasing = true
    icon.draw_style_box(face, Rect2(Vector2(2.0, 2.0), icon.size - Vector2(4.0, 4.0)))
    # 3枚のパネルが交互に傾いたジグザグの輪郭（上の辺と下の辺を、同じ向きにずらす）
    var xs := [-18.0, -6.0, 6.0, 18.0]
    var top_ys := [-8.0, -14.0, -8.0, -14.0]
    var bottom_ys := [14.0, 8.0, 14.0, 8.0]
    var outline := PackedVector2Array()
    for i in xs.size():
        outline.append(center + Vector2(xs[i], top_ys[i]))
    for i in range(xs.size() - 1, -1, -1):
        outline.append(center + Vector2(xs[i], bottom_ys[i]))
    outline.append(outline[0])
    icon.draw_polyline(outline, GameMenu.RING_COLOR, 5.0, true)
    # 折り目
    for i in [1, 2]:
        icon.draw_line(center + Vector2(xs[i], top_ys[i]), center + Vector2(xs[i], bottom_ys[i]), GameMenu.RING_COLOR, 5.0, true)


# 画面の大きさに合わせて、地図を余白つきで縦横比を保って最大に置く
func _layout() -> void:
    var screen := get_viewport().get_visible_rect().size
    var avail := screen - Vector2.ONE * SCREEN_MARGIN * 2.0
    var tex_size := MAP_TEXTURE.get_size()
    var scale_factor := minf(avail.x / tex_size.x, avail.y / tex_size.y)
    var size := tex_size * scale_factor
    _map_rect = Rect2((screen - size) * 0.5, size)
    _texture_rect.position = _map_rect.position
    _texture_rect.size = _map_rect.size
    if is_open:
        _rebuild_labels()


# ワールドの座標（x, z）を、画面上の地図の位置にする
func _world_to_map(world: Vector3) -> Vector2:
    var ratio := Vector2(
            (world.x - WORLD_RECT.position.x) / WORLD_RECT.size.x,
            (world.z - WORLD_RECT.position.y) / WORLD_RECT.size.y)
    return _map_rect.position + ratio * _map_rect.size


# 号館の名前のラベルを置き直す（開くたびにシーンから探す）
func _rebuild_labels() -> void:
    for child in _label_root.get_children():
        child.queue_free()
    var scene := get_tree().current_scene
    if scene == null:
        return
    _add_building_labels(scene)


# 名前が hi_ で始まり _col で終わらない Node3D を探し、メッシュ全体の中心に名前を置く
func _add_building_labels(node: Node) -> void:
    for child in node.get_children():
        if child is Node3D and child.name.begins_with(BUILDING_PREFIX) \
                and not child.name.ends_with(COLLISION_SUFFIX):
            _add_label(child)
        else:
            _add_building_labels(child)


func _add_label(building: Node3D) -> void:
    var bounds := _merged_aabb(building)
    if bounds.size == Vector3.ZERO:
        return
    var label := Label.new()
    label.text = String(building.name).trim_prefix(BUILDING_PREFIX)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_override("font", LABEL_FONT)
    label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
    label.add_theme_color_override("font_color", Color.WHITE)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", LABEL_OUTLINE_SIZE)
    _label_root.add_child(label)
    label.position = _world_to_map(bounds.get_center()) - label.get_minimum_size() * 0.5


# 配下（自身を含む）の MeshInstance3D のワールド空間の AABB を合わせたもの
func _merged_aabb(root: Node) -> AABB:
    var result := AABB()
    var found := false
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
            var mesh_instance := node as MeshInstance3D
            var box := mesh_instance.global_transform * mesh_instance.get_aabb()
            result = box if not found else result.merge(box)
            found = true
        stack.append_array(node.get_children())
    return result


# 看板（オレンジの丸）と自分（向きを指す赤い矢印）を描く
func _on_marker_draw() -> void:
    for board in LinkBoard._boards:
        var pos := _world_to_map(board.global_position)
        _marker_layer.draw_circle(pos, BOARD_RADIUS, BOARD_COLOR, true, -1.0, true)
        _marker_layer.draw_arc(pos, BOARD_RADIUS, 0.0, TAU, 24, OUTLINE_COLOR, OUTLINE_WIDTH, true)
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player == null:
        return
    var center := _world_to_map(player.global_position)
    # 機体の前は global_basis.z
    var forward := Vector2(player.global_basis.z.x, player.global_basis.z.z)
    var dir := forward.normalized() if forward.length() > 0.001 else Vector2.UP
    var side := dir.orthogonal()
    var points := PackedVector2Array([
        center + dir * ARROW_LENGTH * 0.5,
        center - dir * ARROW_LENGTH * 0.5 + side * ARROW_WIDTH * 0.5,
        center - dir * ARROW_LENGTH * 0.5 - side * ARROW_WIDTH * 0.5,
    ])
    _marker_layer.draw_colored_polygon(points, PLAYER_COLOR)
    var outline := points.duplicate()
    outline.append(points[0])
    _marker_layer.draw_polyline(outline, OUTLINE_COLOR, OUTLINE_WIDTH, true)

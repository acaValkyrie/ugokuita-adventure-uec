extends CanvasLayer
# 画面右上のミニマップ。自分を中心に120m四方の地図を、カメラの前方が上になるように回して表示する。
# 看板の場所と自分の矢印、北の印を重ね、押すと全体マップを開く。

const SIZE := 180.0  # 表示の大きさ（px）
const TOP := 100.0  # 画面の上端から（時速の表示とタッチ用リセットボタンの下）
const MARGIN := 16.0  # 画面の右端から
const SPAN_M := 120.0  # 表示する範囲（m四方）
const MAP_TEXTURE := preload("res://assets/map/campus_map.png")
const BACK_COLOR := Color(0.1, 0.1, 0.1, 0.8)
const FRAME_COLOR := Color(1, 1, 1, 0.9)
const FRAME_WIDTH := 3.0
# 看板のマーカー
const BOARD_RADIUS := 5.0
# 目的地のマーカー（範囲の外では、枠からこの距離の内側に寄せる）
const MARKER_SCALE := 0.8
const MARKER_INSET := 12.0
# 自分の矢印
const ARROW_LENGTH := 18.0
const ARROW_WIDTH := 13.0
# 北の印
const NORTH_FONT_SIZE := 16
const NORTH_OUTLINE_SIZE := 4
const NORTH_INSET := 14.0

var _view: Control
# ワールドの xz を画面に回す角度（カメラの前方が上になる）
var _angle: float = 0.0


func _ready() -> void:
    # 全体マップやメニューで一時停止している間も、表示の切り替えを行うため
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 10
    _view = Control.new()
    _view.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _view.offset_right = -MARGIN
    _view.offset_left = -MARGIN - SIZE
    _view.offset_top = TOP
    _view.offset_bottom = TOP + SIZE
    _view.clip_contents = true
    _view.mouse_filter = Control.MOUSE_FILTER_STOP
    _view.draw.connect(_on_draw)
    _view.gui_input.connect(_on_gui_input)
    add_child(_view)


# ミニマップの画面上の矩形（タッチ運転の除外領域に使う）。表示していなければ空
func get_rect() -> Rect2:
    if _view.visible:
        return _view.get_global_rect()
    return Rect2()


func _process(_delta: float) -> void:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    _view.visible = player != null and not Map.is_open
    if _view.visible:
        _view.queue_redraw()


# 押したら全体マップを開く
func _on_gui_input(event: InputEvent) -> void:
    var pressed := false
    if event is InputEventMouseButton:
        pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
    elif event is InputEventScreenTouch:
        pressed = event.pressed
    if pressed:
        Map.open()
        _view.accept_event()


# ワールドの xz を、ミニマップ上の点にする
func _to_view(xz: Vector2) -> Vector2:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    var p := Vector2(player.global_position.x, player.global_position.z)
    return _view.size * 0.5 + (xz - p).rotated(_angle) * (SIZE / SPAN_M)


func _on_draw() -> void:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player == null:
        return
    var center := _view.size * 0.5
    var k := SIZE / SPAN_M
    var p := Vector2(player.global_position.x, player.global_position.z)

    # カメラの前方が画面の上を向く角度
    _angle = 0.0
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        var f := -camera.global_basis.z
        _angle = -PI / 2.0 - atan2(f.z, f.x)

    _view.draw_rect(Rect2(Vector2.ZERO, _view.size), BACK_COLOR)

    # 地図の画像（自分の位置が中心に来るよう回して置く）
    _view.draw_set_transform(center, _angle, Vector2(k, k))
    _view.draw_texture_rect(MAP_TEXTURE, Rect2(Map.WORLD_RECT.position - p, Map.WORLD_RECT.size), false)
    _view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    # 看板（オレンジの丸）
    for board in LinkBoard._boards:
        var pos := _to_view(Vector2(board.global_position.x, board.global_position.z))
        _view.draw_circle(pos, BOARD_RADIUS, Map.BOARD_COLOR, true, -1.0, true)
        _view.draw_arc(pos, BOARD_RADIUS, 0.0, TAU, 24, Map.OUTLINE_COLOR, Map.OUTLINE_WIDTH, true)

    # 目的地のマーカー（範囲の外なら、方向を保ったまま枠の内側に寄せる）
    if Map.has_marker:
        var pos := _to_view(Map.marker_xz)
        var offset := pos - center
        var limit := SIZE * 0.5 - MARKER_INSET
        var over := maxf(absf(offset.x), absf(offset.y))
        if over > limit:
            pos = center + offset * (limit / over)
        Map.draw_marker_pin(_view, pos, MARKER_SCALE)

    # 自分（機体の前を指す赤い矢印）。機体の前は global_basis.z
    var forward := Vector2(player.global_basis.z.x, player.global_basis.z.z).rotated(_angle)
    var dir := forward.normalized() if forward.length() > 0.001 else Vector2.UP
    var side := dir.orthogonal()
    var points := PackedVector2Array([
        center + dir * ARROW_LENGTH * 0.5,
        center - dir * ARROW_LENGTH * 0.5 + side * ARROW_WIDTH * 0.5,
        center - dir * ARROW_LENGTH * 0.5 - side * ARROW_WIDTH * 0.5,
    ])
    _view.draw_colored_polygon(points, Map.PLAYER_COLOR)
    var outline := points.duplicate()
    outline.append(points[0])
    _view.draw_polyline(outline, Map.OUTLINE_COLOR, Map.OUTLINE_WIDTH, true)

    # 北の印（文字の中心が north_pos に来るようにベースラインをずらす）
    var font := ThemeDB.fallback_font
    var north_pos := center + Vector2(0.0, -1.0).rotated(_angle) * (SIZE * 0.5 - NORTH_INSET)
    var text_size := font.get_string_size("N", HORIZONTAL_ALIGNMENT_CENTER, -1.0, NORTH_FONT_SIZE)
    var base := Vector2(north_pos.x - text_size.x * 0.5, north_pos.y + (font.get_ascent(NORTH_FONT_SIZE) - font.get_descent(NORTH_FONT_SIZE)) * 0.5)
    _view.draw_string_outline(font, base, "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, NORTH_FONT_SIZE, NORTH_OUTLINE_SIZE, Color.BLACK)
    _view.draw_string(font, base, "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, NORTH_FONT_SIZE, Color.WHITE)

    # 枠
    _view.draw_rect(Rect2(Vector2.ZERO, _view.size), FRAME_COLOR, false, FRAME_WIDTH)

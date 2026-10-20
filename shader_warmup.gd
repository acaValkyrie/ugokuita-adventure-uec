extends CanvasLayer
# 起動直後に、読み込み中の画面の裏でキャンパス全体を一度描いて、シェーダーを先に作らせる。
# Compatibility では初めて描いた瞬間にシェーダーを作るので、走り出してから止まるのを防ぐ。
# 一時的なカメラを上空のタイルごとと、地上の4方向に向けて、各視点を数フレームずつ見せる。
# 最後に前のカメラの視点で、プレイヤーの効果（ドリフトの帯、火花、ジェット、集中線）も一度描く。
# URL の ?nowarm で飛ばせる（render_quality.gd）。

# タイルに分ける範囲は Map.WORLD_RECT（x / z の範囲）を使う
# 1辺のタイルの数
const GRID := 4
# 上空の視点のカメラの高さ（y=0 から）
const TILE_HEIGHT := 150.0
# 地上の視点の高さ（前のカメラが無いとき、プレイヤーの上にこの分足す）
const GROUND_VIEW_HEIGHT := 1.5
# 各視点を描いて見せるフレーム数
const FRAMES_PER_VIEW := 2
# 効果の視点を見せるフレーム数（粒の出始めを描かせるため長め）
const EFFECT_FRAMES := 4
# メインのシーンとプレイヤーが揃ってから待つフレーム数（パワーアップなどがシーンの開始時に出るため）
const START_WAIT_FRAMES := 3

enum State { WAIT_SCENE, WAIT_FRAMES, RUNNING }

var _state := State.WAIT_SCENE
# 一度でも終えた（または飛ばした）ら true。起動ごとに1回だけ動かす
var _done := false
var _wait_frames := 0
var _camera: Camera3D
var _prev_camera: Camera3D
var _views: Array[Transform3D] = []
var _view_index := 0
var _view_frames := 0
# 効果の視点の番号（無ければ -1）
var _effects_view_index := -1
var _effects_active := false
var _saved_particles: Array = []
var _warm_meshes: Array[MeshInstance3D] = []
var _screen: ColorRect
var _label: Label


func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_screen()


func _process(_delta: float) -> void:
    if _done:
        set_process(false)
        return
    match _state:
        State.WAIT_SCENE:
            if get_tree().current_scene != null \
                    and get_tree().get_first_node_in_group("player") != null:
                _state = State.WAIT_FRAMES
                _wait_frames = 0
        State.WAIT_FRAMES:
            _wait_frames += 1
            if _wait_frames >= START_WAIT_FRAMES:
                _start()
        State.RUNNING:
            _step()


# 読み込み中の画面（全面の不透明な背景と、中央の文字）。入力は受け止める
func _setup_screen() -> void:
    _screen = ColorRect.new()
    _screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    _screen.color = UiStyle.PANEL_SOLID_COLOR
    _screen.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_screen)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _screen.add_child(center)
    _label = UiStyle.make_label("Loading...", 24)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(_label)
    _screen.visible = false


func _start() -> void:
    if RenderQuality.skip_warmup:
        _finish_without_run()
        return
    _screen.visible = true
    get_tree().paused = true
    _prev_camera = get_viewport().get_camera_3d()
    _camera = Camera3D.new()
    _camera.far = 3000.0
    _camera.fov = 75.0
    _camera.process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().current_scene.add_child(_camera)
    _camera.make_current()
    _build_views()
    _view_index = 0
    _view_frames = 0
    _apply_view()
    _state = State.RUNNING


func _finish_without_run() -> void:
    _done = true
    set_process(false)


# 視点の一覧を先に作る（上空のタイルと、地上の4方向）
func _build_views() -> void:
    _views.clear()
    var rect: Rect2 = Map.WORLD_RECT
    var tile := rect.size / float(GRID)
    for iz in GRID:
        for ix in GRID:
            var center := rect.position + Vector2((ix + 0.5) * tile.x, (iz + 0.5) * tile.y)
            var pos := Vector3(center.x, TILE_HEIGHT, center.y)
            # X 軸まわりに -90 度回して、-Z を真下に向ける
            _views.append(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), pos))
    var ground_pos: Vector3
    if is_instance_valid(_prev_camera):
        ground_pos = _prev_camera.global_position
    else:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        ground_pos = player.global_position + Vector3.UP * GROUND_VIEW_HEIGHT
    for yaw in [0.0, 90.0, 180.0, 270.0]:
        _views.append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), ground_pos))
    # 最後に、前のカメラそのものの視点（効果を描く）
    _effects_view_index = -1
    if is_instance_valid(_prev_camera):
        _effects_view_index = _views.size()
        _views.append(_prev_camera.global_transform)


func _apply_view() -> void:
    _camera.global_transform = _views[_view_index]
    _label.text = "Loading...  %d / %d" % [_view_index + 1, _views.size()]
    if _view_index == _effects_view_index:
        _begin_effects()


# 各視点を FRAMES_PER_VIEW フレーム見せてから次へ進む
func _step() -> void:
    _view_frames += 1
    var frames := EFFECT_FRAMES if _view_index == _effects_view_index else FRAMES_PER_VIEW
    if _view_frames < frames:
        return
    _view_frames = 0
    if _view_index == _effects_view_index:
        _end_effects()
    _view_index += 1
    if _view_index >= _views.size():
        _finish()
    else:
        _apply_view()


func _finish() -> void:
    if _effects_active:
        _end_effects()
    _camera.queue_free()
    if is_instance_valid(_prev_camera):
        _prev_camera.make_current()
    get_tree().paused = false
    _screen.visible = false
    _done = true
    set_process(false)


# プレイヤーの効果を一度描かせる（粒を出し、帯の材質に三角形を足し、集中線を出す）
func _begin_effects() -> void:
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return
    for node in player.find_children("*", "CPUParticles3D", true, false):
        var p := node as CPUParticles3D
        _saved_particles.append([p, p.process_mode, p.emitting])
        # 警告中は木が止まっているので、粒だけ動かす
        p.process_mode = Node.PROCESS_MODE_ALWAYS
        p.emitting = true
    for node in player.find_children("*", "MeshInstance3D", true, false):
        var mi := node as MeshInstance3D
        if not (mi.mesh is ImmediateMesh):
            continue
        # 帯は top_level で単位の変換なので、頂点は世界座標
        var p: Vector3 = (player as Node3D).global_position + Vector3.UP * 0.05
        var im := mi.mesh as ImmediateMesh
        im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
        for v in [p, p + Vector3(0.3, 0.0, 0.0), p + Vector3(0.0, 0.0, 0.3)]:
            im.surface_set_color(Color(1.0, 0.2, 0.1, 0.5))
            im.surface_add_vertex(v)
        im.surface_end()
        _warm_meshes.append(mi)
    # 集中線は木と一緒に止まっているので、隠されない
    SpeedLines._rect.visible = true
    _effects_active = true


# 効果を元に戻す
func _end_effects() -> void:
    for entry in _saved_particles:
        var p := entry[0] as CPUParticles3D
        if not is_instance_valid(p):
            continue
        p.emitting = false
        p.restart()
        p.emitting = false
        p.process_mode = entry[1]
        p.emitting = entry[2]
    _saved_particles.clear()
    for mi in _warm_meshes:
        if is_instance_valid(mi):
            (mi.mesh as ImmediateMesh).clear_surfaces()
    _warm_meshes.clear()
    SpeedLines._rect.visible = false
    _effects_active = false

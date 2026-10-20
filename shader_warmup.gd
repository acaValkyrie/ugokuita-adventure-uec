extends CanvasLayer
# 起動直後に、読み込み中の画面の裏でキャンパス全体を一度描いて、シェーダーを先に作らせる。
# Compatibility では初めて描いた瞬間にシェーダーを作るので、走り出してから止まるのを防ぐ。
# 一時的なカメラを上空のタイルごとと、地上の4方向に向けて、各視点を数フレームずつ見せる。
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


func _apply_view() -> void:
    _camera.global_transform = _views[_view_index]
    _label.text = "Loading...  %d / %d" % [_view_index + 1, _views.size()]


# 各視点を FRAMES_PER_VIEW フレーム見せてから次へ進む
func _step() -> void:
    _view_frames += 1
    if _view_frames < FRAMES_PER_VIEW:
        return
    _view_frames = 0
    _view_index += 1
    if _view_index >= _views.size():
        _finish()
    else:
        _apply_view()


func _finish() -> void:
    _camera.queue_free()
    if is_instance_valid(_prev_camera):
        _prev_camera.make_current()
    get_tree().paused = false
    _screen.visible = false
    _done = true
    set_process(false)

extends CanvasLayer
# 起動直後に、読み込み中の画面の裏でキャンパス全体を一度描いて、シェーダーを先に作らせる。
# Compatibility では初めて描いた瞬間にシェーダーを作るので、走り出してから止まるのを防ぐ。
# 一時的なカメラを上空のタイルごとと、地上の4方向に向けて、各視点を数フレームずつ見せる。
# 最後に前のカメラの視点で、プレイヤーの効果（ドリフトの帯、火花、ジェット、集中線）も一度描く。
# 看板の白枠とヒント（近づくまで隠れている）も、先読みの間だけ出して描かせる。

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
# シーンはあるのにプレイヤーが居ないまま、このフレーム数たったら先読みをやめて画面を消す
const NO_PLAYER_GIVE_UP_FRAMES := 30

# 読み込み画面の見た目（DOS のような黒い画面に文字が並ぶ）
const TERM_FONT := preload("res://assets/fonts/vt323/VT323-Regular.ttf")
const TERM_COLOR := Color("#c0c0c0")
const BAR_COLOR := Color("#e0182d")
const TERM_FONT_SIZE := 32
const TERM_MARGIN := 32.0
# 進み具合の棒の文字数
const BAR_CHARS := 20

enum State { WAIT_SCENE, WAIT_FRAMES, RUNNING }

var _state := State.WAIT_SCENE
# 一度でも終えたら true。起動ごとに1回だけ動かす
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
# シーンに置いた効果（噴水など）の粒の、元の process_mode
var _saved_world_particles: Array = []
var _warm_meshes: Array[MeshInstance3D] = []
var _screen: ColorRect
var _term: RichTextLabel


func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_screen()
    _render_term()


# 起動時の先読み（読み込み画面）の途中か。この間はメニューとマップを開かせない
func is_loading() -> bool:
    return not _done


func _process(_delta: float) -> void:
    if _done:
        set_process(false)
        return
    match _state:
        State.WAIT_SCENE:
            _render_term()
            if get_tree().current_scene != null:
                if get_tree().get_first_node_in_group("player") != null:
                    _state = State.WAIT_FRAMES
                    _wait_frames = 0
                else:
                    _wait_frames += 1
                    if _wait_frames >= NO_PLAYER_GIVE_UP_FRAMES:
                        _screen.visible = false
                        _done = true
                        set_process(false)
                        return
        State.WAIT_FRAMES:
            _render_term()
            _wait_frames += 1
            if _wait_frames >= START_WAIT_FRAMES:
                _start()
        State.RUNNING:
            _render_term()
            _step()


# 読み込み中の画面（黒い背景に、DOS のコマンドの文字が並ぶ）。起動直後から出して、ゲーム画面が見えないようにする。入力は受け止める
func _setup_screen() -> void:
    _screen = ColorRect.new()
    _screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    _screen.color = Color(0, 0, 0)
    _screen.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_screen)
    _term = RichTextLabel.new()
    _term.set_anchors_preset(Control.PRESET_FULL_RECT)
    _term.offset_left = TERM_MARGIN
    _term.offset_top = TERM_MARGIN
    _term.offset_right = -TERM_MARGIN
    _term.offset_bottom = -TERM_MARGIN
    _term.bbcode_enabled = true
    _term.scroll_active = false
    _term.fit_content = false
    _term.autowrap_mode = TextServer.AUTOWRAP_OFF
    _term.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _term.add_theme_font_override("normal_font", TERM_FONT)
    _term.add_theme_font_size_override("normal_font_size", TERM_FONT_SIZE)
    _term.add_theme_color_override("default_color", TERM_COLOR)
    _screen.add_child(_term)


# 始まった段階だけ、コマンドと進み具合の棒を並べる。最後の行はまたたくカーソル
func _render_term() -> void:
    var phases: Array = [
        ["LOAD CAMPUS.DAT", 0, GRID * GRID],
        ["SCAN GROUND.DAT", GRID * GRID, 4],
    ]
    if _effects_view_index >= 0:
        phases.append(["INIT EFFECTS.SYS", _effects_view_index, 1])
    var text := "UGOKUITA-OS v1.0\n(C) Ugokuita Project\n\n"
    for phase in phases:
        var start: int = phase[1]
        var total: int = phase[2]
        if _view_index < start:
            break
        var done := clampi(_view_index - start, 0, total)
        var filled := BAR_CHARS * done / total
        text += "C:\\> %s\n" % phase[0]
        text += "  [lb][color=#%s]%s[/color]%s] %d/%d" % [
                BAR_COLOR.to_html(false), "#".repeat(filled),
                ".".repeat(BAR_CHARS - filled), done, total]
        if done >= total:
            text += " OK"
        text += "\n"
    # カーソルは0.5秒ごとに出たり消えたりする
    text += "_" if (Time.get_ticks_msec() / 500) % 2 == 0 else " "
    _term.text = text


func _start() -> void:
    _screen.visible = true
    get_tree().paused = true
    _prev_camera = get_viewport().get_camera_3d()
    # 噴水など、シーンに置いた粒もツリーを止めている間は動かないので、上空と地上の視点で描かれるよう動かす
    for node in get_tree().get_nodes_in_group("warmup_particles"):
        _saved_world_particles.append([node, node.process_mode])
        node.process_mode = Node.PROCESS_MODE_ALWAYS
    _camera = Camera3D.new()
    _camera.far = 3000.0
    _camera.fov = 75.0
    _camera.process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().current_scene.add_child(_camera)
    _camera.make_current()
    # 看板の白枠とヒントは近づくまで隠れているので、先読みの間だけ出す
    LinkBoard.set_warmup(true)
    _build_views()
    _view_index = 0
    _view_frames = 0
    _apply_view()
    _state = State.RUNNING


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
    _render_term()
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
    for entry in _saved_world_particles:
        if is_instance_valid(entry[0]):
            entry[0].process_mode = entry[1]
    _saved_world_particles.clear()
    _camera.queue_free()
    if is_instance_valid(_prev_camera):
        _prev_camera.make_current()
    LinkBoard.set_warmup(false)
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
        # 準備中はツリーを止めているので、粒だけ動かす
        p.process_mode = Node.PROCESS_MODE_ALWAYS
        p.emitting = true
    for node in player.find_children("*", "MeshInstance3D", true, false):
        var mi := node as MeshInstance3D
        if not (mi.mesh is ImmediateMesh):
            continue
        # 帯は top_level で変換が単位行列なので、頂点はワールド座標で書く
        var p: Vector3 = (player as Node3D).global_position + Vector3.UP * 0.05
        var im := mi.mesh as ImmediateMesh
        im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
        for v in [p, p + Vector3(0.3, 0.0, 0.0), p + Vector3(0.0, 0.0, 0.3)]:
            im.surface_set_color(Color(1.0, 0.2, 0.1, 0.5))
            im.surface_add_vertex(v)
        im.surface_end()
        _warm_meshes.append(mi)
    # 集中線もツリーと一緒に止まっているので、ここで出しても隠されない
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

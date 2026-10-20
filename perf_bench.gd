extends Node
# URL の ?bench で動く簡易ベンチ。機体を自動で走らせて物理演算の設定を変えて測り、
# そのあと描画の要素を1つずつ外して、1フレームの時間を測る。
# RenderQuality が作る（autoload ではない）。結果は画面左上のオーバーレイに出す。

# 読み込みが落ち着くまで待つ時間（秒）
const START_DELAY := 5.0
# 状態を切り替えてから測り始めるまでの待ち（秒）
const SETTLE := 1.0
# 測る時間（秒）と最低フレーム数（両方を満たすまで測る）
const MEASURE := 5.0
const MIN_FRAMES := 4
# 走らせる状態で測る時間（秒）
const DRIVE_MEASURE := 8.0
# 走らせるときに、左右のハンドルを切り替える間隔（秒）
const STEER_PERIOD := 1.5

const SHADER_TRIPLANAR := "res://assets/shaders/campus_triplanar.gdshader"
const SHADER_FOLIAGE := "res://assets/shaders/foliage_matte.gdshader"
const SHADER_FENCE := "res://assets/shaders/chain_link_fence.gdshader"

# 走らせる状態の物理演算の設定 [毎秒の回数, 1フレームの最大回数]
const DRIVE_SETTINGS := {
    "drive": [60, 8],
    "drive_steps2": [60, 2],
    "drive_tick30": [30, 8],
    "drive_t30_s2": [30, 2],
    "ref_drive": [60, 2],
    "no_sunray": [60, 2],
    "no_col_leaves": [60, 2],
    "no_col_trunks": [60, 2],
    "no_col_bldg": [60, 2],
    "no_col_all": [60, 2],
}

# 当たり判定を切る状態ごとの対象（StaticBody3D の collision_layer）
const NO_COL_LAYERS := {
    "no_col_leaves": [4],
    "no_col_trunks": [5],
    "no_col_bldg": [1],
    "no_col_all": [4, 5, 1],
}

# 測る状態（この順に実行する）
const STATES := [
    "drive", "drive_steps2", "drive_tick30", "drive_t30_s2",
    "ref_drive", "no_sunray", "no_col_leaves", "no_col_trunks",
    "no_col_bldg", "no_col_all",
    "base", "scale0.25", "no_sky", "no_fog", "no_shadow",
    "no_triplanar", "no_foliage", "no_fence",
    "no_vehicle", "no_campus", "far150",
]

# 場所ごとに測る位置（この順に、止まっている状態と走っている状態を測る）
const LOCATIONS := {
    "west11": Vector3(-187.11, 0.9, -160.23),   # 西11号館前
    "hall": Vector3(74.02, 0.9, -293.62),       # 学生会館前
    "port": Vector3(-225.60, 0.9, 44.51),       # 100周年記念キャンパス前
    "e3roof": Vector3(81.0, 42.9, -154.0),      # 東3号館の屋上
}
# 場所の状態で、移したあと測り始めるまでの待ち（秒）。カメラが追いつくのを待つ
const LOCATION_SETTLE := 2.0

enum Phase { DELAY, SETTLE, MEASURE, DONE }

# 実際に測る状態の一覧（STATES のあとに場所の状態を足したもの）
var _states: Array[String] = []
var _phase := Phase.DELAY
var _timer := 0.0
var _index := 0
var _frames := 0
var _sum := 0.0
var _phys_sum := 0.0
# 測定中の各フレームの実時間（ms）と、前フレームの時刻（マイクロ秒）
var _frame_ms: Array[float] = []
var _last_usec := 0
# 物理演算の回数（1フレームの間の数、測定中の最大と合計）
var _steps_this_frame := 0
var _last := 0
var _max_steps := 0
var _steps_sum := 0
# 状態ごとの結果（key, ok, ms, phys, steps_avg, steps_max, speed, draws, prims）
var _results: Array[Dictionary] = []
# 適用時に保存した元の値
var _saved := {}
var _header := ""
# 走らせるときの機体の開始位置（待ちが終わった時点のもの）
var _start_transform := Transform3D.IDENTITY
var _has_start := false
# 走らせている間の経過時間（ハンドルの切り替え用）
var _drive_time := 0.0
var _driving := false
# 止めたパワーアップのメダル [node, 元の process_mode]
var _saved_medals: Array = []


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_physics_process(true)
    _states.assign(STATES)
    for loc in LOCATIONS:
        _states.append(loc + ":idle")
        _states.append(loc + ":drive")


func _exit_tree() -> void:
    _release_inputs()
    _restore_medals()


func _physics_process(_delta: float) -> void:
    _steps_this_frame += 1


func _process(delta: float) -> void:
    # 1フレームの間に回った物理演算の回数
    _last = _steps_this_frame
    _steps_this_frame = 0
    if _driving:
        _update_steering(delta)
    match _phase:
        Phase.DELAY:
            # シェーダーの事前の準備が終わってから待ち始める
            if not ShaderWarmup.is_done():
                return
            _timer += delta
            if _timer >= START_DELAY:
                var root := get_tree().root
                _header = "bench  screen %dx%d  3D x%.2f  tick %d  maxsteps %d" % [
                    root.size.x, root.size.y, root.scaling_3d_scale,
                    Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame]
                var player := _find_player()
                if player != null:
                    _start_transform = player.global_transform
                    _has_start = true
                _disable_medals()
                _start_state()
        Phase.SETTLE:
            _timer += delta
            if _timer >= _settle_time():
                _phase = Phase.MEASURE
                _timer = 0.0
                _frames = 0
                _sum = 0.0
                _phys_sum = 0.0
                _max_steps = 0
                _steps_sum = 0
                _frame_ms.clear()
                _last_usec = Time.get_ticks_usec()
        Phase.MEASURE:
            var now := Time.get_ticks_usec()
            _frame_ms.append((now - _last_usec) / 1000.0)
            _last_usec = now
            _timer += delta
            _frames += 1
            _sum += delta
            _phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
            _max_steps = maxi(_max_steps, _last)
            _steps_sum += _last
            if _timer >= _measure_time() and _frames >= MIN_FRAMES:
                _finish_state()


# 場所の状態か（"west11:idle" など）
func _is_location(key: String) -> bool:
    return key.contains(":")


# 走らせる状態か
func _is_drive(key: String) -> bool:
    return DRIVE_SETTINGS.has(key) or key.ends_with(":drive")


func _settle_time() -> float:
    if _is_location(_states[_index]):
        return LOCATION_SETTLE
    return SETTLE


func _measure_time() -> float:
    if _is_drive(_states[_index]):
        return DRIVE_MEASURE
    return MEASURE


# 現在の状態を適用して、待ちに入る
func _start_state() -> void:
    var key: String = _states[_index]
    if not _apply(key):
        _results.append({"key": key, "ok": false})
        _next_state()
        return
    _phase = Phase.SETTLE
    _timer = 0.0
    _show_progress()


# 測定を記録して、元に戻す
func _finish_state() -> void:
    var key: String = _states[_index]
    var speed := -1.0
    if _is_drive(key):
        var player := _find_player()
        if player != null:
            speed = player.linear_velocity.length()
    _results.append({
        "key": key,
        "ok": true,
        "ms": _sum / _frames * 1000.0,
        "med": _percentile(_frame_ms, 0.5),
        "p95": _percentile(_frame_ms, 0.95),
        "phys": _phys_sum / _frames * 1000.0,
        "steps_avg": float(_steps_sum) / _frames,
        "steps_max": _max_steps,
        "speed": speed,
        "draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
        "prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
    })
    _revert(key)
    _next_state()


# 昇順に並べた配列の p 番目の値（p95 は ceil(0.95 * n) 番目）。median は中央の値
func _percentile(values: Array[float], p: float) -> float:
    if values.is_empty():
        return 0.0
    var sorted := values.duplicate()
    sorted.sort()
    var n := sorted.size()
    if p == 0.5:
        var half := n >> 1
        if n % 2 == 1:
            return sorted[half]
        return (sorted[half - 1] + sorted[half]) / 2.0
    var idx := clampi(int(ceil(p * n)) - 1, 0, n - 1)
    return sorted[idx]


func _next_state() -> void:
    _index += 1
    if _index >= _states.size():
        _phase = Phase.DONE
        var text := _build_table()
        print(text)
        RenderQuality.set_overlay_text_override(text)
        RenderQuality.save_report("bench", text)
        _restore_medals()
        return
    _start_state()


func _show_progress() -> void:
    var text := _build_table()
    text += "\nmeasuring: %s (%d/%d)" % [_states[_index], _index + 1, _states.size()]
    RenderQuality.set_overlay_text_override(text)


func _build_table() -> String:
    var lines: PackedStringArray = [_header]
    for r in _results:
        if r["ok"]:
            var ms: float = r["ms"]
            var fps := 1000.0 / ms if ms > 0.0 else 0.0
            # physmax は TIME_PHYSICS_PROCESS（直近1秒ほどで一番遅かった物理1回分。平均ではない）の平均
            var line := "%-13s med %6.1fms p95 %6.1fms %5.1ffps physmax %5.1fms st %.1f/%d draw %4d tris %.2fM" % [
                r["key"], r["med"], r["p95"], fps, r["phys"], r["steps_avg"], r["steps_max"],
                r["draws"], r["prims"] / 1000000.0]
            if _is_drive(r["key"]):
                line += " v %.1f" % r["speed"]
            lines.append(line)
        else:
            lines.append("%-13s n/a" % r["key"])
    return "\n".join(lines)


# パワーアップのメダルを止める。
# 場所の状態の位置はメダルの上なので、移すと機体が拾ってしまい、
# ポップアップが開いてゲームがポーズされ、以降の測定が狂うため
func _disable_medals() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    for node in scene.find_children("*", "", true, false):
        var script: Script = node.get_script()
        if script != null and script.resource_path == "res://power_up_item.gd":
            _saved_medals.append([node, node.process_mode])
            node.process_mode = Node.PROCESS_MODE_DISABLED


# 止めたメダルを元に戻す
func _restore_medals() -> void:
    for pair in _saved_medals:
        if is_instance_valid(pair[0]):
            pair[0].process_mode = pair[1]
    _saved_medals.clear()


func _find_player() -> VehicleBody3D:
    return get_tree().get_first_node_in_group("player") as VehicleBody3D


# 機体を開始位置に戻す（respawn.gd と同じやり方）
# place を省くと開始位置（少し浮かせる）、渡すとその位置にそのまま置く
func _reset_vehicle(vehicle: VehicleBody3D, place: Variant = null) -> void:
    var target := Transform3D(_start_transform.basis, _start_transform.origin + Vector3.UP * 0.3)
    if place != null:
        target = place
    var rid := vehicle.get_rid()
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, target)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
    vehicle.global_transform = target
    vehicle._motor_speed = 0.0
    vehicle._boost_time = 0.0
    vehicle.cancel_drift()
    # 速度が0になるので、激突と誤検出しないようにする
    vehicle._prev_velocity = Vector3.ZERO


# 前進を押し続け、一定間隔で左右のハンドルを切り替える
func _update_steering(delta: float) -> void:
    _drive_time += delta
    Input.action_press("up")
    var left := int(_drive_time / STEER_PERIOD) % 2 == 0
    if left:
        Input.action_release("right")
        Input.action_press("left")
    else:
        Input.action_release("left")
        Input.action_press("right")


func _release_inputs() -> void:
    Input.action_release("up")
    Input.action_release("left")
    Input.action_release("right")


# 状態を適用する。対象が無ければ false
func _apply(key: String) -> bool:
    var scene := get_tree().current_scene
    if DRIVE_SETTINGS.has(key):
        var player := _find_player()
        if player == null or not _has_start:
            return false
        # 3つめは比較用の変更の保存先
        var extra: Variant = null
        if key == "no_sunray":
            var sun := _find_node(scene, "RobotSun")
            if sun == null:
                return false
            sun.set_physics_process(false)
            extra = sun
        elif NO_COL_LAYERS.has(key):
            var uec := _find_node(scene, "UEC")
            if uec == null:
                return false
            extra = _disable_collisions(uec, NO_COL_LAYERS[key])
        _saved[key] = [Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame, extra]
        Engine.physics_ticks_per_second = DRIVE_SETTINGS[key][0]
        Engine.max_physics_steps_per_frame = DRIVE_SETTINGS[key][1]
        _reset_vehicle(player)
        _drive_time = 0.0
        _driving = true
        return true
    if _is_location(key):
        var player := _find_player()
        if player == null:
            return false
        var parts := key.split(":")
        _reset_vehicle(player, Transform3D(Basis.IDENTITY, LOCATIONS[parts[0]]))
        # 元に戻す処理を呼ばせるための印
        _saved[key] = true
        if parts[1] == "drive":
            _drive_time = 0.0
            _driving = true
        return true
    match key:
        "base":
            return true
        "scale0.25":
            _saved[key] = get_tree().root.scaling_3d_scale
            get_tree().root.scaling_3d_scale = 0.25
            return true
        "no_sky":
            var env := _find_environment()
            if env == null:
                return false
            _saved[key] = [env.background_mode, env.ambient_light_source]
            env.background_mode = Environment.BG_COLOR
            env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
            return true
        "no_fog":
            var env := _find_environment()
            if env == null:
                return false
            _saved[key] = env.fog_enabled
            env.fog_enabled = false
            return true
        "no_shadow":
            if scene == null:
                return false
            var list: Array = []
            for light in scene.find_children("*", "DirectionalLight3D", true, false):
                list.append([light, light.shadow_enabled])
                light.shadow_enabled = false
            _saved[key] = list
            return not list.is_empty()
        "no_triplanar":
            return _hide_by_shader(key, [SHADER_TRIPLANAR])
        "no_foliage":
            return _hide_by_shader(key, [SHADER_FOLIAGE])
        "no_fence":
            return _hide_by_shader(key, [SHADER_FENCE])
        "no_vehicle":
            var list: Array = []
            for node in get_tree().get_nodes_in_group("player"):
                if "visible" in node:
                    list.append([node, node.visible])
                    node.visible = false
            _saved[key] = list
            return not list.is_empty()
        "no_campus":
            var uec := _find_node(scene, "UEC")
            if uec == null or not ("visible" in uec):
                return false
            _saved[key] = [uec, uec.visible]
            uec.visible = false
            return true
        "far150":
            var camera := get_viewport().get_camera_3d()
            if camera == null:
                return false
            _saved[key] = [camera, camera.far]
            camera.far = 150.0
            return true
    return false


# 適用前の値に戻す
func _revert(key: String) -> void:
    if not _saved.has(key):
        return
    var data = _saved[key]
    _saved.erase(key)
    if _is_location(key):
        _driving = false
        _release_inputs()
        return
    if DRIVE_SETTINGS.has(key):
        _driving = false
        _release_inputs()
        Engine.physics_ticks_per_second = data[0]
        Engine.max_physics_steps_per_frame = data[1]
        var extra: Variant = data[2]
        if key == "no_sunray":
            if is_instance_valid(extra):
                extra.set_physics_process(true)
        elif NO_COL_LAYERS.has(key):
            for pair in extra["shapes"]:
                if is_instance_valid(pair[0]):
                    pair[0].disabled = pair[1]
            if is_instance_valid(extra["floor"]):
                extra["floor"].queue_free()
        return
    match key:
        "scale0.25":
            get_tree().root.scaling_3d_scale = data
        "no_sky":
            var env := _find_environment()
            if env != null:
                env.background_mode = data[0]
                env.ambient_light_source = data[1]
        "no_fog":
            var env := _find_environment()
            if env != null:
                env.fog_enabled = data
        "no_shadow":
            for pair in data:
                if is_instance_valid(pair[0]):
                    pair[0].shadow_enabled = pair[1]
        "no_campus":
            if is_instance_valid(data[0]):
                data[0].visible = data[1]
        "no_triplanar", "no_foliage", "no_fence", "no_vehicle":
            for pair in data:
                if is_instance_valid(pair[0]):
                    pair[0].visible = pair[1]
        "far150":
            if is_instance_valid(data[0]):
                data[0].far = data[1]


# UEC 配下で collision_layer が layers に含まれる StaticBody3D の形を切り、安全用の床を足す。
# 戻り値は元に戻すための情報 {shapes: [[shape, 元の disabled]], floor: 床}
func _disable_collisions(uec: Node, layers: Array) -> Dictionary:
    var shapes: Array = []
    for body in uec.find_children("*", "StaticBody3D", true, false):
        if not (body.collision_layer in layers):
            continue
        for child in body.get_children():
            if child is CollisionShape3D:
                shapes.append([child, child.disabled])
                child.disabled = true
    # 地面が無くなっても落ちないように、仮の床を置く（上面が y = 0）
    var floor_body := StaticBody3D.new()
    floor_body.collision_layer = 1
    floor_body.collision_mask = 0
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(600, 1, 600)
    shape.shape = box
    floor_body.add_child(shape)
    floor_body.position = Vector3(_start_transform.origin.x, -0.5, _start_transform.origin.z)
    get_tree().current_scene.add_child(floor_body)
    return {"shapes": shapes, "floor": floor_body}


func _find_node(scene: Node, node_name: String) -> Node:
    if scene == null:
        return null
    var found := scene.find_children(node_name, "", true, false)
    if found.is_empty():
        return null
    return found[0]


func _find_environment() -> Environment:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    for node in scene.find_children("*", "WorldEnvironment", true, false):
        var env: Environment = (node as WorldEnvironment).environment
        if env != null:
            return env
    return null


# 指定したシェーダーを使う GeometryInstance3D を隠す
func _hide_by_shader(key: String, paths: Array) -> bool:
    var scene := get_tree().current_scene
    if scene == null:
        return false
    var list: Array = []
    for node in scene.find_children("*", "GeometryInstance3D", true, false):
        var geometry := node as GeometryInstance3D
        if _uses_shader(geometry, paths):
            list.append([geometry, geometry.visible])
    for pair in list:
        pair[0].visible = false
    _saved[key] = list
    return not list.is_empty()


func _uses_shader(node: GeometryInstance3D, paths: Array) -> bool:
    if _is_shader_material(node.material_override, paths):
        return true
    if _is_shader_material(node.material_overlay, paths):
        return true
    if node is MeshInstance3D:
        var mesh := (node as MeshInstance3D).mesh
        if mesh == null:
            return false
        for i in mesh.get_surface_count():
            if _is_shader_material((node as MeshInstance3D).get_surface_override_material(i), paths):
                return true
            if _is_shader_material(mesh.surface_get_material(i), paths):
                return true
    return false


func _is_shader_material(material: Material, paths: Array) -> bool:
    var shader_material := material as ShaderMaterial
    if shader_material == null or shader_material.shader == null:
        return false
    return shader_material.shader.resource_path in paths

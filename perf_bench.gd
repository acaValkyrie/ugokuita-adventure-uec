extends Node
# URL の ?bench で動く簡易ベンチ。描画の要素を1つずつ外して、1フレームの時間を測る。
# RenderQuality が作る（autoload ではない）。結果は画面左上のオーバーレイに出す。

# 読み込みが落ち着くまで待つ時間（秒）
const START_DELAY := 5.0
# 状態を切り替えてから測り始めるまでの待ち（秒）
const SETTLE := 1.0
# 測る時間（秒）と最低フレーム数（両方を満たすまで測る）
const MEASURE := 3.0
const MIN_FRAMES := 4

const SHADER_TRIPLANAR := "res://assets/shaders/campus_triplanar.gdshader"
const SHADER_FOLIAGE := "res://assets/shaders/foliage_matte.gdshader"
const SHADER_FENCE := "res://assets/shaders/chain_link_fence.gdshader"
const SHADER_POOL := "res://assets/shaders/pool.gdshader"
const SHADER_POOL_WATER := "res://assets/shaders/pool_water_surface.gdshader"

# 測る状態（この順に実行する）
const STATES := [
    "base", "scale0.25", "no_sky", "no_fog", "no_shadow", "no_lightmap",
    "no_triplanar", "no_foliage", "no_fence", "no_pool",
    "no_vehicle", "no_campus", "far150",
]

enum Phase { DELAY, SETTLE, MEASURE, DONE }

var _phase := Phase.DELAY
var _timer := 0.0
var _index := 0
var _frames := 0
var _sum := 0.0
var _phys_sum := 0.0
# 状態ごとの結果（key, ok, ms, phys, draws, prims）
var _results: Array[Dictionary] = []
# 適用時に保存した元の値
var _saved := {}
var _header := ""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
    match _phase:
        Phase.DELAY:
            _timer += delta
            if _timer >= START_DELAY:
                var root := get_tree().root
                _header = "bench  screen %dx%d  3D x%.2f" % [
                    root.size.x, root.size.y, root.scaling_3d_scale]
                _start_state()
        Phase.SETTLE:
            _timer += delta
            if _timer >= SETTLE:
                _phase = Phase.MEASURE
                _timer = 0.0
                _frames = 0
                _sum = 0.0
                _phys_sum = 0.0
        Phase.MEASURE:
            _timer += delta
            _frames += 1
            _sum += delta
            _phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
            if _timer >= MEASURE and _frames >= MIN_FRAMES:
                _finish_state()


# 現在の状態を適用して、待ちに入る
func _start_state() -> void:
    var key: String = STATES[_index]
    if not _apply(key):
        _results.append({"key": key, "ok": false})
        _next_state()
        return
    _phase = Phase.SETTLE
    _timer = 0.0
    _show_progress()


# 測定を記録して、元に戻す
func _finish_state() -> void:
    var key: String = STATES[_index]
    _results.append({
        "key": key,
        "ok": true,
        "ms": _sum / _frames * 1000.0,
        "phys": _phys_sum / _frames * 1000.0,
        "draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
        "prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
    })
    _revert(key)
    _next_state()


func _next_state() -> void:
    _index += 1
    if _index >= STATES.size():
        _phase = Phase.DONE
        var text := _build_table()
        print(text)
        RenderQuality.set_overlay_text_override(text)
        return
    _start_state()


func _show_progress() -> void:
    var text := _build_table()
    text += "\nmeasuring: %s (%d/%d)" % [STATES[_index], _index + 1, STATES.size()]
    RenderQuality.set_overlay_text_override(text)


func _build_table() -> String:
    var lines: PackedStringArray = [_header]
    for r in _results:
        if r["ok"]:
            var ms: float = r["ms"]
            var fps := 1000.0 / ms if ms > 0.0 else 0.0
            lines.append("%-12s %7.1fms %5.1ffps draw %4d tris %.2fM phys %.1fms" % [
                r["key"], ms, fps, r["draws"], r["prims"] / 1000000.0, r["phys"]])
        else:
            lines.append("%-12s n/a" % r["key"])
    return "\n".join(lines)


# 状態を適用する。対象が無ければ false
func _apply(key: String) -> bool:
    var scene := get_tree().current_scene
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
        "no_lightmap":
            var gi := _find_node(scene, "LightmapGI")
            if gi == null:
                return false
            _saved[key] = [gi, gi.visible]
            gi.visible = false
            return true
        "no_triplanar":
            return _hide_by_shader(key, [SHADER_TRIPLANAR])
        "no_foliage":
            return _hide_by_shader(key, [SHADER_FOLIAGE])
        "no_fence":
            return _hide_by_shader(key, [SHADER_FENCE])
        "no_pool":
            return _hide_by_shader(key, [SHADER_POOL, SHADER_POOL_WATER])
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
        "no_lightmap", "no_campus":
            if is_instance_valid(data[0]):
                data[0].visible = data[1]
        "no_triplanar", "no_foliage", "no_fence", "no_pool", "no_vehicle":
            for pair in data:
                if is_instance_valid(pair[0]):
                    pair[0].visible = pair[1]
        "far150":
            if is_instance_valid(data[0]):
                data[0].far = data[1]


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

extends Node3D

# ドリフトの光の帯。ドリフト中、左右の後輪の接地点に、段階の色で光る帯を地面に引く。帯は少しずつ消える。

# 段階ごとの帯の色（drift_sparks.gd と同じ。0: 淡い黄色、1: オレンジ、2: 赤、3: 虹色）
const COLOR_STAGE0 := Color(1.0, 0.9, 0.5)
const COLOR_STAGE1 := Color(1.0, 0.5, 0.1)
const COLOR_STAGE2 := Color(1.0, 0.12, 0.08)
# 3段目の虹色で色相が一周する速さ [周/s]
const RAINBOW_SPEED := 1.5
# 記録した点が残る時間（秒）
const LIFETIME := 0.5
# 帯の幅（m）
const WIDTH := 0.08
# 地面からの浮かせる高さ（m。地面とのちらつきを避ける）
const LIFT := 0.02
# 点を記録する最小の間隔（m）
const MIN_SPACING := 0.04
# 直前の点からこれより離れたら、つなげずに新しい帯を始める距離（m。リスポーン対策）
const BREAK_DISTANCE := 1.0

var _vehicle: VehicleBody3D
var _meshes: Array[ImmediateMesh] = []
# _meshes と同じ順の、対応するホイール
var _wheels: Array[VehicleWheel3D] = []
# _meshes と同じ順の、記録した点（{"pos", "time", "color", "start"}）
var _points: Array[Array] = []
# _meshes と同じ順の、前のフレームで記録していたか（false なら次の点から新しい帯）
var _was_active: Array[bool] = []
var _time := 0.0

func _ready() -> void:
    _vehicle = get_parent() as VehicleBody3D
    if _vehicle == null:
        return
    var wheel_bl := _vehicle.get_node_or_null("VehicleWheel3D_BL") as VehicleWheel3D
    var wheel_br := _vehicle.get_node_or_null("VehicleWheel3D_BR") as VehicleWheel3D
    if wheel_bl == null or wheel_br == null:
        return
    var material := _make_material()
    for wheel in [wheel_bl, wheel_br]:
        var mesh := ImmediateMesh.new()
        var instance := MeshInstance3D.new()
        instance.mesh = mesh
        instance.material_override = material
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # 機体に追従させず、ワールド座標で描く
        instance.top_level = true
        instance.global_transform = Transform3D.IDENTITY
        add_child(instance)
        _meshes.append(mesh)
        _wheels.append(wheel)
        _points.append([])
        _was_active.append(false)

func _process(delta: float) -> void:
    if _vehicle == null:
        return
    _time += delta
    var color := COLOR_STAGE0
    match int(_vehicle.get("drift_stage")):
        1:
            color = COLOR_STAGE1
        2:
            color = COLOR_STAGE2
        3:
            color = Color.from_hsv(fmod(_time * RAINBOW_SPEED, 1.0), 0.8, 1.0)
    var drifting: bool = _vehicle.get("drifting")
    for i in _meshes.size():
        var wheel := _wheels[i]
        var points := _points[i]
        if drifting and wheel.is_in_contact():
            var pos := wheel.global_position - _vehicle.global_basis.y * wheel.wheel_radius + Vector3.UP * LIFT
            if points.is_empty() or not _was_active[i] or pos.distance_to(points[-1]["pos"]) > BREAK_DISTANCE:
                points.append({"pos": pos, "time": _time, "color": color, "start": true})
            elif pos.distance_to(points[-1]["pos"]) >= MIN_SPACING:
                points.append({"pos": pos, "time": _time, "color": color, "start": false})
            _was_active[i] = true
        else:
            _was_active[i] = false
        # 古い点を消す。先頭は前の点とつながらない
        while not points.is_empty() and _time - points[0]["time"] > LIFETIME:
            points.pop_front()
        if not points.is_empty():
            points[0]["start"] = true
        _rebuild(_meshes[i], points)

func _rebuild(mesh: ImmediateMesh, points: Array) -> void:
    mesh.clear_surfaces()
    if points.size() < 2:
        return
    var verts := PackedVector3Array()
    var colors := PackedColorArray()
    for j in range(1, points.size()):
        var a: Dictionary = points[j - 1]
        var b: Dictionary = points[j]
        if b["start"]:
            continue
        var d: Vector3 = b["pos"] - a["pos"]
        d.y = 0.0
        if d.length() < 0.0001:
            continue
        var side := d.normalized().cross(Vector3.UP) * WIDTH * 0.5
        # 古い点ほど細く、透明にする
        var fade_a := _fade(a)
        var fade_b := _fade(b)
        var ca: Color = a["color"]
        var cb: Color = b["color"]
        ca.a = fade_a
        cb.a = fade_b
        var a_pos: Vector3 = a["pos"]
        var b_pos: Vector3 = b["pos"]
        var a1 := a_pos + side * fade_a
        var a2 := a_pos - side * fade_a
        var b1 := b_pos + side * fade_b
        var b2 := b_pos - side * fade_b
        verts.append_array([a1, a2, b1, b1, a2, b2])
        colors.append_array([ca, ca, cb, cb, ca, cb])
    if verts.is_empty():
        return
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for k in verts.size():
        mesh.surface_set_color(colors[k])
        mesh.surface_add_vertex(verts[k])
    mesh.surface_end()

func _fade(point: Dictionary) -> float:
    var age := _time - float(point["time"])
    return clampf(1.0 - age / LIFETIME, 0.0, 1.0)

func _make_material() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.vertex_color_use_as_albedo = true
    m.no_depth_test = false
    return m

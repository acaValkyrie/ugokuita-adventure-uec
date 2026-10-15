extends Node3D
# 機体の性能を測るためのテスト用ステージ。グリッド付きの広い床と、角度の違う滑らかな坂を並べる。
# 坂は足元を z = 0 に置いて +Z 方向に上る。坂の x は ramp_center_x() で参照できる。

# 足元と上端をなめらかにつなぐ円弧の半径 [m]
const RAMP_RADIUS := 6.0
# 直線部分の長さ [m]
const RAMP_LENGTH := 30.0
# 坂の幅 [m]
const RAMP_WIDTH := 6.0
# 頂上の平らな台の長さ [m]
const TOP_LENGTH := 6.0
const RAMP_ANGLES: Array[float] = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0]
# 坂どうしの間隔 [m]
const RAMP_SPACING := 10.0
# 坂の足元の z [m]
const RAMP_FOOT_Z := 0.0
# 床の一辺 [m]
const FLOOR_SIZE := 400.0

var _grid_material: ShaderMaterial


func _ready() -> void:
    _grid_material = ShaderMaterial.new()
    _grid_material.shader = preload("res://tests/grid.gdshader")
    _build_floor()
    for i in RAMP_ANGLES.size():
        add_child(_build_ramp(RAMP_ANGLES[i], ramp_center_x(i)))


# i 番目の坂の中心の x [m]
func ramp_center_x(i: int) -> float:
    return -0.5 * (RAMP_ANGLES.size() - 1) * RAMP_SPACING + i * RAMP_SPACING


# 坂の足元の z [m]
func ramp_foot_z() -> float:
    return RAMP_FOOT_Z


# 上面が y = 0 の床
func _build_floor() -> void:
    var body := StaticBody3D.new()
    body.name = "Floor"
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE)
    shape.shape = box
    shape.position = Vector3(0.0, -0.5, 0.0)
    body.add_child(shape)
    var mesh_instance := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
    plane.material = _grid_material
    mesh_instance.mesh = plane
    body.add_child(mesh_instance)
    add_child(body)


# 坂の断面（x = 足元からの z、y = 高さ）。足元の円弧、直線、上の円弧、頂上の台の順に並べる
func _ramp_profile(angle_deg: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    var theta := deg_to_rad(angle_deg)
    var steps := roundi(angle_deg)
    # 足元の円弧（水平から theta まで上向きに曲がる）
    for k in steps + 1:
        var phi := theta * k / steps
        points.append(Vector2(RAMP_RADIUS * sin(phi), RAMP_RADIUS * (1.0 - cos(phi))))
    # 直線
    var dir := Vector2(cos(theta), sin(theta))
    var line_end := points[points.size() - 1] + dir * RAMP_LENGTH
    points.append(line_end)
    # 上の円弧（傾きを theta から 0 に戻す。上に凸）
    var center := line_end + RAMP_RADIUS * Vector2(sin(theta), -cos(theta))
    for k in range(1, steps + 1):
        var alpha := theta * (steps - k) / steps
        points.append(center + RAMP_RADIUS * Vector2(-sin(alpha), cos(alpha)))
    # 頂上の平らな台
    points.append(points[points.size() - 1] + Vector2(TOP_LENGTH, 0.0))
    return points


# 角度 angle_deg の坂を、x = center_x を中心に作る。見た目（上面と側壁）と、上面の衝突を持つ
func _build_ramp(angle_deg: float, center_x: float) -> StaticBody3D:
    var profile := _ramp_profile(angle_deg)
    var half := RAMP_WIDTH * 0.5
    var body := StaticBody3D.new()
    body.name = "Ramp%d" % roundi(angle_deg)
    body.position = Vector3(center_x, 0.0, RAMP_FOOT_Z)

    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var faces := PackedVector3Array()
    var count := profile.size()
    # 上面（点ごとの法線は前後の線分の平均）
    for k in count - 1:
        var a := profile[k]
        var b := profile[k + 1]
        var na := _profile_normal(profile, k)
        var nb := _profile_normal(profile, k + 1)
        var quad := [
            Vector3(-half, a.y, a.x), Vector3(half, a.y, a.x),
            Vector3(half, b.y, b.x), Vector3(-half, b.y, b.x),
        ]
        var normals := [na, na, nb, nb]
        _add_quad(st, quad, normals, faces)
    # 側壁（見た目だけ）
    for side: float in [-1.0, 1.0]:
        var n := Vector3(side, 0.0, 0.0)
        for k in count - 1:
            var a := profile[k]
            var b := profile[k + 1]
            var quad := [
                Vector3(side * half, 0.0, a.x), Vector3(side * half, a.y, a.x),
                Vector3(side * half, b.y, b.x), Vector3(side * half, 0.0, b.x),
            ]
            _add_quad(st, quad, [n, n, n, n], null)
    # 奥の壁（見た目だけ）
    var end := profile[count - 1]
    var back := Vector3(0.0, 0.0, 1.0)
    _add_quad(st, [
        Vector3(-half, 0.0, end.x), Vector3(half, 0.0, end.x),
        Vector3(half, end.y, end.x), Vector3(-half, end.y, end.x),
    ], [back, back, back, back], null)

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = st.commit()
    mesh_instance.material_override = _grid_material
    body.add_child(mesh_instance)

    var shape := CollisionShape3D.new()
    var concave := ConcavePolygonShape3D.new()
    concave.set_faces(faces)
    concave.backface_collision = true
    shape.shape = concave
    body.add_child(shape)

    # 角度の表示（頂上の台の手前）
    var label := Label3D.new()
    label.text = "%d°" % roundi(angle_deg)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 96
    label.outline_size = 24
    var top_start := profile[count - 2]
    label.position = Vector3(0.0, top_start.y + 1.5, top_start.x)
    body.add_child(label)
    return body


# profile[k] での上向きの法線（z, y 平面。x は 0）
func _profile_normal(profile: PackedVector2Array, k: int) -> Vector3:
    var dir := Vector2.ZERO
    if k > 0:
        dir += (profile[k] - profile[k - 1]).normalized()
    if k < profile.size() - 1:
        dir += (profile[k + 1] - profile[k]).normalized()
    dir = dir.normalized()
    return Vector3(0.0, dir.x, -dir.y)


# 四角形（頂点は一周する順）を三角形2つにして追加する。
# 法線の向きが表になるよう巻き順をそろえる。faces が null でなければ三角形の頂点も足す
func _add_quad(st: SurfaceTool, quad: Array, normals: Array, faces) -> void:
    for tri in [[0, 1, 2], [0, 2, 3]]:
        var a: Vector3 = quad[tri[0]]
        var b: Vector3 = quad[tri[1]]
        var c: Vector3 = quad[tri[2]]
        var wanted: Vector3 = (normals[tri[0]] + normals[tri[1]] + normals[tri[2]]).normalized()
        # Godot の表は時計回り。(b - a) x (c - a) が法線と同じ向きなら反時計回りなので入れ替える
        var order: Array = tri
        if (b - a).cross(c - a).dot(wanted) > 0.0:
            order = [tri[0], tri[2], tri[1]]
        for index in order:
            st.set_normal(normals[index])
            st.add_vertex(quad[index])
            if faces != null:
                faces.append(quad[index])

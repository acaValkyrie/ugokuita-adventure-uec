extends Node3D

# ドリフトの火花。ドリフト中、左右の後輪の接地点から火花を後ろへ飛ばす。
# 色はドリフトの段階（drift_stage）で変わり、粒はその場に残る（local_coords = false）。

# 段階ごとの火花の色（0: 淡い黄色、1: 青、2: オレンジ）
const COLOR_STAGE0 := Color(1.0, 0.9, 0.5)
const COLOR_STAGE1 := Color(0.3, 0.6, 1.0)
const COLOR_STAGE2 := Color(1.0, 0.5, 0.1)
# 火花を後ろへ飛ばす向きに足す、上向きの成分
const UP_FACTOR := 0.6

var _vehicle: VehicleBody3D
var _emitters: Array[CPUParticles3D] = []
# _emitters と同じ順の、対応するホイール（浮いているときは火花を出さない）
var _wheels: Array[VehicleWheel3D] = []

func _ready() -> void:
    _vehicle = get_parent() as VehicleBody3D
    if _vehicle == null:
        return
    var wheel_bl := _vehicle.get_node_or_null("VehicleWheel3D_BL") as VehicleWheel3D
    var wheel_br := _vehicle.get_node_or_null("VehicleWheel3D_BR") as VehicleWheel3D
    if wheel_bl == null or wheel_br == null:
        return
    var mesh := _make_mesh(_make_material(_make_texture()))
    for wheel in [wheel_bl, wheel_br]:
        # タイヤの接地点に置く
        var pos := Vector3(wheel.position.x, wheel.position.y - wheel.wheel_radius, wheel.position.z)
        _add_emitter(_make_sparks(mesh), pos, wheel)

func _add_emitter(p: CPUParticles3D, pos: Vector3, wheel: VehicleWheel3D) -> void:
    p.position = pos
    add_child(p)
    _emitters.append(p)
    _wheels.append(wheel)

func _process(_delta: float) -> void:
    if _vehicle == null:
        return
    var back := -_vehicle.global_basis.z
    back.y = 0.0
    var dir := (back.normalized() + Vector3.UP * UP_FACTOR).normalized()
    var color := COLOR_STAGE0
    match int(_vehicle.get("drift_stage")):
        1:
            color = COLOR_STAGE1
        2:
            color = COLOR_STAGE2
    var drifting: bool = _vehicle.get("drifting")
    for i in _emitters.size():
        var p := _emitters[i]
        # 向きは機体に追従させず、位置だけタイヤに付いていく
        p.global_basis = Basis.IDENTITY
        p.direction = dir
        p.color = color
        p.emitting = drifting and _wheels[i].is_in_contact()

func _make_texture() -> GradientTexture2D:
    var g := Gradient.new()
    g.set_color(0, Color(1, 1, 1, 1))
    g.set_color(1, Color(1, 1, 1, 0))
    var t := GradientTexture2D.new()
    t.gradient = g
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.0, 0.5)
    t.width = 64
    t.height = 64
    return t

func _make_material(texture: Texture2D) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    # 粒の大きさ（scale）を効かせる
    m.billboard_keep_scale = true
    m.vertex_color_use_as_albedo = true
    m.albedo_texture = texture
    return m

func _make_mesh(material: Material) -> QuadMesh:
    var q := QuadMesh.new()
    q.size = Vector2.ONE
    q.material = material
    return q

func _make_sparks(mesh: Mesh) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.name = "Sparks"
    p.local_coords = false
    p.emitting = false
    p.amount = 24
    p.lifetime = 0.3
    p.mesh = mesh
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.initial_velocity_min = 1.5
    p.initial_velocity_max = 3.0
    p.spread = 35.0
    p.gravity = Vector3(0.0, -6.0, 0.0)
    p.scale_amount_min = 0.05
    p.scale_amount_max = 0.05
    # 白（不透明）→ 白（透明）。色は CPUParticles3D.color で付ける
    var g := Gradient.new()
    g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
    g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    p.color_ramp = g
    return p

extends Node3D

# ジェットの噴射。機体の下の左右2か所のノズルから、炎と煙を出す。
# 粒はその場に残る（local_coords = false）ので、機体が動くと通った跡が筋になる。

# ノズルの左右の位置（機体ローカル）[m]
const NOZZLE_X := 0.15
# 機体の速さに応じて噴射の向きを後ろへ流す割合
const TRAIL_FACTOR := 0.15

var _vehicle: VehicleBody3D
var _emitters: Array[CPUParticles3D] = []

func _ready() -> void:
    _vehicle = get_parent() as VehicleBody3D
    # ノズルの高さは、当たり判定の箱の下端に合わせる
    var nozzle_y := -0.05
    if _vehicle != null:
        for child in _vehicle.get_children():
            var c := child as CollisionShape3D
            if c != null and c.shape is BoxShape3D:
                nozzle_y = c.position.y - (c.shape as BoxShape3D).size.y * 0.5
                break
    var texture := _make_texture()
    var flame_mesh := _make_mesh(_make_material(texture, true))
    var smoke_mesh := _make_mesh(_make_material(texture, false))
    for side in [-1.0, 1.0]:
        var pos := Vector3(NOZZLE_X * side, nozzle_y, 0.0)
        _add_emitter(_make_flame(flame_mesh), pos)
        _add_emitter(_make_smoke(smoke_mesh), pos)

func _add_emitter(p: CPUParticles3D, pos: Vector3) -> void:
    p.position = pos
    add_child(p)
    _emitters.append(p)

func _process(_delta: float) -> void:
    if _vehicle == null:
        return
    var thrusting: bool = _vehicle.get("jet_thrusting")
    var v: Vector3 = _vehicle.linear_velocity
    v.y = 0.0
    var dir := (Vector3.DOWN + (-v) * TRAIL_FACTOR).normalized()
    for p in _emitters:
        # 向きは機体に追従させず、位置だけノズルに付いていく
        p.global_basis = Basis.IDENTITY
        p.direction = dir
        p.emitting = thrusting

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

func _make_material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
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

# 大きさが from から to へ変わるよう、基準の大きさ base に掛ける曲線を作る
func _make_scale_curve(from: float, to: float, base: float) -> Curve:
    var c := Curve.new()
    c.add_point(Vector2(0.0, from / base))
    c.add_point(Vector2(1.0, to / base))
    return c

func _make_flame(mesh: Mesh) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.name = "Flame"
    p.local_coords = false
    p.emitting = false
    p.amount = 24
    p.lifetime = 0.15
    p.mesh = mesh
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.initial_velocity_min = 6.0
    p.initial_velocity_max = 8.0
    p.spread = 8.0
    p.gravity = Vector3.ZERO
    p.scale_amount_min = 0.12
    p.scale_amount_max = 0.12
    p.scale_amount_curve = _make_scale_curve(0.12, 0.02, 0.12)
    var g := Gradient.new()
    g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
    g.set_color(1, Color(1.0, 0.5, 0.1, 0.0))
    g.add_point(0.5, Color(1.0, 0.5, 0.1, 0.8))
    p.color_ramp = g
    return p

func _make_smoke(mesh: Mesh) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.name = "Smoke"
    p.local_coords = false
    p.emitting = false
    p.amount = 40
    p.lifetime = 1.2
    p.mesh = mesh
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.initial_velocity_min = 3.0
    p.initial_velocity_max = 4.0
    p.spread = 15.0
    p.damping_min = 3.0
    p.damping_max = 4.0
    p.gravity = Vector3(0.0, 0.6, 0.0)
    p.scale_amount_min = 0.6
    p.scale_amount_max = 0.6
    p.scale_amount_curve = _make_scale_curve(0.15, 0.6, 0.6)
    var g := Gradient.new()
    g.set_color(0, Color(0.85, 0.85, 0.85, 0.6))
    g.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
    p.color_ramp = g
    return p

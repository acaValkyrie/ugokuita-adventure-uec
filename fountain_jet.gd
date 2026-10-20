extends Node3D

# 噴水の中央に湧き上がる水。まっすぐ上へ噴き上がる水柱と、根元の盛り上がりの2つの粒を、_ready でコードから作る。
# このノードを噴水の水面の中心（水面の高さ）に置く。粒は半透明の淡い水色で、影は落とさない。

# 水柱の粒の数
@export var jet_amount := 60
# 水柱の粒が消えるまでの時間 [s]
@export var jet_lifetime := 0.9
# 水柱の粒の初速の範囲 [m/s]（この速さと重力で高さ約1mまで上がる）
@export var jet_speed_min := 4.0
@export var jet_speed_max := 4.6
# 水柱の広がり（度）
@export var jet_spread := 6.0
# 水柱の粒の大きさ（メートル）
@export var jet_size := 0.08
# 水柱の粒の色（淡い水色。不透明度は 0.75 から透明へ薄れる）
@export var jet_color := Color(0.85, 0.93, 1.0)
# 根元の盛り上がりの粒の数
@export var base_amount := 30
# 根元の粒が消えるまでの時間 [s]
@export var base_lifetime := 0.6
# 根元の粒の初速の範囲 [m/s]
@export var base_speed_min := 0.6
@export var base_speed_max := 1.2
# 根元の粒の広がり（度）
@export var base_spread := 35.0
# 根元の粒の大きさ（メートル）
@export var base_size := 0.12
# 根元の粒の色（白に近い）
@export var base_color := Color(0.95, 0.98, 1.0)
# 水柱の粒の放出元の球の半径（メートル）
@export var emitter_radius := 0.05
# 粒にかかる重力
@export var gravity := Vector3(0.0, -9.8, 0.0)

# 起動時のシェーダーの先読み（shader_warmup.gd）が、ツリーを止めている間も粒を動かせるよう、この名前のグループに入れる
const WARMUP_GROUP := &"warmup_particles"

func _ready() -> void:
    var mesh := _make_mesh(_make_material(_make_texture()))
    add_child(_make_particles("Jet", mesh, jet_amount, jet_lifetime, jet_speed_min, jet_speed_max, jet_spread, jet_size, jet_color, 0.75, emitter_radius))
    add_child(_make_particles("Base", mesh, base_amount, base_lifetime, base_speed_min, base_speed_max, base_spread, base_size, base_color, 0.6, 0.0))

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

# 上向きに水を飛ばす粒を作る。色は color から透明へ薄れる（start_alpha は始めの不透明度）。radius が0より大きければ、その球の中から出す
func _make_particles(particle_name: String, mesh: Mesh, amount: int, lifetime: float, speed_min: float, speed_max: float,
        spread: float, size: float, color: Color, start_alpha: float, radius: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.name = particle_name
    p.emitting = true
    p.amount = amount
    p.lifetime = lifetime
    p.mesh = mesh
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.direction = Vector3.UP
    p.spread = spread
    p.initial_velocity_min = speed_min
    p.initial_velocity_max = speed_max
    p.gravity = gravity
    p.scale_amount_min = size
    p.scale_amount_max = size
    if radius > 0.0:
        p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
        p.emission_sphere_radius = radius
    # 色（不透明度 start_alpha）→ 同じ色（透明）
    var g := Gradient.new()
    g.set_color(0, Color(color.r, color.g, color.b, start_alpha))
    g.set_color(1, Color(color.r, color.g, color.b, 0.0))
    p.color_ramp = g
    p.add_to_group(WARMUP_GROUP)
    return p

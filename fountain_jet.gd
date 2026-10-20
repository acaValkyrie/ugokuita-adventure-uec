@tool
extends Node3D

# 噴水の中央に湧き上がる水。まっすぐ上へ噴き上がる水柱と、根元の盛り上がりの2つの粒を、_ready でコードから作る。
# このノードを噴水の水面の中心（水面の高さ）に置く。粒は縁が青い小さな水滴で、寿命の終わりのほうで透明になる。影は落とさない。

# 水柱の粒の数
@export var jet_amount := 260:
    set(value):
        jet_amount = value
        _rebuild()
# 水柱の粒が消えるまでの時間 [s]
@export var jet_lifetime := 1.0:
    set(value):
        jet_lifetime = value
        _rebuild()
# 水柱の粒の初速の範囲 [m/s]（この速さと重力で高さ約0.7〜1.1mまで上がる）
@export var jet_speed_min := 3.8:
    set(value):
        jet_speed_min = value
        _rebuild()
@export var jet_speed_max := 4.6:
    set(value):
        jet_speed_max = value
        _rebuild()
# 水柱の広がり（度）
@export var jet_spread := 10.0:
    set(value):
        jet_spread = value
        _rebuild()
# 水柱の粒の大きさの範囲（メートル）
@export var jet_size_min := 0.06:
    set(value):
        jet_size_min = value
        _rebuild()
@export var jet_size_max := 0.1:
    set(value):
        jet_size_max = value
        _rebuild()
# 水柱の粒の色（白。不透明のまま、寿命の終わりのほうで透明になる）
@export var jet_color := Color(1.0, 1.0, 1.0):
    set(value):
        jet_color = value
        _rebuild()
# 根元の盛り上がりの粒の数
@export var base_amount := 80:
    set(value):
        base_amount = value
        _rebuild()
# 根元の粒が消えるまでの時間 [s]
@export var base_lifetime := 0.6:
    set(value):
        base_lifetime = value
        _rebuild()
# 根元の粒の初速の範囲 [m/s]
@export var base_speed_min := 0.8:
    set(value):
        base_speed_min = value
        _rebuild()
@export var base_speed_max := 1.6:
    set(value):
        base_speed_max = value
        _rebuild()
# 根元の粒の広がり（度）
@export var base_spread := 60.0:
    set(value):
        base_spread = value
        _rebuild()
# 根元の粒の大きさの範囲（メートル）
@export var base_size_min := 0.06:
    set(value):
        base_size_min = value
        _rebuild()
@export var base_size_max := 0.12:
    set(value):
        base_size_max = value
        _rebuild()
# 根元の粒の色（白。不透明のまま、寿命の終わりのほうで透明になる）
@export var base_color := Color(1.0, 1.0, 1.0):
    set(value):
        base_color = value
        _rebuild()
# 水滴の縁の色。明るい水面の前でも粒が見えるようにする
@export var drop_rim_color := Color(0.35, 0.6, 0.85):
    set(value):
        drop_rim_color = value
        _rebuild()
# 水柱の粒の放出元の球の半径（メートル）
@export var emitter_radius := 0.08:
    set(value):
        emitter_radius = value
        _rebuild()
# 粒にかかる重力
@export var gravity := Vector3(0.0, -9.8, 0.0):
    set(value):
        gravity = value
        _rebuild()
# 噴水の音の大きさ [dB]
@export var sound_volume_db := 0.0:
    set(value):
        sound_volume_db = value
        _apply_sound()
# この距離 [m] までは音量がほぼ下がらない
@export var sound_unit_size := 4.0:
    set(value):
        sound_unit_size = value
        _apply_sound()
# この距離 [m] より遠くでは聞こえない
@export var sound_max_distance := 40.0:
    set(value):
        sound_max_distance = value
        _apply_sound()

# 起動時のシェーダーの先読み（shader_warmup.gd）が、ツリーを止めている間も粒を動かせるよう、この名前のグループに入れる
const WARMUP_GROUP := &"warmup_particles"

# 粒が透明になり始める寿命の割合（1.0 で完全に透明）。水柱は終わり近くまで見せ、根元は早めに薄れさせる
const JET_FADE_START := 0.7
const BASE_FADE_START := 0.5

func _ready() -> void:
    _rebuild()
    # 水音はゲーム中だけ流す（エディタでは鳴らさない）
    if not Engine.is_editor_hint():
        _make_sound()

# 噴水の水音を流し続ける。_rebuild は "Sound" を消さない（消すのは "Jet" と "Base" だけ）
func _make_sound() -> void:
    var stream := load("res://assets/audio/water/fountain.ogg") as AudioStream
    if stream == null:
        push_warning("噴水の音を読み込めませんでした: res://assets/audio/water/fountain.ogg")
        return
    # 取り込み設定に頼らず、ここでループにする
    if stream is AudioStreamOggVorbis:
        stream.loop = true
    var player := AudioStreamPlayer3D.new()
    player.name = "Sound"
    player.stream = stream
    player.bus = &"SE"
    player.position = Vector3(0.0, 0.5, 0.0)
    add_child(player)
    _apply_sound()
    # 毎回同じところから始まらないよう、再生位置をランダムにする
    player.play(randf() * stream.get_length())

# "Sound" があれば、export の値を反映する
func _apply_sound() -> void:
    var player := get_node_or_null(^"Sound") as AudioStreamPlayer3D
    if player == null:
        return
    player.volume_db = sound_volume_db
    player.max_db = sound_volume_db
    player.unit_size = sound_unit_size
    player.max_distance = sound_max_distance

# 粒を作り直す。@tool なのでエディタでも動き、export の値を変えるとすぐ反映される。
# シーン読み込み中にもセッターが呼ばれるので、_ready の前（is_node_ready でない間）は何もしない
func _rebuild() -> void:
    if not is_node_ready():
        return
    for child_name in ["Jet", "Base"]:
        var old := get_node_or_null(NodePath(child_name))
        if old != null:
            remove_child(old)
            old.free()
    var mesh := _make_mesh(_make_material(_make_texture()))
    # 作った粒には owner を付けない（シーンファイルに保存されないようにするため）
    add_child(_make_particles("Jet", mesh, jet_amount, jet_lifetime, jet_speed_min, jet_speed_max, jet_spread, jet_size_min, jet_size_max, jet_color, JET_FADE_START, emitter_radius))
    add_child(_make_particles("Base", mesh, base_amount, base_lifetime, base_speed_min, base_speed_max, base_spread, base_size_min, base_size_max, base_color, BASE_FADE_START, 0.0))

func _make_texture() -> GradientTexture2D:
    var g := Gradient.new()
    # 中心が白く、縁に向かって drop_rim_color の輪になり、外側で透明になる水滴
    g.offsets = PackedFloat32Array([0.0, 0.45, 0.7, 0.85, 1.0])
    g.colors = PackedColorArray([
        Color(1, 1, 1, 1),
        Color(0.95, 0.98, 1, 1),
        drop_rim_color,
        Color(drop_rim_color.r, drop_rim_color.g, drop_rim_color.b, 0.6),
        Color(drop_rim_color.r, drop_rim_color.g, drop_rim_color.b, 0.0),
    ])
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

# 上向きに水を飛ばす粒を作る。色は color のまま不透明で、寿命の fade_start の割合から終わりにかけて透明になる。radius が0より大きければ、その球の中から出す
func _make_particles(particle_name: String, mesh: Mesh, amount: int, lifetime: float, speed_min: float, speed_max: float,
        spread: float, size_min: float, size_max: float, color: Color, fade_start: float, radius: float) -> CPUParticles3D:
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
    p.scale_amount_min = size_min
    p.scale_amount_max = size_max
    if radius > 0.0:
        p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
        p.emission_sphere_radius = radius
    # 色（不透明）→ fade_start までは不透明のまま → 同じ色（透明）
    var g := Gradient.new()
    g.offsets = PackedFloat32Array([0.0, fade_start, 1.0])
    g.colors = PackedColorArray([
        Color(color.r, color.g, color.b, 1.0),
        Color(color.r, color.g, color.b, 1.0),
        Color(color.r, color.g, color.b, 0.0),
    ])
    p.color_ramp = g
    p.add_to_group(WARMUP_GROUP)
    return p

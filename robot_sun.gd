extends DirectionalLight3D

# 本物の太陽
@export var sun_path: NodePath
# 機体
@export var vehicle_path: NodePath
# 日なた判定の光線を遮る物理レイヤー（建物・地面の1と、木の3）
@export_flags_3d_physics var occluder_mask: int = 1 | 4
# 機体だけを置く表示レイヤー
@export_flags_3d_render var robot_layer: int = 2
# 機体の影を描く範囲 [m]
@export var shadow_distance: float = 6.0
# 日なた・日陰の切り替えの速さ [1/s]
@export var fade_speed: float = 4.0

const RAY_LENGTH := 200.0
const SAMPLE_OFFSETS := [
    Vector3(0.0, 0.15, 0.0),
    Vector3(0.2, 0.15, 0.25),
    Vector3(-0.2, 0.15, 0.25),
    Vector3(0.2, 0.15, -0.25),
    Vector3(-0.2, 0.15, -0.25),
]

var _sun: DirectionalLight3D
var _vehicle: VehicleBody3D
var _lit := 1.0

func _ready() -> void:
    _sun = get_node_or_null(sun_path) as DirectionalLight3D
    _vehicle = get_node_or_null(vehicle_path) as VehicleBody3D
    if _sun == null or _vehicle == null:
        push_warning("RobotSun: sun_path または vehicle_path が見つからない")
        set_physics_process(false)
        return

    global_transform = _sun.global_transform
    light_color = _sun.light_color
    light_energy = _sun.light_energy
    shadow_enabled = false
    light_bake_mode = Light3D.BAKE_DISABLED
    light_cull_mask = robot_layer
    # 明るさを0にすると空の太陽が黒く描かれるので、空には描かない
    sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY

    for node in _vehicle.find_children("*", "GeometryInstance3D", true, false):
        (node as GeometryInstance3D).layers = robot_layer

    # エディタ上では変えない。ベイク時は静止物も影を落とす必要があるため
    _sun.light_cull_mask &= ~robot_layer
    _sun.shadow_caster_mask = robot_layer
    _sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    _sun.directional_shadow_max_distance = shadow_distance

    _lit = 1.0

func _physics_process(delta: float) -> void:
    # DirectionalLight は -Z 方向へ照らすので、+Z が太陽の方向
    var to_sun := global_basis.z
    var space := _vehicle.get_world_3d().direct_space_state
    var lit_count := 0
    for offset in SAMPLE_OFFSETS:
        var p: Vector3 = _vehicle.global_position + _vehicle.global_basis * offset
        if not _is_occluded(space, p, p + to_sun * RAY_LENGTH):
            lit_count += 1
    var target := lit_count / float(SAMPLE_OFFSETS.size())
    _lit = move_toward(_lit, target, fade_speed * delta)
    light_energy = _sun.light_energy * _lit

func _is_occluded(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [_vehicle.get_rid()]
    query.collision_mask = occluder_mask
    return not space.intersect_ray(query).is_empty()

extends DirectionalLight3D

# 本物の太陽
@export var sun_path: NodePath
# 機体
@export var vehicle_path: NodePath
# 木のノード（当たり判定がないので箱で影を判定する）
@export var trees_path: NodePath
# 機体だけを置く表示レイヤー
@export_flags_3d_render var robot_layer: int = 2
# 機体の影を描く範囲 [m]
@export var shadow_distance: float = 6.0
# 日なた・日陰の切り替えの速さ [1/s]
@export var fade_speed: float = 4.0

const RAY_LENGTH := 200.0
# これより水平方向に離れた木の箱は判定しない [m]
const TREE_MAX_DISTANCE := 80.0
const SAMPLE_OFFSETS := [
    Vector3(0.0, 0.15, 0.0),
    Vector3(0.2, 0.15, 0.25),
    Vector3(-0.2, 0.15, 0.25),
    Vector3(0.2, 0.15, -0.25),
    Vector3(-0.2, 0.15, -0.25),
]

var _sun: DirectionalLight3D
var _vehicle: VehicleBody3D
var _tree_boxes: Array[AABB] = []
var _tree_centers: Array[Vector3] = []
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

    for node in _vehicle.find_children("*", "GeometryInstance3D", true, false):
        (node as GeometryInstance3D).layers = robot_layer

    # エディタ上では変えない。ベイク時は静止物も影を落とす必要があるため
    _sun.light_cull_mask &= ~robot_layer
    _sun.shadow_caster_mask = robot_layer
    _sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    _sun.directional_shadow_max_distance = shadow_distance

    var trees := get_node_or_null(trees_path)
    if trees != null:
        for node in trees.find_children("*", "MeshInstance3D", true, false):
            var mi := node as MeshInstance3D
            var box := mi.global_transform * mi.get_aabb()
            _tree_boxes.append(box)
            _tree_centers.append(box.get_center())
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
    if not space.intersect_ray(query).is_empty():
        return true
    for i in _tree_boxes.size():
        var c := _tree_centers[i]
        if Vector2(c.x - from.x, c.z - from.z).length() > TREE_MAX_DISTANCE:
            continue
        if _tree_boxes[i].intersects_segment(from, to):
            return true
    return false

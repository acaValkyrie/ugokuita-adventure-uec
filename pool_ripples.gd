extends Node

# 機体がプールの水面（y=0.5）を上下にまたいだときに波紋の発生点を記録して、プールの底のシェーダーに渡す

# 機体のノード
@export var vehicle_path: NodePath = ^"../VehicleBody3D"
# プールの底のノード
@export var floor_path: NodePath = ^"../UEC/ground/プールの底"

const MAX_RIPPLES := 8
# プールの長方形（pool.gdshader と同じ値。x が短辺、y が長辺）
const POOL_CENTER := Vector2(-207.759, -178.832)
const POOL_LONG_AXIS := Vector2(0.2664, -0.9639)
const POOL_HALF_SIZE := Vector2(6.69, 12.705)
# 水面の高さ（ワールドY）
const POOL_WATER_Y := 0.5
# 波紋の強さの最小値
const MIN_STRENGTH := 0.4
# この縦の速さ [m/s] で水面をまたぐと波紋が最大になる
const FULL_VERTICAL_SPEED := 3.0

var _now := 0.0
var _ripples: Array[Vector4] = []
var _next_index := 0
var _was_below := false
var _has_prev := false
var _floor_material: ShaderMaterial

func _ready() -> void:
    _ripples.clear()
    for i in MAX_RIPPLES:
        _ripples.append(Vector4.ZERO)
    var floor_mesh := get_node_or_null(floor_path) as MeshInstance3D
    if floor_mesh:
        _floor_material = floor_mesh.get_surface_override_material(0) as ShaderMaterial
    if _floor_material == null:
        push_warning("プールの底のマテリアルが見つかりません: %s" % floor_path)

func _physics_process(delta: float) -> void:
    _now += delta
    var vehicle := get_node_or_null(vehicle_path) as VehicleBody3D
    if vehicle == null:
        return
    var pos := vehicle.global_position
    # プールの長方形の中にいるか
    var d := Vector2(pos.x, pos.z) - POOL_CENTER
    var short_axis := Vector2(-POOL_LONG_AXIS.y, POOL_LONG_AXIS.x)
    var in_rect := absf(d.dot(short_axis)) < POOL_HALF_SIZE.x \
        and absf(d.dot(POOL_LONG_AXIS)) < POOL_HALF_SIZE.y
    var below := pos.y < POOL_WATER_Y
    # 水面を上下にまたいだ瞬間だけ波紋を出す
    if _has_prev and in_rect and below != _was_below:
        _add_ripple(pos, clampf(absf(vehicle.linear_velocity.y) / FULL_VERTICAL_SPEED, MIN_STRENGTH, 1.0))
    _was_below = below
    _has_prev = true
    if _floor_material == null:
        return
    _floor_material.set_shader_parameter("ripples", PackedVector4Array(_ripples))
    _floor_material.set_shader_parameter("ripple_now", _now)

# 波紋の発生点を1つ記録する（古いものから上書きする）
func _add_ripple(pos: Vector3, strength: float) -> void:
    _ripples[_next_index] = Vector4(pos.x, pos.z, _now, strength)
    _next_index = (_next_index + 1) % MAX_RIPPLES

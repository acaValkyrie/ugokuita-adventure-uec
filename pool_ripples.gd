extends Node

# 機体がプールの中を動くと波紋の発生点を記録して、プールの底のシェーダーに渡す

# 機体のノード
@export var vehicle_path: NodePath = ^"../VehicleBody3D"
# プールの底のノード
@export var floor_path: NodePath = ^"../UEC/ground/プールの底"
# 動いている間に波紋を出す間隔 [秒]
@export var ripple_interval := 0.2
# 波紋を出す最低の速さ [m/s]
@export var min_speed := 0.5

const MAX_RIPPLES := 8
# プールの長方形（pool.gdshader と同じ値。x が短辺、y が長辺）
const POOL_CENTER := Vector2(-207.759, -178.832)
const POOL_LONG_AXIS := Vector2(0.2664, -0.9639)
const POOL_HALF_SIZE := Vector2(6.69, 12.705)
# 水面 y=0.5 より少し上まで。台座 y=1.0 の上はプールの外
const POOL_INSIDE_MAX_Y := 0.8
# プールに入ったときの波紋の強さ
const ENTRY_STRENGTH := 1.0
# 動いている間の波紋の強さの範囲
const MOVE_STRENGTH_MAX := 0.8
const MOVE_STRENGTH_MIN := 0.3
# この速さ [m/s] で波紋と乱れが最大になる
const FULL_SPEED := 6.0

var _now := 0.0
var _ripples: Array[Vector4] = []
var _next_index := 0
var _since_last := 0.0
var _was_inside := false
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
    var inside := absf(d.dot(short_axis)) < POOL_HALF_SIZE.x \
        and absf(d.dot(POOL_LONG_AXIS)) < POOL_HALF_SIZE.y \
        and pos.y < POOL_INSIDE_MAX_Y
    var speed := Vector2(vehicle.linear_velocity.x, vehicle.linear_velocity.z).length()
    if inside and not _was_inside:
        _add_ripple(pos, ENTRY_STRENGTH)
        _since_last = 0.0
    elif inside and speed > min_speed:
        _since_last += delta
        if _since_last >= ripple_interval:
            _since_last = 0.0
            _add_ripple(pos, clampf(speed / FULL_SPEED, MOVE_STRENGTH_MIN, MOVE_STRENGTH_MAX))
    _was_inside = inside
    # 機体の周りの乱れ
    var wake_strength := clampf(speed / FULL_SPEED, 0.0, 1.0) if inside else 0.0
    var wake := Vector4(pos.x, pos.z, wake_strength, 0.0)
    if _floor_material == null:
        return
    _floor_material.set_shader_parameter("ripples", PackedVector4Array(_ripples))
    _floor_material.set_shader_parameter("ripple_now", _now)
    _floor_material.set_shader_parameter("vehicle_wake", wake)

# 波紋の発生点を1つ記録する（古いものから上書きする）
func _add_ripple(pos: Vector3, strength: float) -> void:
    _ripples[_next_index] = Vector4(pos.x, pos.z, _now, strength)
    _next_index = (_next_index + 1) % MAX_RIPPLES

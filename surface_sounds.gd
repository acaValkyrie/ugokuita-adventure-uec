extends Node3D

# 草の上を走るときの音
@export var grass_sounds: Array[AudioStream] = []
# 水の上を走るときの音
@export var water_sounds: Array[AudioStream] = []
# この距離 [m] 進むごとに草の音を1つ鳴らす
@export var grass_step := 0.35
# 水の音の間隔 [m]
@export var water_step := 0.6
# 間隔のばらつき（割合）
@export var step_jitter := 0.3
# 音の高さのばらつき（割合）
@export var pitch_jitter := 0.1
@export var volume_db := -6.0

const POOL_SIZE := 4

# 鳴らした回数（テスト用）
var played_count := 0
# 機体の下の地面の種類（テスト用）
var current_kind := ""

var _pool: Array[AudioStreamPlayer3D] = []
var _pool_index := 0
var _distance := 0.0
var _next_step := 0.35

func _ready() -> void:
    for i in POOL_SIZE:
        var player := AudioStreamPlayer3D.new()
        player.unit_size = 3.0
        player.max_db = 0.0
        add_child(player)
        _pool.append(player)
    _next_step = grass_step

func _physics_process(delta: float) -> void:
    var vehicle := get_parent() as VehicleBody3D
    if vehicle == null:
        return
    current_kind = _ground_kind(vehicle)
    var sounds: Array[AudioStream] = []
    var step := grass_step
    if current_kind == "grass":
        sounds = grass_sounds
    elif current_kind == "water":
        sounds = water_sounds
        step = water_step
    if sounds.is_empty():
        _distance = 0.0
        return
    var speed := absf(vehicle._motor_speed)
    _distance += speed * delta
    if _distance < _next_step:
        return
    var player := _pool[_pool_index]
    _pool_index = (_pool_index + 1) % _pool.size()
    player.stream = sounds[randi() % sounds.size()]
    player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
    player.volume_db = volume_db + linear_to_db(clampf(speed / vehicle.MAX_SPEED * 2.0, 0.2, 1.0))
    player.play()
    played_count += 1
    _distance = 0.0
    _next_step = step * (1.0 + randf_range(-step_jitter, step_jitter))

# 機体の真下の地面の種類を返す（取り込み時にメッシュへ付けたメタデータを見る）
func _ground_kind(vehicle: VehicleBody3D) -> String:
    var from := vehicle.global_position + Vector3(0.0, 0.3, 0.0)
    var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -1.0, 0.0), 1, [vehicle.get_rid()])
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return ""
    var parent := (hit["collider"] as Node).get_parent()
    if parent == null:
        return ""
    return parent.get_meta("surface_kind", "")

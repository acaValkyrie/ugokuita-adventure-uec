extends Node3D

# 草の上を走るときの音
@export var grass_sounds: Array[AudioStream] = []
# 水の上を走るときに流し続ける音
@export var water_loop: AudioStream
# この距離 [m] 進むごとに草の音を1つ鳴らす
@export var grass_step := 0.35
# 間隔のばらつき（割合）
@export var step_jitter := 0.3
# 音の高さのばらつき（割合）
@export var pitch_jitter := 0.1
@export var volume_db := -6.0

const POOL_SIZE := 4
# 水の音の音量が目標へ近づく速さ [1/s]
const WATER_FADE_SPEED := 6.0

# 鳴らした回数（テスト用）
var played_count := 0
# 機体の下の地面の種類（テスト用）
var current_kind := ""

var _water_player: AudioStreamPlayer3D
# 水の音の現在の音量（線形 0〜1）
var _water_gain := 0.0
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_index := 0
var _distance := 0.0
var _next_step := 0.35

func _ready() -> void:
    for i in POOL_SIZE:
        var player := AudioStreamPlayer3D.new()
        player.unit_size = 3.0
        player.max_db = 0.0
        player.bus = "SE"
        add_child(player)
        _pool.append(player)
    _next_step = grass_step
    # 水の音は1つのプレイヤーでループさせ続け、音量だけを上げ下げする
    _water_player = AudioStreamPlayer3D.new()
    _water_player.unit_size = 3.0
    _water_player.max_db = 0.0
    _water_player.bus = "SE"
    if water_loop != null:
        var stream := water_loop.duplicate() as AudioStream
        if stream is AudioStreamOggVorbis:
            (stream as AudioStreamOggVorbis).loop = true
        _water_player.stream = stream
    add_child(_water_player)

func _physics_process(delta: float) -> void:
    var vehicle := get_parent() as VehicleBody3D
    if vehicle == null:
        return
    current_kind = _ground_kind(vehicle)
    var speed := absf(vehicle._motor_speed)
    _update_water(vehicle, speed, delta)
    _update_grass(vehicle, speed, delta)

# 水の上では速さに応じた音量でループを流し、離れたらフェードアウトして止める
func _update_water(vehicle: VehicleBody3D, speed: float, delta: float) -> void:
    if _water_player.stream == null:
        return
    var target := 0.0
    if current_kind == "water":
        target = clampf(speed / vehicle.MAX_SPEED * 2.0, 0.0, 1.0)
    _water_gain = lerpf(_water_gain, target, 1.0 - exp(-WATER_FADE_SPEED * delta))
    if _water_gain > 0.01:
        if not _water_player.playing:
            # ループの同じ所から始まらないように、開始位置をずらす
            _water_player.play(randf() * _water_player.stream.get_length())
        _water_player.volume_db = volume_db + linear_to_db(_water_gain)
    elif _water_player.playing:
        _water_player.stop()

# 草の上では一定の距離ごとにワンショットを鳴らす
func _update_grass(vehicle: VehicleBody3D, speed: float, delta: float) -> void:
    var sounds: Array[AudioStream] = []
    if current_kind == "grass":
        sounds = grass_sounds
    if sounds.is_empty():
        _distance = 0.0
        return
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
    _next_step = grass_step * (1.0 + randf_range(-step_jitter, step_jitter))

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

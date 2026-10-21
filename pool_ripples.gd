extends Node

# 機体が水面（プールなら y=0.5）を上下にまたいだときに波紋の発生点を記録して、底のシェーダーに渡す。
# 既定値はプールの値。噴水などプール以外の水面では export で値を変えて使う

# 機体のノード
@export var vehicle_path: NodePath = ^"../VehicleBody3D"
# 水面の底のノード
@export var floor_path: NodePath = ^"../UEC/ground/プールの底"
# 水面の長方形の中心（ワールドXZ。pool.gdshader と同じ値）
@export var water_center := Vector2(-207.759, -178.832)
# 水面の長辺の向き（単位ベクトル、ワールドXZ）
@export var long_axis := Vector2(0.2664, -0.9639)
# 水面の半分の大きさ（x が短辺方向、y が長辺方向、メートル）
@export var half_size := Vector2(6.69, 12.705)
# 水面の高さ（ワールドY）
@export var water_y := 0.5
# 0 より大きいとき、長方形でなく water_center を中心とするこの半径（メートル）の円を水面とみなす
@export var radius := 0.0
# 0 より大きいとき、この間隔（秒）ごとに water_center へ波紋を記録する（音は鳴らさない。噴水の湧き上がる水が水面を揺らす表現）
@export var constant_ripple_interval := 0.0
# 一定の間隔で出す波紋の強さ
@export var constant_ripple_strength := 0.0

# 水中の判定に使うグループ
const WATER_GROUP := "water_areas"
const MAX_RIPPLES := 8
# 普通に飛び込んだとき（縦の速さ REFERENCE_VERTICAL_SPEED）の波紋の強さ（プレビューで決めた値）
const BASE_STRENGTH := 8.35
# 普通に飛び込んだときの縦の速さ [m/s]（台座の高さから落ちたくらい）
const REFERENCE_VERTICAL_SPEED := 3.5
# 縦の速さによる強さの倍率の範囲（ゆっくり出入りしたとき〜高く跳んでから落ちたとき）
const MIN_SCALE := 0.3
const MAX_SCALE := 2.0
# 水面をまたいだときのしぶきの音（普通に飛び込んだときの音量 [dB]）
const SPLASH_SOUND := preload("res://assets/audio/water/water_splash.ogg")
const SPLASH_VOLUME_DB := 9.0
# しぶきの音の再生開始位置 [s]。音源は 0.49 秒あたりで水を打つ音が最大になり、それより前は小さな前置きなので、ここから鳴らして水面を通った瞬間に合わせる
const SPLASH_START := 0.3

# 鳴らした回数（テスト用）
var splash_count := 0

var _splash_player: AudioStreamPlayer3D
var _now := 0.0
# 次に一定の間隔の波紋を出す時刻
var _next_constant_ripple := 0.0
var _ripples: Array[Vector4] = []
var _next_index := 0
var _was_below := false
var _has_prev := false
var _floor_material: ShaderMaterial

func _ready() -> void:
    add_to_group(WATER_GROUP)
    _ripples.clear()
    for i in MAX_RIPPLES:
        _ripples.append(Vector4.ZERO)
    var floor_mesh := get_node_or_null(floor_path) as MeshInstance3D
    if floor_mesh:
        _floor_material = floor_mesh.get_surface_override_material(0) as ShaderMaterial
    if _floor_material == null:
        push_warning("水面の底のマテリアルが見つかりません: %s" % floor_path)
    _splash_player = AudioStreamPlayer3D.new()
    _splash_player.unit_size = 3.0
    _splash_player.max_db = SPLASH_VOLUME_DB
    _splash_player.bus = "SE"
    _splash_player.stream = SPLASH_SOUND
    add_child(_splash_player)

func _physics_process(delta: float) -> void:
    _now += delta
    # 一定の間隔で水面の中心に波紋を出す
    if constant_ripple_interval > 0.0 and _now >= _next_constant_ripple:
        _next_constant_ripple = _now + constant_ripple_interval
        _add_ripple(Vector3(water_center.x, water_y, water_center.y), constant_ripple_strength)
    var vehicle := get_node_or_null(vehicle_path) as VehicleBody3D
    if vehicle != null:
        var pos := vehicle.global_position
        var in_water := _is_inside_xz(pos)
        var below := pos.y < water_y
        # 水面を上下にまたいだ瞬間だけ波紋を出す
        if _has_prev and in_water and below != _was_below:
            # 縦の速さによる倍率は、波紋の強さとしぶきの音量で共有する
            var scale := clampf(absf(vehicle.linear_velocity.y) / REFERENCE_VERTICAL_SPEED, MIN_SCALE, MAX_SCALE)
            _add_ripple(pos, BASE_STRENGTH * scale)
            _play_splash(pos, scale)
        _was_below = below
        _has_prev = true
    if _floor_material == null:
        return
    _floor_material.set_shader_parameter("ripples", PackedVector4Array(_ripples))
    _floor_material.set_shader_parameter("ripple_now", _now)

# 水面の中（円または長方形）にいるか
func _is_inside_xz(pos: Vector3) -> bool:
    var d := Vector2(pos.x, pos.z) - water_center
    if radius > 0.0:
        return d.length() < radius
    var short_axis := Vector2(-long_axis.y, long_axis.x)
    return absf(d.dot(short_axis)) < half_size.x \
        and absf(d.dot(long_axis)) < half_size.y

# その点が水の中（水面の範囲の真下で、水面より低い）か
func is_under_water(pos: Vector3) -> bool:
    return pos.y < water_y and _is_inside_xz(pos)

# 水面をまたいだ位置でしぶきの音を鳴らす（音量は普通の飛び込みより強くしない）
func _play_splash(pos: Vector3, scale: float) -> void:
    _splash_player.global_position = pos
    _splash_player.volume_db = SPLASH_VOLUME_DB + linear_to_db(clampf(scale, MIN_SCALE, 1.0))
    _splash_player.pitch_scale = 1.0 + randf_range(-0.08, 0.08)
    _splash_player.play(SPLASH_START)
    splash_count += 1

# 波紋の発生点を1つ記録する（古いものから上書きする）
func _add_ripple(pos: Vector3, strength: float) -> void:
    _ripples[_next_index] = Vector4(pos.x, pos.z, _now, strength)
    _next_index = (_next_index + 1) % MAX_RIPPLES

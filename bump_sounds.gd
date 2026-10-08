extends Node3D

# 段差を乗り越えたときの音
@export var sounds: Array[AudioStream] = []
# 段差の音に重ねる音（Classic のカチャカチャ。空なら鳴らさない）
@export var rattle_sounds: Array[AudioStream] = []
@export var rattle_volume_db := 0.0
# サスペンションがこの速さ [m/s] より速く縮む・伸びたら段差とみなす
@export var min_speed := 0.7
# この速さで最大音量
@export var full_speed := 2.0
# 同じタイヤで続けて鳴らさない時間 [s]
@export var cooldown := 0.15
@export var volume_db := 0.0

# 鳴らした回数（テスト用）
var played_count := 0
# 前回のリセット以降のサスペンションの最大の速さ [m/s]（テスト用）
var max_abs_v := 0.0

# {wheel, player, rattle, prev_y, prev_contact, timer}
var _wheels: Array[Dictionary] = []
var _has_prev := false

func _ready() -> void:
    for node in get_parent().get_children():
        var wheel := node as VehicleWheel3D
        if wheel == null:
            continue
        # タイヤの位置から音が鳴るようにタイヤの子にする
        var player := AudioStreamPlayer3D.new()
        player.unit_size = 3.0
        wheel.add_child(player)
        # 段差の音に重ねるカチャカチャ音用
        var rattle := AudioStreamPlayer3D.new()
        rattle.unit_size = 3.0
        wheel.add_child(rattle)
        _wheels.append({"wheel": wheel, "player": player, "rattle": rattle, "prev_y": 0.0, "prev_contact": false, "timer": 0.0})

func _physics_process(delta: float) -> void:
    var vehicle := get_parent() as VehicleBody3D
    if vehicle == null or delta <= 0.0:
        return
    var inv := vehicle.global_transform.affine_inverse()
    for w in _wheels:
        var wheel: VehicleWheel3D = w["wheel"]
        var y: float = (inv * wheel.global_position).y
        var contact := wheel.is_in_contact()
        w["timer"] = maxf(w["timer"] - delta, 0.0)
        if _has_prev:
            var v: float = (y - w["prev_y"]) / delta
            var landed: bool = contact and not w["prev_contact"]
            max_abs_v = maxf(max_abs_v, absf(v))
            if (absf(v) > min_speed or landed) and w["timer"] <= 0.0 and contact and not sounds.is_empty():
                var strength := maxf(absf(v), full_speed * 0.6 if landed else 0.0)
                var player: AudioStreamPlayer3D = w["player"]
                player.stream = sounds[randi() % sounds.size()]
                player.pitch_scale = 1.0 + randf_range(-0.08, 0.08)
                player.volume_db = volume_db + linear_to_db(clampf(strength / full_speed, 0.25, 1.0))
                player.play()
                played_count += 1
                if not rattle_sounds.is_empty():
                    var rattle: AudioStreamPlayer3D = w["rattle"]
                    rattle.stream = rattle_sounds[randi() % rattle_sounds.size()]
                    rattle.pitch_scale = 1.0 + randf_range(-0.1, 0.15)
                    rattle.volume_db = rattle_volume_db + linear_to_db(clampf(strength / full_speed, 0.25, 1.0))
                    rattle.play()
                w["timer"] = cooldown
        w["prev_y"] = y
        w["prev_contact"] = contact
    _has_prev = true

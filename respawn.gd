extends Node
# 動けなくなったとき、最後に安全だった地点に戻す（時間では判定せず、手動で呼ぶ）

# この距離 [m] 進むごとに安全な地点を記録する
@export var record_interval := 2.0
# この速さ [m/s] 以上で動いているときだけ記録する
@export var min_speed := 0.5
# 戻り先は今の位置からこの距離 [m] 以上離れた地点にする
@export var min_distance := 2.0
# 記録しておく地点の数
@export var max_points := 20
# 戻るときに地面から浮かせる高さ [m]
@export var lift := 0.3
# この時間 [s] 以内の連続操作は、さらに古い地点に戻る
const REPEAT_WINDOW := 3.0

var _points: Array[Transform3D] = []
var _travel := 0.0
var _cursor := -1
var _last_time := -100.0
var _safe_since_respawn := true
# 戻した回数（テスト用）
var respawned_count := 0

func _ready() -> void:
    # 開始位置はそのまま戻り先に使える
    var vehicle := get_parent() as VehicleBody3D
    _points.append(vehicle.global_transform)

func point_count() -> int:
    return _points.size()

func _is_safe(vehicle: VehicleBody3D) -> bool:
    for node in vehicle.get_children():
        var wheel := node as VehicleWheel3D
        if wheel != null and not wheel.is_in_contact():
            return false
    if vehicle.global_basis.y.dot(Vector3.UP) <= 0.9:
        return false
    return vehicle.linear_velocity.length() >= min_speed

func _physics_process(delta: float) -> void:
    var vehicle := get_parent() as VehicleBody3D
    if _is_safe(vehicle):
        _safe_since_respawn = true
        _travel += vehicle.linear_velocity.length() * delta
        if _travel >= record_interval:
            _points.append(vehicle.global_transform)
            while _points.size() > max_points:
                _points.pop_front()
            _travel = 0.0
    if Input.is_action_just_pressed("respawn"):
        respawn()

func respawn() -> void:
    if _points.is_empty():
        return
    var vehicle := get_parent() as VehicleBody3D
    var now := Time.get_ticks_msec() / 1000.0
    var start := _points.size() - 1
    # 続けて押したときは、前回より古い地点に戻る
    if now - _last_time < REPEAT_WINDOW and not _safe_since_respawn:
        start = _cursor - 1
    # 古い地点へ向かう途中で記録が刈り込まれても範囲外にならないようにする
    start = mini(start, _points.size() - 1)
    var index := 0
    for i in range(start, -1, -1):
        if _points[i].origin.distance_to(vehicle.global_position) >= min_distance:
            index = i
            break
    var point := _points[index]
    var target := Transform3D(point.basis.orthonormalized(), point.origin + Vector3.UP * lift)
    var rid := vehicle.get_rid()
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, target)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
    vehicle.global_transform = target
    vehicle._motor_speed = 0.0
    vehicle._boost_time = 0.0
    _cursor = index
    _last_time = now
    _safe_since_respawn = false
    _travel = 0.0
    respawned_count += 1

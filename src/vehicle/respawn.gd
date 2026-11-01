extends Node
# 動けなくなったとき、最後に安全だった地点に戻す（時間では判定せず、手動で呼ぶ）
# 動けなくなっていそうかも判定する（操作説明の Recover に縁取りを付けるため。自動では戻さない）

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
# 動けなくなっていそうと判定するまでの時間 [s]。この間ずっと条件が続き、動いた距離が STUCK_DISTANCE 未満なら判定する
const STUCK_TIME := 2.5
# この時間に動いた距離 [m] がこれ未満なら「ほとんど動いていない」
const STUCK_DISTANCE := 1.0
# 位置を記録する間隔 [s]
const STUCK_SAMPLE_INTERVAL := 0.1

var _points: Array[Transform3D] = []
var _travel := 0.0
var _cursor := -1
var _last_time := -100.0
var _safe_since_respawn := true
# 戻した回数（テスト用）
var respawned_count := 0
# 動けなくなっていそうな状態が続いている時間 [s]、その間に記録した位置、判定の結果
var _stuck_time := 0.0
var _stuck_sample_timer := 0.0
var _stuck_samples: Array[Vector3] = []
var _stuck := false

func _ready() -> void:
    # 開始位置はそのまま戻り先に使える。
    # ただし機体の切り替えでは、旧機体の記録が先に入っている（今の空中・転倒の姿勢は戻り先にしない）ので足さない
    if _points.is_empty():
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

func is_stuck() -> bool:
    return _stuck

# 抜け出そうとしている、または機体の状態がおかしい（動けなくなっていそうかを調べる条件）
func _is_stuck_condition(vehicle: VehicleBody3D) -> bool:
    # エンディング2の無重力では漂うので判定しない
    if Ending.is_zero_gravity():
        return false
    # 進もうとしている
    if absf(Input.get_axis("down", "up")) > 0.5:
        return true
    # ひっくり返っている
    if vehicle.global_basis.y.dot(Vector3.UP) < 0.5:
        return true
    # 浮いたまま（ジェットで浮いているときは除く）
    if Input.is_action_pressed("jump"):
        return false
    for node in vehicle.get_children():
        var wheel := node as VehicleWheel3D
        if wheel != null and wheel.is_in_contact():
            return false
    return true

func _clear_stuck() -> void:
    _stuck_time = 0.0
    _stuck_sample_timer = 0.0
    _stuck_samples.clear()
    _stuck = false

func _update_stuck(vehicle: VehicleBody3D, delta: float) -> void:
    if not _is_stuck_condition(vehicle):
        _clear_stuck()
        return
    _stuck_time += delta
    _stuck_sample_timer += delta
    if _stuck_sample_timer >= STUCK_SAMPLE_INTERVAL:
        _stuck_sample_timer = 0.0
        _stuck_samples.append(vehicle.global_position)
        while _stuck_samples.size() > int(STUCK_TIME / STUCK_SAMPLE_INTERVAL):
            _stuck_samples.pop_front()
    # 一番古い記録から、ほとんど動いていなければ動けなくなっていそうと判定する
    if _stuck_time >= STUCK_TIME and not _stuck_samples.is_empty():
        _stuck = _stuck_samples[0].distance_to(vehicle.global_position) < STUCK_DISTANCE
    else:
        _stuck = false

func _physics_process(delta: float) -> void:
    var vehicle := get_parent() as VehicleBody3D
    _update_stuck(vehicle, delta)
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
    vehicle.cancel_drift()
    # 速度が0になるので、激突と誤検出しないようにする
    vehicle._prev_velocity = Vector3.ZERO
    _cursor = index
    _last_time = now
    _safe_since_respawn = false
    _travel = 0.0
    _clear_stuck()
    respawned_count += 1

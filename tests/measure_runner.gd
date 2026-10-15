extends Node
# 機体の登坂力とBOOSTゲージの貯まり方を自動で測る。結果は results にためて print もする。
# テスト用ステージ（test_stage.gd）の坂の位置を使う。

signal finished

# true のとき、始まったら自動で計測する
@export var run_on_start := false
@export var vehicle_path: NodePath = NodePath("../VehicleBody3D")
@export var stage_path: NodePath = NodePath("..")

# 計測の前に待つ時間 [s]（機体を置いて落ち着かせる）
const SETTLE_TIME := 0.7
# 登坂でアクセルを踏む時間 [s]
const CLIMB_TIME := 10.0
# 登坂の開始位置の z [m]（坂の足元の手前）
const CLIMB_START_Z := -5.0
# BOOST ゲージの計測の開始位置と打ち切り時間
const BOOST_START := Vector3(60.0, 0.3, -150.0)
const BOOST_TIMEOUT := 30.0
const START_HEIGHT := 0.3

var results: Array[String] = []

var _car: VehicleBody3D
var _stage: Node  # test_stage.gd のノード（型は付けられない）


func _ready() -> void:
    _car = get_node(vehicle_path) as VehicleBody3D
    _stage = get_node(stage_path)
    if run_on_start:
        run()


# 全部の計測を順に行う
func run() -> void:
    # PowerUps がシーンの切り替わりで取った効果を消すので、1フレーム待ってから始める
    await get_tree().process_frame
    await get_tree().process_frame
    results.clear()
    for torque in [false, true]:
        _set_power_ups({"torque": true} if torque else {})
        for i in _stage.RAMP_ANGLES.size():
            await _measure_slope(i, torque)
    for boost_charge in [false, true]:
        _set_power_ups({"boost_charge": true} if boost_charge else {})
        await _measure_boost(boost_charge)
    Input.action_release("up")
    _set_power_ups({})
    finished.emit()


func _set_power_ups(acquired: Dictionary) -> void:
    PowerUps._acquired = acquired


# i 番目の坂を登り、開始時の高さからの最大の上昇量を記録する
func _measure_slope(i: int, torque: bool) -> void:
    var angle: float = _stage.RAMP_ANGLES[i]
    var start_z: float = _stage.ramp_foot_z() + CLIMB_START_Z
    _place_car(Vector3(_stage.ramp_center_x(i), START_HEIGHT, start_z))
    await _wait(SETTLE_TIME)
    var start_y := _car.global_position.y
    var max_height := 0.0
    Input.action_press("up")
    var elapsed := 0.0
    while elapsed < CLIMB_TIME:
        await get_tree().physics_frame
        elapsed += get_physics_process_delta_time()
        max_height = maxf(max_height, _car.global_position.y - start_y)
    Input.action_release("up")
    _log("slope torque=%s angle=%d max_height=%.2fm (along slope %.1fm)" \
            % [torque, roundi(angle), max_height, max_height / sin(deg_to_rad(angle))])


# ゲージが 1 になるまでに走った水平距離と時間を記録する
func _measure_boost(boost_charge: bool) -> void:
    _place_car(BOOST_START)
    await _wait(SETTLE_TIME)
    var start := _car.global_position
    Input.action_press("up")
    var elapsed := 0.0
    while elapsed < BOOST_TIMEOUT and _car.boost_gauge < 1.0:
        await get_tree().physics_frame
        elapsed += get_physics_process_delta_time()
    Input.action_release("up")
    var moved := _car.global_position - start
    moved.y = 0.0
    _log("boost boost_charge=%s distance=%.1fm time=%.1fs" % [boost_charge, moved.length(), elapsed])


# 機体を +Z 向き・速度0で置き直し、機体側の状態も初期化する
func _place_car(pos: Vector3) -> void:
    var rid := _car.get_rid()
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, pos))
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, false)
    _car._prev_velocity = Vector3.ZERO
    _car._motor_speed = 0.0
    _car.boost_gauge = 0.0


func _wait(seconds: float) -> void:
    var elapsed := 0.0
    while elapsed < seconds:
        await get_tree().physics_frame
        elapsed += get_physics_process_delta_time()


func _log(line: String) -> void:
    results.append(line)
    print(line)

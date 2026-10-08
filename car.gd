extends VehicleBody3D

@export var MAX_STEER = 0.5
@export var ENGINE_POWER = 80.0
@export var MAX_SPEED = 6.0
@export var BRAKE_FORCE = 1.0
# 走行音のピッチ（停止時〜最高速度）
@export var RUN_SOUND_MIN_PITCH := 0.8
@export var RUN_SOUND_MAX_PITCH := 1.4
# 走行音の音量の追従の速さ [1/s]
@export var RUN_SOUND_FADE := 6.0
# モーター（後輪の外周）の速さの変化の速さ [m/s²]
@export var MOTOR_ACCEL = 12.0
# ジャンプの初速 [m/s]
@export var JUMP_SPEED = 4.0
# ブーストの加速度 [m/s²] と、かける時間 [s]
@export var BOOST_ACCEL = 20.0
@export var BOOST_DURATION = 0.4
# ブーストのゲージが満タンになるまでに走る距離 [m]
@export var BOOST_CHARGE_DISTANCE = 40.0

var _run_sound: AudioStreamPlayer3D
var _run_volume := 0.0
# 後輪の外周の速さ [m/s]、前進が正
var _motor_speed := 0.0
# ブーストのゲージ（0〜1、1で発動できる）
var boost_gauge := 0.0
# ブーストの残り時間 [s] と向き（前が1、後ろが-1）
var _boost_time := 0.0
var _boost_dir := 1.0

func _physics_process(delta: float) -> void:
    steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)

    var throttle = Input.get_axis("down", "up")
    var forward_speed = linear_velocity.dot(global_basis.z)
    # 最高速度に近づくほど推力を絞る（減速方向の入力は絞らない）
    var limit = clampf(1.0 - absf(forward_speed) / MAX_SPEED, 0.0, 1.0)
    if throttle * forward_speed < 0.0:
        limit = 1.0
    engine_force = throttle * ENGINE_POWER * limit
    # 入力がないときはブレーキをかけて坂でずり落ちないようにする
    brake = BRAKE_FORCE if is_zero_approx(throttle) else 0.0

    # アクセル中はモーターの指令に、離したら実際の回転に合わせる（乗り上げて空転しても回り、音も鳴るようにする）
    var wheel_bl := get_node_or_null("VehicleWheel3D_BL") as VehicleWheel3D
    var wheel_br := get_node_or_null("VehicleWheel3D_BR") as VehicleWheel3D
    if wheel_bl != null and wheel_br != null:
        var rpm := (wheel_bl.get_rpm() + wheel_br.get_rpm()) * 0.5
        var measured := rpm / 60.0 * TAU * wheel_bl.wheel_radius
        # 機体が固定されているときなどに回転数がNaNになることがあるので、そのときは0として扱う
        if is_nan(measured):
            measured = 0.0
        var target := measured
        if not is_zero_approx(throttle):
            target = throttle * MAX_SPEED
        _motor_speed = move_toward(_motor_speed, target, MOTOR_ACCEL * delta)

    # 車輪がどれか接地しているときだけジャンプできる
    if Input.is_action_just_pressed("jump") and _is_on_ground():
        apply_central_impulse(Vector3.UP * JUMP_SPEED * mass)

    # 接地して走った水平距離でゲージを貯める（ブースト中は貯めない）
    if _boost_time <= 0.0 and _is_on_ground():
        var horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
        boost_gauge = minf(boost_gauge + horizontal.length() * delta / BOOST_CHARGE_DISTANCE, 1.0)
    # 満タンのときだけ発動できる。後退の入力中なら後ろ向き、それ以外は前向き
    if Input.is_action_just_pressed("boost") and boost_gauge >= 1.0:
        boost_gauge = 0.0
        _boost_time = BOOST_DURATION
        _boost_dir = -1.0 if throttle < 0.0 else 1.0
    if _boost_time > 0.0:
        apply_central_force(global_basis.z * _boost_dir * BOOST_ACCEL * mass)
        _boost_time -= delta


func _is_on_ground() -> bool:
    for child in get_children():
        var wheel := child as VehicleWheel3D
        if wheel != null and wheel.is_in_contact():
            return true
    return false


# 見た目のタイヤ（ugokuita-neo内）を物理ホイールの回転・ステアリング・サスペンションに合わせて動かす
# group: 上下とステアリングで動かすキャスター部分（前輪のみ。後輪は空で部品を直接動かす）
# parts: 1つ目がタイヤ、2つ目がハブ（回転する部品）
const WHEELS := {
    "VehicleWheel3D_FL": {
        "group": "Main Frame III v42/4944825545635 v13_1/4944825545635 v13",
        "parts": [
            "Main Frame III v42/4944825545635 v13_1/4944825545635 v13/Wheel",
            "Main Frame III v42/4944825545635 v13_1/4944825545635 v13/Body85",
        ],
    },
    "VehicleWheel3D_FR": {
        "group": "Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)",
        "parts": [
            "Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)/Body1_029",
            "Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)/Body2_011",
        ],
    },
    "VehicleWheel3D_BL": {
        "group": "",
        "parts": [
            "Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body48",
            "Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body1_001",
        ],
    },
    "VehicleWheel3D_BR": {
        "group": "",
        "parts": [
            "Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body2_008",
            "Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body1_024",
        ],
    },
}

# ステアリングの見た目の向き（左入力でsteering > 0）
const STEER_SIGN := 1.0

# {wheel, group, group_rest, group_pivot, parts: [{node, rest}], pivot, axis, angle, tire_center_body}
var _visual_wheels: Array[Dictionary] = []

func _ready() -> void:
    add_to_group("player")
    _setup_run_sound()
    var model := get_node_or_null("ugokuita-neo")
    if model == null:
        push_warning("ugokuita-neo が見つからない")
        return
    var body_inv := global_transform.affine_inverse()
    for wheel_name in WHEELS:
        var wheel := get_node_or_null(NodePath(wheel_name)) as VehicleWheel3D
        if wheel == null:
            push_warning("%s が見つからない" % wheel_name)
            continue
        var info: Dictionary = WHEELS[wheel_name]
        var parts: Array[Dictionary] = []
        var pivot := Vector3.ZERO
        var axis := Vector3.RIGHT
        var tire_center_body := Vector3.ZERO
        var group_pivot := Vector3.ZERO
        var moved_parent: Node3D = null
        var group: Node3D = null
        if info["group"] != "":
            group = model.get_node_or_null(NodePath(info["group"])) as Node3D
            if group == null:
                push_warning("キャスターが見つからない: %s" % info["group"])
        for i in info["parts"].size():
            var path: String = info["parts"][i]
            var node := model.get_node_or_null(NodePath(path)) as MeshInstance3D
            if node == null:
                push_warning("タイヤの部品が見つからない: %s" % path)
                continue
            parts.append({"node": node, "rest": node.transform})
            # 1つ目（タイヤ）のAABB中心を回転の中心にし、車体のX軸を回転軸にする
            if i == 0:
                var parent := node.get_parent() as Node3D
                pivot = (node.transform * node.get_aabb()).get_center()
                axis = (parent.global_basis.inverse() * global_basis.x).normalized()
                var center_global := (node.global_transform * node.get_aabb()).get_center()
                tire_center_body = body_inv * center_global
                if group != null:
                    group_pivot = group.get_parent().global_transform.affine_inverse() * center_global
        if parts.is_empty():
            continue
        if group != null:
            moved_parent = group.get_parent() as Node3D
        else:
            moved_parent = parts[0]["node"].get_parent() as Node3D
        _visual_wheels.append({
            "wheel": wheel, "group": group, "moved_parent": moved_parent,
            "group_rest": group.transform if group != null else Transform3D.IDENTITY,
            "group_pivot": group_pivot, "parts": parts, "pivot": pivot, "axis": axis,
            "angle": 0.0, "tire_center_body": tire_center_body,
        })

func _setup_run_sound() -> void:
    _run_sound = get_node_or_null("RunningSound") as AudioStreamPlayer3D
    if _run_sound == null:
        return
    var wav := _run_sound.stream as AudioStreamWAV
    if wav != null:
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = wav.data.size() / 2
    _run_sound.volume_db = -80.0
    _run_sound.play()

func _update_run_sound(delta: float) -> void:
    if _run_sound == null:
        return
    var wheel_speed := absf(_motor_speed)
    var ratio := clampf(wheel_speed / MAX_SPEED, 0.0, 1.0)
    var target := smoothstep(0.02, 0.25, ratio)
    _run_volume = move_toward(_run_volume, target, RUN_SOUND_FADE * delta)
    _run_sound.volume_db = linear_to_db(maxf(_run_volume, 0.0001))
    _run_sound.pitch_scale = lerpf(RUN_SOUND_MIN_PITCH, RUN_SOUND_MAX_PITCH, ratio)

func _process(delta: float) -> void:
    _update_run_sound(delta)
    var body_inv := global_transform.affine_inverse()
    for w in _visual_wheels:
        var wheel: VehicleWheel3D = w["wheel"]
        # 見た目のタイヤ中心の車体上下位置を物理ホイール中心に合わせる
        var dy: float = (body_inv * wheel.global_position).y - w["tire_center_body"].y
        var moved_parent: Node3D = w["moved_parent"]
        var to_local := moved_parent.global_basis.inverse()
        var offset_local: Vector3 = to_local * (global_basis * Vector3(0.0, dy, 0.0))
        var offset := Transform3D(Basis.IDENTITY, offset_local)

        var spin := wheel.get_rpm() / 60.0 * TAU
        if wheel.use_as_traction:
            spin = _motor_speed / wheel.wheel_radius
        var angle: float = fposmod(w["angle"] + spin * delta, TAU)
        w["angle"] = angle
        var rot := Basis(w["axis"], angle)
        var around := Transform3D(rot, w["pivot"] - rot * w["pivot"])

        var group: Node3D = w["group"]
        if group != null:
            # 前輪: キャスターを上下させてステアリング方向に向ける（回転はタイヤ中心まわり）
            var up_axis: Vector3 = (to_local * global_basis.y).normalized()
            var steer := Basis(up_axis, wheel.steering * STEER_SIGN)
            var gp: Vector3 = w["group_pivot"]
            group.transform = offset * Transform3D(steer, gp - steer * gp) * w["group_rest"]
            for part in w["parts"]:
                part["node"].transform = around * part["rest"]
        else:
            # 後輪: 部品を直接上下させる
            for part in w["parts"]:
                part["node"].transform = offset * around * part["rest"]

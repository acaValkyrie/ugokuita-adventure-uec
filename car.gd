extends VehicleBody3D

@export var MAX_STEER = 0.5
@export var ENGINE_POWER = 80.0
@export var MAX_SPEED = 6.0
@export var BRAKE_FORCE = 1.0

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

# 見た目のタイヤ（ugokuita-neo内）を物理ホイールの回転に合わせて回す
# 各リストの1つ目がタイヤ、2つ目がハブ
const WHEEL_PARTS := {
    "VehicleWheel3D_FL": [
        "Main Frame III v42/4944825545635 v13_1/4944825545635 v13/Wheel",
        "Main Frame III v42/4944825545635 v13_1/4944825545635 v13/Body85",
    ],
    "VehicleWheel3D_FR": [
        "Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)/Body1_029",
        "Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)/Body2_011",
    ],
    "VehicleWheel3D_BL": [
        "Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body48",
        "Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body1_001",
    ],
    "VehicleWheel3D_BR": [
        "Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body2_008",
        "Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body1_024",
    ],
}

# {wheel, parts: [{node, rest}], pivot, axis, angle}
var _spin_wheels: Array[Dictionary] = []

func _ready() -> void:
    var model := get_node_or_null("ugokuita-neo")
    if model == null:
        push_warning("ugokuita-neo が見つからない")
        return
    for wheel_name in WHEEL_PARTS:
        var wheel := get_node_or_null(NodePath(wheel_name)) as VehicleWheel3D
        if wheel == null:
            push_warning("%s が見つからない" % wheel_name)
            continue
        var parts: Array[Dictionary] = []
        var pivot := Vector3.ZERO
        var axis := Vector3.RIGHT
        for i in WHEEL_PARTS[wheel_name].size():
            var path: String = WHEEL_PARTS[wheel_name][i]
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
        if parts.is_empty():
            continue
        _spin_wheels.append({"wheel": wheel, "parts": parts, "pivot": pivot, "axis": axis, "angle": 0.0})

func _process(delta: float) -> void:
    for w in _spin_wheels:
        var angle: float = fposmod(w["angle"] + w["wheel"].get_rpm() / 60.0 * TAU * delta, TAU)
        w["angle"] = angle
        var rot := Basis(w["axis"], angle)
        var around := Transform3D(rot, w["pivot"] - rot * w["pivot"])
        for part in w["parts"]:
            part["node"].transform = around * part["rest"]

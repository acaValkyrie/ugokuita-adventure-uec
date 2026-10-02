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

func _process(delta: float) -> void:
    var body_inv := global_transform.affine_inverse()
    for w in _visual_wheels:
        var wheel: VehicleWheel3D = w["wheel"]
        # 見た目のタイヤ中心の車体上下位置を物理ホイール中心に合わせる
        var dy: float = (body_inv * wheel.global_position).y - w["tire_center_body"].y
        var moved_parent: Node3D = w["moved_parent"]
        var to_local := moved_parent.global_basis.inverse()
        var offset_local: Vector3 = to_local * (global_basis * Vector3(0.0, dy, 0.0))
        var offset := Transform3D(Basis.IDENTITY, offset_local)

        var angle: float = fposmod(w["angle"] + wheel.get_rpm() / 60.0 * TAU * delta, TAU)
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

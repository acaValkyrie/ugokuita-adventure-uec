extends Camera3D

var vehicle
@export var vehicle_path: NodePath
# 車の向きへの追従の速さ（大きいほど素早く回り込む）
@export var follow_speed: float = 4.0
# 視点操作をやめたあと、真後ろへ戻る速さ [rad/s]
@export var offset_return_speed: float = 2.0
# この速さ [m/s] を超えて走っているときだけ真後ろへ戻す
@export var return_min_speed: float = 0.3

# ブーストやドリフトのダッシュを出した瞬間にカメラを引く距離 [m]
@export var kick_distance: float = 2.0
# 引いた位置を目指す時間 [s]。過ぎたら元の距離へ戻す
@export var kick_hold: float = 0.1
# 引くときと、戻すときの追従の速さ（大きいほど素早い）
@export var kick_out_speed: float = 15.0
@export var kick_in_speed: float = 4.0
# エンディング中のカメラと機体の距離 [m]
@export var ending_radius: float = 1.2
# カメラを遮る物理レイヤー（建物・地面はレイヤー1。木の葉のレイヤー3は含めない）
@export_flags_3d_physics var obstacle_mask: int = 1
# 壁からカメラを離す距離 [m]
@export var obstacle_margin: float = 0.2
# 遮る物がなくなったあと元の距離へ戻る速さ（大きいほど素早い）
@export var obstacle_return_speed: float = 3.0
# 壁に寄せたときの、カメラと機体の最小距離 [m]
@export var obstacle_min_distance: float = 0.4

# 普段のカメラと機体の距離 [m]
const BASE_RADIUS := 2.0

var radius: float = BASE_RADIUS
# カメラと機体の実際の距離 [m]（壁に遮られたときに縮む）
var obstructed_distance: float = BASE_RADIUS
var theta: float = - 0.5 * PI
var phi: float = 0.3 * PI
var theta_offset: float = 0.0
# ダッシュを出してからの時間 [s]
var _kick_time := INF
# 最後に見た機体の dash_count
var _last_dash_count := 0

func to_camera_position() -> Vector3:
    var x = radius * sin(phi) * cos(theta)
    var y = radius * cos(phi)
    var z = radius * sin(phi) * sin(theta)
    return Vector3(x, y, z)

# 車の真後ろにあたる theta を返す。車が大きく傾いて前方向が水平面上で定まらないときは現在の theta を返す
func behind_vehicle_theta() -> float:
    var forward = vehicle.global_basis.z
    var flat = Vector2(forward.x, forward.z)
    if flat.length() < 0.1:
        return theta - theta_offset
    return atan2(-flat.y, -flat.x)

func _ready():
    vehicle = get_node(vehicle_path)
    if not vehicle:
        push_error("Vehicle not found at path: " + str(vehicle_path))
    else:
        _last_dash_count = vehicle.dash_count
        theta = behind_vehicle_theta()
        obstructed_distance = radius
        # Set the camera to follow the vehicle
        global_transform.origin = vehicle.global_transform.origin + to_camera_position()
        look_at(vehicle.global_transform.origin, Vector3.UP)
    # 機体が入れ替わったら追いかける対象を付け替える
    PlayerSwitch.player_changed.connect(func(p):
        vehicle = p
        _last_dash_count = p.dash_count
    )


var theta_speed: float = 3
var phi_speed: float = 1

func _physics_process(delta: float) -> void:
    var input_LR = Input.get_axis("view_left", "view_right")
    var input_UD = Input.get_axis("view_up", "view_down")
    if is_zero_approx(input_LR):
        # 止まっているときは視点を動かした位置のまま残す
        if vehicle.linear_velocity.length() > return_min_speed:
            theta_offset = move_toward(theta_offset, 0.0, offset_return_speed * delta)
    else:
        theta_offset = wrapf(theta_offset + input_LR * theta_speed * delta, -PI, PI)
    phi += -input_UD * phi_speed * delta
    phi = clamp(phi, 0.1, 0.5*PI)  # Prevent camera from flipping over

    # 車の真後ろへ滑らかに回り込む
    var follow_theta = lerp_angle(theta - theta_offset, behind_vehicle_theta(), 1.0 - exp(-follow_speed * delta))
    theta = follow_theta + theta_offset

    # ブーストやドリフトのダッシュを出した瞬間だけ、カメラを一瞬引いてすぐ戻す
    if vehicle.dash_count != _last_dash_count:
        _last_dash_count = vehicle.dash_count
        _kick_time = 0.0
    _kick_time += delta
    var target_radius := BASE_RADIUS + (kick_distance if _kick_time < kick_hold else 0.0)
    # エンディング中は機体に寄せる
    if Ending.is_shown():
        target_radius = ending_radius
    var kick_speed := kick_out_speed if target_radius > radius else kick_in_speed
    radius = lerpf(radius, target_radius, 1.0 - exp(-kick_speed * delta))

    # 機体からカメラへ光線を飛ばし、壁に遮られたら壁の手前へ寄せる
    # （寄るときは即座に、戻るときはゆっくり）
    var origin: Vector3 = vehicle.global_transform.origin
    var offset := to_camera_position()
    var desired := offset.length()
    var query := PhysicsRayQueryParameters3D.create(origin, origin + offset, obstacle_mask, [vehicle.get_rid()])
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var allowed := desired
    if not hit.is_empty():
        allowed = maxf(origin.distance_to(hit.position) - obstacle_margin, obstacle_min_distance)
    if allowed < obstructed_distance:
        obstructed_distance = allowed
    else:
        obstructed_distance = lerpf(obstructed_distance, allowed, 1.0 - exp(-obstacle_return_speed * delta))
    global_transform.origin = origin + offset.normalized() * obstructed_distance
    look_at(origin, Vector3.UP)

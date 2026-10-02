extends Camera3D

var vehicle
@export var vehicle_path: NodePath
# 車の向きへの追従の速さ（大きいほど素早く回り込む）
@export var follow_speed: float = 4.0
# 視点操作をやめたあと、真後ろへ戻る速さ [rad/s]
@export var offset_return_speed: float = 2.0
# この速さ [m/s] を超えて走っているときだけ真後ろへ戻す
@export var return_min_speed: float = 0.3

var radius: float = 2.0
var theta: float = - 0.5 * PI
var phi: float = 0.3 * PI
var theta_offset: float = 0.0

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
        theta = behind_vehicle_theta()
        # Set the camera to follow the vehicle
        global_transform.origin = vehicle.global_transform.origin + to_camera_position()
        look_at(vehicle.global_transform.origin, Vector3.UP)


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

    # Update camera position based on theta and phi
    global_transform.origin = vehicle.global_transform.origin + to_camera_position()
    look_at(vehicle.global_transform.origin, Vector3.UP)

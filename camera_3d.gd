extends Camera3D

var vehicle
@export var vehicle_path: NodePath
# 車の向きへの追従の速さ（大きいほど素早く回り込む）
@export var follow_speed: float = 4.0
# 視点操作をやめたあと、真後ろへ戻る速さ [rad/s]
@export var offset_return_speed: float = 2.0
# この速さ [m/s] を超えて走っているときだけ真後ろへ戻す
@export var return_min_speed: float = 0.3

# 通常の最高速度（機体の MAX_SPEED）を超えたとき、超えた速さ1m/sあたりカメラを離す（近づける）距離 [m]
@export var dash_distance_per_speed: float = 0.2
# 速さに応じて離す距離の上限 [m]
@export var dash_max_distance: float = 1.6
# カメラに向かって進んでいるときに近づける距離の上限 [m]
@export var dash_max_approach: float = 0.8
# カメラを離すときと、近づけて戻すときの追従の速さ（大きいほど素早い）
@export var dash_out_speed: float = 6.0
@export var dash_in_speed: float = 2.0

# 普段のカメラと機体の距離 [m]
const BASE_RADIUS := 2.0

var radius: float = BASE_RADIUS
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

    # 通常の最高速度を超えた分だけ、カメラから遠ざかる向きに進んでいるなら離し、近づく向きなら近づける（ブースト中などのダッシュ演出）
    var velocity: Vector3 = vehicle.linear_velocity
    var over_speed := maxf(velocity.length() - vehicle.MAX_SPEED, 0.0)
    var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
    var away := Vector3(global_position.x - vehicle.global_position.x, 0.0, global_position.z - vehicle.global_position.z)
    # カメラから遠ざかる向きなら1、カメラへ向かう向きなら-1、横向きなら0
    var direction := 0.0
    if flat_velocity.length() > 0.01 and away.length() > 0.01:
        direction = -flat_velocity.normalized().dot(away.normalized())
    var shift := over_speed * dash_distance_per_speed * direction
    var target_radius := BASE_RADIUS + clampf(shift, -dash_max_approach, dash_max_distance)
    # 標準の距離から離れていくときは素早く、戻るときはゆっくり追従する
    var dash_speed := dash_out_speed if absf(target_radius - BASE_RADIUS) > absf(radius - BASE_RADIUS) else dash_in_speed
    radius = lerpf(radius, target_radius, 1.0 - exp(-dash_speed * delta))

    # Update camera position based on theta and phi
    global_transform.origin = vehicle.global_transform.origin + to_camera_position()
    look_at(vehicle.global_transform.origin, Vector3.UP)

extends Camera3D

var vehicle
@export var vehicle_path: NodePath
# 車の向きへの追従の速さ（大きいほど素早く回り込む）
@export var follow_speed: float = 4.0
# 視点操作をやめたあと、真後ろへ戻る速さ [rad/s]
@export var offset_return_speed: float = 2.0
# この速さ [m/s] を超えて走っているときだけ真後ろへ戻す
@export var return_min_speed: float = 0.3

# ブーストやドリフトのダッシュを出した瞬間に、カメラを機体の進む向きと逆へ水平に引く距離 [m]
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
# いまカメラを引いている距離 [m]
var _kick_amount := 0.0
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

# カメラを引く向き。機体の進む向きと逆の水平方向（ほぼ止まっているときは機体の後ろ）。
# 後ろ向きのブーストなどでカメラのほうへ進んでいるときは、カメラを機体の向こうへ押し出さないよう引かない
func _kick_direction(camera_offset: Vector3) -> Vector3:
    var flat := Vector3(vehicle.linear_velocity.x, 0.0, vehicle.linear_velocity.z)
    if flat.length() < 0.5:
        flat = vehicle.global_basis.z
        flat.y = 0.0
    if flat.length() < 0.01:
        return Vector3.ZERO
    var dir := -flat.normalized()
    if dir.dot(Vector3(camera_offset.x, 0.0, camera_offset.z)) < 0.0:
        return Vector3.ZERO
    return dir

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
    # 水中にいるときの見た目
    add_child(preload("res://underwater_view.gd").new())


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

    # ブーストやドリフトのダッシュを出した瞬間だけ、カメラを一瞬引いてすぐ戻す（高さは変えず、進む向きと逆へ水平に引く）
    if vehicle.dash_count != _last_dash_count:
        _last_dash_count = vehicle.dash_count
        _kick_time = 0.0
    _kick_time += delta
    var kick_target := kick_distance if _kick_time < kick_hold else 0.0
    var kick_speed := kick_out_speed if kick_target > _kick_amount else kick_in_speed
    _kick_amount = lerpf(_kick_amount, kick_target, 1.0 - exp(-kick_speed * delta))
    # エンディング中は機体に寄せる
    var target_radius := ending_radius if Ending.is_shown() else BASE_RADIUS
    radius = lerpf(radius, target_radius, 1.0 - exp(-kick_in_speed * delta))

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
    var base_position := origin + offset.normalized() * obstructed_distance
    # ダッシュの引きは、壁を避けた位置からさらに水平に足す（壁に当たる手前で止める）
    var kick := _kick_direction(offset) * _kick_amount
    if not kick.is_zero_approx():
        var kick_query := PhysicsRayQueryParameters3D.create(base_position, base_position + kick, obstacle_mask, [vehicle.get_rid()])
        var kick_hit := get_world_3d().direct_space_state.intersect_ray(kick_query)
        if not kick_hit.is_empty():
            kick = kick.normalized() * maxf(base_position.distance_to(kick_hit.position) - obstacle_margin, 0.0)
    # 引いた位置から機体が見えないとき（低い壁や建物の角）は引かない
    if not kick.is_zero_approx():
        var view_query := PhysicsRayQueryParameters3D.create(origin, base_position + kick, obstacle_mask, [vehicle.get_rid()])
        if not get_world_3d().direct_space_state.intersect_ray(view_query).is_empty():
            kick = Vector3.ZERO
    global_transform.origin = base_position + kick
    look_at(origin, Vector3.UP)

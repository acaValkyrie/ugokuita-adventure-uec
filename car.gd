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

extends VehicleBody3D

@export var MAX_STEER = 0.5
@export var ENGINE_POWER = 10

func _physics_process(delta: float) -> void:
    steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
    engine_force = Input.get_axis("down", "up") * ENGINE_POWER

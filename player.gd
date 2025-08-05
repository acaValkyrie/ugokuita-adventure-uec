extends CharacterBody3D

@export var MAX_STEER = 0.5
@export var ENGINE_POWER = 10

var steering = 0.0

func _physics_process(delta: float) -> void:
    var steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
    var engine_force = Input.get_axis("down", "up") * ENGINE_POWER
    velocity = engine_force * Vector3(cos(-steering), 0, sin(-steering))
    
    move_and_slide()

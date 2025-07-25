extends Camera3D

var vehicle
@export var vehicle_path: NodePath

var radius: float = 2.0
var theta: float = - 0.5 * PI
var phi: float = 0.3 * PI

func to_camera_position() -> Vector3:
    var x = radius * sin(phi) * cos(theta)
    var y = radius * cos(phi)
    var z = radius * sin(phi) * sin(theta)
    return Vector3(x, y, z)

func _ready():
    vehicle = get_node(vehicle_path)
    if not vehicle:
        push_error("Vehicle not found at path: " + str(vehicle_path))
    else:
        # Set the camera to follow the vehicle
        global_transform.origin = vehicle.global_transform.origin + to_camera_position()
        look_at(vehicle.global_transform.origin, Vector3.UP)


var theta_speed: float = 3
var phi_speed: float = 1

func _physics_process(delta: float) -> void:
    var input_LR = Input.get_axis("view_left", "view_right")
    var input_UD = Input.get_axis("view_up", "view_down")
    theta += input_LR * theta_speed * delta
    phi += -input_UD * phi_speed * delta
    phi = clamp(phi, 0.1, 0.5*PI)  # Prevent camera from flipping over

    # Update camera position based on theta and phi
    global_transform.origin = vehicle.global_transform.origin + to_camera_position()
    look_at(vehicle.global_transform.origin, Vector3.UP)

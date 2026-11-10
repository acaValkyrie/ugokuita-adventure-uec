class_name SimulatedLidar
extends Node
# 機体に載った疑似 LiDAR の命中点を、汎用の点群描画へ渡す。

# Web 版の負荷を見て調整する、物理フレームごとのレイ数。
const RAYS_PER_TICK := 300
const NEO_MIN_ELEVATION := -7.0
const NEO_MAX_ELEVATION := 52.0
const NEO_MAX_DISTANCE := 40.0
const CLASSIC_HALF_ANGLE := 35.2
const CLASSIC_MAX_DISTANCE := 90.0

var enabled := false
var _car: VehicleBody3D
var _renderer: PointCloudRenderer
var _local_offset := Vector3(0.0, 0.3, 0.0)
var _classic := false
var _ray_index := 0
var _query := PhysicsRayQueryParameters3D.new()


func _init() -> void:
	_query.collision_mask = 1 | 4
	_query.collide_with_areas = false
	_query.hit_from_inside = false


func setup(car: VehicleBody3D, renderer: PointCloudRenderer) -> void:
	_car = car
	_renderer = renderer
	_local_offset = Vector3(0.0, 0.3, 0.0)
	_classic = false
	_query.exclude = []
	if not is_instance_valid(_car):
		return
	_query.exclude = [_car.get_rid()]
	var sensors := _car.find_children("*mid-360-asm*", "", true, false)
	if sensors.is_empty():
		sensors = _car.find_children("*Livox Mid-70*", "", true, false)
	if sensors.is_empty():
		return
	var sensor: Node = sensors[0]
	_classic = String(sensor.name).contains("Livox Mid-70")
	# センサー配下のメッシュをワールド空間で合わせ、その中心を機体の座標に保存する。
	var bounds := AABB()
	var found := false
	var stack: Array[Node] = [sensor]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh_instance := node as MeshInstance3D
			var box := mesh_instance.global_transform * mesh_instance.get_aabb()
			bounds = box if not found else bounds.merge(box)
			found = true
		stack.append_array(node.get_children())
	if found:
		_local_offset = _car.to_local(bounds.get_center())


func _physics_process(_delta: float) -> void:
	if not enabled or not is_instance_valid(_car) or not is_instance_valid(_renderer):
		return
	if not _car.is_inside_tree():
		return
	var origin := _car.global_transform * _local_offset
	var basis := _car.global_basis.orthonormalized()
	var max_distance := CLASSIC_MAX_DISTANCE if _classic else NEO_MAX_DISTANCE
	var space := _car.get_world_3d().direct_space_state
	var points := PackedVector3Array()
	_query.from = origin
	for _i in RAYS_PER_TICK:
		_ray_index += 1
		var u := fposmod(_ray_index * 0.6180339887, 1.0)
		var v := fposmod(_ray_index * 0.7548776662, 1.0)
		var direction := _sample_direction(u, v)
		_query.to = origin + basis * direction * max_distance
		var hit := space.intersect_ray(_query)
		if not hit.is_empty():
			points.append(hit["position"])
	_renderer.add_points(points)


# 球面上の面積が一様になるよう、仰角の正弦または円錐角の余弦を補間する。
func _sample_direction(u: float, v: float) -> Vector3:
	var azimuth := u * TAU
	if _classic:
		var cos_angle := lerpf(1.0, cos(deg_to_rad(CLASSIC_HALF_ANGLE)), v)
		var radial := sqrt(maxf(0.0, 1.0 - cos_angle * cos_angle))
		return Vector3(radial * cos(azimuth), radial * sin(azimuth), cos_angle)
	var sin_elevation := lerpf(sin(deg_to_rad(NEO_MIN_ELEVATION)), sin(deg_to_rad(NEO_MAX_ELEVATION)), v)
	var horizontal := sqrt(maxf(0.0, 1.0 - sin_elevation * sin_elevation))
	return Vector3(horizontal * sin(azimuth), sin_elevation, horizontal * cos(azimuth))

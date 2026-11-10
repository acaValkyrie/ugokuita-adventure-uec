class_name SimulatedLidar
extends Node
# 機体に載った疑似 LiDAR の命中点を、汎用の点群描画へ渡す。

# Web 版の負荷を見て調整する、物理フレームごとのレイ数。
const RAYS_PER_TICK := 150
const NEO_MIN_ELEVATION := -7.0
const NEO_MAX_ELEVATION := 52.0
const NEO_MAX_DISTANCE := 40.0
const CLASSIC_HALF_ANGLE := 35.2
const CLASSIC_MAX_DISTANCE := 90.0
const OCCLUSION_U_BINS := 360
const OCCLUSION_V_BINS := 64
const OCCLUSION_RAY_LENGTH := 2.0
const NEO_OCCLUSION_PATH := "res://src/lidar/occlusion_neo.res"
const CLASSIC_OCCLUSION_PATH := "res://src/lidar/occlusion_classic.res"

var enabled := false
var _car: VehicleBody3D
var _renderer: PointCloudRenderer
var _local_offset := Vector3(0.0, 0.3, 0.0)
var _classic := false
var _ray_index := 0
var _query := PhysicsRayQueryParameters3D.new()
var _sensor: Node
var _occluded := PackedByteArray()


func _init() -> void:
	_query.collision_mask = 1 | 4
	_query.collide_with_areas = false
	_query.hit_from_inside = false


func setup(car: VehicleBody3D, renderer: PointCloudRenderer) -> void:
	_sensor = null
	_occluded = PackedByteArray()
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
	_sensor = sensor
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
	var path := CLASSIC_OCCLUSION_PATH if _classic else NEO_OCCLUSION_PATH
	if ResourceLoader.exists(path):
		var table := load(path) as LidarOcclusionTable
		if table != null and table.u_bins == OCCLUSION_U_BINS and table.v_bins == OCCLUSION_V_BINS and table.occluded.size() == OCCLUSION_U_BINS * OCCLUSION_V_BINS:
			_occluded = table.occluded
			return
	push_warning("LiDAR の遮蔽表が無いか大きさが違います: " + path)


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
		if _is_occluded(u, v):
			continue
		var direction := _sample_direction(u, v)
		_query.to = origin + basis * direction * max_distance
		var hit := space.intersect_ray(_query)
		if not hit.is_empty():
			points.append(hit["position"])
	_renderer.add_points(points)


# 機体の描画メッシュでセンサーから遮られる方向を調べる。重いので tools/bake_lidar_occlusion.gd で前もって作り、ゲーム中は setup で読むだけにする。
# 専用空間を使い、通常の走行用コリジョンやレイの除外設定には影響させない。
func build_occlusion() -> PackedByteArray:
	var faces := PackedVector3Array()
	var car_inverse := _car.global_transform.affine_inverse()
	for node in _car.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.top_level or not mesh_instance.is_visible_in_tree():
			continue
		if is_instance_valid(_sensor) and (_sensor == mesh_instance or _sensor.is_ancestor_of(mesh_instance)):
			continue
		var transform := car_inverse * mesh_instance.global_transform
		for vertex in mesh_instance.mesh.get_faces():
			faces.append(transform * vertex)
	if faces.is_empty():
		return PackedByteArray()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = false
	shape.set_faces(faces)
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(body, space)
	PhysicsServer3D.body_add_shape(body, shape.get_rid(), Transform3D.IDENTITY)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D.IDENTITY)
	var direct_state := PhysicsServer3D.space_get_direct_state(space)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = _local_offset
	query.hit_from_inside = false
	var occluded := PackedByteArray()
	occluded.resize(OCCLUSION_U_BINS * OCCLUSION_V_BINS)
	for v_index in OCCLUSION_V_BINS:
		var v := (v_index + 0.5) / OCCLUSION_V_BINS
		for u_index in OCCLUSION_U_BINS:
			var u := (u_index + 0.5) / OCCLUSION_U_BINS
			query.to = _local_offset + _sample_direction(u, v) * OCCLUSION_RAY_LENGTH
			if not direct_state.intersect_ray(query).is_empty():
				occluded[v_index * OCCLUSION_U_BINS + u_index] = 1
	PhysicsServer3D.free_rid(body)
	PhysicsServer3D.free_rid(space)
	return occluded


func _is_occluded(u: float, v: float) -> bool:
	if _occluded.is_empty():
		return false
	var u_index := mini(int(u * OCCLUSION_U_BINS), OCCLUSION_U_BINS - 1)
	var v_index := mini(int(v * OCCLUSION_V_BINS), OCCLUSION_V_BINS - 1)
	return _occluded[v_index * OCCLUSION_U_BINS + u_index] != 0


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

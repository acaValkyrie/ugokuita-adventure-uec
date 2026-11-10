class_name LidarJetRings
extends Node3D
# 点群モードの噴射を、速度と逆向きに流れる輪で示す。

const EMIT_INTERVAL := 0.1
const RING_SPEED := 4.0
const RING_LIFETIME := 0.6
const RING_TUBE := 0.012
const MIN_SPEED := 0.5

class Ring:
	var instance: MeshInstance3D
	var direction: Vector3
	var age := 0.0


var _car: VehicleBody3D
var _mesh := TorusMesh.new()
var _material := create_material()
var _rings: Array[Ring] = []
var _nozzle_y := -0.05
var _emit_elapsed := 0.0
var _was_thrusting := false


# 先読みでも噴射と同じマテリアルを使う。
static func create_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = LidarView.OUTLINE_COLOR
	material.disable_fog = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func set_car(car: VehicleBody3D) -> void:
	clear()
	_car = car
	_nozzle_y = -0.05
	if not is_instance_valid(_car):
		return
	# 子の変形も含め、機体ローカルで外形を測る。
	var bounds := AABB()
	var has_bounds := false
	var to_car := _car.global_transform.affine_inverse()
	for node in _car.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.top_level or mesh.mesh == null:
			continue
		var local_bounds: AABB = (to_car * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
		has_bounds = true
	var diameter := maxf(bounds.size.x, bounds.size.z) if has_bounds else 0.5
	var radius := maxf(diameter * 0.5, RING_TUBE)
	_mesh.inner_radius = maxf(radius - RING_TUBE, 0.0)
	_mesh.outer_radius = radius + RING_TUBE
	_mesh.rings = 48
	_mesh.ring_segments = 6
	_mesh.material = _material
	# ノズルは機体直下の箱の下端に合わせる。
	for child in _car.get_children():
		var collision := child as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D:
			_nozzle_y = collision.position.y - (collision.shape as BoxShape3D).size.y * 0.5
			break


func clear() -> void:
	for ring in _rings:
		ring.instance.hide()
		ring.instance.queue_free()
	_rings.clear()
	_emit_elapsed = 0.0
	_was_thrusting = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_car):
		return
	if not is_visible_in_tree():
		clear()
		return
	for index in range(_rings.size() - 1, -1, -1):
		var ring := _rings[index]
		ring.age += delta
		if ring.age >= RING_LIFETIME:
			ring.instance.hide()
			ring.instance.queue_free()
			_rings.remove_at(index)
			continue
		ring.instance.global_position += ring.direction * RING_SPEED * delta
		ring.instance.transparency = ring.age / RING_LIFETIME
	var thrusting := bool(_car.get("jet_thrusting"))
	if not thrusting:
		_emit_elapsed = 0.0
		_was_thrusting = false
		return
	if not _was_thrusting:
		_emit_ring()
		_was_thrusting = true
		return
	_emit_elapsed += delta
	while _emit_elapsed >= EMIT_INTERVAL:
		_emit_elapsed -= EMIT_INTERVAL
		_emit_ring()


func _emit_ring() -> void:
	var velocity := _car.linear_velocity
	var direction := -velocity.normalized() if velocity.length() >= MIN_SPEED else Vector3.DOWN
	var ring := Ring.new()
	ring.direction = direction
	ring.instance = MeshInstance3D.new()
	ring.instance.mesh = _mesh
	ring.instance.layers = PointCloudRenderer.RENDER_LAYER
	ring.instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.instance.top_level = true
	add_child(ring.instance)
	# 輪の法線を進行方向へ向け、発生後は機体に追従させない。
	var reference := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var axis_x := direction.cross(reference).normalized()
	var axis_z := axis_x.cross(direction).normalized()
	ring.instance.global_transform = Transform3D(
		Basis(axis_x, direction, axis_z),
		_car.to_global(Vector3(0.0, _nozzle_y, 0.0))
	)
	_rings.append(ring)

class_name LidarSpaceScan
extends Node3D
# ED2 の上空で、地球と太陽を近い点から走査する。

# ED2 高度で地平線が沈む角度 [rad]。
const HORIZON_DIP := 0.1
# 地球の仰角・方位の走査間隔 [度]。
const RING_STEP_DEG := 0.6
# 地球の走査を打ち切る距離 [m]。
const MAX_DISTANCE := 3800.0
# 太陽の中心までの距離 [m]。
const SUN_DISTANCE := 3000.0
# 太陽の大きさを決める見かけの半径 [度]。
const SUN_ANGULAR_RADIUS_DEG := 4.0
# 太陽へ飛ばすレイの本数。
const SUN_RAYS := 6000
# 近距離から遠距離まで走査する時間 [秒]。
const SCAN_DURATION := 3.0

var _renderer := PointCloudRenderer.new()
var _started := false
var _origin := Vector3.ZERO
# 各リングの交点距離と仰角を保存する。
var _earth_rings: Array[Vector2] = []
var _earth_index := 0
var _sun_points := PackedVector3Array()
var _sun_front := 0.0
var _sun_added := false
var _elapsed := 0.0
var _r_min := 0.0
var _r_max := 0.0


func _init() -> void:
	add_child(_renderer)


func update_scan(car: VehicleBody3D, delta: float) -> void:
	if not is_instance_valid(car):
		return
	if car.global_position.y <= Ending.ENDING2_HEIGHT:
		clear()
		return
	if not _started:
		_start(car)
	_elapsed += delta
	var radius := _r_min * pow(_r_max / _r_min, clampf(_elapsed / SCAN_DURATION, 0.0, 1.0))
	# 終点の丸め誤差で最後のリングが残るのを防ぐ。
	if _elapsed >= SCAN_DURATION:
		radius = _r_max
	while _earth_index < _earth_rings.size() and _earth_rings[_earth_index].x <= radius:
		_add_earth_ring(_earth_index)
		_earth_index += 1
	if not _sun_added and radius >= _sun_front:
		_add_sun()
		_sun_added = true


func clear() -> void:
	if not _started:
		return
	_renderer.clear()
	_started = false
	_origin = Vector3.ZERO
	_earth_rings.clear()
	_earth_index = 0
	_sun_points.clear()
	_sun_front = 0.0
	_sun_added = false
	_elapsed = 0.0
	_r_min = 0.0
	_r_max = 0.0


func _start(car: VehicleBody3D) -> void:
	_started = true
	_origin = car.global_position
	var h := Ending.ENDING2_HEIGHT
	var earth_radius := h * cos(HORIZON_DIP) / (1.0 - cos(HORIZON_DIP))
	# 球の中心は (機体.x, -半径, 機体.z)。高さは倍精度で計算する。
	var height_from_center := _origin.y + earth_radius
	var elevation_deg := -90.0
	while elevation_deg <= 0.0:
		var elevation := deg_to_rad(elevation_deg)
		# 中心が真下なので、球の手前交点を仰角だけから求める。
		var b := height_from_center * sin(elevation)
		var discriminant := b * b - (_origin.y * (_origin.y + 2.0 * earth_radius))
		if discriminant < 0.0:
			break
		var distance := -b - sqrt(discriminant)
		if distance > MAX_DISTANCE:
			break
		_earth_rings.append(Vector2(distance, elevation))
		elevation_deg += RING_STEP_DEG
	_make_sun_points()
	# 地球全体が走査距離の外でも、太陽だけは走査できる。
	_r_min = _earth_rings[0].x if not _earth_rings.is_empty() else MAX_DISTANCE
	_r_max = maxf(_earth_rings[-1].x if not _earth_rings.is_empty() else _r_min, _sun_front)


func _add_earth_ring(index: int) -> void:
	var ring := _earth_rings[index]
	var count := maxi(1, roundi(360.0 * cos(ring.y) / RING_STEP_DEG))
	var points := PackedVector3Array()
	points.resize(count)
	# 黄金比の位相で隣のリングの方位をずらす。
	var phase := fposmod(float(index) * TAU / ((1.0 + sqrt(5.0)) * 0.5), TAU)
	for i in count:
		var azimuth := TAU * float(i) / float(count) + phase
		var direction := Vector3(cos(ring.y) * sin(azimuth), sin(ring.y), cos(ring.y) * cos(azimuth))
		points[i] = _origin + direction * ring.x
	_renderer.add_points(points)


func _make_sun_points() -> void:
	var scene := get_tree().current_scene
	var sun: DirectionalLight3D = scene.get_node_or_null("DirectionalLight3D") as DirectionalLight3D if scene != null else null
	if sun == null:
		_sun_added = true
		return
	var direction := sun.global_basis.z.normalized()
	var center := _origin + direction * SUN_DISTANCE
	var radius := SUN_DISTANCE * tan(deg_to_rad(SUN_ANGULAR_RADIUS_DEG))
	_sun_front = SUN_DISTANCE - radius
	var reference := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var axis_x := direction.cross(reference).normalized()
	var axis_y := axis_x.cross(direction).normalized()
	# 見かけの縁を少し越える円錐を、黄金比の方位で均等に探す。
	var cone_cos := cos(asin(radius / SUN_DISTANCE) * 1.02)
	var golden_angle := TAU / ((1.0 + sqrt(5.0)) * 0.5)
	var offset := _origin - center
	for i in SUN_RAYS:
		var ray_cos := lerpf(1.0, cone_cos, (float(i) + 0.5) / float(SUN_RAYS))
		var ray_sin := sqrt(maxf(0.0, 1.0 - ray_cos * ray_cos))
		var azimuth := float(i) * golden_angle
		var ray := direction * ray_cos + (axis_x * cos(azimuth) + axis_y * sin(azimuth)) * ray_sin
		var b := offset.dot(ray)
		var discriminant := b * b - (offset.length_squared() - radius * radius)
		if discriminant < 0.0:
			continue
		var distance := -b - sqrt(discriminant)
		if distance > 0.0:
			_sun_points.append(_origin + ray * distance)


func _add_sun() -> void:
	_renderer.add_points(_sun_points)

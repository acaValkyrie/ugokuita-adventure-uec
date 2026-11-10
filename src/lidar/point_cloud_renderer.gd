class_name PointCloudRenderer
extends Node3D
# ワールド座標の点と色だけを受け取り、ボクセルで間引いて描く。

# ボクセルで間引いた後に新しく足した点。
signal points_accepted(points: PackedVector3Array, colors: PackedColorArray)

const RENDER_LAYER := 1 << 18
const POINT_SIZE := 3.0
const VOXEL_SIZE := 0.1
const CHUNK_POINTS := 8192
const MAX_POINTS := 400000
const REBUILD_INTERVAL := 0.1

class PointChunk:
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var keys: Array[Vector3i] = []
	var mesh := ArrayMesh.new()
	var instance: MeshInstance3D


var _material := StandardMaterial3D.new()
var _chunks: Array[PointChunk] = []
var _current: PointChunk
var _voxels := {}
var _point_count := 0
var _dirty := false
var _rebuild_elapsed := 0.0


func _init() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.use_point_size = true
	_material.point_size = POINT_SIZE
	_material.vertex_color_use_as_albedo = true
	_material.disable_fog = true


func add_points(points: PackedVector3Array, colors: PackedColorArray = PackedColorArray()) -> void:
	if not colors.is_empty() and colors.size() != points.size():
		push_error("点と色の数が一致していません")
		return
	var accepted_points := PackedVector3Array()
	var accepted_colors := PackedColorArray()
	for i in points.size():
		var point := points[i]
		var key := Vector3i((point / VOXEL_SIZE).floor())
		if _voxels.has(key):
			continue
		if _current == null:
			_start_chunk()
		_voxels[key] = true
		var color := height_color(point.y) if colors.is_empty() else colors[i]
		_current.points.append(point)
		_current.colors.append(color)
		accepted_points.append(point)
		accepted_colors.append(color)
		_current.keys.append(key)
		_point_count += 1
		_dirty = true
		if _current.points.size() == CHUNK_POINTS:
			_rebuild_current()
			_current = null
		# 上限を超えたら、古いチャンクごとに点とボクセルの記録を捨てる。
		while _point_count > MAX_POINTS:
			_remove_oldest_chunk()
	if not accepted_points.is_empty():
		points_accepted.emit(accepted_points, accepted_colors)


func clear() -> void:
	for chunk in _chunks:
		chunk.instance.visible = false
		chunk.instance.queue_free()
	_chunks.clear()
	_current = null
	_voxels.clear()
	_point_count = 0
	_dirty = false
	_rebuild_elapsed = 0.0


func get_point_count() -> int:
	return _point_count


# 高さ -1〜15m を、青・シアン・緑・黄・赤の順に色付けする。
static func height_color(y: float) -> Color:
	var t := clampf((y + 1.0) / 16.0, 0.0, 1.0) * 4.0
	if t < 1.0:
		return Color.BLUE.lerp(Color.CYAN, t)
	if t < 2.0:
		return Color.CYAN.lerp(Color.GREEN, t - 1.0)
	if t < 3.0:
		return Color.GREEN.lerp(Color.YELLOW, t - 2.0)
	return Color.YELLOW.lerp(Color.RED, t - 3.0)


func _process(delta: float) -> void:
	_rebuild_elapsed += delta
	if _dirty and _rebuild_elapsed >= REBUILD_INTERVAL:
		_rebuild_current()


func _start_chunk() -> void:
	_current = PointChunk.new()
	_current.instance = MeshInstance3D.new()
	_current.instance.mesh = _current.mesh
	_current.instance.material_override = _material
	_current.instance.layers = RENDER_LAYER
	_current.instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_current.instance.top_level = true
	add_child(_current.instance)
	# 親が移動・回転していても、点はワールド座標のまま表示する。
	_current.instance.global_transform = Transform3D.IDENTITY
	_chunks.append(_current)


func _rebuild_current() -> void:
	if _current == null or not _dirty:
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _current.points
	arrays[Mesh.ARRAY_COLOR] = _current.colors
	_current.mesh.clear_surfaces()
	_current.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	_dirty = false
	_rebuild_elapsed = 0.0


func _remove_oldest_chunk() -> void:
	var chunk: PointChunk = _chunks.pop_front()
	for key in chunk.keys:
		_voxels.erase(key)
	_point_count -= chunk.points.size()
	chunk.instance.visible = false
	chunk.instance.queue_free()

extends RefCounted

# 屋外階段の実三角形と機体の描画外形を包む回転付きボックスの距離。
# 階段を2mセルに登録し、フェード範囲に入る面だけを調べる。
const CELL_SIZE := 2.0
const BOX_EDGES := [[0, 1], [0, 2], [0, 4], [1, 3], [1, 5], [2, 3], [2, 6], [3, 7], [4, 5], [4, 6], [5, 7], [6, 7]]
var _faces := PackedVector3Array()
var _cells := {}
var _face_bounds: Array[AABB] = []
var _player: Node3D
var _bounds := AABB()


func setup(stairs: MeshInstance3D) -> void:
	_faces = stairs.mesh.get_faces()
	for i in _faces.size():
		_faces[i] = stairs.global_transform * _faces[i]
	for i in range(0, _faces.size(), 3):
		var box := AABB(_faces[i], Vector3.ZERO)
		box = box.expand(_faces[i + 1]).expand(_faces[i + 2])
		_face_bounds.append(box)
		for cell in _box_cells(box):
			if not _cells.has(cell):
				_cells[cell] = []
			_cells[cell].append(i)


func distance_to(player: Node3D, limit: float) -> float:
	if player != _player:
		_player = player
		_bounds = AABB()
		_collect_bounds(player, player.global_transform.affine_inverse())
	var frame := Transform3D(player.global_basis.orthonormalized(), player.global_position)
	var box: AABB = (frame.affine_inverse() * player.global_transform) * _bounds
	var world_box: AABB = frame * box
	var candidates := {}
	for cell in _box_cells(world_box.grow(limit)):
		for index in _cells.get(cell, []):
			candidates[index] = true
	var corners := PackedVector3Array()
	for i in 8:
		corners.append(box.get_endpoint(i))
	var inverse := frame.affine_inverse()
	var best := limit * limit
	for i in candidates:
		if _box_distance_squared(world_box, _face_bounds[i / 3]) >= best:
			continue
		var a: Vector3 = inverse * _faces[i]
		var b: Vector3 = inverse * _faces[i + 1]
		var c: Vector3 = inverse * _faces[i + 2]
		# 各面のAABBによる安価な枝刈り。
		var triangle_box := AABB(a, Vector3.ZERO).expand(b).expand(c)
		if _box_distance_squared(triangle_box, box) >= best:
			continue
		best = minf(best, _triangle_box_distance_squared(a, b, c, box, corners))
		if best <= 1.0:
			# 1m以下はすべて完全表示なので、それ以上の精度は不要。
			return sqrt(best)
	return sqrt(best)


func _box_distance_squared(a: AABB, b: AABB) -> float:
	var gap := (a.position - b.end).max(b.position - a.end).max(Vector3.ZERO)
	return gap.length_squared()


func _collect_bounds(node: Node, inverse: Transform3D) -> void:
	# ドリフトの軌跡など、機体の移動に追従しない描画は機体外形ではない。
	# 空のワールド座標メッシュまで含めると、機体から原点までの巨大な外形になる。
	if node != _player and node is Node3D and node.top_level:
		return
	if node is MeshInstance3D and node.mesh != null and node.mesh.get_surface_count() > 0 and node.is_visible_in_tree():
		var box: AABB = (inverse * node.global_transform) * node.mesh.get_aabb()
		_bounds = box if _bounds.size == Vector3.ZERO else _bounds.merge(box)
	for child in node.get_children():
		_collect_bounds(child, inverse)


func _box_cells(box: AABB) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var first := Vector3i((box.position / CELL_SIZE).floor())
	var last := Vector3i((box.end / CELL_SIZE).floor())
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			for z in range(first.z, last.z + 1):
				result.append(Vector3i(x, y, z))
	return result


func _triangle_box_distance_squared(a: Vector3, b: Vector3, c: Vector3, box: AABB, corners: PackedVector3Array) -> float:
	var best := INF
	for pair in [[a, b], [b, c], [c, a]]:
		if box.intersects_segment(pair[0], pair[1]) != null:
			return 0.0
	for vertex in [a, b, c]:
		best = minf(best, vertex.distance_squared_to(vertex.clamp(box.position, box.end)))
	for corner in corners:
		best = minf(best, _point_triangle_distance_squared(corner, a, b, c))
	for edge in BOX_EDGES:
		var p := corners[edge[0]]
		var q := corners[edge[1]]
		if Geometry3D.segment_intersects_triangle(p, q, a, b, c) != null:
			return 0.0
		for pair in [[a, b], [b, c], [c, a]]:
			var nearest := Geometry3D.get_closest_points_between_segments(p, q, pair[0], pair[1])
			best = minf(best, nearest[0].distance_squared_to(nearest[1]))
	return best


func _point_triangle_distance_squared(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var normal := (b - a).cross(c - a)
	var length_squared := normal.length_squared()
	if length_squared > 0.000000000001:
		var q := p - normal * ((p - a).dot(normal) / length_squared)
		if (b - a).cross(q - a).dot(normal) >= 0.0 and (c - b).cross(q - b).dot(normal) >= 0.0 and (a - c).cross(q - c).dot(normal) >= 0.0:
			return p.distance_squared_to(q)
	var best := INF
	for pair in [[a, b], [b, c], [c, a]]:
		best = minf(best, p.distance_squared_to(Geometry3D.get_closest_point_to_segment(p, pair[0], pair[1])))
	return best

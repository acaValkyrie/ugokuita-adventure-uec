extends SceneTree

# 新旧の当たり判定を同じレイで比較する。
# 実行: Godot --headless --path . --script res://tools/compare_gomi_collision.gd -- <old_res_path> <new_res_path>
var bounds := AABB()
var physics_frames := 0
var ready_to_compare := false
var ray_count := 0
var both_hit_count := 0
var mismatch_count := 0
var differences := PackedFloat64Array()
var mismatches: Array[String] = []

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("引数は <old_res_path> <new_res_path> を指定してください")
		quit(1)
		return
	var old_shape := load(args[0]) as ConcavePolygonShape3D
	var new_shape := load(args[1]) as ConcavePolygonShape3D
	if old_shape == null or new_shape == null:
		push_error("新旧のConcavePolygonShape3Dを読み込めません")
		quit(1)
		return
	var old_faces := old_shape.get_faces()
	var new_faces := new_shape.get_faces()
	if old_faces.is_empty() or old_faces.size() % 3 != 0 or new_faces.is_empty() or new_faces.size() % 3 != 0:
		push_error("新旧の三角形がありません")
		quit(1)
		return
	bounds = AABB(old_faces[0], Vector3.ZERO)
	for vertex in old_faces:
		bounds = bounds.expand(vertex)
	var old_body := StaticBody3D.new()
	old_body.collision_layer = 1
	old_body.collision_mask = 0
	var old_collision := CollisionShape3D.new()
	old_collision.shape = old_shape
	old_body.add_child(old_collision)
	root.add_child(old_body)
	var new_body := StaticBody3D.new()
	new_body.collision_layer = 2
	new_body.collision_mask = 0
	var new_collision := CollisionShape3D.new()
	new_collision.shape = new_shape
	new_body.add_child(new_collision)
	root.add_child(new_body)
	ready_to_compare = true


func _physics_process(_delta: float) -> bool:
	if not ready_to_compare:
		return true
	physics_frames += 1
	if physics_frames < 3:
		return false
	_compare()
	quit()
	return true


func _compare() -> void:
	var space := root.get_world_3d().direct_space_state
	var minimum := bounds.position
	var maximum := bounds.end
	# 当たり判定の形は Z が上（gomi_station.tscn の Collision ノードが回して Y を上にする）。
	# 床や段の面と同じ高さを光線がなぞると、ヒットするかが数値の誤差で変わるので、格子と高さを少しずらす。
	const JITTER := 0.0137
	# 上から床や屋根を調べる。
	for x in _grid(minimum.x + JITTER, maximum.x, 0.2):
		for y in _grid(minimum.y + JITTER, maximum.y, 0.2):
			_cast(space, Vector3(x, y, maximum.z + 30.0), Vector3(x, y, minimum.z - 5.0))
	# 横から壁や通路を両方向に調べる。
	for height in [0.3 + JITTER, 1.0 + JITTER, 2.0 + JITTER, 5.0 + JITTER]:
		for y in _grid(minimum.y + JITTER, maximum.y, 0.25):
			var from := Vector3(minimum.x - 5.0, y, height)
			var to := Vector3(maximum.x + 5.0, y, height)
			_cast(space, from, to)
			_cast(space, to, from)
		for x in _grid(minimum.x + JITTER, maximum.x, 0.25):
			var from := Vector3(x, minimum.y - 5.0, height)
			var to := Vector3(x, maximum.y + 5.0, height)
			_cast(space, from, to)
			_cast(space, to, from)

	print("レイ: %d / 両方ヒット: %d / 不一致: %d" % [ray_count, both_hit_count, mismatch_count])
	if differences.is_empty():
		print("距離差(mm): 最大 / 99パーセンタイル / 平均 = 該当なし（両方ヒットなし）")
	else:
		differences.sort()
		var total := 0.0
		for difference in differences:
			total += difference
		var percentile_index := ceili(differences.size() * 0.99) - 1
		print("距離差(mm): 最大 %.6f / 99パーセンタイル %.6f / 平均 %.6f" % [differences[-1] * 1000.0, differences[percentile_index] * 1000.0, total / differences.size() * 1000.0])
	for mismatch in mismatches:
		print(mismatch)


func _grid(minimum: float, maximum: float, step: float) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	for index in range(floori((maximum - minimum) / step) + 1):
		values.append(minimum + index * step)
	# 間隔の余りがあっても最大端を含める。
	if values[-1] < maximum:
		values.append(maximum)
	return values


func _cast(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.hit_back_faces = false
	query.collision_mask = 1
	var old_hit := space.intersect_ray(query)
	query.collision_mask = 2
	var new_hit := space.intersect_ray(query)
	ray_count += 1
	if not old_hit.is_empty() and not new_hit.is_empty():
		var old_position: Vector3 = old_hit["position"]
		var new_position: Vector3 = new_hit["position"]
		differences.append(old_position.distance_to(new_position))
		both_hit_count += 1
	elif old_hit.is_empty() != new_hit.is_empty():
		mismatch_count += 1
		if mismatches.size() < 10:
			mismatches.append("不一致 %d: 始点 %s / 終点 %s / 旧ヒット %s / 新ヒット %s" % [mismatch_count, from, to, not old_hit.is_empty(), not new_hit.is_empty()])

extends SceneTree

# 実行: Godot --headless --path . --script res://tools/verify_gomi_split_meshes.gd
# 自動ロードのUIはheadless未対応のため、表示サーバーの警告とは別に判定する。
var station: StaticBody3D
var player: Node3D
var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	station = load("res://gomi_station.tscn").instantiate()
	root.add_child(station)
	station.set_process(false)
	var inside := station.get_node("InsideStairs") as MeshInstance3D
	var outside := station.get_node("OutsideStairs") as MeshInstance3D
	_require(outside.get_active_material(0) != outside.mesh.surface_get_material(0), "屋外階段の材質は専用の複製")
	_require(is_equal_approx(outside.mesh.surface_get_material(0).albedo_color.a, 1.0), "元材質のアルファは未変更")
	_require(inside.visible and not outside.visible)
	_require(inside.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_require(outside.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_require(station.get_node("Collision").shape == load("res://assets/models/GOMI_collision.res"))
	_verify_mesh(inside.mesh, true)
	_verify_mesh(outside.mesh, false)
	player = Node3D.new()
	player.add_to_group("player")
	root.add_child(player)
	var player_body := MeshInstance3D.new()
	player_body.mesh = BoxMesh.new()
	player_body.mesh.size = Vector3.ONE
	player.add_child(player_body)
	_check(Vector3(-4.0, 7.85, 0.0), "屋外道路")
	_check(Vector3(-4.0, 7.85, 6.0), "屋外階段付近")
	_check(Vector3(10.0, 4.0, 0.1), "屋内の階段外")
	_check(Vector3(3.5, 7.85, 0.3), "屋内階段")
	_verify_indoor_distance_fade()
	player.remove_from_group("player")
	station._process(0.0)
	_require(not outside.visible and inside.visible)
	_verify_distance_and_fade()
	_verify_vehicle_effect_bounds()
	print("Gomi stairs verification: メッシュ属性・外壁境界・影OFF・衝突保持・距離フェード: %d failures" % failures)
	station.free()
	player.free()
	quit(1 if failures else 0)


func _check(point: Vector3, label: String) -> void:
	player.global_position = station.to_global(point)
	station._process(0.0)
	var distance: float = station._proximity.distance_to(player, 2.0)
	var expected_alpha := clampf(2.0 - distance, 0.0, 1.0)
	_require(is_equal_approx(station._outside_alpha, expected_alpha), label + " 距離に応じた表示")
	_require(station.get_node("InsideStairs").visible, "屋内階段は常設")


func _require(condition: bool, label: String = "メッシュ構造") -> void:
	if not condition:
		failures += 1
		push_error(label)


func _verify_distance_and_fade() -> void:
	var stairs := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, -10, -10), Vector3(0, 10, -10), Vector3(0, 0, 10)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	stairs.mesh = mesh
	root.add_child(stairs)
	var vehicle := Node3D.new()
	root.add_child(vehicle)
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3.ONE
	vehicle.add_child(body)
	var proximity := preload("res://stair_proximity.gd").new()
	proximity.setup(stairs)
	for distance in [2.1, 2.0, 1.999, 1.75, 1.5, 1.25, 1.001, 1.0, 0.9]:
		vehicle.position = Vector3(distance + 0.5, 0, 0)
		var actual := proximity.distance_to(vehicle, 2.0)
		_require(absf(actual - minf(distance, 2.0)) < 0.00001, "機体外形から面の最短距離 %f -> %f" % [distance, actual])
		station._set_outside_alpha(clampf(2.0 - actual, 0.0, 1.0))
		var material := station.get_node("OutsideStairs").get_active_material(0) as BaseMaterial3D
		_require(absf(material.albedo_color.a - clampf(2.0 - distance, 0.0, 1.0)) < 0.00001, "線形アルファ %f" % distance)
		_require(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Compatibility用のアルファブレンド")
		_require(station.get_node("OutsideStairs").visible == (distance < 2.0), "2m境界の表示 %f" % distance)
	vehicle.rotation.z = PI / 4.0
	vehicle.position.x = 1.5 + sqrt(0.5)
	_require(absf(proximity.distance_to(vehicle, 2.0) - 1.5) < 0.00001, "回転した外形")
	vehicle.position = Vector3.ZERO
	_require(is_zero_approx(proximity.distance_to(vehicle, 2.0)), "三角形と外形が交差")
	var started := Time.get_ticks_usec()
	for i in 60:
		player.position = Vector3(-4.0, 6.0, 6.0)
		station._proximity.distance_to(player, 2.0)
	print("実階段の近傍距離計算: %.3f ms/query" % ((Time.get_ticks_usec() - started) / 60000.0))
	stairs.free()
	vehicle.free()


func _verify_indoor_distance_fade() -> void:
	var found := {"far": false, "middle": false, "near": false}
	for x in range(0, 41):
		var point := Vector3(x * 0.1, 7.85, 0.01 + ((x * 0.1 - 3.82) / (-25.8688557 - 3.82)) * (20.421085 - 0.01))
		player.global_position = station.to_global(point)
		station._process(0.0)
		var distance: float = station._proximity.distance_to(player, 2.0)
		if distance >= 2.0:
			found["far"] = true
		elif distance > 1.0:
			found["middle"] = true
		else:
			found["near"] = true
		_require(is_equal_approx(station._outside_alpha, clampf(2.0 - distance, 0.0, 1.0)), "屋内階段位置x=%.1fの距離フェード" % point.x)
	_require(found["far"], "屋内階段上で屋外階段まで2m超のケース")
	_require(found["middle"], "屋内階段上で屋外階段まで1〜2mのケース")
	_require(found["near"], "屋内階段上で屋外階段まで1m以内のケース")


func _verify_vehicle_effect_bounds() -> void:
	var test_station = load("res://gomi_station.tscn").instantiate()
	# main_scene.tscnと同じ配置と通常開始位置で、実際の機体の外形を調べる。
	test_station.transform = Transform3D(Vector3(0.96813136, 0.25044295, 0), Vector3(0, 0, 1), Vector3(0.25044295, -0.96813136, 0), Vector3(103.399, 0, 4.568))
	root.add_child(test_station)
	test_station.set_process(false)
	for scene in ["res://car.tscn", "res://car_classic.tscn"]:
		var vehicle = load(scene).instantiate()
		vehicle.position = Vector3(72.1656, 0.259146, -112.579)
		vehicle.freeze = true
		root.add_child(vehicle)
		vehicle.set_process(false)
		vehicle.set_physics_process(false)
		var proximity = preload("res://stair_proximity.gd").new()
		proximity.setup(test_station.get_node("OutsideStairs"))
		test_station._proximity = proximity
		proximity.distance_to(vehicle, 2.0)
		var bounds: AABB = proximity._bounds
		_require(bounds.size.x < 1.0 and bounds.size.y < 1.0 and bounds.size.z < 1.0, scene + " 空のドリフト軌跡は機体外形に含めない")
		# 旧実装では静止時に非表示でも、さらに離れた位置で制動相当の小さな
		# ピッチを付けると、原点まで伸びた偽の外形によって屋外階段が再出現した。
		for pose in [Vector4(104.0, 0.3, -10.0, 0.0), Vector4(104.0, 0.3, -10.1, 0.04)]:
			vehicle.position = Vector3(pose.x, pose.y, pose.z)
			vehicle.rotation.x = pose.w
			var distance: float = proximity.distance_to(vehicle, 2.0)
			_require(is_equal_approx(distance, 2.0), scene + " 遠方の静止・離れる途中の傾きで階段を表示しない")
			test_station._process(0.0)
			_require(is_zero_approx(test_station._outside_alpha) and not test_station.get_node("OutsideStairs").visible, scene + " 屋外階段は非表示を維持")
		# 軌跡に面があっても除外する。top_levelの親の子孫も車体には含めない。
		var world_effect := Node3D.new()
		vehicle.add_child(world_effect)
		world_effect.top_level = true
		world_effect.global_position = Vector3.ZERO
		var effect_mesh := MeshInstance3D.new()
		effect_mesh.mesh = BoxMesh.new()
		world_effect.add_child(effect_mesh)
		var empty_mesh := MeshInstance3D.new()
		empty_mesh.position = Vector3(100, 100, 100)
		empty_mesh.mesh = ImmediateMesh.new()
		vehicle.add_child(empty_mesh)
		# プレイヤー自身がtop_levelであっても、その本体は収集対象。
		vehicle.top_level = true
		var with_effects = preload("res://stair_proximity.gd").new()
		with_effects.setup(test_station.get_node("OutsideStairs"))
		with_effects.distance_to(vehicle, 2.0)
		_require(bounds.position.is_equal_approx(with_effects._bounds.position) and bounds.size.is_equal_approx(with_effects._bounds.size), scene + " ワールド座標の有面エフェクトと空メッシュを除外")
		print("機体外形検証 %s: %s、離れながらの傾きでもalpha=0" % [scene, bounds])
		vehicle.free()
	test_station.free()


func _verify_mesh(mesh: ArrayMesh, inside: bool) -> void:
	var original := (load("res://assets/models/GOMI.obj") as ArrayMesh).surface_get_arrays(108)
	var arrays := mesh.surface_get_arrays(0)
	_require(arrays[Mesh.ARRAY_TEX_UV2].size() == arrays[Mesh.ARRAY_VERTEX].size())
	for i in range(original[Mesh.ARRAY_VERTEX].size()):
		_require(arrays[Mesh.ARRAY_TEX_UV2][i] == original[Mesh.ARRAY_TEX_UV2][i])
	for i in arrays[Mesh.ARRAY_INDEX]:
		var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
		_require(point.x >= -0.00001 if inside else point.x <= 0.00001)
		_require(point.is_finite())
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
		_require(normal.is_finite() and normal.length_squared() > 0.99)
		var tangent := Vector3(arrays[Mesh.ARRAY_TANGENT][i * 4], arrays[Mesh.ARRAY_TANGENT][i * 4 + 1], arrays[Mesh.ARRAY_TANGENT][i * 4 + 2])
		_require(tangent.is_finite() and tangent.length_squared() > 0.99)

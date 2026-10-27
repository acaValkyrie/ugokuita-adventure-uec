extends SceneTree

# 実行: Godot --path . --script res://tools/verify_gomi_contents.gd
# 棚の分類・体育館と同じ縮尺・4箱の物理面と実際の入退出通知を確認する。
var _events: Array = []


func _initialize() -> void:
	create_timer(20.0).timeout.connect(func():
		push_error("新倉庫の検証が完了しませんでした")
		quit(1)
	)
	call_deferred("_verify")


func _verify() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	viewport.add_child(Camera3D.new())
	var station: StaticBody3D = load("res://gomi_station.tscn").instantiate()
	station.rotation.x = -PI / 2
	viewport.add_child(station)
	station.set_process(false)
	station.surplus_bin_entered.connect(func(bin_id: StringName, body: Node3D): _events.append(["enter", bin_id, body]))
	station.surplus_bin_exited.connect(func(bin_id: StringName, body: Node3D): _events.append(["exit", bin_id, body]))
	var contents := station.get_node("SurplusContents")
	if not _verify_categories(contents) or not _verify_nadegg_size(contents):
		quit(1)
		return
	await _physics_frames(4)
	var bins := contents.get_node("BinContents")
	for bin in bins.get_children():
		assert(is_equal_approx(bin.position.y, 0.37))
		var ray := PhysicsRayQueryParameters3D.create(bin.to_global(Vector3(0, 0.2, 0)), bin.to_global(Vector3(0, -0.2, 0)), 1)
		var hit := viewport.world_3d.direct_space_state.intersect_ray(ray)
		assert(hit.get("collider") == bin.get_node("ContentsCollision"), "箱の画像面に物理面がありません")
		assert((hit.position as Vector3).distance_to(bin.global_position) < 0.001)
	# 棚やNadeggなどのStaticBodyが入ってもプレイヤー通知に含めない。
	var ignored: StaticBody3D = load("res://gomi_nadegg.tscn").instantiate()
	viewport.add_child(ignored)
	ignored.global_position = bins.get_child(0).to_global(Vector3(0, 0.02, 0))
	await _physics_frames(4)
	assert(_events.is_empty())
	assert(station.get_surplus_bin_ids_for_body(ignored).is_empty())
	assert(station.get_bodies_in_surplus_bin(bins.get_child(0).name).is_empty())
	ignored.queue_free()
	# 現行車と旧CharacterBodyの実シーンから衝突形状を使い、全箱へ出入りさせる。
	for scene_path in ["res://car.tscn", "res://player.tscn"]:
		var probe: PhysicsBody3D = load(scene_path).instantiate()
		_strip_scripts(probe)
		if probe is RigidBody3D:
			# Joltは静的にfreezeしたbodyをArea検知から外すため、移動可能なfreezeを使う。
			probe.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			probe.freeze = true
		assert(probe.collision_layer == 1)
		viewport.add_child(probe)
		probe.global_position = Vector3(30, 4, 0)
		await _physics_frames(4)
		for bin in bins.get_children():
			_events.clear()
			probe.global_position = bin.to_global(Vector3(0, 0.18, 0))
			await _physics_frames(4)
			assert(_events.size() == 1 and _events[0] == ["enter", StringName(bin.name), probe], "箱ごとの入場通知が不正")
			assert(station.get_surplus_bin_ids_for_body(probe) == [StringName(bin.name)])
			assert(station.get_bodies_in_surplus_bin(bin.name) == [probe])
			probe.global_position = Vector3(30, 4, 0)
			await _physics_frames(4)
			assert(_events.size() == 2 and _events[1] == ["exit", StringName(bin.name), probe], "箱ごとの退場通知が不正")
			assert(station.get_surplus_bin_ids_for_body(probe).is_empty())
		probe.queue_free()
		await _physics_frames(2)
	# 画像面が重力で落ちる物体を支えることも確認する。
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.07
	shape.shape = sphere
	ball.add_child(shape)
	viewport.add_child(ball)
	ball.global_position = bins.get_child(0).to_global(Vector3(0, 0.4, 0))
	await _physics_frames(90)
	assert(absf(ball.global_position.y - (bins.get_child(0).global_position.y + 0.07)) < 0.025, "箱の物理面を落下物が貫通しました")
	assert(station.get_surplus_bin_ids_for_body(ball).is_empty())
	ball.queue_free()
	print("Gomi contents verified: 94 items by shelf category; gym-size Nadegg; 4 solid bin surfaces; car/player enter+exit and query APIs; static visitors excluded")
	viewport.queue_free()
	await process_frame
	quit()


func _verify_categories(contents: Node) -> bool:
	var counts := {"display": 0, "pc": 0, "oscilloscope": 0}
	var expected := {"FrontWest": "pc", "FrontEast": "pc", "SideSouth": "pc", "SideMiddleSouth": "display", "SideMiddleNorth": "display", "SideNorth": "display"}
	for rack in contents.get_node("GreenRackEquipment").get_children():
		for sprite in rack.find_children("*", "Sprite3D"):
			var category := _category(sprite)
			if category != expected[rack.name]:
				push_error("緑ラック内に異なるカテゴリが混在: %s" % rack.name)
				return false
			counts[category] += 1
	for sprite in contents.get_node("ShelfEquipment").find_children("*", "Sprite3D"):
		var category := _category(sprite)
		if category != ("display" if sprite.name.begins_with("North") else "oscilloscope"):
			push_error("白棚内に異なるカテゴリが混在: %s" % sprite.name)
			return false
		counts[category] += 1
	if counts != {"display": 44, "pc": 44, "oscilloscope": 6}:
		push_error("棚の備品数が不正: %s" % counts)
		return false
	print("Shelf categories: ", counts)
	return true


func _category(sprite: Sprite3D) -> String:
	var texture := sprite.texture as AtlasTexture
	if texture.atlas.resource_path.ends_with("surplus_oscilloscope.png"):
		return "oscilloscope"
	return "display" if texture.region.position.y < 250 else "pc"


func _verify_nadegg_size(contents: Node) -> bool:
	var gym: Node3D = load("res://gym.tscn").instantiate()
	var reference := _bounds(gym.get_node("Nadegg"))
	if contents.get_node("Browsers").get_child_count() != 3:
		push_error("新倉庫のNadeggは3体にする")
		gym.free()
		return false
	for browser in contents.get_node("Browsers").get_children():
		var bounds := _bounds(browser.get_node("Model"))
		var radius: float = (browser.get_node("CollisionShape3D").shape as SphereShape3D).radius
		if not bounds.size.is_equal_approx(reference.size) or not is_equal_approx(radius, 0.115):
			push_error("体育館のNadeggと寸法または衝突サイズが不一致")
			gym.free()
			return false
		var on_rim: bool = browser.name == &"BinBrowser"
		var placement_valid: bool = is_equal_approx(browser.position.y, 0.733) if on_rim else is_equal_approx(browser.position.y, 0.01)
		if not placement_valid or bounds.position.y < -0.001 or bounds.position.y >= 0.025:
			push_error("Nadeggの棚前/箱縁の配置または高さが不正")
			gym.free()
			return false
	print("Nadegg gym bounds: ", reference.size)
	gym.free()
	return true


func _bounds(node: Node3D, parent_transform := Transform3D.IDENTITY) -> AABB:
	var transform := parent_transform * node.transform
	var bounds := AABB()
	var found := false
	if node is MeshInstance3D:
		bounds = transform * node.mesh.get_aabb()
		found = true
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := _bounds(child, transform)
			if child_bounds.size != Vector3.ZERO:
				bounds = bounds.merge(child_bounds) if found else child_bounds
				found = true
	return bounds


func _strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		# 移動はテスト側で行う。VehicleWheelのサスペンション更新は不要。
		if child is VehicleWheel3D:
			child.free()
		else:
			_strip_scripts(child)


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

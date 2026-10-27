extends Node3D

# 新倉庫（Web 版では gomi.pck）を読み込めたら、この位置に置く

# 新倉庫の当たり判定
const COLLISION_SHAPE_PATH := "res://assets/models/GOMI_collision.res"
# ED3 のスクリプト
const ENDING_SCRIPT_PATH := "res://gomi_ending.gd"

var _preloaded: Array = []


func _ready() -> void:
	DeferredPacks.when_ready(&"gomi", _spawn)


# 読み込みを1フレームにまとめると Web 版で約0.5秒止まるため、重い当たり判定（約180ms）と ED3 のスクリプト（約50ms）を別のフレームで先に読む
func _spawn() -> void:
	# pck を開いたのと同じフレームにならないよう、1フレーム待つ
	await get_tree().process_frame
	_preloaded.append(load(COLLISION_SHAPE_PATH))
	await get_tree().process_frame
	_preloaded.append(load(ENDING_SCRIPT_PATH))
	await get_tree().process_frame
	var scene := load("res://gomi_station.tscn") as PackedScene
	await get_tree().process_frame
	# 新倉庫を初めて描くとき、Nadegg と棚のビルボードのシェーダーを作るのに約 0.2 秒かかる。置く前に、同じ世界を映す小さな画面で同じマテリアルを1つずつ描いて、シェーダーを1フレームずつ作っておく（Compatibility は描くときにシェーダーを作り、ライトマップの有無などで別のシェーダーになるので、同じ世界で描く）
	var warm_root := scene.instantiate() as Node3D
	var representatives: Array[GeometryInstance3D] = []
	_collect_warmup_geometry(warm_root, {}, representatives)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.world_3d = get_viewport().world_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.transparent_bg = true
	add_child(viewport)
	var camera := Camera3D.new()
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0, -2000, 0))
	viewport.add_child(camera)
	camera.current = true
	for representative in representatives:
		var copy := representative.duplicate() as GeometryInstance3D
		copy.process_mode = Node.PROCESS_MODE_DISABLED
		_remove_warmup_physics(copy)
		copy.top_level = true
		viewport.add_child(copy)
		var warm_transform := _warmup_transform(representative)
		warm_transform.origin = Vector3(0, -2000, -3) - warm_transform.basis * copy.get_aabb().get_center()
		copy.global_transform = warm_transform
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await get_tree().process_frame
		copy.queue_free()
	viewport.queue_free()
	warm_root.free()
	await get_tree().process_frame
	var station = scene.instantiate()
	station.name = "GomiStation"
	station.axis_lock_angular_z = true
	# ライトマップは新倉庫がメインシーンの直下の GomiStation だったときに焼いたので、同じ名前と位置で置き、あとから足した新倉庫にも当たるようライトマップを付け直す
	station.transform = transform
	add_sibling(station)
	var lightmaps := get_parent().find_children("*", "LightmapGI", false, false)
	if not lightmaps.is_empty():
		var lightmap := lightmaps[0] as LightmapGI
		if lightmap.light_data != null:
			var data := lightmap.light_data
			lightmap.light_data = null
			lightmap.light_data = data
	_preloaded.clear()


func _collect_warmup_geometry(node: Node, seen: Dictionary, representatives: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		var size := geometry.get_aabb().size
		if geometry.name != &"Mesh" and maxf(size.x, maxf(size.y, size.z)) <= 10.0:
			var keys: Array[String] = []
			if geometry.material_override != null:
				keys.append("material:%s" % geometry.material_override.get_instance_id())
			if geometry is MeshInstance3D:
				var mesh_instance := geometry as MeshInstance3D
				if mesh_instance.mesh != null:
					for surface in mesh_instance.mesh.get_surface_count():
						var material := mesh_instance.get_surface_override_material(surface)
						if material == null:
							material = mesh_instance.mesh.surface_get_material(surface)
						keys.append("material:%s" % material.get_instance_id() if material != null else "material:default")
			if geometry is SpriteBase3D:
				var sprite := geometry as SpriteBase3D
				keys.append("sprite:%s:%s:%s:%s:%s:%s:%s" % [sprite.get_class(), sprite.billboard, sprite.alpha_cut, sprite.transparent, sprite.shaded, sprite.double_sided, sprite.texture_filter])
			if geometry.material_override == null and not geometry is MeshInstance3D and not geometry is SpriteBase3D:
				keys.append("class:%s" % geometry.get_class())
			var is_new := false
			for key in keys:
				if not seen.has(key):
					seen[key] = true
					is_new = true
			if is_new:
				representatives.append(geometry)
	for child in node.get_children():
		_collect_warmup_geometry(child, seen, representatives)


func _remove_warmup_physics(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape3D or child is Area3D or child is PhysicsBody3D:
			child.free()
		else:
			_remove_warmup_physics(child)


func _warmup_transform(node: Node3D) -> Transform3D:
	# ツリー外なので、親をたどって変換を求める
	var result := node.transform
	var parent := node.get_parent()
	while parent != null:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

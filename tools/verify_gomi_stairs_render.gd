extends SceneTree

# 実描画検証（headlessを付けずに実行）。比較画像は.codexへ保存する。
func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var station: StaticBody3D = load("res://gomi_station.tscn").instantiate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(station)
	station.set_process(false)
	station.get_node("Mesh").hide()
	station.get_node("InsideStairs").hide()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.2, 0.3)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.9
	viewport.add_child(environment)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34.0
	var center := Vector3(-12.5, 7.85, 10.0)
	camera.position = center + Vector3(3, -30, 8)
	camera.look_at(center, Vector3(0, 0, 1))
	var combined := Image.create(384 * 3, 256, false, Image.FORMAT_RGBA8)
	var images: Array[Image] = []
	for alpha in [0.0, 0.5, 1.0]:
		station._set_outside_alpha(alpha)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		images.append(image)
		combined.blit_rect(image, Rect2i(0, 0, 384, 256), Vector2i((images.size() - 1) * 384, 0))
	var changed := 0
	var intermediate := 0
	for y in 256:
		for x in 384:
			var hidden := images[0].get_pixel(x, y)
			var half := images[1].get_pixel(x, y)
			var full := images[2].get_pixel(x, y)
			if hidden != full:
				changed += 1
				if half != hidden and half != full:
					intermediate += 1
	DirAccess.make_dir_recursive_absolute("res://.codex")
	combined.save_png("res://.codex/stairs-fade-render.png")
	print("Compatibility render verification: changed=%d intermediate=%d image=res://.codex/stairs-fade-render.png" % [changed, intermediate])
	quit(0 if changed > 100 and intermediate > 100 else 1)

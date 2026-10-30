extends SceneTree
## 使用法（描画が必要なため --headless は付けない）:
## Godot_v4.7.1-stable_win64_console.exe --path . --resolution 800x600 -s res://tools/capture_model_views.gd -- <出力フォルダ>

const TARGETS: Array[Array] = [
	["neo", "res://assets/models/ugokuita-neo.glb"],
	["classic", "res://assets/models/ugokuita-classic.fbx"],
	["gym", "res://assets/models/Gym.fbx"],
	["nadegg", "res://assets/models/NadeggMini.glb"],
	["gomi_contents", "res://gomi_station_contents.tscn"],
]


func _initialize() -> void:
	_capture_all.call_deferred()


func _capture_all() -> void:
	# 既存シーンの処理と UI を止め、撮影への映り込みを防ぐ。
	for child: Node in root.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		for layer: Node in child.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
		for item: Node in child.find_children("*", "CanvasItem", true, false):
			(item as CanvasItem).visible = false
	# 撮影用の 3D 描画を有効にする。
	root.disable_3d = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("出力フォルダを指定してください。")
		quit(1)
		return
	var output_dir: String = args[0]
	if not output_dir.is_absolute_path():
		output_dir = ProjectSettings.globalize_path("res://").path_join(output_dir)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(output_dir)
	if directory_error != OK:
		push_error("出力フォルダを作成できません: %s (%s)" % [output_dir, directory_error])
		quit(1)
		return
	for target: Array in TARGETS:
		var result: Error = await _capture_target(str(target[0]), str(target[1]), output_dir)
		if result != OK:
			quit(1)
			return
	quit()


func _capture_target(target_name: String, scene_path: String, output_dir: String) -> Error:
	# 対象ごとに独立した撮影用ステージを用意する。
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.6, 0.7)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	light.shadow_enabled = false
	light.light_energy = 1.0
	stage.add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.01
	camera.far = 500.0
	stage.add_child(camera)
	camera.current = true

	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("シーンを読み込めません: %s" % scene_path)
		stage.free()
		return ERR_CANT_OPEN
	var instance: Node = packed_scene.instantiate()
	# 追加前に無効化し、モデル固有の通常処理を撮影中に進めない。
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	stage.add_child(instance)
	var visual_bounds: Array[AABB] = []
	_collect_visual_bounds(instance, visual_bounds)
	if visual_bounds.is_empty():
		push_error("描画対象の AABB がありません: %s" % scene_path)
		stage.free()
		return ERR_INVALID_DATA
	var bounds: AABB = visual_bounds[0]
	for bounds_index: int in range(1, visual_bounds.size()):
		bounds = bounds.merge(visual_bounds[bounds_index])
	var center: Vector3 = bounds.get_center()
	var distance: float = bounds.get_longest_axis_size() * 1.4
	var view_index: int = 0

	# 外側の 16 視点は、水平からの仰角 20 度と 60 度で一周する。
	for elevation_degrees: float in [20.0, 60.0]:
		var elevation: float = deg_to_rad(elevation_degrees)
		for azimuth_index: int in range(8):
			var azimuth: float = deg_to_rad(float(azimuth_index) * 45.0)
			var direction: Vector3 = Vector3(
				sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)
			)
			camera.position = center + direction * distance
			camera.look_at(center, Vector3.UP)
			var save_error: Error = await _save_view(output_dir, target_name, view_index)
			if save_error != OK:
				stage.free()
				return save_error
			view_index += 1

	# 中心から水平に四方を見た 4 視点も撮影する。
	for azimuth_index: int in range(4):
		var azimuth: float = deg_to_rad(float(azimuth_index) * 90.0)
		var direction: Vector3 = Vector3(sin(azimuth), 0.0, cos(azimuth))
		camera.position = center
		camera.look_at(center + direction, Vector3.UP)
		var save_error: Error = await _save_view(output_dir, target_name, view_index)
		if save_error != OK:
			stage.free()
			return save_error
		view_index += 1
	stage.free()
	for frame_index: int in range(2):
		await process_frame
	return OK


func _collect_visual_bounds(node: Node, bounds: Array[AABB]) -> void:
	# 各描画ノードのローカル AABB をワールド空間へ変換して集める。
	if node is VisualInstance3D:
		var visual: VisualInstance3D = node as VisualInstance3D
		bounds.append(visual.global_transform * visual.get_aabb())
	for child: Node in node.get_children():
		_collect_visual_bounds(child, bounds)


func _save_view(output_dir: String, target_name: String, view_index: int) -> Error:
	# カメラ変更後の描画が安定するまで 4 フレーム待つ。
	for frame_index: int in range(4):
		await process_frame
	var image: Image = root.get_texture().get_image()
	var image_path: String = output_dir.path_join("%s_%02d.png" % [target_name, view_index])
	var save_error: Error = image.save_png(image_path)
	if save_error != OK:
		push_error("画像を保存できません: %s (%s)" % [image_path, save_error])
		return save_error
	print(image_path)
	return OK

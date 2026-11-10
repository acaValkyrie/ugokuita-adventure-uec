extends Node
# 点群表示の切り替えと、機体・カメラへの接続を受け持つ。

signal enabled_changed(on: bool)

# src/world/robot_sun.gd の robot_layer の既定値と揃える。
const ROBOT_RENDER_LAYER := 2
const OUTLINE_COLOR := Color(0.2, 0.6, 1.0)
const OUTLINE_WIDTH := 0.004

var _enabled := false
var _renderer: PointCloudRenderer
var _top_view := PointCloudTopView.new(Map.WORLD_RECT)
var _lidar: SimulatedLidar
var _car: VehicleBody3D
# カメラのインスタンス ID → 切り替え前の描画設定。
var _cameras := {}
# メッシュのインスタンス ID → 切り替え前のマテリアル。
var _car_materials := {}
var _car_material: StandardMaterial3D


func _ready() -> void:
	PlayerSwitch.player_changed.connect(_on_player_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"lidar_view") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_enabled(not _enabled)


func set_enabled(on: bool) -> void:
	if _enabled == on:
		return
	_enabled = on
	if on:
		_ensure_nodes()
		_update_camera()
	else:
		if is_instance_valid(_lidar):
			_lidar.enabled = false
		if is_instance_valid(_renderer):
			_renderer.visible = false
		_restore_car_materials()
		_restore_cameras()
	enabled_changed.emit(on)


func is_enabled() -> bool:
	return _enabled


# 点群モード中にミニマップと全体マップが地図の画像の代わりに使う。
func get_map_texture() -> Texture2D:
	return _top_view.get_texture()


func _process(_delta: float) -> void:
	if not _enabled:
		return
	_ensure_nodes()
	_update_camera()


# シーンの読み込み直しで描画ノードが消えた場合も、現在の世界に作り直す。
func _ensure_nodes() -> void:
	if not is_instance_valid(_lidar):
		_lidar = SimulatedLidar.new()
		add_child(_lidar)
	var needs_setup := false
	if not is_instance_valid(_renderer):
		var scene := get_tree().current_scene
		if scene == null:
			_lidar.enabled = false
			return
		_renderer = PointCloudRenderer.new()
		_top_view.clear()
		_renderer.points_accepted.connect(_top_view.add_points)
		scene.add_child(_renderer)
		needs_setup = true
	if not is_instance_valid(_car):
		_restore_car_materials()
		_car = get_tree().get_first_node_in_group("player") as VehicleBody3D
		needs_setup = true
	_apply_car_material()
	if needs_setup:
		_lidar.setup(_car, _renderer)
	_renderer.visible = true
	_lidar.enabled = true


func _on_player_changed(player: VehicleBody3D) -> void:
	if _car != player:
		_restore_car_materials()
	_car = player
	if _enabled:
		_apply_car_material()
	if is_instance_valid(_lidar) and is_instance_valid(_renderer):
		_lidar.setup(_car, _renderer)


func _apply_car_material() -> void:
	if not is_instance_valid(_car):
		return
	if _car_material == null:
		var outline := StandardMaterial3D.new()
		outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline.albedo_color = OUTLINE_COLOR
		outline.cull_mode = BaseMaterial3D.CULL_FRONT
		outline.grow = true
		outline.grow_amount = OUTLINE_WIDTH
		outline.disable_fog = true
		_car_material = StandardMaterial3D.new()
		_car_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_car_material.albedo_color = Color.BLACK
		_car_material.disable_fog = true
		_car_material.next_pass = outline
	for node in _car.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.top_level:
			continue
		var id := mesh.get_instance_id()
		if _car_materials.has(id):
			continue
		_car_materials[id] = mesh.material_override
		mesh.material_override = _car_material


func _restore_car_materials() -> void:
	for id in _car_materials:
		var mesh := instance_from_id(id) as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		mesh.material_override = _car_materials[id]
	_car_materials.clear()


func _update_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var id := camera.get_instance_id()
	if _cameras.has(id):
		return
	_cameras[id] = {"cull_mask": camera.cull_mask, "environment": camera.environment}
	camera.cull_mask = PointCloudRenderer.RENDER_LAYER | ROBOT_RENDER_LAYER
	camera.environment = _make_lidar_environment(camera)


func _make_lidar_environment(camera: Camera3D) -> Environment:
	var source := camera.environment
	if source == null:
		source = camera.get_world_3d().environment
	if source == null:
		source = camera.get_world_3d().fallback_environment
	if source == null:
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color.BLACK
		return environment
	var environment := source.duplicate() as Environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.fog_enabled = false
	environment.glow_enabled = false
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	return environment


func _restore_cameras() -> void:
	for id in _cameras:
		var camera := instance_from_id(id) as Camera3D
		if not is_instance_valid(camera):
			continue
		var settings: Dictionary = _cameras[id]
		camera.cull_mask = settings["cull_mask"]
		camera.environment = settings["environment"]
	_cameras.clear()

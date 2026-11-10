extends Node
# 点群表示の切り替えと、機体・カメラへの接続を受け持つ。

signal enabled_changed(on: bool)

# src/world/robot_sun.gd の robot_layer の既定値と揃える。
const ROBOT_RENDER_LAYER := 2
const OUTLINE_COLOR := Color(0.2, 0.6, 1.0)
const OUTLINE_WIDTH := 0.004
const LIDAR_BUTTON := preload("res://src/lidar/lidar_button.gd")

var _enabled := false
var _button_layer: CanvasLayer
var _renderer: PointCloudRenderer
var _jet_rings: LidarJetRings
var _space_scan: LidarSpaceScan
var _top_view := PointCloudTopView.new(Map.WORLD_RECT)
var _lidar: SimulatedLidar
var _car: VehicleBody3D
# 点群モード中に隠している普段のジェットの炎と煙。輪で見せるので隠す
var _hidden_exhaust: Node3D
# カメラのインスタンス ID → 切り替え前の描画設定。
var _cameras := {}
# メッシュのインスタンス ID → 切り替え前のマテリアル。
var _car_materials := {}
# メッシュのワールドスケール → 黒い面と輪郭のマテリアル。
# grow はメッシュのローカル単位なので、スケールで割って輪郭幅を揃える。
var _car_materials_by_scale := {}


func _ready() -> void:
	PlayerSwitch.player_changed.connect(_on_player_changed)
	# 左上のマップボタンの右に置く切り替えボタン
	_button_layer = LIDAR_BUTTON.new()
	add_child(_button_layer)


# タッチ運転の除外領域に使う
func get_button_rect() -> Rect2:
	return _button_layer.get_button_rect()


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
		if is_instance_valid(_jet_rings):
			_jet_rings.hide()
			_jet_rings.clear()
		if is_instance_valid(_space_scan):
			# 地面の点群と同じく、切っても消さずに隠すだけにする。消すのは ED2 の高さより下に戻ったとき
			_space_scan.hide()
		_restore_car_materials()
		_restore_cameras()
	enabled_changed.emit(on)


func is_enabled() -> bool:
	return _enabled


# 点群モードで初めて使うマテリアル。起動時の先読みで一度描かせ、初めて切り替えたときの引っかかりをなくす。輪郭は next_pass なので先読み側でたどられる。
func get_warmup_materials() -> Array[Material]:
	return [PointCloudRenderer.create_material(), _car_material_for(1.0), LidarJetRings.create_material()]


# 点群モード中にミニマップと全体マップが地図の画像の代わりに使う。
func get_map_texture() -> Texture2D:
	return _top_view.get_texture()


func _process(delta: float) -> void:
	# 点群モードを切っている間に ED2 の高さより下に戻ったら、宇宙の点群を消す（次に着いたら、その位置からスキャンし直す）
	if is_instance_valid(_space_scan) and is_instance_valid(_car) and _car.global_position.y <= Ending.ENDING2_HEIGHT:
		_space_scan.clear()
	if not _enabled:
		return
	_ensure_nodes()
	_update_camera()
	if is_instance_valid(_space_scan):
		_space_scan.update_scan(_car, delta)


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
	if not is_instance_valid(_jet_rings):
		var scene := get_tree().current_scene
		if scene == null:
			_lidar.enabled = false
			return
		_jet_rings = LidarJetRings.new()
		scene.add_child(_jet_rings)
		needs_setup = true
	if not is_instance_valid(_space_scan):
		var scene := get_tree().current_scene
		if scene == null:
			_lidar.enabled = false
			return
		_space_scan = LidarSpaceScan.new()
		scene.add_child(_space_scan)
	if not is_instance_valid(_car):
		_restore_car_materials()
		_car = get_tree().get_first_node_in_group("player") as VehicleBody3D
		needs_setup = true
	_apply_car_material()
	if needs_setup:
		_lidar.setup(_car, _renderer)
		_jet_rings.set_car(_car)
	_renderer.visible = true
	_jet_rings.visible = true
	_space_scan.visible = true
	_lidar.enabled = true


func _on_player_changed(player: VehicleBody3D) -> void:
	if _car != player:
		_restore_car_materials()
	_car = player
	if _enabled:
		_apply_car_material()
	if is_instance_valid(_lidar) and is_instance_valid(_renderer):
		_lidar.setup(_car, _renderer)
	if is_instance_valid(_jet_rings):
		_jet_rings.set_car(_car)


func _car_material_for(scale: float) -> StandardMaterial3D:
	var key := snappedf(scale, 0.0001)
	if _car_materials_by_scale.has(key):
		return _car_materials_by_scale[key]
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = OUTLINE_COLOR
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = OUTLINE_WIDTH / maxf(scale, 0.0001)
	outline.disable_fog = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	material.disable_fog = true
	material.next_pass = outline
	_car_materials_by_scale[key] = material
	return material


func _apply_car_material() -> void:
	if not is_instance_valid(_car):
		return
	for node in _car.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.top_level:
			continue
		var id := mesh.get_instance_id()
		if _car_materials.has(id):
			continue
		_car_materials[id] = mesh.material_override
		var mesh_scale := mesh.global_basis.get_scale()
		var scale := (mesh_scale.x + mesh_scale.y + mesh_scale.z) / 3.0
		mesh.material_override = _car_material_for(scale)
	var exhaust := _car.get_node_or_null("JetExhaust") as Node3D
	if exhaust != null and exhaust != _hidden_exhaust:
		exhaust.visible = false
		_hidden_exhaust = exhaust


func _restore_car_materials() -> void:
	for id in _car_materials:
		var mesh := instance_from_id(id) as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		mesh.material_override = _car_materials[id]
	_car_materials.clear()
	if is_instance_valid(_hidden_exhaust):
		_hidden_exhaust.visible = true
	_hidden_exhaust = null


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

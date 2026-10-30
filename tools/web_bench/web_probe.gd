extends Node
# 書き出し時だけ読み込む、倉庫の起動・定点計測。

const SPOTS: Array[String] = ["outside_west", "inside_center", "stairs_base", "stairs_mid"]
const PHASES: Array[String] = ["normal", "no_station_process", "no_crowd"]
enum State { WAIT, SPOT_SETTLE, BD_BASE_WAIT, BD_BASE, BD_HIDE_WAIT, BD_HIDE, BD_RESTORE_WAIT, PHASE_SETTLE, MEASURE, DONE }

var _state: State = State.WAIT
var _player: VehicleBody3D
var _station: Node3D
var _warmup: Node
var _viewport_rid: RID
var _logs: Array[String] = []
var _last_mirror_ms: int = 0
var _previous_us: int = 0
var _previous_physics_frames: int = 0
var _warmup_done_ms: int = -1
var _particle_frame: int = -1
var _gomi_added_ms: int = -1
var _mat_warmup_logged: bool = false
var _mat_gomi_logged: bool = false
var _mat_run: int = 0
var _mat_default: StandardMaterial3D = StandardMaterial3D.new()
var _warmup_started: bool = false
var _warmup_view: int = -1
var _first_scene: bool = false
var _spot_index: int = 0
var _phase_index: int = 0
var _phase_start_us: int = 0
var _phase_start_physics_frames: int = 0
var _phase_start_process_frames: int = 0
var _frame_ms: Array[float] = []
var _process_sum: float = 0.0
var _process_max: float = 0.0
var _physics_sum: float = 0.0
var _render_sum: float = 0.0
var _render_max: float = 0.0
var _draw_sum: float = 0.0
var _primitive_sum: float = 0.0
var _stopped_crowd: Object
var _disabled_station: Node3D
var _bd_targets: Array[Node3D] = []
var _bd_target: Node3D
var _bd_index: int = 0
var _bd_frames: int = 0
var _bd_draw_sum: float = 0.0
var _bd_object_sum: float = 0.0
var _bd_primitive_sum: float = 0.0
var _bd_cpu_sum: float = 0.0
var _bd_baseline: Array[float] = []
var _bd_lights_logged: bool = false
var _exp_noomni: bool = false
var _exp_noshadow: bool = false

func _ready() -> void:
	var query: String = ""
	if OS.has_feature("web"):
		query = str(JavaScriptBridge.eval("location.search", true))
	_exp_noomni = query.contains("noomni")
	_exp_noshadow = query.contains("noshadow")
	_log("exp flags %s" % query)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
	_warmup = get_node_or_null("/root/ShaderWarmup")
	if not is_instance_valid(_warmup):
		_log("skip missing ShaderWarmup")
	_connect_event("DeferredPacks", &"pack_ready", _on_pack_ready)
	_connect_event("GameMenu", &"robot_model_changed", _on_robot_model_changed)
	_connect_event("PlayerSwitch", &"player_changed", _on_player_changed)
	get_tree().node_added.connect(_on_node_added)
	_previous_us = Time.get_ticks_usec()
	_previous_physics_frames = Engine.get_physics_frames()
	_log("ready")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var elapsed_us: int = now - _previous_us
	_previous_us = now
	var physics_frames: int = Engine.get_physics_frames()
	var physics_frames_delta: int = physics_frames - _previous_physics_frames
	_previous_physics_frames = physics_frames
	_observe_startup()
	_observe_particles()
	_observe_materials()
	if elapsed_us > 50000:
		_log("long %.1f proc=%.1f phys=%.1f rcpu=%.1f warm=%s/%s paused=%s dphys=%d" % [
			float(elapsed_us) / 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid),
			_warmup.get("_state") if is_instance_valid(_warmup) else -1,
			_warmup.get("_view_index") if is_instance_valid(_warmup) else -1, get_tree().paused,
			physics_frames_delta])
	match _state:
		State.WAIT:
			_try_start(now)
		State.SPOT_SETTLE:
			if now - _phase_start_us >= 3000000:
				if SPOTS[_spot_index] in ["outside_west", "inside_center"]:
					_start_breakdown()
				else:
					_start_phase(now)
		State.BD_BASE_WAIT:
			_bd_frames += 1
			if _bd_frames >= 5:
				_reset_breakdown_sample()
				_state = State.BD_BASE
		State.BD_BASE:
			_sample_breakdown()
			if _bd_frames >= 30:
				_bd_baseline = _breakdown_average()
				_log("bd %s base draws=%.1f objs=%.1f prims=%.0f rcpu=%.1f" % [
					SPOTS[_spot_index], _bd_baseline[0], _bd_baseline[1], _bd_baseline[2], _bd_baseline[3]])
				_hide_breakdown_target()
		State.BD_HIDE_WAIT:
			_bd_frames += 1
			if _bd_frames >= 5:
				_reset_breakdown_sample()
				_state = State.BD_HIDE
		State.BD_HIDE:
			_sample_breakdown()
			if _bd_frames >= 20:
				_finish_breakdown_target()
		State.BD_RESTORE_WAIT:
			_bd_frames += 1
			if _bd_frames >= 3:
				_hide_breakdown_target()
		State.PHASE_SETTLE:
			if now - _phase_start_us >= 1000000:
				_begin_measurement(now)
		State.MEASURE:
			_sample(elapsed_us)
			if now - _phase_start_us >= 5000000:
				_finish_measurement(now)
				_restore_phase()
				_phase_index += 1
				if _phase_index < PHASES.size():
					_start_phase(Time.get_ticks_usec())
				else:
					_spot_index += 1
					_phase_index = 0
					_start_spot(Time.get_ticks_usec())
	if Time.get_ticks_msec() - _last_mirror_ms >= 1000:
		_mirror()

func _connect_event(autoload_name: String, signal_name: StringName, callback: Callable) -> void:
	var source: Node = get_node_or_null("/root/" + autoload_name)
	if is_instance_valid(source) and source.has_signal(signal_name):
		source.connect(signal_name, callback)
	else:
		_log("skip missing %s.%s" % [autoload_name, signal_name])

func _property(source: Object, key: StringName, fallback: Variant = null) -> Variant:
	if is_instance_valid(source):
		for info: Dictionary in source.get_property_list():
			if info["name"] == key:
				return source.get(key)
	return fallback

func _robot_key(player: Object) -> String:
	return str(_property(player, &"robot_key", _property(player, &"name", "unknown")))

func _on_pack_ready(pack_name: StringName) -> void:
	_log("pack_ready %s" % pack_name)

func _on_robot_model_changed(model: Variant) -> void:
	_log("robot_model_changed %s" % str(model))

func _on_player_changed(player: Variant) -> void:
	_log("player_changed %s" % (_robot_key(player) if player is Object else str(player)))

func _on_node_added(node: Node) -> void:
	_apply_experiment(node)
	if node.name == &"GomiStation":
		_gomi_added_ms = Time.get_ticks_msec()
		_log("gomi_added")
	if node is VehicleBody3D:
		_check_player_added.call_deferred(node)

func _apply_experiment(node: Node) -> void:
	if _exp_noomni and (node is OmniLight3D or node is SpotLight3D or (ClassDB.class_exists("AreaLight3D") and node.is_class("AreaLight3D"))):
		if not node.is_queued_for_deletion():
			_log("exp removed_light %s" % node.get_path())
			node.queue_free()
	if _exp_noshadow and node is DirectionalLight3D:
		node.shadow_enabled = false
		_log("exp noshadow %s" % node.name)

func _scan_experiments(node: Node) -> void:
	_apply_experiment(node)
	for child: Node in node.get_children():
		_scan_experiments(child)

func _check_player_added(node: Node) -> void:
	if is_instance_valid(node) and node.is_in_group("player"):
		_log("player_added %s" % _robot_key(node))

func _observe_startup() -> void:
	var view: int = int(_warmup.get("_view_index")) if is_instance_valid(_warmup) else -1
	if view != _warmup_view:
		_warmup_view = view
		_log("warmup_view %d" % view)
	if not _warmup_started and is_instance_valid(_warmup) and int(_warmup.get("_state")) == 2:
		_warmup_started = true
		_log("warmup_start")
	if _warmup_done_ms < 0 and is_instance_valid(_warmup) and bool(_warmup.get("_done")):
		_warmup_done_ms = Time.get_ticks_msec()
		_log("warmup_done")
		_particle_frame = 0
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene):
		if not _first_scene:
			_first_scene = true
			_scan_experiments(get_tree().root)
			_log("first_scene")
		if _gomi_added_ms < 0 and scene.find_child("GomiStation", false, false) != null:
			_gomi_added_ms = Time.get_ticks_msec()
			_log("gomi_added")

func _observe_particles() -> void:
	if _particle_frame < 0 or _particle_frame > 5:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		_scan_particles(get_tree().root, player.global_position)
	_particle_frame += 1

func _scan_particles(node: Node, player_position: Vector3) -> void:
	if node is CPUParticles3D or node is GPUParticles3D:
		var distance: float = node.global_position.distance_to(player_position)
		if distance <= 15.0:
			_log("ptc %d %s emitting=%s visible=%s pmode=%s can_process=%s amount=%s lifetime=%s local=%s dist=%.1f" % [
				_particle_frame, get_tree().root.get_path_to(node), node.emitting, node.is_visible_in_tree(),
				node.process_mode, node.can_process(), node.amount, node.lifetime, node.local_coords, distance])
	for child: Node in node.get_children(true):
		_scan_particles(child, player_position)

func _observe_materials() -> void:
	var now_ms: int = Time.get_ticks_msec()
	var warmup_ready: bool = _warmup_done_ms >= 0 and now_ms - _warmup_done_ms >= 2000
	var gomi_ready: bool = _gomi_added_ms >= 0 and now_ms - _gomi_added_ms >= 3000
	if not _mat_warmup_logged and warmup_ready:
		_mat_warmup_logged = true
		_mat_gomi_logged = gomi_ready
		_log_materials()
	elif _mat_warmup_logged and not _mat_gomi_logged and gomi_ready:
		_mat_gomi_logged = true
		_log_materials()

func _log_materials() -> void:
	_mat_run += 1
	var groups: Dictionary = {}
	_scan_materials(get_tree().root, groups)
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var a_count: int = groups[a]["objects"].size()
		var b_count: int = groups[b]["objects"].size()
		return a_count > b_count if a_count != b_count else a < b)
	var index: int = 0
	for key: String in keys:
		index += 1
		var group: Dictionary = groups[key]
		var stats: String = ""
		if group["base_material"]:
			stats = " tex_albedo=%d tex_normal=%d emis=%d emis_max=%.3f" % [
				group["tex_albedo"], group["tex_normal"], group["emis"], group["emis_max"]]
		_log("mat %d #%d n=%d uniq=%d key=%s%s" % [
			_mat_run, index, group["instances"], group["objects"].size(), key, stats])
		for path: String in group["paths"]:
			_log("matex %d #%d %s" % [_mat_run, index, path])
		for resource_path: String in group["resource_paths"]:
			_log("matres %d #%d %s" % [_mat_run, index, resource_path])
	_log("mat %d groups=%d" % [_mat_run, keys.size()])

func _scan_materials(node: Node, groups: Dictionary) -> void:
	if node is GeometryInstance3D:
		if node.material_override != null:
			_record_material_chain(node.material_override, node, groups)
		elif node is MeshInstance3D and node.mesh != null:
			for surface: int in range(node.mesh.get_surface_count()):
				_record_material_chain(node.get_active_material(surface), node, groups)
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			var mesh: Mesh = node.multimesh.mesh
			for surface: int in range(mesh.get_surface_count()):
				_record_material_chain(mesh.surface_get_material(surface), node, groups)
		if node.material_overlay != null:
			_record_material_chain(node.material_overlay, node, groups)
		if node is SpriteBase3D or node is Label3D:
			var key: String = "SpriteBase3D alpha_cut=%s billboard=%s shaded=%s double_sided=%s transparent=%s texture_filter=%s" % [
				node.get("alpha_cut"), node.get("billboard"), node.get("shaded"),
				node.get("double_sided"), _property(node, &"transparent", "n/a"), node.get("texture_filter")]
			# 内部材質はMaterial objectを取得できないためuniqには含めない。
			_record_material_key(key, 0, node, "", groups)
	for child: Node in node.get_children(true):
		_scan_materials(child, groups)

func _record_material_chain(material: Material, node: Node, groups: Dictionary) -> void:
	var seen: Dictionary = {}
	while material != null:
		var object_id: int = material.get_instance_id()
		if seen.has(object_id):
			break
		seen[object_id] = true
		_record_material_key(_material_key(material), object_id, node, material.resource_path, groups, material)
		material = material.next_pass

func _record_material_key(key: String, object_id: int, node: Node, resource_path: String, groups: Dictionary, material: Material = null) -> void:
	if not groups.has(key):
		groups[key] = {"instances": 0, "objects": {}, "paths": PackedStringArray(), "resource_paths": PackedStringArray(),
			"base_material": material is BaseMaterial3D, "tex_albedo": 0, "tex_normal": 0, "emis": 0, "emis_max": 0.0}
	var group: Dictionary = groups[key]
	group["instances"] += 1
	if object_id != 0 and not group["objects"].has(object_id):
		group["objects"][object_id] = true
		if material is BaseMaterial3D:
			if material.get_texture(BaseMaterial3D.TEXTURE_ALBEDO) != null:
				group["tex_albedo"] += 1
			if material.get_texture(BaseMaterial3D.TEXTURE_NORMAL) != null:
				group["tex_normal"] += 1
			if material.get_feature(BaseMaterial3D.FEATURE_EMISSION):
				group["emis"] += 1
				var emission: Color = material.emission
				var intensity: float = maxf(emission.r, maxf(emission.g, emission.b)) * material.emission_energy_multiplier
				group["emis_max"] = maxf(group["emis_max"], intensity)
	var paths: PackedStringArray = group["paths"]
	var path: String = str(get_tree().root.get_path_to(node))
	if paths.size() < 8 and not paths.has(path):
		paths.append(path)
		group["paths"] = paths
	var resource_paths: PackedStringArray = group["resource_paths"]
	if resource_path != "" and resource_paths.size() < 5 and not resource_paths.has(resource_path):
		resource_paths.append(resource_path)
		group["resource_paths"] = resource_paths

func _material_key(material: Material) -> String:
	if material is ShaderMaterial:
		var shader: Shader = material.shader
		if shader == null:
			return "Shader <null>"
		return "Shader " + shader.resource_path if shader.resource_path != "" else "Shader <builtin>@" + str(shader.get_instance_id())
	if not material is BaseMaterial3D:
		return material.get_class()
	var parts: PackedStringArray = [material.get_class()]
	if material is ORMMaterial3D:
		parts.append("orm")
	var properties: Array[StringName] = [&"texture_filter", &"detail_uv_layer", &"transparency", &"alpha_antialiasing_mode",
		&"shading_mode", &"blend_mode", &"depth_draw_mode", &"depth_test", &"cull_mode", &"diffuse_mode",
		&"specular_mode", &"billboard_mode", &"detail_blend_mode", &"roughness_texture_channel", &"emission_operator",
		&"distance_fade_mode", &"stencil_mode", &"heightmap_deep_parallax", &"grow", &"proximity_fade_enabled"]
	var names: PackedStringArray = ["tf", "duv", "tr", "aa", "sh", "bl", "dd", "dt", "cu", "di",
		"sp", "bi", "db", "rc", "eo", "df", "st", "hp", "gr", "pf"]
	for index: int in range(properties.size()):
		var property_name: StringName = properties[index]
		var value: Variant
		var default_value: Variant
		if property_name == &"depth_test":
			value = _property(material, &"depth_test", "n/a")
			default_value = _property(_mat_default, &"depth_test", "n/a")
		elif property_name == &"stencil_mode":
			value = _property(material, &"stencil_mode", "n/a")
			default_value = _property(_mat_default, &"stencil_mode", "n/a")
		else:
			value = material.get(property_name)
			default_value = _mat_default.get(property_name)
		if value != default_value:
			parts.append("%s=%s" % [names[index], value])
	for feature: int in range(BaseMaterial3D.FEATURE_MAX):
		if material.get_feature(feature) and not _mat_default.get_feature(feature):
			parts.append("f%d" % feature)
	for flag: int in range(BaseMaterial3D.FLAG_MAX):
		if material.get_flag(flag) and not _mat_default.get_flag(flag):
			parts.append("g%d" % flag)
	return " ".join(parts)

func _try_start(now: int) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if _warmup_done_ms < 0 or now_ms - _warmup_done_ms < 3000:
		return
	var packs: Node = get_node_or_null("/root/DeferredPacks")
	if not is_instance_valid(packs) or not packs.has_method("is_ready"):
		_log("skip missing DeferredPacks.is_ready")
		_complete()
		return
	if not bool(packs.call("is_ready", &"gomi")):
		return
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return
	_station = scene.find_child("GomiStation", false, false) as Node3D
	if not is_instance_valid(_station) or _gomi_added_ms < 0 or now_ms - _gomi_added_ms < 3000:
		return
	_player = get_tree().get_first_node_in_group("player") as VehicleBody3D
	if not is_instance_valid(_player):
		_log("skip missing player")
		_complete()
		return
	_disable_items()
	_start_spot(now)

func _disable_items() -> void:
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		_log("skip missing scene")
		return
	for node: Node in scene.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path == "res://power_up_item.gd":
			node.process_mode = Node.PROCESS_MODE_DISABLED

func _start_spot(now: int) -> void:
	if _spot_index >= SPOTS.size():
		_complete()
		return
	if not is_instance_valid(_station) or not is_instance_valid(_player):
		_log("skip missing station or player")
		_complete()
		return
	var pos := Vector3(68, 0, 4.6)
	var look := Vector3(103.4, 0, 4.6)
	var ray_height: float = 3.0
	if _spot_index > 0:
		var local_pos := Vector3(6.0, 7.85, 0.5)
		var local_look := Vector3(-10, 7.85, 0.5)
		if _spot_index == 1:
			var mesh: MeshInstance3D = _station.get_node_or_null("Mesh") as MeshInstance3D
			if not is_instance_valid(mesh) or mesh.mesh == null:
				_log("skip inside_center missing Mesh")
				_spot_index += 1
				_start_spot(now)
				return
			var center: Vector3 = mesh.transform * mesh.get_aabb().get_center()
			local_pos = Vector3(center.x, center.y, 0.5)
			local_look = Vector3(center.x - 10, center.y, 0.5)
		elif _spot_index == 3:
			local_pos = Vector3(-10, 7.85, 10.3)
			local_look = Vector3(-30, 7.85, 10.3)
			ray_height = 1.5
		pos = _station.global_transform * local_pos
		look = _station.global_transform * local_look
	var ray_from: Vector3 = pos + Vector3.UP * ray_height
	var ray_to: Vector3 = pos + Vector3.DOWN * 5.0
	if _spot_index == 0:
		ray_from.y = 80.0
		ray_to.y = -20.0
	var world: World3D = _player.get_world_3d()
	if world == null:
		_log("skip missing player world")
		_complete()
		return
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var ground: Vector3 = hit["position"]
		pos.y = ground.y + 0.6
	var direction := Vector3(look.x - pos.x, 0, look.z - pos.z).normalized()
	var power_ups: Node = get_node_or_null("/root/PowerUps")
	if direction.is_zero_approx() or not is_instance_valid(power_ups) or not power_ups.has_method("_move_player_to"):
		_log("skip invalid direction or missing PowerUps._move_player_to")
		_complete()
		return
	power_ups.call("_move_player_to", _player, Transform3D(Basis.looking_at(-direction, Vector3.UP), pos))
	_state = State.SPOT_SETTLE
	_phase_start_us = now

func _start_breakdown() -> void:
	_bd_targets.clear()
	_bd_index = 0
	var scene: Node = get_tree().current_scene
	for node: Node in scene.get_children():
		if node is Node3D and node != _station and not node.is_in_group("player") and not node is Camera3D and not node is Light3D and not node is WorldEnvironment:
			if node.is_visible_in_tree():
				_bd_targets.append(node)
	for node: Node in _station.get_children():
		if node is Node3D and node.name != &"SurplusContents" and node.is_visible_in_tree():
			_bd_targets.append(node)
	var surplus: Node = _station.get_node_or_null("SurplusContents")
	if is_instance_valid(surplus):
		for node: Node in surplus.get_children():
			if node is Node3D and node.is_visible_in_tree():
				_bd_targets.append(node)
	_log_breakdown_geometry()
	if not _bd_lights_logged:
		_log_breakdown_lights(scene)
		_bd_lights_logged = true
	_bd_frames = 0
	_state = State.BD_BASE_WAIT

func _log_breakdown_geometry() -> void:
	var counts: Dictionary = {}
	var surfaces: int = 0
	for node: Node in _station.find_children("*", "GeometryInstance3D", true, false):
		var class_name_text: String = node.get_class()
		counts[class_name_text] = int(counts.get(class_name_text, 0)) + 1
		if node is MeshInstance3D and node.mesh != null:
			surfaces += node.mesh.get_surface_count()
	var classes: Array = counts.keys()
	classes.sort()
	var parts: PackedStringArray = []
	for class_name_text: String in classes:
		parts.append("%s=%d" % [class_name_text, counts[class_name_text]])
	_log("bd %s geom %s surfaces=%d" % [SPOTS[_spot_index], " ".join(parts), surfaces])

func _log_breakdown_lights(scene: Node) -> void:
	for node: Node in scene.find_children("*", "Light3D", true, false):
		var light: Light3D = node as Light3D
		var range_text: String = ""
		if light is OmniLight3D:
			range_text = " range=%.1f" % light.omni_range
		elif light is SpotLight3D:
			range_text = " range=%.1f" % light.spot_range
		elif not light is DirectionalLight3D:
			continue
		_log("bd light %s %s visible=%s%s" % [scene.get_path_to(light), light.get_class(), light.visible, range_text])

func _reset_breakdown_sample() -> void:
	_bd_frames = 0
	_bd_draw_sum = 0.0
	_bd_object_sum = 0.0
	_bd_primitive_sum = 0.0
	_bd_cpu_sum = 0.0

func _sample_breakdown() -> void:
	_bd_frames += 1
	_bd_draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_bd_object_sum += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_bd_primitive_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_bd_cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid)

func _breakdown_average() -> Array[float]:
	return [_bd_draw_sum / _bd_frames, _bd_object_sum / _bd_frames, _bd_primitive_sum / _bd_frames, _bd_cpu_sum / _bd_frames]

func _hide_breakdown_target() -> void:
	# 各対象は元の表示状態で個別に測る。
	while _bd_index < _bd_targets.size():
		_bd_target = _bd_targets[_bd_index]
		_bd_index += 1
		if is_instance_valid(_bd_target):
			_bd_target.visible = false
			_bd_frames = 0
			_state = State.BD_HIDE_WAIT
			return
	_bd_target = null
	_start_phase(Time.get_ticks_usec())

func _finish_breakdown_target() -> void:
	var average: Array[float] = _breakdown_average()
	if is_instance_valid(_bd_target):
		_log("bd %s hide %s d_draws=%.1f d_objs=%.1f d_prims=%.0f d_rcpu=%.1f" % [
			SPOTS[_spot_index], get_tree().current_scene.get_path_to(_bd_target),
			_bd_baseline[0] - average[0], _bd_baseline[1] - average[1],
			_bd_baseline[2] - average[2], _bd_baseline[3] - average[3]])
		_bd_target.visible = true
	_bd_target = null
	_bd_frames = 0
	_state = State.BD_RESTORE_WAIT

func _start_phase(now: int) -> void:
	if not is_instance_valid(_station) or not is_instance_valid(_player):
		_log("skip missing station or player")
		_complete()
		return
	if _phase_index == 1:
		_disabled_station = _station
		_station.set_process(false)
	elif _phase_index == 2:
		var crowd: Object = _property(_station, &"_crowd_player") as Object
		if is_instance_valid(crowd) and crowd.has_method("stop") and crowd.has_method("play"):
			_stopped_crowd = crowd
			crowd.call("stop")
		else:
			_log("skip missing crowd player")
	var proximity: Object = _property(_station, &"_proximity") as Object
	if is_instance_valid(proximity) and proximity.has_method("distance_to"):
		var before: int = Time.get_ticks_usec()
		var distance: Variant = proximity.call("distance_to", _player, 2.0)
		var took_us: int = Time.get_ticks_usec() - before
		_log("stair_dist %s took_us=%d" % [str(distance), took_us])
	else:
		_log("skip missing stair proximity")
	_state = State.PHASE_SETTLE
	_phase_start_us = now

func _begin_measurement(now: int) -> void:
	_phase_start_physics_frames = Engine.get_physics_frames()
	_phase_start_process_frames = Engine.get_process_frames()
	_frame_ms.clear()
	_process_sum = 0.0
	_process_max = 0.0
	_physics_sum = 0.0
	_render_sum = 0.0
	_render_max = 0.0
	_draw_sum = 0.0
	_primitive_sum = 0.0
	_phase_start_us = now
	_state = State.MEASURE

func _sample(elapsed_us: int) -> void:
	_frame_ms.append(float(elapsed_us) / 1000.0)
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid)
	_process_sum += process_ms
	_process_max = maxf(_process_max, process_ms)
	_physics_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_render_sum += render_ms
	_render_max = maxf(_render_max, render_ms)
	_draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_primitive_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)

func _finish_measurement(now: int) -> void:
	var count: int = _frame_ms.size()
	if count == 0 or not is_instance_valid(_player):
		_log("skip empty phase or missing player")
		return
	_frame_ms.sort()
	var middle: int = count >> 1
	var median: float = _frame_ms[middle]
	if count % 2 == 0:
		median = (_frame_ms[middle - 1] + median) / 2.0
	var pos: Vector3 = _player.global_position
	var position_text: String = "(%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z]
	var physics_frames: int = Engine.get_physics_frames() - _phase_start_physics_frames
	var process_frames: int = Engine.get_process_frames() - _phase_start_process_frames
	var steps: float = float(physics_frames) / process_frames if process_frames > 0 else 0.0
	_log("phase %s %s frames=%d fps=%.1f med=%.1f p95=%.1f max=%.1f proc=%.1f proc_max=%.1f phys=%.1f rcpu=%.1f rcpu_max=%.1f draws=%.1f prims=%.1f steps=%.2f pos=%s" % [
		SPOTS[_spot_index], PHASES[_phase_index], count, count / (float(now - _phase_start_us) / 1000000.0),
		median, _frame_ms[ceili(count * 0.95) - 1], _frame_ms[-1], _process_sum / count, _process_max,
		_physics_sum / count, _render_sum / count, _render_max, _draw_sum / count, _primitive_sum / count, steps, position_text])

func _restore_phase() -> void:
	if is_instance_valid(_disabled_station):
		_disabled_station.set_process(true)
	_disabled_station = null
	if is_instance_valid(_stopped_crowd):
		_stopped_crowd.call("play")
	_stopped_crowd = null

func _complete() -> void:
	if is_instance_valid(_bd_target):
		_bd_target.visible = true
	_bd_target = null
	_restore_phase()
	_state = State.DONE
	_log("scenario_done")
	_mirror()
	_js("window.__probeDone = true;")

func _log(text: String) -> void:
	var line: String = "[probe] %d %s" % [Time.get_ticks_msec(), text]
	print(line)
	_logs.append(line)

func _mirror() -> void:
	_js("window.__probe = %s;" % JSON.stringify(_logs))
	_last_mirror_ms = Time.get_ticks_msec()

func _js(code: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(code, true)

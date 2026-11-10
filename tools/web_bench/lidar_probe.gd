extends Node
# 書き出し時だけ読み込む、点群モードの重さの計測。

var _logs: Array[String] = []
var _last_mirror_ms: int = 0
var _viewport_rid: RID


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _last_mirror_ms >= 1000:
		_mirror()


func _run() -> void:
	var warmup: Node = get_node_or_null("/root/ShaderWarmup")
	while not is_instance_valid(warmup) or not bool(warmup.get("_done")):
		await get_tree().process_frame
		warmup = get_node_or_null("/root/ShaderWarmup")
	await get_tree().create_timer(3.0).timeout

	var game_settings: Node = get_node_or_null("/root/GameSettings")
	var robot_model: String = str(game_settings.get("robot_model")) if is_instance_valid(game_settings) else "unknown"
	var player: VehicleBody3D
	var model_wait_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - model_wait_start < 120000:
		var candidate: Node = get_tree().get_first_node_in_group("player")
		if candidate is VehicleBody3D and str(candidate.get("robot_key")) == robot_model:
			player = candidate as VehicleBody3D
			break
		await get_tree().process_frame
	if not is_instance_valid(player):
		_log("timeout model=%s" % robot_model)
		_complete()
		return
	_log("start model=%s" % robot_model)
	_log("env touch=%s window=%s" % [UiStyle.is_touch_device(), get_tree().root.size])
	_log("shot normal")
	await get_tree().create_timer(2.0).timeout

	_disable_items()
	var lidar_view: Node = get_node_or_null("/root/LidarView")
	var power_ups: Node = get_node_or_null("/root/PowerUps")
	if not is_instance_valid(lidar_view) or not is_instance_valid(power_ups):
		_log("skip missing LidarView or PowerUps")
		_complete()
		return

	var start_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(45.0)), Vector3(72.17, 0.6, -112.58))
	for phase: String in ["normal", "lidar"]:
		power_ups.call("_move_player_to", player, start_transform)
		await get_tree().create_timer(1.0).timeout
		if phase == "lidar":
			lidar_view.call("set_enabled", true)
		Input.action_press("up")
		await get_tree().create_timer(1.5).timeout
		var frame_ms: Array[float] = []
		var physics_sum: float = 0.0
		var render_sum: float = 0.0
		var render_max: float = 0.0
		var draw_sum: float = 0.0
		var primitive_sum: float = 0.0
		var start_us: int = Time.get_ticks_usec()
		var previous_us: int = start_us
		var start_physics_frames: int = Engine.get_physics_frames()
		var start_process_frames: int = Engine.get_process_frames()
		while Time.get_ticks_usec() - start_us < 6000000:
			await get_tree().process_frame
			var now_us: int = Time.get_ticks_usec()
			frame_ms.append(float(now_us - previous_us) / 1000.0)
			previous_us = now_us
			physics_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid)
			render_sum += render_ms
			render_max = maxf(render_max, render_ms)
			draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			primitive_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		Input.action_release("up")
		var end_physics_frames: int = Engine.get_physics_frames()
		var end_process_frames: int = Engine.get_process_frames()
		var elapsed_sec: float = float(Time.get_ticks_usec() - start_us) / 1000000.0
		var count: int = frame_ms.size()
		frame_ms.sort()
		var median: float = 0.0
		var p95: float = 0.0
		var max_frame: float = 0.0
		var physics_ms: float = 0.0
		var render_avg: float = 0.0
		var draw_avg: float = 0.0
		var primitive_avg: float = 0.0
		if count > 0:
			median = frame_ms[count >> 1]
			if count % 2 == 0:
				median = (frame_ms[(count >> 1) - 1] + median) / 2.0
			p95 = frame_ms[ceili(count * 0.95) - 1]
			max_frame = frame_ms[-1]
			physics_ms = physics_sum / count
			render_avg = render_sum / count
			draw_avg = draw_sum / count
			primitive_avg = primitive_sum / count
		var process_frames: int = end_process_frames - start_process_frames
		var steps: float = float(end_physics_frames - start_physics_frames) / process_frames if process_frames > 0 else 0.0
		var points: int = 0
		if phase == "lidar":
			var renderer: Object = lidar_view.get("_renderer")
			if is_instance_valid(renderer):
				points = int(renderer.call("get_point_count"))
		_log("phase %s model=%s frames=%d fps=%.1f med=%.1f p95=%.1f max=%.1f phys=%.2f rcpu=%.2f rcpu_max=%.1f draws=%.1f prims=%.0f steps=%.2f points=%d" % [
			phase, robot_model, count, float(count) / elapsed_sec if elapsed_sec > 0.0 else 0.0,
			median, p95, max_frame, physics_ms, render_avg, render_max, draw_avg, primitive_avg, steps, points])

	var lidar: Object = lidar_view.get("_lidar")
	if is_instance_valid(lidar):
		_log("lidar rays_per_tick=%d" % lidar.rays_per_tick)
	_log("shot lidar")
	await get_tree().create_timer(2.0).timeout

	power_ups.call("_move_player_to", player, start_transform)
	if is_instance_valid(lidar):
		var tick_start_us: int = Time.get_ticks_usec()
		for _i: int in range(60):
			lidar.call("_physics_process", 1.0 / 60.0)
		_log("bench lidar_tick us=%.1f" % (float(Time.get_ticks_usec() - tick_start_us) / 60.0))
		var car: VehicleBody3D = player
		var world: World3D = car.get_world_3d()
		var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
		var query := PhysicsRayQueryParameters3D.new()
		query.collision_mask = 1 | 4
		query.exclude = [car.get_rid()]
		var ray_from: Vector3 = car.global_position + Vector3(0.0, 0.2, 0.0)
		var ray_hits: int = 0
		var ray_start_us: int = Time.get_ticks_usec()
		for i: int in range(3000):
			var u: float = fposmod(i * 0.6180339887, 1.0)
			var v: float = fposmod(i * 0.7548776662, 1.0)
			query.from = ray_from
			query.to = ray_from + lidar.call("_sample_direction", u, v) * 40.0
			if not space_state.intersect_ray(query).is_empty():
				ray_hits += 1
		var ray_elapsed_us: int = Time.get_ticks_usec() - ray_start_us
		_log("bench ray us=%.2f hit=%.2f" % [float(ray_elapsed_us) / 3000.0, float(ray_hits) / 3000.0])
	else:
		_log("bench lidar_tick us=0.0")
		_log("bench ray us=0.00 hit=0.00")

	var renderer: Object = lidar_view.get("_renderer")
	if is_instance_valid(renderer):
		var rebuild_start_us: int = Time.get_ticks_usec()
		for _i: int in range(20):
			renderer.set("_dirty", true)
			renderer.call("_rebuild_current")
		_log("bench rebuild us=%.1f" % (float(Time.get_ticks_usec() - rebuild_start_us) / 20.0))
	else:
		_log("bench rebuild us=0.0")
	var top_view: Object = lidar_view.get("_top_view")
	if is_instance_valid(top_view):
		var topview_start_us: int = Time.get_ticks_usec()
		for _i: int in range(10):
			top_view.set("_dirty", true)
			top_view.set("_last_update_msec", -1000000)
			top_view.call("get_texture")
		_log("bench topview_upload us=%.1f" % (float(Time.get_ticks_usec() - topview_start_us) / 10.0))
	else:
		_log("bench topview_upload us=0.0")
	lidar_view.call("set_enabled", false)
	_complete()


func _disable_items() -> void:
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return
	for node: Node in scene.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path == "res://src/progression/power_up_item.gd":
			node.process_mode = Node.PROCESS_MODE_DISABLED


func _complete() -> void:
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

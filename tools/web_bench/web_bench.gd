extends Node
# Web版の定点計測。tools/web_bench/export_bench.ps1 が書き出しのときだけ自動読み込みに入れる。

const SPOTS: Array[Dictionary] = [
	{"name": "start"},
	{"name": "main_street", "car": Vector2(85, -10), "look": Vector2(85, -80)},
	{"name": "warehouse", "car": Vector2(68, 4.6), "look": Vector2(103.4, 4.6)},
	{"name": "fountain", "car": Vector2(109.4, 72), "look": Vector2(109.4, 58.8)},
	{"name": "pool", "car": Vector2(-185, -178.8), "look": Vector2(-207.76, -178.83)},
]
enum State { WARMUP, WAIT, SETTLE, IDLE, DRIVE, DONE }

var _state: State = State.WARMUP
var _player: VehicleBody3D
var _label: Label
var _spot_index: int = 0
var _warmup_done_ms: int = 0
var _phase_start_us: int = 0
var _previous_us: int = 0
var _start_epoch_ms: int = 0
var _frame_ms: Array[float] = []
var _process_sum: float = 0.0
var _physics_sum: float = 0.0
var _physics_max: float = 0.0
var _draw_sum: float = 0.0
var _primitive_sum: float = 0.0
var _object_sum: float = 0.0
var _results: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_label = Label.new()
	layer.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -340
	_label.offset_right = -16
	_label.offset_top = 16
	_label.offset_bottom = 56
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.text = "start:warmup"

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	match _state:
		State.WARMUP:
			_player = get_tree().get_first_node_in_group("player") as VehicleBody3D
			if ShaderWarmup._done and is_instance_valid(_player):
				_warmup_done_ms = Time.get_ticks_msec()
				_js("window.__benchWarmupDone = performance.now();")
				_state = State.WAIT
				_phase_start_us = now
		State.WAIT:
			if now - _phase_start_us >= 3000000:
				_disable_items()
				_start_spot(now)
		State.SETTLE:
			if now - _phase_start_us >= 4000000:
				_begin_measurement(State.IDLE, now)
		State.IDLE, State.DRIVE:
			_sample(now - _previous_us)
			var limit_us: int = 10000000 if _state == State.IDLE else 8000000
			if now - _phase_start_us >= limit_us:
				var was_idle: bool = _state == State.IDLE
				if not was_idle:
					Input.action_release("up")
				_finish_measurement(now)
				if was_idle:
					_begin_measurement(State.DRIVE, Time.get_ticks_usec())
				else:
					_spot_index += 1
					if _spot_index < SPOTS.size():
						_start_spot(Time.get_ticks_usec())
					else:
						_state = State.DONE
						_show_phase("done")
						_js("window.__benchDone = true;")
	_previous_us = now

func _disable_items() -> void:
	for node: Node in get_tree().current_scene.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path == "res://power_up_item.gd":
			node.process_mode = Node.PROCESS_MODE_DISABLED

func _start_spot(now: int) -> void:
	var spot: Dictionary = SPOTS[_spot_index]
	if spot.has("car"):
		var car: Vector2 = spot["car"]
		var look: Vector2 = spot["look"]
		var query := PhysicsRayQueryParameters3D.create(Vector3(car.x, 80, car.y), Vector3(car.x, -20, car.y))
		query.exclude = [_player.get_rid()]
		var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
		var height: float = 1.0
		if not hit.is_empty():
			var position: Vector3 = hit["position"]
			height = position.y + 1.0
		var direction := Vector3(look.x - car.x, 0, look.y - car.y).normalized()
		PowerUps._move_player_to(_player, Transform3D(Basis.looking_at(-direction, Vector3.UP), Vector3(car.x, height, car.y)))
	_state = State.SETTLE
	_phase_start_us = now
	_show_phase("settle")

func _begin_measurement(state: State, now: int) -> void:
	_state = state
	_phase_start_us = now
	_start_epoch_ms = int(Time.get_unix_time_from_system() * 1000.0)
	_frame_ms.clear()
	_process_sum = 0.0
	_physics_sum = 0.0
	_physics_max = 0.0
	_draw_sum = 0.0
	_primitive_sum = 0.0
	_object_sum = 0.0
	_show_phase("idle" if state == State.IDLE else "drive")
	if state == State.DRIVE:
		Input.action_press("up")

func _sample(elapsed_us: int) -> void:
	_frame_ms.append(float(elapsed_us) / 1000.0)
	_process_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_physics_sum += physics_ms
	_physics_max = maxf(_physics_max, physics_ms)
	_draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_primitive_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_object_sum += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

func _finish_measurement(now: int) -> void:
	var count: int = _frame_ms.size()
	var duration: float = float(now - _phase_start_us) / 1000000.0
	_frame_ms.sort()
	var slow: int = 0
	for milliseconds: float in _frame_ms:
		if milliseconds > 33.4:
			slow += 1
	var middle: int = count >> 1
	var median: float = _frame_ms[middle]
	if count % 2 == 0:
		median = (_frame_ms[middle - 1] + median) / 2.0
	var position: Vector3 = _player.global_position
	var result: Dictionary = {
		"spot": SPOTS[_spot_index]["name"], "phase": "idle" if _state == State.IDLE else "drive",
		"start_epoch_ms": _start_epoch_ms, "end_epoch_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"frames": count, "duration_s": duration, "fps": count / duration,
		"median_ms": median, "p95_ms": _frame_ms[ceili(count * 0.95) - 1], "max_ms": _frame_ms[-1],
		"frames_over_33_4_ms": slow, "avg_process_ms": _process_sum / count,
		"avg_physics_ms": _physics_sum / count, "max_physics_ms": _physics_max,
		"avg_draw_calls": _draw_sum / count, "avg_primitives": _primitive_sum / count,
		"avg_objects": _object_sum / count,
		"memory_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_memory_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"texture_memory_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_memory_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"car_position": [snappedf(position.x, 0.01), snappedf(position.y, 0.01), snappedf(position.z, 0.01)],
		"car_speed_m_s": _player.linear_velocity.length(),
	}
	for key: String in result:
		if result[key] is float:
			result[key] = snappedf(float(result[key]), 0.01)
	_results.append(result)
	print(JSON.stringify(result))
	_js("window.__bench = %s;" % JSON.stringify({"warmup_done_ms": _warmup_done_ms, "results": _results}))

func _show_phase(phase: String) -> void:
	var spot: String = str(SPOTS[mini(_spot_index, SPOTS.size() - 1)]["name"])
	_label.text = spot + ":" + phase
	_js("window.__benchPhase = %s;" % JSON.stringify(_label.text))

func _js(code: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(code, true)

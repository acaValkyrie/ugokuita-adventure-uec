extends Node3D

enum Phase { IDLE, GATHERING, DISMANTLING, COMPLETE }

# 画像面は箱底より34cm高い。車輪/サスペンションは画像面へ潜っても、
# 内底より上で、シャーシ中心が画像面以上なら箱内に入ったとみなす。
const CONTENTS_TO_BIN_FLOOR := 0.34
const FLOOR_EPSILON := 0.012
const RIM_EPSILON := 0.012
# 群がって分解している間に流す電動ドライバの音と、ランダムに鳴らすねじの音。クレジットは assets/audio/CREDITS.md
const POWER_TOOL_SOUND := preload("res://assets/audio/salvage/power_tool.ogg")
const SCREWS_SOUND := preload("res://assets/audio/salvage/screws.ogg")
const POWER_TOOL_VOLUME_DB := -4.0
const SCREWS_INTERVAL_MIN := 0.5
const SCREWS_INTERVAL_MAX := 1.2
# 目が光るカットで鳴らす音
const EYE_SPARKLE_SOUND := preload("res://assets/audio/salvage/eye_sparkle.ogg")
# ED3 が始まってから Back to Start を押すまで流す BGM（ループしない）
const BGM := preload("res://assets/audio/salvage/ed3_bgm.ogg")
const BGM_VOLUME_DB := 0.0
const PlaybackInput := preload("res://salvage_playback_input.gd")
# 最初のカットでは、機体から OVERHEAD_DISTANCE [m]、仰角 OVERHEAD_ELEVATION_DEG [度] の位置から見下ろし、経度を OVERHEAD_ORBIT_DEG [度] 回す。
const OVERHEAD_DISTANCE := 2.4
const OVERHEAD_ELEVATION_DEG := 60.0
const OVERHEAD_ORBIT_DEG := 20.0
# 最初のカットの長さ [秒]
const OVERHEAD_DURATION := 1.5
# 目が光るカットのカメラは、頭から GLINT_CAMERA_DISTANCE [m] 離れた候補を順に試し、
# 機体の中に入らず、頭までの視線が機体に遮られない最初の位置を使う。
# 向きは箱の内側を基準に左右へ GLINT_CAMERA_TURNS [度] ずらし、見上げる角度は GLINT_CAMERA_ELEVATIONS [度]。
const GLINT_CAMERA_DISTANCE := 1.5
const GLINT_CAMERA_ELEVATIONS := [10.0, 30.0, 50.0]
const GLINT_CAMERA_TURNS := [0.0, 30.0, -30.0, 60.0, -60.0]
# 群がってから BAD END までは、機体を中心にカメラの経度を ORBIT_SPEED_DEG [度/秒] で回し続ける。
const ORBIT_SPEED_DEG := 15.0
# 回っている間は、機体からの距離を ORBIT_RADIUS [m] まで ORBIT_RADIUS_SPEED [m/秒] で縮める（箱のまわりの棚にカメラが届かないようにする）。
const ORBIT_RADIUS := 1.8
const ORBIT_RADIUS_SPEED := 1.0
const COMIC_FONT := preload("res://assets/fonts/noto_sans_jp_bold_ending.otf")
const EYE_GLINT := preload("res://assets/textures/gomi_station/nadegg_eye_glint.png")
# 目のくぼみの縁（高さ0.183m、前へ0.052m）に合わせる。
const NADEGG_HEAD_CENTER := Vector3(0, 0.168, 0)
const NADEGG_HEAD_RADIUS := 0.052
const EYE_SURFACE_OFFSET := 0.0008
# 目の画像は球面に沿わせず、頭部に接する平らな板にする。
const EYE_SIZE := Vector2(1024.0 * 0.000100 * 0.80, 1024.0 * 0.000100 * 0.65) * 1.08
# 目は光がまたたくように、全体が大きくなったり小さくなったりする。
const EYE_PULSE_AMOUNT := 0.10
const EYE_PULSE_PERIOD := 0.6
const INITIAL_NADEGG_COUNT := 9
const REINFORCEMENT_WAVES := 4
const EXTRA_NADEGG_COUNT := INITIAL_NADEGG_COUNT + REINFORCEMENT_WAVES * 2
const SCUFFLE_WORDS := {6: "ドタ", 7: "バタ", 8: "ガタ", 9: "ゴト"}
const SCUFFLE_WORD_OFFSETS := {
	6: Vector3(-0.68, 0.40, 0.05),
	7: Vector3(0.68, 0.50, -0.10),
	8: Vector3(-0.92, 0.52, -0.16),
	9: Vector3(0.98, 0.42, 0.16),
}

var phase := Phase.IDLE
var _vehicle: Node3D
var _bin: Node3D
var _actors: Array[Node3D] = []
var _actor_rest: Array[Transform3D] = []
var _actor_layers: Array[int] = []
var _saved_vehicle: Dictionary = {}
var _source_meshes: Array[MeshInstance3D] = []
var _taken_meshes: Array[MeshInstance3D] = []
var _cargos: Array[Node3D] = []
var _tweens: Array[Tween] = []
var _camera: Camera3D
var _previous_camera: Camera3D
var _camera_focus := Vector3.ZERO
var _orbiting := false
# 回る中心（箱の座標の機体の位置）と、カメラまでの距離・仰角・経度 [rad]
var _orbit_center := Vector3.ZERO
var _orbit_radius := 0.0
var _orbit_elevation := 0.0
var _orbit_azimuth := 0.0
# 部品を見せている間、カメラに対して固定するNadeggと、カメラから見たその位置
var _showcase_actor: Node3D
var _showcase_offset := Transform3D.IDENTITY
var _power_tool: AudioStreamPlayer3D
var _screws: AudioStreamPlayer3D
var _screws_timer := 0.0
var _eye_sparkle: AudioStreamPlayer
var _bgm: AudioStreamPlayer
var _playback_input: Node
var _playback_paused := false
var _leaving_tree := false
var _crowd: Array[Node3D] = []
var _smoke: Node3D
var _smoke_puffs: Array[MeshInstance3D] = []
var _smoke_base_scales: Array[Vector3] = []
var _smoke_elapsed := 0.0
var _comic_labels: Array[Label3D] = []
var _scuffle_word_labels: Dictionary = {}
var _crowd_bounce_tweens: Array[Tween] = []
var _carrier_idle_tweens: Dictionary = {}
var _carrier_idle_states: Dictionary = {}
var _crowd_scuffle_states: Dictionary = {}
var _eye_labels: Array[Node3D] = []
var _eye_pulse_time := 0.0
var _reinforcement_waves := 0
var _departed_carriers: Array[int] = []
var _finishing_scuffle := false
var _gather_start_screens: Array[Vector2] = []
var _wave_start_positions: Array[Vector3] = []
var _retreat_exit_positions: Array[Vector3] = []


func _ready() -> void:
	for actor in get_parent().get_node("SurplusContents/Browsers").get_children():
		_actors.append(actor)
		_actor_rest.append(actor.transform)
		_actor_layers.append(actor.collision_layer)


func _physics_process(_delta: float) -> void:
	if phase != Phase.IDLE or Ending.is_shown():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var bin_id := get_fully_containing_bin(player)
	if bin_id != &"":
		_begin.call_deferred(player, bin_id)


func _process(delta: float) -> void:
	if is_instance_valid(_camera) and is_instance_valid(_bin):
		if _orbiting:
			_orbit_azimuth += deg_to_rad(ORBIT_SPEED_DEG) * delta
			_orbit_radius = move_toward(_orbit_radius, ORBIT_RADIUS, ORBIT_RADIUS_SPEED * delta)
			_camera.global_position = _bin.to_global(_orbit_center + _orbit_offset())
			_camera_focus = _bin.to_global(_orbit_center)
		_camera.look_at(_camera_focus)
		if is_instance_valid(_showcase_actor):
			_showcase_actor.global_transform = _camera.global_transform * _showcase_offset
	if is_instance_valid(_smoke) and not _finishing_scuffle:
		_update_smoke_puffs(delta)
	_update_eye_pulse(delta)
	_update_screws(delta)


func get_fully_containing_bin(body: Node3D) -> StringName:
	if not is_instance_valid(body):
		return &""
	var station := get_parent()
	for bin_id in station.get_surplus_bin_ids_for_body(body):
		var bin: Node3D = station.get_node("SurplusContents/BinContents/" + String(bin_id))
		var area := bin.get_node("Interior") as Area3D
		var shape := area.get_node("CollisionShape3D").shape as BoxShape3D
		var bounds := _body_bounds_in(body, area.global_transform.affine_inverse())
		if bounds.size == Vector3.ZERO:
			continue
		var half := shape.size * 0.5
		var low := bounds.position
		var high := bounds.end
		var chassis_center: Vector3 = area.global_transform.affine_inverse() * body.global_position
		if low.x >= -half.x and high.x <= half.x and low.z >= -half.z and high.z <= half.z \
				and low.y >= -half.y - CONTENTS_TO_BIN_FLOOR - FLOOR_EPSILON \
				and chassis_center.y >= -half.y and high.y <= half.y + RIM_EPSILON:
			return bin_id
	return &""


func _body_bounds_in(body: Node3D, inverse: Transform3D) -> AABB:
	var bounds := AABB()
	var found := false
	for mesh in body.find_children("*", "MeshInstance3D"):
		if mesh.mesh != null and mesh.is_visible_in_tree():
			var box: AABB = inverse * mesh.global_transform * mesh.mesh.get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
	for collision in body.find_children("*", "CollisionShape3D"):
		if collision.get_parent() == body and not collision.disabled and collision.shape != null:
			var box: AABB = inverse * collision.global_transform * collision.shape.get_debug_mesh().get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
	return bounds


func _begin(body: Node3D, bin_id: StringName) -> void:
	if phase != Phase.IDLE or not Ending.begin_salvage_ending(self):
		return
	phase = Phase.GATHERING
	_reinforcement_waves = 0
	_departed_carriers.clear()
	_finishing_scuffle = false
	_gather_start_screens.clear()
	_wave_start_positions.clear()
	_retreat_exit_positions.clear()
	_vehicle = body
	_bin = get_parent().get_node("SurplusContents/BinContents/" + String(bin_id))
	_saved_vehicle = {"process_mode": body.process_mode, "visible": body.visible, "collision_layer": body.collision_layer, "collision_mask": body.collision_mask}
	if body is RigidBody3D:
		_saved_vehicle["freeze"] = body.freeze
		_saved_vehicle["linear_velocity"] = body.linear_velocity
		_saved_vehicle["angular_velocity"] = body.angular_velocity
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
	if body.has_method("cancel_drift"):
		body.cancel_drift()
	body.process_mode = Node.PROCESS_MODE_DISABLED
	for mesh in body.find_children("*", "MeshInstance3D"):
		if mesh.mesh != null and mesh.is_visible_in_tree():
			_source_meshes.append(mesh)
	for actor in _actors:
		actor.collision_layer = 0
	_prepare_ambush()
	_setup_camera()
	var power_tool_stream := POWER_TOOL_SOUND as AudioStreamOggVorbis
	power_tool_stream.loop = true
	_power_tool = AudioStreamPlayer3D.new()
	_power_tool.stream = power_tool_stream
	_power_tool.bus = "SE"
	_power_tool.unit_size = 3.0
	_power_tool.volume_db = POWER_TOOL_VOLUME_DB
	add_child(_power_tool)
	_power_tool.global_position = body.global_position
	_screws = AudioStreamPlayer3D.new()
	_screws.stream = SCREWS_SOUND
	_screws.bus = "SE"
	_screws.unit_size = 3.0
	_screws.max_polyphony = 3
	add_child(_screws)
	_screws.global_position = body.global_position
	_eye_sparkle = AudioStreamPlayer.new()
	_eye_sparkle.stream = EYE_SPARKLE_SOUND
	_eye_sparkle.bus = "SE"
	_eye_sparkle.max_polyphony = 2
	add_child(_eye_sparkle)
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = BGM
	_bgm.bus = "BGM"
	_bgm.volume_db = BGM_VOLUME_DB
	add_child(_bgm)
	_bgm.play()
	_playback_input = PlaybackInput.new()
	_playback_input.director = self
	add_child(_playback_input)
	ControlsHelp.set_salvage_playback(true)
	await _glint()
	if phase != Phase.GATHERING:
		return
	await _gather()
	if phase != Phase.GATHERING:
		return
	phase = Phase.DISMANTLING
	_reinforce()
	await _dismantle()
	if phase != Phase.DISMANTLING:
		return
	await _finish_scuffle()
	body.hide()
	body.collision_layer = 0
	body.collision_mask = 0
	phase = Phase.COMPLETE
	_power_tool.stop()
	_screws.stop()
	_end_playback_controls()
	Ending.complete_salvage_ending(self)


func _setup_camera() -> void:
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.fov = 52.0
	_camera.near = 0.03
	add_child(_camera)
	_camera.global_position = _bin.to_global(Vector3(1.45, 1.10, -1.45))
	_camera_focus = _bin.to_global(Vector3(0, 0.10, 0))
	_camera.look_at(_camera_focus)
	_camera.make_current()


func _glint() -> void:
	# それぞれ別のNadeggを、機体の側面/タイヤと上面フレーム越しに見る。
	# 最初のカット: 箱に入った機体を斜め上から見下ろし、経度を回して右へ回り込む。_process で毎フレーム機体を向き直すので、視点は機体のまま。
	var vehicle_in_bin := _bin.to_local(_vehicle.global_position)
	_cut_camera(vehicle_in_bin + _overhead_offset(0.0), vehicle_in_bin, 50.0)
	var overhead := create_tween()
	_tweens.append(overhead)
	overhead.tween_method(_orbit_overhead.bind(vehicle_in_bin), 0.0, deg_to_rad(OVERHEAD_ORBIT_DEG), OVERHEAD_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await overhead.finished
	if phase != Phase.GATHERING:
		return
	var first_actor := _actors[2]
	var second_actor := _actors[0]
	first_actor.global_position = _bin.to_global(Vector3(0.91, 0.70, -0.27))
	first_actor.rotation.z = 0.0
	first_actor.rotation.x = 0.0
	var first_eyes := _eye_labels[2]
	var second_eyes := _eye_labels[0]
	_set_eye_scale(1.0, first_eyes)
	# 1カット目: 機体の横から、縁のNadeggの目に寄って大きく見せる。
	var first_pitch := _place_glint_camera(first_eyes, Vector3.LEFT, 24.0)
	# 上から撮るカメラに顔を向ける。
	first_actor.rotation.x = deg_to_rad(first_pitch)
	_face_toward(first_actor, _camera.global_position)
	_focus_on_eyes(first_eyes, 24.0)
	_eye_sparkle.play()
	var first_glint := create_tween()
	_tweens.append(first_glint)
	first_glint.tween_method(_set_eye_scale.bind(first_eyes), 1.0, 1.35, 0.18).set_trans(Tween.TRANS_BACK)
	first_glint.tween_method(_set_eye_scale.bind(first_eyes), 1.35, 1.15, 0.14)
	await first_glint.finished
	await get_tree().create_timer(0.33, false).timeout
	# 2カット目: 緑の棚の前の別個体に寄って、反対側から見る。
	first_eyes.hide()
	second_actor.global_position = _bin.to_global(Vector3(-0.91, 0.80, -0.27))
	second_actor.rotation.x = 0.0
	second_eyes.show()
	var second_pitch := _place_glint_camera(second_eyes, Vector3.RIGHT, 26.0)
	_face_toward(second_actor, _camera.global_position)
	var facing_camera := second_actor.rotation.y
	# 緑の棚のPCなどを物色していた個体が、機体に気づいて振り向いてから目を光らせる。
	second_actor.rotation.y = facing_camera + PI
	_focus_on_eyes(second_eyes, 26.0)
	_set_eye_scale(1.0, second_eyes)
	var turn := create_tween()
	_tweens.append(turn)
	turn.tween_interval(0.35)
	turn.tween_property(second_actor, "rotation:y", facing_camera, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn.parallel().tween_property(second_actor, "rotation:x", deg_to_rad(second_pitch), 0.32)
	await turn.finished
	if phase != Phase.GATHERING:
		return
	_eye_sparkle.play()
	var second_glint := create_tween()
	_tweens.append(second_glint)
	second_glint.tween_method(_set_eye_scale.bind(second_eyes), 1.0, 1.8, 0.20).set_trans(Tween.TRANS_BACK)
	second_glint.tween_method(_set_eye_scale.bind(second_eyes), 1.8, 1.5, 0.14)
	await second_glint.finished
	await get_tree().create_timer(0.40, false).timeout
	# 群がりのカットから注視点を機体にしておき、回り始めで視点が飛ばないようにする。
	_cut_camera(Vector3(1.45, 1.10, -1.45), _bin.to_local(_vehicle.global_position), 52.0)
	await get_tree().create_timer(0.08, false).timeout


func _cut_camera(position_in_bin: Vector3, focus_in_bin: Vector3, fov: float) -> void:
	_camera.global_position = _bin.to_global(position_in_bin)
	_camera_focus = _bin.to_global(focus_in_bin)
	_camera.fov = fov
	_camera.look_at(_camera_focus)


# 目の位置にカメラを向け、画角を絞ってNadeggを大きく見せる。
func _focus_on_eyes(eyes: Node3D, fov: float) -> void:
	_camera_focus = eyes.global_position
	_camera.fov = fov
	_camera.look_at(_camera_focus)


# 目を光らせる個体の頭を、機体にめり込まず、機体に遮られない位置から撮る。toward は箱の座標で、頭から見て箱の内側の向き。使った見上げる角度 [度] を返す。
func _place_glint_camera(eyes: Node3D, toward: Vector3, fov: float) -> float:
	var head := _bin.to_local(eyes.global_position)
	var vehicle: AABB = _body_bounds_in(_vehicle, _bin.global_transform.affine_inverse())
	var base := atan2(toward.x, toward.z)
	var camera := head
	for elevation: float in GLINT_CAMERA_ELEVATIONS:
		for turn: float in GLINT_CAMERA_TURNS:
			var azimuth := base + deg_to_rad(turn)
			var pitch := deg_to_rad(elevation)
			camera = head + Vector3(sin(azimuth) * cos(pitch), sin(pitch), cos(azimuth) * cos(pitch)) * GLINT_CAMERA_DISTANCE
			if not vehicle.grow(0.1).has_point(camera) and vehicle.grow(0.03).intersects_segment(camera, head) == null:
				_cut_camera(camera, head, fov)
				return elevation
	# どの候補も遮られるときは、いちばん高い位置から撮る。
	_cut_camera(camera, head, fov)
	return GLINT_CAMERA_ELEVATIONS[-1]


# 経度 azimuth [rad] での、機体から見た最初のカットのカメラの位置（箱の座標）。経度 0 は箱の +Z 側。
func _overhead_offset(azimuth: float) -> Vector3:
	var elevation := deg_to_rad(OVERHEAD_ELEVATION_DEG)
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * OVERHEAD_DISTANCE


func _orbit_overhead(azimuth: float, center_in_bin: Vector3) -> void:
	_camera.global_position = _bin.to_global(center_in_bin + _overhead_offset(azimuth))


# 今のカメラの位置から、機体を中心に回り始める。距離と仰角はそのまま保つ。
func _start_orbit() -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_vehicle):
		return
	_orbit_center = _bin.to_local(_vehicle.global_position)
	var offset := _bin.to_local(_camera.global_position) - _orbit_center
	_orbit_radius = offset.length()
	_orbit_elevation = asin(clampf(offset.y / maxf(_orbit_radius, 0.001), -1.0, 1.0))
	_orbit_azimuth = atan2(offset.x, offset.z)
	_orbiting = true


# 回っているカメラの、機体から見た位置（箱の座標）
func _orbit_offset() -> Vector3:
	return Vector3(sin(_orbit_azimuth) * cos(_orbit_elevation), sin(_orbit_elevation), cos(_orbit_azimuth) * cos(_orbit_elevation)) * _orbit_radius


func _gather() -> void:
	# 二つのカットで目を光らせた個体が順番に飛びかかり、その途中から残りが続く。
	_eye_labels[2].show()
	_actors[2].rotation.x = 0.0
	_face_toward(_actors[2], _vehicle.global_position)
	var first := create_tween().set_parallel(true)
	_tweens.append(first)
	_tween_hop(first, _actors[2], _gather_position(2), 0.7, 0.46)
	first.finished.connect(_start_carrier_idle.bind(_actors[2], 2))
	first.finished.connect(_start_salvage_sounds)
	await get_tree().create_timer(0.32, false).timeout
	if phase != Phase.GATHERING:
		return
	_actors[0].rotation.x = 0.0
	_face_toward(_actors[0], _vehicle.global_position)
	var second := create_tween().set_parallel(true)
	_tweens.append(second)
	_tween_hop(second, _actors[0], _gather_position(0), 0.62, 0.42)
	second.finished.connect(_start_carrier_idle.bind(_actors[0], 0))
	await get_tree().create_timer(0.13, false).timeout
	if phase != Phase.GATHERING:
		return
	var swarm := create_tween().set_parallel(true)
	_tweens.append(swarm)
	_eye_labels[1].show()
	_face_toward(_actors[1], _vehicle.global_position)
	_tween_hop(swarm, _actors[1], _gather_position(1), 1.05, 0.65)
	swarm.finished.connect(_start_carrier_idle.bind(_actors[1], 1))
	var camera_move := create_tween()
	_tweens.append(camera_move)
	camera_move.tween_property(_camera, "global_position", _bin.to_global(Vector3(1.6, 1.55, -1.75)), 1.15)
	camera_move.finished.connect(_start_orbit)
	# 各個体を飛び込み直前に画面外へ配置する。カメラ移動中も出現点が画面内へ入らない。
	var launch_gaps := [0.0, 0.13, 0.17, 0.10, 0.20, 0.12, 0.18, 0.11, 0.16]
	var last_arrival: Tween
	for i in INITIAL_NADEGG_COUNT:
		if launch_gaps[i] > 0.0:
			await get_tree().create_timer(launch_gaps[i], false).timeout
		if phase != Phase.GATHERING:
			return
		var angle := float(i) * TAU / float(INITIAL_NADEGG_COUNT)
		var target := _vehicle_offset(Vector3(cos(angle) * 0.45, 0.04, sin(angle) * 0.32))
		_crowd[i].global_position = _offscreen_position(target, i)
		_gather_start_screens.append(_camera.unproject_position(_crowd[i].global_position))
		_face_toward(_crowd[i], target)
		_crowd[i].show()
		last_arrival = create_tween()
		_tweens.append(last_arrival)
		_tween_hop(last_arrival, _crowd[i], target, 0.9, 0.45)
		if i < 6:
			last_arrival.finished.connect(_start_carrier_idle.bind(_crowd[i], i + 3))
		if i == 2:
			last_arrival.finished.connect(_start_smoke_after_third_arrival)
	await last_arrival.finished
	if phase != Phase.GATHERING:
		return
	_start_crowd_bounce()


func _start_smoke_after_third_arrival() -> void:
	if phase == Phase.GATHERING and not is_instance_valid(_smoke):
		_start_smoke()


func _reinforce() -> void:
	# 部品が運び出されている間も、別のNadeggが二体ずつ箱へ飛び込む。
	for wave in REINFORCEMENT_WAVES:
		await get_tree().create_timer(1.05, false).timeout
		if phase != Phase.DISMANTLING:
			return
		var arrivals := create_tween().set_parallel(true)
		_tweens.append(arrivals)
		for lane in 2:
			var index := INITIAL_NADEGG_COUNT + wave * 2 + lane
			var actor := _crowd[index]
			var angle := float(index - INITIAL_NADEGG_COUNT) * 2.39996
			var target := _vehicle_offset(Vector3(cos(angle) * 0.78, 0.12, sin(angle) * 0.43))
			actor.global_position = _offscreen_position(target, index)
			_wave_start_positions.append(actor.global_position)
			_face_toward(actor, target)
			actor.show()
			_tween_hop(arrivals, actor, target, 0.88, 0.58, float(lane) * 0.12)
		arrivals.finished.connect(_start_bounce_after_arrival.bind(INITIAL_NADEGG_COUNT + wave * 2))
		_reinforcement_waves += 1


func _start_bounce_after_arrival(first_index: int) -> void:
	if phase != Phase.DISMANTLING or _finishing_scuffle:
		return
	for lane in 2:
		_start_crowd_bounce_for(_crowd[first_index + lane])


func _prepare_ambush() -> void:
	# 普段の三体はそのまま残し、ED中だけ追加のNadeggを出す。
	for i in EXTRA_NADEGG_COUNT:
		var actor := _actors[0].duplicate() as Node3D
		actor.name = "SalvageNadegg%02d" % i
		# 常設個体と同じ座標系に置き、顔の回転軸を上方向に揃える。
		_actors[0].get_parent().add_child(actor)
		actor.global_position = _vehicle.global_position
		_face_toward(actor, _vehicle.global_position)
		actor.collision_layer = 0
		actor.collision_mask = 0
		actor.hide()
		_crowd.append(actor)
	var eye_quad := QuadMesh.new()
	eye_quad.size = EYE_SIZE
	for actor in _actors + _crowd:
		var eyes := Node3D.new()
		eyes.name = "MischievousEyes"
		# 黄色い頭部の前面に星形画像の板を接して置き、横からは頭部自身の深度で隠す。
		eyes.position = NADEGG_HEAD_CENTER
		actor.add_child(eyes)
		for x in [-0.0264, 0.0264]:
			var glint := MeshInstance3D.new()
			glint.name = "LeftEye" if x < 0 else "RightEye"
			glint.mesh = eye_quad
			# 左右の目を同じ向きにそろえ、顔の正面（-Z）に向けて地面に垂直に立てる。
			# 頭の一番前に接する面に置き、板の角が頭にめり込まないようにする。
			var surface := _eye_forward(x) * (NADEGG_HEAD_RADIUS + EYE_SURFACE_OFFSET)
			glint.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(surface.x, surface.y, -(NADEGG_HEAD_RADIUS + EYE_SURFACE_OFFSET)))
			var material := StandardMaterial3D.new()
			material.albedo_texture = EYE_GLINT
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.2
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			material.no_depth_test = false
			glint.material_override = material
			eyes.add_child(glint)
		_set_eye_scale(1.0, eyes)
		_eye_labels.append(eyes)
	_eye_labels[0].hide()
	_eye_labels[1].hide()


func _set_eye_scale(size: float, eyes: Node3D) -> void:
	eyes.set_meta("eye_scale", size)
	var pulse := 1.0 + EYE_PULSE_AMOUNT * sin(TAU * _eye_pulse_time / EYE_PULSE_PERIOD)
	for glint in eyes.get_children():
		glint.scale = Vector3.ONE * pulse * size


func _eye_forward(x: float) -> Vector3:
	return Vector3(x, 0.015, -sqrt(NADEGG_HEAD_RADIUS * NADEGG_HEAD_RADIUS - x * x - 0.015 * 0.015)).normalized()


# 見えている目を、全体が大きくなったり小さくなったりするように動かす。
func _update_eye_pulse(delta: float) -> void:
	_eye_pulse_time += delta
	for eyes in _eye_labels:
		if is_instance_valid(eyes) and eyes.is_visible_in_tree():
			_set_eye_scale(float(eyes.get_meta("eye_scale")), eyes)


# 一体目が機体に着いたところから、電動ドライバとねじの音を流す。
func _start_salvage_sounds() -> void:
	if phase != Phase.GATHERING and phase != Phase.DISMANTLING:
		return
	if not is_instance_valid(_power_tool) or _power_tool.playing:
		return
	_power_tool.play()
	_screws_timer = 0.0


# 群がっている間（電動ドライバの音が鳴っている間）、ねじの音を少しずつ高さを変えてランダムな間隔で鳴らす。
func _update_screws(delta: float) -> void:
	if not is_instance_valid(_power_tool) or not _power_tool.playing or not is_instance_valid(_screws):
		return
	_screws_timer -= delta
	if _screws_timer <= 0.0:
		_screws.pitch_scale = randf_range(0.9, 1.1)
		_screws.play()
		_screws_timer = randf_range(SCREWS_INTERVAL_MIN, SCREWS_INTERVAL_MAX)


func _face_toward(actor: Node3D, target: Vector3) -> void:
	var parent := actor.get_parent() as Node3D
	var direction: Vector3 = parent.to_local(target) - actor.position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		# Nadeggの顔はローカル -Z。棚前での傾きは維持する。
		actor.rotation.y = atan2(-direction.x, -direction.z)


func _start_smoke() -> void:
	_smoke = Node3D.new()
	_smoke.name = "ComicScuffleSmoke"
	add_child(_smoke)
	_smoke.global_position = _vehicle.global_position + Vector3.UP * 0.15
	# 不透明なので、分解中のカメラ（機体から約2.75m）が煙の中に入らない大きさにする。
	_smoke.scale = Vector3(2.0, 1.93, 2.0)
	_smoke_puffs.clear()
	_smoke_base_scales.clear()
	_smoke_elapsed = 0.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# 煙は不透明にし、大きさの変化だけで現れたり消えたりさせる。
	material.albedo_color = Color(0.97, 0.96, 0.90)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	for i in 12:
		var puff := MeshInstance3D.new()
		puff.name = "Puff%02d" % i
		puff.mesh = ball
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := float(i) * 2.39996
		var ring := 0.11 + float(i % 5) * 0.065
		puff.position = Vector3(cos(angle) * ring, float(i % 4) * 0.09, sin(angle) * ring * 0.75)
		var radius := 0.24 + float(i % 4) * 0.05
		puff.scale = Vector3(radius, radius * 0.8, radius)
		_smoke.add_child(puff)
		_smoke_puffs.append(puff)
		_smoke_base_scales.append(puff.scale)
	# 手前の煙は一時停止し、奥側の個別の煙球を調整する。
	var foreground := Node3D.new()
	foreground.name = "ForegroundPuffs"
	_smoke.add_child(foreground)
	foreground.hide()
	var toward_camera := (_camera.global_position - _vehicle.global_position).normalized()
	foreground.position = _smoke.to_local(_smoke.global_position + toward_camera * 0.18)
	foreground.scale = Vector3.ONE * 0.25
	var foreground_material := material.duplicate() as StandardMaterial3D
	var right := _camera.global_basis.x
	var up := _camera.global_basis.y
	for i in 6:
		var front_puff := MeshInstance3D.new()
		front_puff.name = "ForegroundPuff%02d" % i
		front_puff.mesh = ball
		front_puff.material_override = foreground_material
		front_puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var column := float(i % 3 - 1)
		var row := float(i / 3)
		front_puff.position = _smoke.to_local(_smoke.global_position + right * column * 0.24 + up * (row - 0.5) * 0.20) - _smoke.to_local(_smoke.global_position)
		front_puff.scale = Vector3(0.28, 0.28, 0.28)
		foreground.add_child(front_puff)
	_update_smoke_puffs(0.0)


func _update_smoke_puffs(delta: float) -> void:
	_smoke_elapsed += delta
	for i in _smoke_puffs.size():
		var puff := _smoke_puffs[i]
		var duration := 1.25 + float((i * 7) % 5) * 0.14
		var phase := fposmod(_smoke_elapsed / duration + float(i) * 0.618034, 1.0)
		# 小さい状態から一気にふくらんで現れ、各自の速さで縮んで消える。
		var grow := smoothstep(0.0, 0.20, phase)
		puff.scale = _smoke_base_scales[i] * maxf(grow * lerpf(1.3, 0.06, pow(phase, 1.2)), 0.01)


func _show_comic_word(word: String, offset: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = word
	label.font = COMIC_FONT
	label.font_size = 34
	label.pixel_size = 0.0032
	label.modulate = Color(0.10, 0.08, 0.08)
	label.outline_modulate = Color(1, 1, 1)
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)
	label.global_position = _vehicle.global_position + offset
	_comic_labels.append(label)
	return label


func _hide_comic_word(label: Label3D) -> void:
	if not is_instance_valid(label):
		return
	_comic_labels.erase(label)
	label.hide()
	label.queue_free()


func _clear_comic_words() -> void:
	for label in _comic_labels.duplicate():
		_hide_comic_word(label)
	_scuffle_word_labels.clear()


func _start_crowd_bounce() -> void:
	# 運搬担当は着地時から別の待機動作を行い、ここでは追加の群れだけ跳ねる。
	for i in range(6, INITIAL_NADEGG_COUNT):
		_start_crowd_bounce_for(_crowd[i])


func _start_carrier_idle(actor: Node3D, index: int) -> void:
	if phase != Phase.GATHERING and phase != Phase.DISMANTLING:
		return
	var center := actor.global_position
	_carrier_idle_states[actor] = {"center": center, "index": index, "step": 0}
	var tween := create_tween().set_loops()
	_tweens.append(tween)
	_carrier_idle_tweens[actor] = tween
	tween.tween_interval(0.43 + float(index % 3) * 0.10)
	tween.tween_callback(_teleport_idle_carrier.bind(actor))


func _carrier_idle_target(center: Vector3, index: int, step: int) -> Vector3:
	var angle := float((index * 13 + step * 17) % 41) * TAU / 41.0
	var radius := 0.25 + float((index * 3 + step * 7) % 5) * 0.065
	return _inside_bin_scuffle(center + _bin.global_basis * Vector3(cos(angle) * radius, 0.0, sin(angle) * radius * 0.85))


func _teleport_idle_carrier(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not _carrier_idle_states.has(actor):
		return
	var state: Dictionary = _carrier_idle_states[actor]
	state["step"] += 1
	actor.global_position = _carrier_idle_target(state["center"], state["index"], state["step"])


func _stop_carrier_idle(actor: Node3D) -> void:
	if not _carrier_idle_tweens.has(actor):
		return
	var tween: Tween = _carrier_idle_tweens[actor]
	if tween.is_valid():
		tween.kill()
	_carrier_idle_tweens.erase(actor)
	_carrier_idle_states.erase(actor)


func _start_crowd_bounce_for(actor: Node3D) -> void:
	var index := _crowd.find(actor)
	_crowd_scuffle_states[actor] = {"index": index, "step": 0}
	var tween := create_tween().set_loops()
	_tweens.append(tween)
	_crowd_bounce_tweens.append(tween)
	tween.tween_interval(0.38 + float(index % 4) * 0.11)
	tween.tween_callback(_teleport_scuffling_actor.bind(actor))


func _scuffle_target(index: int, step: int) -> Vector3:
	var angle := float((index * 11 + step * 19) % 47) * TAU / 47.0
	var radius := 0.42 + float((index * 7 + step * 13) % 7) * 0.12
	return _inside_bin_scuffle(_vehicle_offset(Vector3(cos(angle) * radius, 0.05, sin(angle) * radius * 0.75)))


func _inside_bin_scuffle(position: Vector3) -> Vector3:
	# 青箱の内側から縁付近まで使い、瞬間移動先の中心は箱内に保つ。
	var local := _bin.to_local(position)
	local.x = clampf(local.x, -0.82, 0.82)
	local.z = clampf(local.z, -0.42, 0.42)
	return _bin.to_global(local)


func _teleport_scuffling_actor(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not _crowd_scuffle_states.has(actor):
		return
	var state: Dictionary = _crowd_scuffle_states[actor]
	state["step"] += 1
	var target_step: int = state["step"] + 9 if (state["index"] + state["step"]) % 5 == 0 else state["step"]
	actor.global_position = _scuffle_target(state["index"], target_step)
	# 文字の切り替えはこの個体自身の瞬間移動と同じフレームで行う。
	if SCUFFLE_WORDS.has(state["index"]):
		if _scuffle_word_labels.has(actor):
			_hide_comic_word(_scuffle_word_labels[actor])
			_scuffle_word_labels.erase(actor)
		else:
			_scuffle_word_labels[actor] = _show_comic_word(SCUFFLE_WORDS[state["index"]], SCUFFLE_WORD_OFFSETS[state["index"]])


func _gather_position(index: int) -> Vector3:
	var offsets := [Vector3(-0.45, 0, -0.18), Vector3(0.45, 0, -0.18), Vector3(0, 0, 0.43)]
	return _vehicle_offset(offsets[index])


func _vehicle_offset(offset: Vector3) -> Vector3:
	return _vehicle.global_position + _bin.global_basis * offset


func _offscreen_position(target: Vector3, index: int) -> Vector3:
	# 投影面で左右交互に画面外へ置く。余白はNadegg本体と十字目の幅を含む。
	var size := get_viewport().get_visible_rect().size
	var projected := _camera.unproject_position(target)
	var edge_x := -180.0 if index % 2 == 0 else size.x + 180.0
	var edge_y := clampf(projected.y, size.y * 0.2, size.y * 0.8)
	var depth := maxf(0.5, -_camera.global_basis.z.dot(target - _camera.global_position))
	return _camera.project_position(Vector2(edge_x, edge_y), depth)


func _tween_hop(tween: Tween, actor: Node3D, target: Vector3, duration: float, height: float, delay := 0.0) -> void:
	var start := actor.global_position
	tween.tween_method(func(weight: float):
		if is_instance_valid(actor):
			actor.global_position = start.lerp(target, weight) + Vector3.UP * sin(weight * PI) * height
	, 0.0, 1.0, duration).set_delay(delay)


func _dismantle() -> void:
	# 5種類を別個体が一度ずつ提示する。車体側は全メッシュを取り外す。
	var carriers: Array[Node3D] = []
	carriers.append_array(_actors)
	for i in 2:
		carriers.append(_crowd[i])
	var salvage_groups := _select_salvage_parts()
	var display_parts := _select_showcase_parts(salvage_groups)
	var batches: Array[Array] = []
	for i in salvage_groups.size():
		batches.append([])
	var selected := {}
	for i in salvage_groups.size():
		for part: MeshInstance3D in salvage_groups[i]:
			batches[i].append(part)
			selected[part] = true
	var remaining_index := 0
	for source in _source_meshes:
		if not selected.has(source):
			# 結合済みの小物も少しずつ消す。フレーム二本は最後にまとめて外す。
			batches[remaining_index % batches.size()].append(source)
			remaining_index += 1
	for i in salvage_groups.size():
		var actor := carriers[i]
		_stop_carrier_idle(actor)
		var cargo := _make_cargo(batches[i], display_parts[i])
		if phase != Phase.DISMANTLING:
			return
		# 実車部品を画面の真ん中に置き、Nadeggは部品の横（左右交互）に寄せて、カメラ前で静止して提示する。
		var back := _camera.global_basis.z.normalized()
		var up := _camera.global_basis.y.normalized()
		var showcase_center := _camera.global_position - back * 0.60 - up * 0.04
		actor.global_position = showcase_center
		_face_toward(actor, _camera.global_position)
		cargo.reparent(actor, true)
		cargo.position = Vector3(0.24 if i % 2 == 0 else -0.24, 0.04, -0.02)
		# 横へずらした位置からカメラを向き直す。向きを変えると持っている部品も回るので、部品が真ん中に来るよう位置を合わせ直すのを数回繰り返す。
		for adjust in 3:
			actor.global_position = showcase_center - actor.global_basis * cargo.position
			_face_toward(actor, _camera.global_position)
		actor.global_position = showcase_center - actor.global_basis * cargo.position
		# 回るカメラに合わせて、見せている間は画面の同じ位置に留める。
		_showcase_actor = actor
		_showcase_offset = _camera.global_transform.affine_inverse() * actor.global_transform
		await get_tree().create_timer(1.05, false).timeout
		_showcase_actor = null
		if phase != Phase.DISMANTLING:
			return
		_complete_carrier_exit(actor, cargo)


func _select_salvage_parts() -> Array[Array]:
	# タイヤ4本、計算機、電池ケース、距離センサー、左右のフレーム材を5種類にまとめる。
	# car.gd の実ホイール設定を使い、モデルごとに別のメッシュを選ぶ。
	var groups: Array[Array] = []
	for i in 5:
		groups.append([])
	var visual_wheels: Array = _vehicle.get("_visual_wheels")
	for i in mini(4, visual_wheels.size()):
		for part: Dictionary in visual_wheels[i]["parts"]:
			var node: MeshInstance3D = part["node"]
			if _source_meshes.has(node):
				groups[0].append(node)
	var neo: bool = _vehicle.get("robot_key") == "neo"
	for source in _source_meshes:
		var path := String(_vehicle.get_path_to(source))
		if neo:
			if path.contains("/Orin_nano_case_main_No_CAN_No inserts v6_1/") \
					or (path.contains("/P3766-P3768SKU4-P3767ENVELOPE v4_1/") \
					and source.name in [&"Body1_718", &"Body1_078", &"Body1_064"]):
				groups[1].append(source)
			elif path.contains("/BATTERY_COVER_12V v11_1/") and source.name in [&"Battery_Top", &"Battery_Bottom"]:
				groups[2].append(source)
			elif path.contains("/mid-360-asm v5_1/"):
				groups[3].append(source)
			elif path.contains("/HFSF6-3060-598-X8-AH16-BH582 v1_1/"):
				groups[4].append(source)
			elif path.contains("/HFSF6-3060-598-X8-AH16-BH582 v1(Mirror)_1/"):
				groups[4].append(source)
		else:
			if path.contains("/N100DC-ITX v7_1/"):
				groups[1].append(source)
			elif source.name.begins_with("Battery_Case_Right_12V7_2Ah"):
				groups[2].append(source)
			elif path.contains("/Livox Mid-70 3D Model and FOV Shape v4_1/"):
				groups[3].append(source)
			elif path.ends_with("/MainFrame - Reverse Prototype v12/Body5"):
				groups[4].append(source)
			elif path.ends_with("/MainFrame - Reverse Prototype v12/Body6"):
				groups[4].append(source)
	for i in groups.size():
		assert(not groups[i].is_empty(), "ED3の実車部品が見つかりません: %s/%d" % [_vehicle.get("robot_key"), i])
	return groups


func _select_showcase_parts(groups: Array[Array]) -> Array[Array]:
	# 同種の実物は一つだけ見せる。車輪は一本分、フレームは片側だけを複製する。
	var displays: Array[Array] = []
	var first_wheel: Array = []
	var visual_wheels: Array = _vehicle.get("_visual_wheels")
	for part: Dictionary in visual_wheels[0]["parts"]:
		var node: MeshInstance3D = part["node"]
		if groups[0].has(node):
			first_wheel.append(node)
	displays.append(first_wheel)
	for i in range(1, 4):
		displays.append(groups[i])
	var first_frame: Array = []
	for source: MeshInstance3D in groups[4]:
		var path := String(_vehicle.get_path_to(source))
		if path.contains("/HFSF6-3060-598-X8-AH16-BH582 v1_1/") or path.ends_with("/MainFrame - Reverse Prototype v12/Body5"):
			first_frame.append(source)
	displays.append(first_frame)
	assert(not displays[0].is_empty() and not displays[4].is_empty())
	return displays

func _complete_carrier_exit(actor: Node3D, cargo: Node3D) -> void:
	if not is_instance_valid(actor):
		return
	actor.hide()
	_departed_carriers.append(actor.get_instance_id())
	if is_instance_valid(cargo):
		cargo.hide()
		cargo.queue_free()


func _make_cargo(meshes: Array, display_parts: Array) -> Node3D:
	var cargo := Node3D.new()
	cargo.name = "SalvagedParts"
	add_child(cargo)
	cargo.global_transform = Transform3D(Basis.IDENTITY, _vehicle.global_position)
	_cargos.append(cargo)
	for source: MeshInstance3D in meshes:
		source.hide()
		_taken_meshes.append(source)
	_add_real_part(cargo, display_parts)
	return cargo


func _add_real_part(cargo: Node3D, display_parts: Array) -> void:
	# 車体上で隣り合う元メッシュを、相対位置とマテリアルごと縮小して運ぶ。
	var vehicle_inverse := _vehicle.global_transform.affine_inverse()
	var bounds := AABB()
	var found := false
	for source: MeshInstance3D in display_parts:
		var local_transform := vehicle_inverse * source.global_transform
		var box := local_transform * source.mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	assert(found)
	var max_size := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var display_scale := 0.30 / maxf(max_size, 0.01)
	var display_transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * display_scale), -bounds.get_center() * display_scale)
	for source: MeshInstance3D in display_parts:
		var part := MeshInstance3D.new()
		part.name = "SalvagedVehicleMesh"
		part.mesh = source.mesh
		part.material_override = source.material_override
		for surface in part.mesh.get_surface_count():
			part.set_surface_override_material(surface, source.get_surface_override_material(surface))
		part.transform = display_transform * vehicle_inverse * source.global_transform
		cargo.add_child(part)


func _finish_scuffle() -> void:
	_finishing_scuffle = true
	for idle: Tween in _carrier_idle_tweens.values():
		if idle.is_valid():
			idle.kill()
	_carrier_idle_tweens.clear()
	_carrier_idle_states.clear()
	for bounce in _crowd_bounce_tweens:
		if bounce.is_valid():
			bounce.kill()
	_crowd_bounce_tweens.clear()
	_crowd_scuffle_states.clear()
	var clear := create_tween().set_parallel(true)
	_tweens.append(clear)
	if is_instance_valid(_smoke):
		clear.tween_property(_smoke, "scale", Vector3(0.05, 0.05, 0.05), 0.55)
	_retreat_exit_positions.clear()
	for i in _crowd.size():
		if not _crowd[i].visible:
			continue
		var exit_point := _offscreen_position(_crowd[i].global_position, i)
		_retreat_exit_positions.append(exit_point)
		clear.tween_property(_crowd[i], "global_position", exit_point, 0.55)
	await clear.finished
	_clear_swarm()


# 追加のNadegg・煙・漫画文字・目を片付ける。
func _clear_swarm() -> void:
	for actor in _crowd:
		if is_instance_valid(actor):
			actor.queue_free()
	_crowd.clear()
	if is_instance_valid(_smoke):
		_smoke.queue_free()
	_smoke_puffs.clear()
	_smoke_base_scales.clear()
	_clear_comic_words()
	for eyes in _eye_labels:
		if is_instance_valid(eyes):
			eyes.queue_free()
	_eye_labels.clear()


func is_playback_paused() -> bool:
	return _playback_paused


# ED3 の再生を一時停止・再開する。ゲーム全体を止めるので、待ち時間・アニメーション・音も止まる。
func toggle_playback_pause() -> void:
	if phase != Phase.GATHERING and phase != Phase.DISMANTLING:
		return
	_playback_paused = not _playback_paused
	get_tree().paused = _playback_paused


# 再生中の演出を止めて片付け、最後の BAD END の表示まで飛ばす。BGM は流したままにする。
# 待っている途中の処理は、phase が変わったのを見て抜けるか、止めたアニメーションの終わりを待ったまま進まない。
func skip_to_bad_end() -> void:
	if phase != Phase.GATHERING and phase != Phase.DISMANTLING:
		return
	phase = Phase.COMPLETE
	_showcase_actor = null
	_finishing_scuffle = true
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	for idle: Tween in _carrier_idle_tweens.values():
		if idle.is_valid():
			idle.kill()
	_carrier_idle_tweens.clear()
	_carrier_idle_states.clear()
	for bounce in _crowd_bounce_tweens:
		if bounce.is_valid():
			bounce.kill()
	_crowd_bounce_tweens.clear()
	_crowd_scuffle_states.clear()
	for player in [_power_tool, _screws, _eye_sparkle]:
		if is_instance_valid(player):
			player.stop()
	for cargo in _cargos:
		if is_instance_valid(cargo):
			cargo.queue_free()
	_cargos.clear()
	for mesh in _source_meshes:
		if is_instance_valid(mesh):
			mesh.hide()
	_taken_meshes = _source_meshes.duplicate()
	for actor in _actors:
		actor.hide()
	_clear_swarm()
	_camera.global_position = _bin.to_global(Vector3(1.8, 1.75, -1.75))
	_camera.fov = 52.0
	_start_orbit()
	_camera_focus = _bin.to_global(_orbit_center)
	_camera.look_at(_camera_focus)
	_vehicle.hide()
	_vehicle.collision_layer = 0
	_vehicle.collision_mask = 0
	_end_playback_controls()
	Ending.complete_salvage_ending(self)


# 一時停止とスキップの入力を片付け、一時停止していたら再開する。
func _end_playback_controls() -> void:
	ControlsHelp.set_salvage_playback(false)
	if is_instance_valid(_playback_input):
		_playback_input.queue_free()
	_playback_input = null
	if _playback_paused:
		_playback_paused = false
		get_tree().paused = false


func get_remaining_part_count() -> int:
	return _source_meshes.size() - _taken_meshes.size()


func restore_after_ending() -> void:
	_orbiting = false
	_showcase_actor = null
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_carrier_idle_tweens.clear()
	_carrier_idle_states.clear()
	_crowd_scuffle_states.clear()
	if _leaving_tree:
		return
	for cargo in _cargos:
		if is_instance_valid(cargo):
			cargo.queue_free()
	_cargos.clear()
	for actor in _crowd:
		if is_instance_valid(actor):
			actor.queue_free()
	_crowd.clear()
	_departed_carriers.clear()
	_reinforcement_waves = 0
	if is_instance_valid(_smoke):
		_smoke.queue_free()
	_smoke_puffs.clear()
	_smoke_base_scales.clear()
	_clear_comic_words()
	for eyes in _eye_labels:
		if is_instance_valid(eyes):
			eyes.queue_free()
	_eye_labels.clear()
	for mesh in _taken_meshes:
		if is_instance_valid(mesh):
			mesh.show()
	_taken_meshes.clear()
	_source_meshes.clear()
	for i in _actors.size():
		_actors[i].transform = _actor_rest[i]
		_actors[i].collision_layer = _actor_layers[i]
	if is_instance_valid(_vehicle):
		for property in _saved_vehicle:
			_vehicle.set(property, _saved_vehicle[property])
	_saved_vehicle.clear()
	if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
		_previous_camera.make_current()
	if is_instance_valid(_camera):
		_camera.queue_free()
	for player in [_power_tool, _screws, _eye_sparkle, _bgm]:
		if is_instance_valid(player):
			player.queue_free()
	_end_playback_controls()
	phase = Phase.IDLE


func _exit_tree() -> void:
	_leaving_tree = true
	Ending.cancel_salvage_ending(self)

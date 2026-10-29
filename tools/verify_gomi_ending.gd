extends SceneTree

# 実行: Godot --path . --script res://tools/verify_gomi_ending.gd
# 画像が必要なら -- --screenshots=res://tmp/gomi を付ける。
const STAGE := "res://tests/gomi_ending_stage.tscn"
var _screenshot_dir := ""
var _run_model := "neo"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			_screenshot_dir = arg.trim_prefix("--screenshots=")
		if arg == "--robot=classic":
			_run_model = "classic"
	create_timer(90.0).timeout.connect(func():
		push_error("ED3検証が完了しませんでした")
		quit(1)
	)
	call_deferred("_verify")


func _verify() -> void:
	if not _screenshot_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_screenshot_dir))
	root.size = Vector2i(1000,650)
	var menu := root.get_node("GameMenu")
	menu.robot_model = "neo"
	var warmup := root.get_node("ShaderWarmup")
	warmup.set("_done", true)
	warmup.set_process(false)
	warmup.get("_screen").hide()
	var ending := root.get_node("Ending")
	var stage: Node3D = load(STAGE).instantiate()
	root.add_child(stage)
	current_scene = stage
	var station := stage.get_node("Station")
	var director := station.get_node("SalvageEnding")
	director.set_physics_process(false)
	var car := stage.get_node("Car") as VehicleBody3D
	car.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	car.freeze = true
	car.collision_mask = 0
	car.set_process(false)
	car.set_physics_process(false)
	var overview := stage.get_node("Camera") as Camera3D
	overview.look_at(Vector3(3.9, 0.65, -3.9))
	await _frames(4)
	await _screenshot("ed3_initial")
	# Neo/Classicとも、見た目と衝突外形を合わせて全4箱で内包判定できる。
	for key in ["neo", "classic"]:
		var probe: VehicleBody3D = car
		if key == "classic":
			menu.robot_model = key
			probe = load("res://car_classic.tscn").instantiate()
			probe.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			probe.freeze = true
			probe.collision_mask = 0
			stage.add_child(probe)
			probe.set_process(false)
			probe.set_physics_process(false)
			await _frames(2)
		for bin in station.get_node("SurplusContents/BinContents").get_children():
			_place(probe, bin, director, Vector3.ZERO)
			await _frames(3)
			assert(director.get_fully_containing_bin(probe) == StringName(bin.name), "完全進入が検知されません")
			_place(probe, bin, director, Vector3(0.90, 0, 0))
			await _frames(3)
			assert(director.get_fully_containing_bin(probe) == &"", "水平にはみ出してもED3判定されました")
			_place(probe, bin, director, Vector3(0, 0.32, 0))
			await _frames(3)
			assert(director.get_fully_containing_bin(probe) == &"", "縁より上の機体がED3判定されました")
			if key == "neo" and bin.name == "SouthWest":
				var edge_area := bin.get_node("Interior") as Area3D
				_place(probe, bin, director, Vector3(1.10, 0, 0))
				await _frames(3)
				assert(edge_area.overlaps_body(probe), "横からの接触が再現されません")
				assert(director.get_fully_containing_bin(probe) == &"", "横壁接触でED3判定されました")
				_place(probe, bin, director, Vector3(0, -0.26, 0))
				await _frames(3)
				assert(edge_area.overlaps_body(probe), "画像面の下への進入が再現されません")
				assert(director.get_fully_containing_bin(probe) == &"", "シャーシが画像面より下でもED3判定されました")
		if key == "classic":
			probe.queue_free()
			await _frames(2)
	menu.robot_model = _run_model
	# 静的な包含判定用プローブを捨て、非凍結の実車を箱へ落として接地後の判定を確かめる。
	stage.queue_free()
	await _frames(2)
	stage = load(STAGE).instantiate()
	if _run_model == "classic":
		var neo_car := stage.get_node("Car") as VehicleBody3D
		var classic_car := load("res://car_classic.tscn").instantiate() as VehicleBody3D
		classic_car.name = "Car"
		classic_car.transform = neo_car.transform
		neo_car.free()
		stage.add_child(classic_car)
	root.add_child(stage)
	current_scene = stage
	station = stage.get_node("Station")
	director = station.get_node("SalvageEnding")
	director.set_physics_process(false)
	car = stage.get_node("Car")
	await _frames(2)
	var bin := station.get_node("SurplusContents/BinContents/SouthWest")
	var area := bin.get_node("Interior") as Area3D
	# 一部が箱の縁にかかる着地ではED3に入らない。
	if _run_model == "neo":
		_place(car, bin, director, Vector3(0.90, 0.65, 0))
		await _frames(80)
		assert(director.get_fully_containing_bin(car) == &"" and director.phase == 0)
	# 中央へ落とし直す。停止時の車輪は支持面に約2cm潜るが、見た目は完全に箱内。
	_place(car, bin, director, Vector3(0.12, 0.65, 0))
	await _frames(90)
	assert(not car.freeze and area.overlaps_body(car))
	assert(absf(bin.to_local(car.global_position).x) > 0.08, "機体と箱の中心がずれた配置になっていません")
	var settled_bounds: AABB = director.call("_body_bounds_in", car, area.global_transform.affine_inverse())
	var half := (area.get_node("CollisionShape3D").shape as BoxShape3D).size * 0.5
	if _run_model == "neo":
		assert(settled_bounds.position.y < -half.y - 0.012, "車輪の沈み込みが再現されません")
	assert(settled_bounds.end.y <= half.y + 0.012, "車体が縁より上です")
	assert(director.get_fully_containing_bin(car) == &"SouthWest")
	director.set_physics_process(true)
	await _wait_phase(director, 1)
	assert(ending.is_controls_locked() and car.process_mode == Node.PROCESS_MODE_DISABLED and car.freeze)
	assert(car.linear_velocity == Vector3.ZERO)
	var first_actor: Node3D = director.get("_actors")[2]
	var second_actor: Node3D = director.get("_actors")[0]
	var first_eyes: Node3D = director.get("_eye_labels")[2]
	var second_eyes: Node3D = director.get("_eye_labels")[0]
	assert(first_actor != second_actor and first_eyes.get_parent() == first_actor and second_eyes.get_parent() == second_actor, "二つのカットが別個体ではありません")
	for i in 120:
		if first_eyes.visible and float(first_eyes.get_meta("eye_scale")) > 1.1:
			break
		await create_timer(0.02).timeout
	assert(first_eyes.visible and not second_eyes.visible and float(first_eyes.get_meta("eye_scale")) > 1.1, "一体目の星形目強調カットが出ません")
	var director_camera := director.get("_camera") as Camera3D
	assert(_face_alignment(first_actor, director_camera) > 0.90, "一体目の目がカメラを向いていません")
	await _screenshot("ed3_glint_side")
	# 検証中だけ横向きにし、頭部から星が浮かず奥側が隠れる状態を記録する。
	var first_facing := first_actor.rotation.y
	first_actor.rotation.y += 1.25
	await _screenshot("ed3_eye_oblique")
	first_actor.rotation.y = first_facing
	var second_glint_deadline := Time.get_ticks_msec() + 2000
	while (not second_eyes.visible or float(second_eyes.get_meta("eye_scale")) <= 1.25) and Time.get_ticks_msec() < second_glint_deadline:
		await create_timer(0.02).timeout
	assert(second_eyes.visible and not first_eyes.visible and float(second_eyes.get_meta("eye_scale")) > 1.25, "別個体の星形目強調が出ません")
	assert(_face_alignment(second_actor, director_camera) > 0.90, "二体目の目がカメラを向いていません")
	assert(bin.to_local(first_actor.global_position).x > 0.8 and bin.to_local(second_actor.global_position).x < -0.8, "二体が別位置にいません")
	for actor in director.get("_actors") + director.get("_crowd"):
		var eyes := actor.get_node("MischievousEyes") as Node3D
		assert(eyes.get_child_count() == 2, "Nadeggに左右の目がありません")
		assert(eyes.position == Vector3(0, 0.135, 0), "目の基点が黄色い頭部の中心ではありません")
		var eye_centers: Array[Vector3] = []
		for glint in eyes.get_children():
			assert(glint is MeshInstance3D and (glint as MeshInstance3D).mesh is QuadMesh, "星形目が平らな板ではありません")
			var material := (glint as MeshInstance3D).material_override as StandardMaterial3D
			assert(material.albedo_texture.resource_path == "res://assets/textures/gomi_station/nadegg_eye_glint.png" and material.albedo_color == Color.WHITE, "星形目の画像または白色が違います")
			assert(not material.no_depth_test and material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "星形目の深度設定が違います")
			assert(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "星形目の表示設定が違います")
			assert(((glint as MeshInstance3D).mesh as QuadMesh).size.x > 0.055, "星形目が従来より小さくなっています")
			var center: Vector3 = glint.position
			eye_centers.append(center)
			assert(center.y > 0.01 and center.z < -0.06, "星形目が頭部の前面を向いていません")
			assert(absf(center.z + 0.0828) < 0.0001, "星形目が黄色い頭部の一番前の面にありません")
			assert(glint.basis.z.normalized().dot(Vector3.FORWARD) > 0.999 and absf(glint.basis.y.normalized().dot(Vector3.UP)) > 0.999, "星形目の板が正面を向いて地面に垂直に立っていません")
			var eye_scale := float(eyes.get_meta("eye_scale"))
			assert(is_equal_approx(glint.scale.x, glint.scale.y) and glint.scale.x / eye_scale > 0.89 and glint.scale.x / eye_scale < 1.11, "星形目の拡大縮小が縦横でそろっていません")
		assert(absf(eye_centers[1].x - eye_centers[0].x - 0.0553) < 0.004, "二つの星形目が重なっています")
		assert(eye_centers[1].normalized().dot(Vector3.LEFT) < 0.0, "横から見た右目が頭部に隠れません")
	await _screenshot("ed3_glint_frame")
	await create_timer(0.75).timeout
	await _screenshot("ed3_first_ambush")
	for i in 300:
		if second_actor.global_position.distance_to(bin.to_global(Vector3(-0.91, 0.80, -0.27))) > 0.2:
			break
		await create_timer(0.02).timeout
	assert(second_actor.global_position.distance_to(bin.to_global(Vector3(-0.91, 0.80, -0.27))) > 0.2, "二体目が飛びかかっていません")
	await _screenshot("ed3_second_ambush")
	var swarm_actor: Node3D = director.get("_crowd")[0]
	for i in 120:
		if swarm_actor.visible:
			break
		await create_timer(0.02).timeout
	assert(swarm_actor.visible, "追加Nadeggが群がりません")
	assert(first_actor.global_position.distance_to(director.call("_gather_position", 2)) > 0.1, "一体目の飛び込みが終わる前に群れが始まりません")
	assert(second_actor.global_position.distance_to(director.call("_gather_position", 0)) > 0.1, "二体目の飛び込みが終わる前に群れが始まりません")
	await _screenshot("ed3_overlap_ambush")
	var crowd: Array = director.get("_crowd")
	var launch_times: Array[int] = []
	for i in 9:
		while not crowd[i].visible:
			await create_timer(0.02).timeout
		launch_times.append(Time.get_ticks_msec())
		var gather_starts: Array = director.get("_gather_start_screens")
		assert(gather_starts.size() > i, "群れの開始位置が記録されていません")
		var screen: Vector2 = gather_starts[i]
		var size := root.get_visible_rect().size
		assert(screen.x < -35.0 or screen.x > size.x + 35.0 or screen.y < -35.0 or screen.y > size.y + 35.0, "最初の群れ%dが画面内から始まります: %s" % [i, screen])
		var angle := float(i) * TAU / 9.0
		var target: Vector3 = director.call("_vehicle_offset", Vector3(cos(angle) * 0.45, 0.04, sin(angle) * 0.32))
		assert(_face_alignment_to(crowd[i], target) > 0.8, "群れが機体周囲を向いていません")
		if i == 2:
			assert(not is_instance_valid(director.get("_smoke")), "三体目の着地前に煙が出ました")
	assert(launch_times[8] - launch_times[0] >= 850, "九体の飛び込み時刻が十分に分散していません")
	for actor in director.get("_actors"):
		assert(director.get("_carrier_idle_tweens").has(actor), "元の三体に到着後の待機動作がありません")
	var smoke_deadline := Time.get_ticks_msec() + 1500
	while not is_instance_valid(director.get("_smoke")) and Time.get_ticks_msec() < smoke_deadline:
		await create_timer(0.02).timeout
	assert(is_instance_valid(director.get("_smoke")), "三体目の着地時に煙が出ません")
	assert(director.get("_carrier_idle_tweens").has(crowd[2]), "煙が三体目の着地前に出ました")
	var comic_word_state := {"shown": {6: false, 7: false, 8: false, 9: false}, "hidden": {6: false, 7: false, 8: false, 9: false}, "done": false}
	assert(not director.get("_crowd_scuffle_states").has(crowd[9]), "追加Nadeggの到着前にゴトが始まりました")
	_watch_comic_words(director, comic_word_state)
	var first_smoke := director.get("_smoke") as Node3D
	var growing_puff := first_smoke.get_node("Puff00") as MeshInstance3D
	var initial_size := growing_puff.scale.x
	await create_timer(0.12).timeout
	assert(growing_puff.scale.x > initial_size, "煙球が小さい状態から現れません")
	await create_timer(0.24).timeout
	var grown_size := growing_puff.scale.x
	var last_angle := 8.0 * TAU / 9.0
	var last_target: Vector3 = director.call("_vehicle_offset", Vector3(cos(last_angle) * 0.45, 0.04, sin(last_angle) * 0.32))
	assert(crowd[8].global_position.distance_to(last_target) > 0.2, "後続の群れが飛び込む前に煙が出ました")
	await _screenshot("ed3_smoke_early")
	var last_swarm: Node3D = crowd[8]
	var swarm_start := last_swarm.global_position
	var swarm_eyes := last_swarm.get_node("MischievousEyes") as Node3D
	var swarm_eyes_start := swarm_eyes.global_position
	assert(_face_alignment_to(last_swarm, car.global_position) > 0.80, "群れの目が機体へ向いていません")
	await create_timer(0.24).timeout
	assert(last_swarm.global_position.distance_to(swarm_start) > 0.05, "追加Nadeggが移動しません")
	assert(growing_puff.scale.x < grown_size, "煙球が個別に縮みません")
	assert(swarm_eyes.global_position.distance_to(swarm_eyes_start) > 0.05, "星形目が移動するNadeggから離れています")
	await _screenshot("ed3_swarm_midair")
	var smoke_elapsed: float = director.get("_smoke_elapsed")
	var smoke_cycle := 1.25
	var next_cycle_start := (floorf(smoke_elapsed / smoke_cycle) + 1.0) * smoke_cycle
	director.call("_update_smoke_puffs", next_cycle_start + smoke_cycle * 0.01 - smoke_elapsed)
	assert(growing_puff.scale.x < 0.05, "煙球が縮んで消えたあと小さい状態から再出現しません")
	var player_switch := root.get_node("PlayerSwitch")
	player_switch.call("_replace", car, "neo" if _run_model == "classic" else "classic")
	assert(is_instance_valid(car) and car.robot_key == _run_model)
	var parts: int = director.get_remaining_part_count()
	assert(parts > 9)
	await _wait_phase(director, 2)
	for i in range(6, 9):
		var angle := float(i) * TAU / 9.0
		var expected: Vector3 = car.global_position + bin.global_basis * Vector3(cos(angle) * 0.45, 0.04, sin(angle) * 0.32)
		assert(crowd[i].global_position.distance_to(expected) < 0.16, "群れの着地点が機体位置を基準にしていません")
	var salvage_groups: Array = director.call("_select_salvage_parts")
	var showcase_groups: Array = director.call("_select_showcase_parts", salvage_groups)
	assert(salvage_groups.size() == 5 and showcase_groups.size() == 5, "部品が5種類にまとまっていません")
	var expected_paths := [
		["P3766-P3768SKU4-P3767ENVELOPE", "Orin_nano_case"] if _run_model == "neo" else ["N100DC-ITX"],
		["BATTERY_COVER_12V"] if _run_model == "neo" else ["Battery_Case_Right_12V7_2Ah"],
		["mid-360-asm"] if _run_model == "neo" else ["Livox Mid-70"],
		["HFSF6-3060-598-X8-AH16-BH582 v1_1", "HFSF6-3060-598-X8-AH16-BH582 v1(Mirror)_1"] if _run_model == "neo" else ["MainFrame - Reverse Prototype v12/Body5", "MainFrame - Reverse Prototype v12/Body6"],
	]
	var wheels: Array = car.get("_visual_wheels")
	assert(wheels.size() == 4, "実車の車輪が四本ではありません")
	var wheel_parts := 0
	for wheel_index in wheels.size():
		var wheel: Dictionary = wheels[wheel_index]
		var selected_parts := 0
		for part: Dictionary in wheel["parts"]:
			if salvage_groups[0].has(part["node"]):
				wheel_parts += 1
				selected_parts += 1
				if wheel_index == 0:
					assert(showcase_groups[0].has(part["node"]), "提示用の車輪が一本目と一致しません")
		assert(selected_parts > 0, "車体から外す車輪が欠けています: %d" % wheel_index)
	assert(wheel_parts == salvage_groups[0].size(), "四本の車輪が同じ搬出単位にまとまっていません")
	assert(showcase_groups[0].size() == (wheels[0]["parts"] as Array).size(), "カメラ前の車輪が一本分ではありません")
	assert(showcase_groups[0].size() < salvage_groups[0].size(), "四本の車輪を全てカメラ前で見せています")
	assert(showcase_groups[4].size() < salvage_groups[4].size(), "左右のフレームを両方カメラ前で見せています")
	for group_index in salvage_groups.size():
		var group: Array = salvage_groups[group_index]
		assert(not group.is_empty(), "運搬用の実車部品が欠けています")
		if group_index >= 1:
			for marker in expected_paths[group_index - 1]:
				var found := false
				for source: MeshInstance3D in group:
					if String(car.get_path_to(source)).contains(marker):
						found = true
						break
				assert(found, "機種固有の実車部品が運搬品に含まれません: %s" % marker)
		var copy := Node3D.new()
		director.add_child(copy)
		director.call("_add_real_part", copy, showcase_groups[group_index])
		assert(copy.get_child_count() == showcase_groups[group_index].size(), "元メッシュと運搬用メッシュが一致しません")
		assert(copy.find_children("*", "Label3D").is_empty(), "運搬部品に文字が付いています")
		for i in showcase_groups[group_index].size():
			assert(copy.get_child(i) is MeshInstance3D and copy.get_child(i).mesh == showcase_groups[group_index][i].mesh, "運搬用に別の形状を作っています")
		copy.queue_free()
	var showcase_state := {"seen": [], "done": false}
	_watch_showcases(director, showcase_groups, showcase_state)
	# カメラが回り続けるので、追加波の開始点は記録された瞬間のカメラで画面外かを確かめる。
	var wave_state := {"checked": 0}
	_watch_wave_starts(director, wave_state)
	assert(director.get("_crowd").size() == 17 and is_instance_valid(director.get("_smoke")))
	assert(_visible_crowd_count(director) == 9, "最初の群れが九体ではありません")
	await _screenshot("ed3_first_parts")
	var first_carrier: Node3D = director.get("_actors")[0]
	for i in 240:
		if first_carrier.visible and first_carrier.get_node_or_null("SalvagedParts") != null \
				and first_carrier.global_position.distance_to(director_camera.global_position) < 0.7 \
				and not director_camera.is_position_behind(first_carrier.global_position):
			break
		await create_timer(0.02).timeout
	assert(first_carrier.visible and first_carrier.global_position.distance_to(director_camera.global_position) < 0.7, "部品を持ったNadeggがカメラ前に来ません")
	assert(not director.get("_carrier_idle_tweens").has(first_carrier) and director.get("_carrier_idle_tweens").has(crowd[0]), "担当交代時に待機動作が切り替わりません")
	assert(first_carrier.get_node("SalvagedParts").find_children("*", "Label3D").is_empty(), "運搬部品に文字が付いています")
	# カメラが回るので、見せている間はカメラから見た位置が止まっていることを確かめる。
	var showcase_position := director_camera.global_transform.affine_inverse() * first_carrier.global_position
	var showcased_cargo := first_carrier.get_node("SalvagedParts") as Node3D
	assert(showcased_cargo.get_child_count() == showcase_groups[0].size(), "カメラ前の運搬品が実車部品ではありません")
	await create_timer(0.16).timeout
	assert(first_carrier.visible and (director_camera.global_transform.affine_inverse() * first_carrier.global_position).distance_to(showcase_position) < 0.001, "部品提示中にNadeggがカメラに対して動いています")
	assert(first_carrier.get_node("SalvagedParts").find_children("*", "Label3D").is_empty(), "部品提示に漫画文字が付いています")
	await _screenshot("ed3_carrier_showcase")
	for i in 240:
		if not first_carrier.visible:
			break
		await create_timer(0.02).timeout
	# 消えたあともカメラは回り続けるので、消えたのに気づくまでに回った分（数cm）は許す。
	assert(not first_carrier.visible and (director_camera.global_transform.affine_inverse() * first_carrier.global_position).distance_to(showcase_position) < 0.05, "部品提示後のNadeggがその場で消えません")
	assert(director.get("_departed_carriers").size() >= 1)
	await _screenshot("ed3_carrier_exit")
	var idle_tweens: Dictionary = director.get("_carrier_idle_tweens")
	for i in range(2, 6):
		assert(idle_tweens.has(crowd[i]) and idle_tweens[crowd[i]].is_running(), "順番待ちの運搬担当の瞬間移動が止まっています")
	var widest_idle := 0.0
	for i in range(2, 6):
		var center: Vector3 = director.get("_carrier_idle_states")[crowd[i]]["center"]
		for step in range(1, 42):
			var target: Vector3 = director.call("_carrier_idle_target", center, i + 3, step)
			var local: Vector3 = bin.to_local(target)
			assert(absf(local.x) <= 0.821 and absf(local.z) <= 0.421, "運搬担当の瞬間移動先が箱から外れています")
			widest_idle = maxf(widest_idle, target.distance_to(center))
	assert(widest_idle > 0.40, "運搬担当の瞬間移動範囲が狭すぎます")
	var widest_crowd := 0.0
	var reached_x_rim := false
	var reached_z_rim := false
	for index in range(6, 17):
		for step in range(1, 48):
			var target: Vector3 = director.call("_scuffle_target", index, step)
			var local: Vector3 = bin.to_local(target)
			assert(absf(local.x) <= 0.821 and absf(local.z) <= 0.421, "群れの瞬間移動先が箱から外れています")
			widest_crowd = maxf(widest_crowd, Vector2(local.x - bin.to_local(car.global_position).x, local.z - bin.to_local(car.global_position).z).length())
			reached_x_rim = reached_x_rim or absf(local.x) >= 0.80
			reached_z_rim = reached_z_rim or absf(local.z) >= 0.40
	assert(widest_crowd > 0.80 and reached_x_rim and reached_z_rim, "群れが青箱の縁付近まで瞬間移動しません")
	await _screenshot("ed3_gathering")
	# 各フレームで位置が「着地点」か「次の瞬間移動先」のどちらかに一致する。
	# 補間中の座標と上下の跳ねが入り込まないことを、運搬担当と非運搬担当の両方で確認する。
	var teleport_steps: Array[int] = []
	var teleport_heights: Array[float] = []
	for i in 9:
		teleport_steps.append(0)
		teleport_heights.append(crowd[i].global_position.y)
	for sample in 45:
		await create_timer(0.02).timeout
		for i in range(2, 9):
			var states: Dictionary = director.get("_carrier_idle_states") if i < 6 else director.get("_crowd_scuffle_states")
			assert(states.has(crowd[i]), "群れの瞬間移動状態がありません: %d" % i)
			var state: Dictionary = states[crowd[i]]
			var step: int = state["step"]
			teleport_steps[i] = maxi(teleport_steps[i], step)
			if step > 0:
				var expected: Vector3
				if i < 6:
					expected = director.call("_carrier_idle_target", state["center"], state["index"], step)
				else:
					var target_step := step + 9 if (state["index"] + step) % 5 == 0 else step
					expected = director.call("_scuffle_target", state["index"], target_step)
				assert(crowd[i].global_position.distance_to(expected) < 0.001, "群れが瞬間移動先の途中にいます: %d" % i)
			if i < 6:
				assert(absf(crowd[i].global_position.y - teleport_heights[i]) < 0.001, "運搬担当が上下に跳ねています: %d" % i)
	for i in range(2, 9):
		assert(teleport_steps[i] > 0, "群れの瞬間移動が起きません: %d" % i)
	await _screenshot("ed3_carrier_idle")
	await create_timer(0.35).timeout
	var smoke := director.get("_smoke") as Node3D
	assert(smoke.scale.is_equal_approx(Vector3(2.0, 1.93, 2.0)), "煙全体の倍率が変化しています")
	var foreground := smoke.get_node("ForegroundPuffs") as Node3D
	assert(not foreground.visible, "停止中の手前の煙が表示されています")
	assert(smoke.get_child_count() == 13, "奥側の煙球が12個ありません")
	var visible_puffs := 0
	var differing_phases := 0
	for i in 12:
		var puff := smoke.get_node("Puff%02d" % i) as MeshInstance3D
		if puff.scale.x > 0.05:
			visible_puffs += 1
		if absf(puff.scale.x - growing_puff.scale.x) > 0.03:
			differing_phases += 1
	assert(visible_puffs >= 5 and differing_phases >= 5, "煙球の出現時刻が揃っています")
	assert(absf((smoke.get_node("Puff00") as Node3D).position.z - (smoke.get_node("Puff01") as Node3D).position.z) > 0.05, "煙球が奥行き方向へ散っていません")
	for i in 360:
		if director.get("_reinforcement_waves") >= 3 and director.get("_departed_carriers").size() >= 3:
			break
		await create_timer(0.02).timeout
	assert(director.get("_reinforcement_waves") >= 3 and director.get("_departed_carriers").size() >= 3 and _visible_crowd_count(director) > 9, "追加Nadeggが段階的に増えません")
	var scuffle_states: Dictionary = director.get("_crowd_scuffle_states")
	assert(scuffle_states.has(crowd[6]) and scuffle_states[crowd[6]]["step"] >= 4, "非運搬の群れのドタバタが続いていません")
	await _screenshot("ed3_reinforcements")
	for tick in 120:
		if director.get("_scuffle_word_labels").has(crowd[9]):
			break
		await create_timer(0.02).timeout
	assert(director.get("_scuffle_word_labels").has(crowd[9]), "追加Nadeggのゴトが表示されません")
	await _screenshot("ed3_goto_scuffle")
	while director.get_remaining_part_count() > parts / 2:
		await create_timer(0.02).timeout
	await create_timer(0.55).timeout
	assert(director.get_remaining_part_count() < parts)
	await _screenshot("ed3_carrying_parts")
	for i in 600:
		if director.get("_reinforcement_waves") >= 4 and director.get("_departed_carriers").size() >= 4:
			break
		await create_timer(0.02).timeout
	assert(director.get("_reinforcement_waves") == 4 and _visible_crowd_count(director) > 9, "終盤の追加Nadeggが現れません")
	await _screenshot("ed3_late_reinforcements")
	for i in 600:
		if director.get("_reinforcement_waves") == 4 and director.get("_departed_carriers").size() == 5:
			break
		await create_timer(0.02).timeout
	assert(director.get("_reinforcement_waves") == 4 and director.get("_departed_carriers").size() == 5, "5種類の提示と追加波が完了しません")
	for tick in 30:
		if showcase_state["done"]:
			break
		await create_timer(0.02).timeout
	assert(showcase_state["done"] and showcase_state["seen"] == [0, 1, 2, 3, 4], "5種類の実車部品が一度ずつ提示されません")
	var wave_starts: Array = director.get("_wave_start_positions")
	assert(wave_starts.size() == 8 and wave_state["checked"] == 8, "追加4波の開始位置が記録されていません")
	await _screenshot("ed3_final_wave")
	for i in 120:
		if not director.get("_retreat_exit_positions").is_empty():
			break
		await create_timer(0.02).timeout
	assert(not director.get("_retreat_exit_positions").is_empty(), "最後の退散が始まりません")
	await create_timer(0.35).timeout
	await _screenshot("ed3_retreat_midflight")
	await _wait_phase(director, 3)
	for position: Vector3 in director.get("_retreat_exit_positions"):
		_assert_offscreen(position, director_camera, "最後の退散先")
	assert(director.get("_reinforcement_waves") == 4, "BAD ENDまで追加の飛び込みが続きません")
	var departed: Array = director.get("_departed_carriers")
	assert(departed.size() == 5, "5種類の運搬を別々のNadeggが担当していません")
	for i in departed.size():
		if is_instance_id_valid(departed[i]):
			assert(not (instance_from_id(departed[i]) as Node3D).visible, "運搬したNadeggが箱へ戻っています")
		for j in range(i + 1, departed.size()):
			assert(departed[i] != departed[j], "同じNadeggが複数回運搬しています")
	assert(director.get_remaining_part_count() == 0 and not car.visible)
	assert(director.get("_crowd").is_empty())
	assert(comic_word_state["done"], "漫画文字の監視が完了しません")
	for index in [6, 7, 8, 9]:
		assert(comic_word_state["shown"][index] and comic_word_state["hidden"][index], "Nadegg%dの漫画文字が瞬間移動と同期して現れたり消えたりしません" % index)
	assert(director.get("_comic_labels").is_empty() and director.find_children("*", "Label3D").is_empty(), "BAD ENDに漫画文字が残っています")
	assert(ending.is_shown() and ending.get("_ending") == 3 and ending.get("_title_label").text == "BAD END")
	await _screenshot("ed3_bad_end")
	# 実際のBack to Startボタンを押し、シーン再読込後の操作状態を確認する。
	var old_stage_id := stage.get_instance_id()
	ending.get("_button").pressed.emit()
	for i in 120:
		if current_scene != null and current_scene.get_instance_id() != old_stage_id:
			break
		await create_timer(0.02).timeout
	assert(not ending.is_controls_locked() and not ending.is_shown())
	assert(current_scene != null, "Back to Startでシーンが読み込まれません")
	assert(current_scene.get_instance_id() != old_stage_id)
	var fresh := current_scene.get_node("Car") as VehicleBody3D
	assert(not fresh.freeze and fresh.process_mode == Node.PROCESS_MODE_INHERIT and fresh.is_in_group("player"))
	assert(current_scene.get_node("Station/SalvageEnding").phase == 0)
	# ED1/ED2の既存表示がED3後も通常タイトルに戻る。
	ending.call("_show", 1)
	assert(ending.get("_title_label").text == "Thank you for Playing!")
	ending.call("_hide")
	ending.call("_show", 2)
	assert(ending.is_zero_gravity())
	ending.call("_hide")
	print("ED3 verified (%s): five unique part types showcased by distinct Nadegg; 4 reinforcement waves; BAD END; Back to Start; ED1/2 intact" % _run_model)
	quit()


func _watch_comic_words(director: Node, state: Dictionary) -> void:
	var crowd: Array = director.get("_crowd")
	var words := {6: "ドタ", 7: "バタ", 8: "ガタ", 9: "ゴト"}
	var fixed_positions := {}
	while director.phase < 3:
		await process_frame
		if director.get("_finishing_scuffle"):
			break
		var labels: Array = director.get("_comic_labels")
		var word_labels: Dictionary = director.get("_scuffle_word_labels")
		assert(labels.size() == word_labels.size() and labels.size() <= 4, "群衆と無関係な漫画文字が表示または蓄積しています")
		for label: Label3D in labels:
			assert(is_instance_valid(label) and label.visible and label.modulate.a == 1.0 and label.outline_modulate.a == 1.0, "表示中の漫画文字が消えかけています")
			assert(not label.no_depth_test, "漫画文字が前景のNadeggや部品を透過して表示されます")
			assert(word_labels.values().has(label), "部品提示に漫画文字が同期しています")
			var id := label.get_instance_id()
			if fixed_positions.has(id):
				assert(label.global_position.distance_to(fixed_positions[id]) < 0.001, "表示中の漫画文字が移動しています")
			else:
				fixed_positions[id] = label.global_position
		for index in [6, 7, 8, 9]:
			var actor: Node3D = crowd[index]
			var scuffle_states: Dictionary = director.get("_crowd_scuffle_states")
			if not scuffle_states.has(actor):
				assert(not word_labels.has(actor), "Nadegg%dの到着前に文字が現れました" % index)
				continue
			var step: int = scuffle_states[actor]["step"]
			var showing := word_labels.has(actor)
			assert(showing == (step % 2 == 1), "Nadegg%dの瞬間移動と漫画文字表示がずれています" % index)
			if showing:
				var label := word_labels[actor] as Label3D
				assert(labels.has(label) and label.text == words[index], "瞬間移動に対応する文字が違います")
				state["shown"][index] = true
			elif step >= 2:
				state["hidden"][index] = true
	state["done"] = true


func _watch_showcases(director: Node, showcase_groups: Array, state: Dictionary) -> void:
	var carriers: Array = director.get("_actors").duplicate()
	var crowd: Array = director.get("_crowd")
	carriers.append(crowd[0])
	carriers.append(crowd[1])
	var camera := director.get("_camera") as Camera3D
	for i in showcase_groups.size():
		var actor := carriers[i] as Node3D
		var cargo: Node3D
		for tick in 300:
			cargo = actor.get_node_or_null("SalvagedParts") as Node3D
			if actor.visible and cargo != null and cargo.global_position.distance_to(camera.global_position) < 0.62:
				break
			await create_timer(0.02).timeout
		assert(actor.visible and cargo != null and cargo.global_position.distance_to(camera.global_position) < 0.62, "部品種類%dのカメラ前提示がありません" % i)
		# unproject_position はゲームの基準解像度の座標で返るので、窓の大きさではなく描いている範囲で比べる。
		var screen_size := camera.get_viewport().get_visible_rect().size
		var screen_center := screen_size * 0.5
		var cargo_on_screen := camera.unproject_position(cargo.global_position)
		var actor_on_screen := camera.unproject_position(actor.global_position)
		assert(cargo_on_screen.distance_to(screen_center) < screen_size.x * 0.08, "部品種類%dが画面の真ん中にありません" % i)
		assert(absf(actor_on_screen.x - screen_center.x) > screen_size.x * 0.12, "部品種類%dのNadeggが左右に寄っていません" % i)
		var word_count: int = director.get("_comic_labels").size()
		assert(cargo.get_child_count() == showcase_groups[i].size(), "部品種類%dの提示用メッシュ数が違います" % i)
		for part_index in showcase_groups[i].size():
			var copy := cargo.get_child(part_index) as MeshInstance3D
			assert(copy != null and copy.mesh == showcase_groups[i][part_index].mesh, "部品種類%dが実車部品と一致しません" % i)
			assert(not (showcase_groups[i][part_index] as MeshInstance3D).visible, "提示した部品が車体に残っています: %d" % i)
		state["seen"].append(i)
		await create_timer(0.12).timeout
		assert(actor.visible and cargo.find_children("*", "Label3D").is_empty(), "部品提示中に文字が付いています: %d" % i)
		await _screenshot("ed3_carrier_showcase_%d" % i)
		for tick in 300:
			if not actor.visible:
				break
			await create_timer(0.02).timeout
		assert(not actor.visible, "部品種類%dの提示後にNadeggが消えません" % i)
		assert(director.get("_comic_labels").size() <= 4 and word_count <= 4, "部品提示で漫画文字が増えています: %d" % i)
	state["done"] = true


# 追加波の開始点が記録されるたびに、そのときのカメラで画面外にあるかを確かめる。
func _watch_wave_starts(director: Node, state: Dictionary) -> void:
	var camera := director.get("_camera") as Camera3D
	while director.phase < 3 and state["checked"] < 8:
		var starts: Array = director.get("_wave_start_positions")
		while state["checked"] < starts.size():
			var i: int = state["checked"]
			_assert_offscreen(starts[i], camera, "追加波%d-%dの開始点" % [i / 2, i % 2])
			state["checked"] = i + 1
		await process_frame


func _place(body: VehicleBody3D, bin: Node3D, director: Node, offset: Vector3) -> void:
	body.global_basis = bin.global_basis.orthonormalized()
	var local: AABB = director.call("_body_bounds_in", body, body.global_transform.affine_inverse())
	var origin := Vector3(-local.get_center().x, -local.position.y + 0.004, -local.get_center().z)
	body.global_position = bin.to_global(origin + offset)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO


func _wait_phase(director: Node, target: int) -> void:
	while director.phase < target:
		await create_timer(0.02).timeout
	assert(director.phase == target)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await create_timer(0.02).timeout


func _face_alignment(actor: Node3D, camera: Camera3D) -> float:
	return _face_alignment_to(actor, camera.global_position)


func _face_alignment_to(actor: Node3D, target: Vector3) -> float:
	var look_direction := target - actor.global_position
	look_direction.y = 0.0
	var face_direction := -actor.global_basis.z
	face_direction.y = 0.0
	return look_direction.normalized().dot(face_direction.normalized())


func _visible_crowd_count(director: Node) -> int:
	var count := 0
	for actor in director.get("_crowd"):
		if actor.visible:
			count += 1
	return count


func _assert_offscreen(position: Vector3, camera: Camera3D, message: String) -> void:
	var screen := camera.unproject_position(position)
	var size := root.get_visible_rect().size
	assert(camera.is_position_behind(position) or screen.x < -35.0 or screen.x > size.x + 35.0 or screen.y < -35.0 or screen.y > size.y + 35.0, "%sが画面内です: %s" % [message, screen])


func _screenshot(name: String) -> void:
	if _screenshot_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_screenshot_dir.path_join(name + ".png"))

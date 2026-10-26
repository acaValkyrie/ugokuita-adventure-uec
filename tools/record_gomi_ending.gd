extends SceneTree

# ED3を検証用の操作を挟まずに一度だけ流す。動画にするときはMovie Makerで書き出す。
# 実行: Godot --path . --script res://tools/record_gomi_ending.gd --write-movie tmp/ed3.avi --fixed-fps 30
# Classicで流すときは末尾に -- --robot=classic を付ける。
const STAGE := "res://tests/gomi_ending_stage.tscn"
# BAD ENDの画面を見せておく時間 [秒]
const BAD_END_HOLD := 3.0
var _run_model := "neo"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--robot=classic":
			_run_model = "classic"
	create_timer(180.0).timeout.connect(func():
		push_error("ED3の書き出しが完了しませんでした")
		quit(1)
	)
	call_deferred("_record")


func _record() -> void:
	root.size = Vector2i(1280, 720)
	# GameMenuは窓からフォーカスが外れると全部の音を消す。書き出しの窓は前に出ないことがあるので、毎フレーム消音を外す。
	process_frame.connect(func(): AudioServer.set_bus_mute(0, false))
	var menu := root.get_node("GameMenu")
	menu.robot_model = _run_model
	var warmup := root.get_node("ShaderWarmup")
	warmup.set("_done", true)
	warmup.set_process(false)
	warmup.get("_screen").hide()
	var stage: Node3D = load(STAGE).instantiate()
	if _run_model == "classic":
		var neo_car := stage.get_node("Car") as VehicleBody3D
		var classic_car := load("res://car_classic.tscn").instantiate() as VehicleBody3D
		classic_car.name = "Car"
		classic_car.transform = neo_car.transform
		neo_car.free()
		stage.add_child(classic_car)
	root.add_child(stage)
	current_scene = stage
	(stage.get_node("Camera") as Camera3D).look_at(Vector3(3.9, 0.65, -3.9))
	var station := stage.get_node("Station")
	var director := station.get_node("SalvageEnding")
	director.set_physics_process(false)
	var car := stage.get_node("Car") as VehicleBody3D
	await _frames(2)
	# 箱の中央へ落とし、接地してからED3の判定を始める。
	var bin := station.get_node("SurplusContents/BinContents/SouthWest") as Node3D
	_place(car, bin, director, Vector3(0.12, 0.65, 0))
	await _frames(90)
	director.set_physics_process(true)
	while director.phase < 3:
		await create_timer(0.02).timeout
	await create_timer(BAD_END_HOLD).timeout
	quit()


func _place(body: VehicleBody3D, bin: Node3D, director: Node, offset: Vector3) -> void:
	body.global_basis = bin.global_basis.orthonormalized()
	var local: AABB = director.call("_body_bounds_in", body, body.global_transform.affine_inverse())
	var origin := Vector3(-local.get_center().x, -local.position.y + 0.004, -local.get_center().z)
	body.global_position = bin.to_global(origin + offset)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await create_timer(0.02).timeout

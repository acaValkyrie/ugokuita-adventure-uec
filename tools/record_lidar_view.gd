extends SceneTree

# 点群モードで7秒走り、停止後3秒、全体マップを2秒、閉じて1秒見せる。実行: Godot --path . --script res://tools/record_lidar_view.gd --write-movie tmp/lidar_map.avi --fixed-fps 30
const STAGE := "res://src/main/main_scene.tscn"


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func():
		push_error("点群モードの書き出しが完了しませんでした")
		quit(1)
	)
	call_deferred("_record")


func _record() -> void:
	root.size = Vector2i(1280, 720)
	# GameSettingsは窓からフォーカスが外れると全部の音を消す。書き出しの窓は前に出ないことがあるので、毎フレーム消音を外す。
	process_frame.connect(func(): AudioServer.set_bus_mute(0, false))
	var warmup := root.get_node("ShaderWarmup")
	warmup.set("_done", true)
	warmup.set_process(false)
	warmup.get("_screen").hide()
	# 先読みは起動時に 3D の描画を止め、終わると戻す。途中で止めたので自分で戻す。
	root.disable_3d = false
	var stage: Node3D = load(STAGE).instantiate()
	root.add_child(stage)
	current_scene = stage
	await _frames(30)
	# 開始位置へ機体を置き、通常表示を見せてから点群表示に切り替える。
	var car := get_first_node_in_group("player") as VehicleBody3D
	root.get_node("PowerUps")._move_player_to(car, Transform3D(Basis(Vector3.UP, deg_to_rad(45.0)), Vector3(72.17, 0.6, -112.58)))
	await _frames(30)
	await create_timer(2.0).timeout
	var lidar_view := root.get_node("LidarView")
	lidar_view.set_enabled(true)
	# 開けた方向へ 7 秒まっすぐ走り、止まってから 3 秒見せる。
	Input.action_press("up")
	await create_timer(7.0).timeout
	Input.action_release("up")
	await create_timer(3.0).timeout
	var map := root.get_node("Map")
	map.open()
	await create_timer(2.0, true).timeout
	map.close()
	await create_timer(1.0).timeout
	lidar_view.set_enabled(false)
	await create_timer(2.0).timeout
	quit()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await create_timer(0.02).timeout

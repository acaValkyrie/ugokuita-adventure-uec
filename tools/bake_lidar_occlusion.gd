# 機体自身にさえぎられる方向の表を作り直す。機体のモデルを変えたら流す。実行: Godot --headless --path . --script res://tools/bake_lidar_occlusion.gd
extends SceneTree


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	for pair in [["res://src/vehicle/car.tscn", SimulatedLidar.NEO_OCCLUSION_PATH], ["res://src/vehicle/car_classic.tscn", SimulatedLidar.CLASSIC_OCCLUSION_PATH]]:
		var scene_path: String = pair[0]
		var path: String = pair[1]
		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_error("機体のシーンを読み込めません: " + scene_path)
			quit(1)
			return
		var car := packed.instantiate() as VehicleBody3D
		if car == null:
			push_error("機体のシーンが VehicleBody3D ではありません: " + scene_path)
			quit(1)
			return
		car.freeze = true
		root.get_node("GameSettings").set("robot_model", car.get("robot_key"))
		root.add_child(car)
		var lidar := SimulatedLidar.new()
		root.add_child(lidar)
		lidar.setup(car, null)
		var cells := lidar.build_occlusion()
		if cells.is_empty():
			push_error("遮蔽表を作れません: " + scene_path)
			lidar.free()
			car.queue_free()
			quit(1)
			return
		var table := LidarOcclusionTable.new()
		table.u_bins = SimulatedLidar.OCCLUSION_U_BINS
		table.v_bins = SimulatedLidar.OCCLUSION_V_BINS
		table.occluded = cells
		var error := ResourceSaver.save(table, path)
		var occluded := 0
		for cell in cells:
			occluded += cell
		print("OCCLUSION_BAKE scene=%s path=%s occluded=%d total=%d error=%d" % [scene_path, path, occluded, cells.size(), error])
		lidar.free()
		car.queue_free()
		await process_frame
		if error != OK:
			push_error("遮蔽表を保存できません: %s (error=%d)" % [path, error])
			quit(1)
			return
	quit()

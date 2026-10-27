extends Node3D

# 新倉庫（Web 版では gomi.pck）を読み込めたら、この位置に置く


func _ready() -> void:
	DeferredPacks.when_ready(&"gomi", _spawn)


func _spawn() -> void:
	var scene := load("res://gomi_station.tscn") as PackedScene
	var station = scene.instantiate()
	station.name = "GomiStation"
	station.axis_lock_angular_z = true
	# ライトマップは新倉庫がメインシーンの直下の GomiStation だったときに焼いたので、同じ名前と位置で置き、あとから足した新倉庫にも当たるようライトマップを付け直す
	station.transform = transform
	add_sibling(station)
	var lightmaps := get_parent().find_children("*", "LightmapGI", false, false)
	if not lightmaps.is_empty():
		var lightmap := lightmaps[0] as LightmapGI
		if lightmap.light_data != null:
			var data := lightmap.light_data
			lightmap.light_data = null
			lightmap.light_data = data

extends Node3D

# 新倉庫（Web 版では gomi.pck）を読み込めたら、この位置に置く

# 新倉庫の当たり判定
const COLLISION_SHAPE_PATH := "res://assets/models/GOMI_collision.res"
# ED3 のスクリプト
const ENDING_SCRIPT_PATH := "res://gomi_ending.gd"

var _preloaded: Array = []


func _ready() -> void:
	DeferredPacks.when_ready(&"gomi", _spawn)


# 読み込みを1フレームにまとめると Web 版で約0.5秒止まるため、重い当たり判定（約180ms）と ED3 のスクリプト（約50ms）を別のフレームで先に読む
func _spawn() -> void:
	# pck を開いたのと同じフレームにならないよう、1フレーム待つ
	await get_tree().process_frame
	_preloaded.append(load(COLLISION_SHAPE_PATH))
	await get_tree().process_frame
	_preloaded.append(load(ENDING_SCRIPT_PATH))
	await get_tree().process_frame
	var scene := load("res://gomi_station.tscn") as PackedScene
	await get_tree().process_frame
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
	_preloaded.clear()

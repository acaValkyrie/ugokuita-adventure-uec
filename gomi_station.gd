extends StaticBody3D

const GOMI_RENDER_LAYER := 1
const GOMI_SHADOW_LAYER := 4
const FADE_START_DISTANCE := 2.0
const FADE_FULL_DISTANCE := 1.0
const StairProximity = preload("res://stair_proximity.gd")

@onready var _outside_stairs: MeshInstance3D = $OutsideStairs

var _proximity := StairProximity.new()
var _fade_materials: Array[BaseMaterial3D] = []
var _outside_alpha := 0.0


func _ready() -> void:
	_outside_stairs.hide()
	_proximity.setup(_outside_stairs)
	# GeometryInstance3D.transparencyはForward+専用。Compatibilityでも
	# フェードするよう屋外階段のマテリアルだけを複製する。
	for surface in _outside_stairs.mesh.get_surface_count():
		var material := _outside_stairs.get_active_material(surface).duplicate() as BaseMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_outside_stairs.set_surface_override_material(surface, material)
		_fade_materials.append(material)
	_set_outside_alpha(0.0)
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_instance == null:
		return
	mesh_instance.layers = GOMI_RENDER_LAYER | GOMI_SHADOW_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_set_outside_alpha(0.0)
		return

	# 屋外階段の表示は、機体外形と実際の屋外階段メッシュとの距離だけで決める。
	var distance := _proximity.distance_to(player, FADE_START_DISTANCE)
	_set_outside_alpha(clampf((FADE_START_DISTANCE - distance) / (FADE_START_DISTANCE - FADE_FULL_DISTANCE), 0.0, 1.0))


func _set_outside_alpha(alpha: float) -> void:
	_outside_alpha = alpha
	_outside_stairs.visible = alpha > 0.0
	for material in _fade_materials:
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color

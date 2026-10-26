extends StaticBody3D

signal surplus_bin_entered(bin_id: StringName, body: Node3D)
signal surplus_bin_exited(bin_id: StringName, body: Node3D)

const GOMI_RENDER_LAYER := 1
const GOMI_SHADOW_LAYER := 4
const FADE_START_DISTANCE := 2.0
const FADE_FULL_DISTANCE := 1.0
const StairProximity = preload("res://stair_proximity.gd")

@onready var _outside_stairs: MeshInstance3D = $OutsideStairs

var _proximity := StairProximity.new()
var _fade_materials: Array[BaseMaterial3D] = []
var _outside_alpha := 0.0
var _surplus_bin_areas: Dictionary = {}


func _ready() -> void:
	_setup_surplus_bins()
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


func _setup_surplus_bins() -> void:
	for bin in $SurplusContents/BinContents.get_children():
		var bin_id := StringName(bin.name)
		var area := bin.get_node("Interior") as Area3D
		_surplus_bin_areas[bin_id] = area
		area.body_entered.connect(_on_surplus_bin_body_entered.bind(bin_id))
		area.body_exited.connect(_on_surplus_bin_body_exited.bind(bin_id))


# Area3Dの重なりは物理フレームで更新される。
func get_surplus_bin_ids_for_body(body: Node3D) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not _is_surplus_bin_visitor(body):
		return ids
	for bin_id in _surplus_bin_areas:
		if (_surplus_bin_areas[bin_id] as Area3D).overlaps_body(body):
			ids.append(bin_id)
	return ids


func get_bodies_in_surplus_bin(bin_id: StringName) -> Array[Node3D]:
	var bodies: Array[Node3D] = []
	var area := _surplus_bin_areas.get(bin_id) as Area3D
	if area == null:
		return bodies
	for body in area.get_overlapping_bodies():
		if _is_surplus_bin_visitor(body):
			bodies.append(body)
	return bodies


func _is_surplus_bin_visitor(body: Node3D) -> bool:
	# playerグループの現行機体と、単独で使う車/旧CharacterBodyの両方に対応。
	# 棚やNadeggなどのStaticBodyは検知対象にしない。
	return is_instance_valid(body) and (body.is_in_group("player") or body is VehicleBody3D or body is CharacterBody3D)


func _on_surplus_bin_body_entered(body: Node3D, bin_id: StringName) -> void:
	if _is_surplus_bin_visitor(body):
		surplus_bin_entered.emit(bin_id, body)


func _on_surplus_bin_body_exited(body: Node3D, bin_id: StringName) -> void:
	if _is_surplus_bin_visitor(body):
		surplus_bin_exited.emit(bin_id, body)


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

extends StaticBody3D

const GOMI_RENDER_LAYER := 1
const GOMI_SHADOW_LAYER := 4

func _ready() -> void:
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_instance == null:
		return
	mesh_instance.layers = GOMI_RENDER_LAYER | GOMI_SHADOW_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

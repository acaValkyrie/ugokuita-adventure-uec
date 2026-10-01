@tool
extends EditorScenePostImport

# ステージ用GLBの取り込み時に、ローポリ版の建物を取り除き、建物・地面・オブジェクトのメッシュへ当たり判定を自動で付ける
const COLLIDABLE_PREFIXES := ["hi_", "ground", "object", "UEC", "本館B"]


func _post_import(scene: Node) -> Object:
	for child in scene.get_children():
		if _is_low_poly(child.name):
			scene.remove_child(child)
			child.free()
		elif _is_collidable(child.name):
			_add_collisions(child)
	return scene


func _is_low_poly(node_name: String) -> bool:
	return node_name == "low-building" or node_name.begins_with("buil_")


func _is_collidable(node_name: String) -> bool:
	for prefix in COLLIDABLE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _add_collisions(node: Node) -> void:
	for child in node.get_children():
		_add_collisions(child)
	if node is MeshInstance3D:
		node.create_trimesh_collision()

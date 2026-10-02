@tool
extends EditorScenePostImport

# 機体GLBの取り込み時に、部品のメッシュをマテリアルごとに1つへまとめて描画回数を減らす
# car.gd がタイヤを回すために使うノードはまとめずそのまま残す
# 次のパスは car.gd の WHEELS（parts）と一致させること
const KEEP_SUBTREES: Array[String] = [
	"Main Frame III v42/4944825545635 v13_1/4944825545635 v13",
	"Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)",
	"Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body48",
	"Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body1_001",
	"Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body2_008",
	"Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body1_024",
]

# 残すノード（サブツリー全体と、その祖先）
var _keep := {}


func _post_import(scene: Node) -> Object:
	_keep.clear()
	# 残すノードのパスが取り込み後のシーンに存在するか確かめる。1つでも無ければ何も変えない
	for path in KEEP_SUBTREES:
		var node := scene.get_node_or_null(NodePath(path))
		if node == null:
			push_error("robot_merge_import: 残すノードが見つからないためまとめを中止する: %s" % path)
			return scene
		_mark_subtree(node)
		var ancestor := node.get_parent()
		while ancestor != null:
			_keep[ancestor] = true
			ancestor = ancestor.get_parent()

	var sources: Array[MeshInstance3D] = []
	_collect_meshes(scene, sources)
	var kept_count := _count_meshes(scene) - sources.size()

	# マテリアル → 頂点フォーマット → {st, 元サーフェスの有無} の順でまとめる
	var groups := {}
	for mi in sources:
		var xform := _scene_transform(mi, scene)
		for i in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
				push_warning("robot_merge_import: 三角形以外のサーフェスを飛ばす: %s (%d)" % [mi.name, i])
				continue
			var material := _surface_material(mi, i)
			var format: int = mi.mesh.surface_get_format(i)
			if not groups.has(material):
				groups[material] = {}
			if not groups[material].has(format):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(material)
				groups[material][format] = st
			groups[material][format].append_from(mi.mesh, i, xform)

	# 元のメッシュを取り除き、空になった枝も片づける
	for mi in sources:
		mi.get_parent().remove_child(mi)
		mi.free()
	_prune_empty(scene)

	# まとめたメッシュをルート直下へ追加する
	var merged_count := 0
	for material in groups:
		for format in groups[material]:
			var st: SurfaceTool = groups[material][format]
			var merged := MeshInstance3D.new()
			merged.name = "Merged_%d" % merged_count
			merged.mesh = st.commit()
			scene.add_child(merged)
			merged.owner = scene
			merged_count += 1

	# ライトマップのベイク対象から外し、ベイクした間接光（プローブ）だけ受けるようにする
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC

	print("robot_merge_import: まとめた元メッシュ %d 個 -> %d 個、残したメッシュ %d 個" % [sources.size(), merged_count, kept_count])
	return scene


func _mark_subtree(node: Node) -> void:
	_keep[node] = true
	for child in node.get_children():
		_mark_subtree(child)


# 残す対象に含まれないMeshInstance3Dを集める
func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null and not _keep.has(node):
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)


func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count


# サーフェスのオーバーライド、material_override、メッシュ本来のマテリアルの順で採用する
func _surface_material(mi: MeshInstance3D, surface: int) -> Material:
	var material := mi.get_surface_override_material(surface)
	if material == null:
		material = mi.material_override
	if material == null:
		material = mi.mesh.surface_get_material(surface)
	return material


# 子が無くなった素のNode3Dを、残す対象を除いて取り除く
func _prune_empty(node: Node) -> void:
	for child in node.get_children():
		_prune_empty(child)
		if child.get_class() == "Node3D" and child.get_child_count() == 0 and not _keep.has(child):
			node.remove_child(child)
			child.free()


# 取り込み中はSceneTree外でglobal_transformが使えないため、rootの手前まで親のtransformを掛け合わせる
func _scene_transform(node: Node3D, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = current.transform * result
		current = current.get_parent()
	return result

# 機体の基板の部品を扱う共通の設定と関数
# robot_merge_import.gd（取り込み時に背の低い部品を取り除く）と
# tools/bake_board_textures.gd（部品を写した画像を撮る）が preload して使う
extends RefCounted

# 取り込み元のファイル名 → 基板ごとの設定の配列
# group: シーンのルートから、部品を直接の子に持つノードまでのパス
# board: group の直接の子のうち、素の基板のメッシュを含むものの名前
# top_height: 基板の上面から、これ以下しか出っ張らない部品を背が低いとみなして取り除く（group ローカルの単位、ここでは mm。0 ならこの側は取り除かない）
# bottom_height: 基板の下面から、これ以下しか下に出ない部品について同様に判定する（0 なら取り除かない）
# texture: 部品を写した画像。"" なら取り除くだけで貼らない
# view: texture を撮って貼る面。"top" は上面（+Y 側）、"bottom" は下面（-Y 側）
const BOARDS := {
	"ugokuita-neo.glb": [
		{
			# 主基板。機体の中の板の下に隠れて見えないので、部品を取り除くだけ
			"group": "Main Frame III v42/UgokuIta_Main v4_1/UgokuIta_Main v4",
			"board": "UgokuIta_Main_PCB_1",
			"top_height": 3.5,
			"bottom_height": 3.5,
			"texture": "",
			"view": "top",
		},
		{
			# Jetson のキャリア基板。裏返しに付いていて下面が上から見えるので、下面の部品を写した画像を貼る。上面は見えないので取り除くだけ
			"group": "Main Frame III v42/P3766-P3768SKU4-P3767ENVELOPE v4_1/P3766-P3768SKU4-P3767ENVELOPE v4/600-13768-0000-A04_ASM_1/600-13768-0000-A04_ASM",
			"board": "600-13768-0000-A04_1",
			"top_height": 3.5,
			"bottom_height": 3.5,
			"texture": "res://assets/textures/boards/jetson_carrier_bottom.png",
			"view": "bottom",
		},
	],
}


# node から ancestor の手前までの transform を掛け合わせる
# 取り込み中はシーンが SceneTree の外にあり、global_transform が使えないため
static func transform_to(node: Node3D, ancestor: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


# group の子 board_name の配下（自身を含む）にある、最初のメッシュを返す。無ければ null
static func find_board_mesh(group: Node3D, board_name: String) -> MeshInstance3D:
	var board := group.get_node_or_null(NodePath(board_name))
	if board == null:
		return null
	return _first_mesh(board)


static func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


# group の直接の子のうち、基板の上下に少ししか出っ張らない（背の低い）部品を返す
# 基板そのもの（board_mesh を含む子）は対象にしない
static func find_low_parts(group: Node3D, board_mesh: MeshInstance3D, top_height: float, bottom_height: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var board_box := transform_to(board_mesh, group) * board_mesh.mesh.get_aabb()
	for child in group.get_children():
		if not child is Node3D:
			continue
		if child == board_mesh or child.is_ancestor_of(board_mesh):
			continue
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(child, meshes)
		if meshes.is_empty():
			continue
		var part_box := AABB()
		for i in meshes.size():
			var box := transform_to(meshes[i], group) * meshes[i].mesh.get_aabb()
			part_box = box if i == 0 else part_box.merge(box)
		var is_low_top := top_height > 0.0 \
				and part_box.position.y >= board_box.position.y - 0.01 \
				and part_box.end.y <= board_box.end.y + top_height
		var is_low_bottom := bottom_height > 0.0 \
				and part_box.end.y <= board_box.end.y + 0.01 \
				and part_box.position.y >= board_box.position.y - bottom_height
		if is_low_top or is_low_bottom:
			result.append(child)
	return result


# node 自身と子孫のうち、メッシュを持つ MeshInstance3D を集める
static func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)


# メッシュの頂点の X・Z を AABB の範囲で 0〜1 にしたものを UV にする（真上から貼る投影）
# 画像の左はどちらの面でもメッシュの -X。上は "top" なら -Z、"bottom" なら +Z
# bake_board_textures.gd のカメラの向きと合わせる
# 反対側の面と側面にも同じ投影がかかるが、薄くて目立たない
static func set_projected_uv(mi: MeshInstance3D, view: String) -> void:
	var old_mesh := mi.mesh
	var aabb := old_mesh.get_aabb()
	var new_mesh := ArrayMesh.new()
	for i in old_mesh.get_surface_count():
		var arrays := old_mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs := PackedVector2Array()
		uvs.resize(verts.size())
		for j in verts.size():
			var v := verts[j]
			var u := (v.x - aabb.position.x) / aabb.size.x
			# 下から見ると上下が逆になる
			var w := (aabb.end.z - v.z) / aabb.size.z if view == "bottom" else (v.z - aabb.position.z) / aabb.size.z
			uvs[j] = Vector2(u, w)
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		new_mesh.add_surface_from_arrays(old_mesh.surface_get_primitive_type(i), arrays)
		new_mesh.surface_set_material(i, old_mesh.surface_get_material(i))
		new_mesh.surface_set_name(i, old_mesh.surface_get_name(i))
	mi.mesh = new_mesh

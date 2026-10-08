@tool
extends EditorScenePostImport

# 機体の取り込み時に、部品のメッシュをマテリアルごとに1つへまとめて描画回数を減らす
# car.gd がタイヤを回すために使うノードはまとめずそのまま残す
# 次のパスは car.gd の MODELS の wheels と一致させること
# 取り込み元のファイル名 → 残すノードのパス
const KEEP_SUBTREES := {
	"ugokuita-neo.glb": [
		"Main Frame III v42/4944825545635 v13_1/4944825545635 v13",
		"Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)",
		"Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body48",
		"Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body1_001",
		"Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body2_008",
		"Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body1_024",
	],
	"ugokuita-classic.fbx": [
		"MainFrame - Reverse Prototype v12/350W Hub Motor v10_1/350W Hub Motor v10",
		"MainFrame - Reverse Prototype v12/350W Hub Motor v10_2/350W Hub Motor v102",
		"MainFrame - Reverse Prototype v12/STM-100 VS v4_1/STM-100 VS v4",
		"MainFrame - Reverse Prototype v12/STM-100 VS v4_2/STM-100 VS v42",
	],
}

# 取り込み元のファイル名 → {差し替えるマテリアルの名前: 差し替え先のマテリアルのパス}
# Fusion から書き出すと木目などの外観の画像が含まれず、色も黒になるため
const MATERIAL_OVERRIDES := {
	"ugokuita-classic.fbx": {
		"Oak": "res://assets/textures/oak_veneer_03/oak_veneer_03.tres",
	},
}

# 取り込み元のファイル名 → 取り除くノードのパス（ゲームで見せない部品）
const REMOVE_NODES := {
	"ugokuita-classic.fbx": [
		# Livox Mid-70 の視野（FOV）を示す形状。センサー本体は残す
		"MainFrame - Reverse Prototype v12/Livox Mid-70 3D Model and FOV Shape v4_1/Livox Mid-70 3D Model and FOV Shape v4/Body342",
	],
}

# 取り込み元のファイル名 → 面の向きを直すノードのパス（書き出し時に一部の面が内向きに裏返っている部品）
const FIX_FACE_NODES := {
	"ugokuita-classic.fbx": [
		# Livox Mid-70 の本体。側面が内向きで、裏面カリングにより透けて見える
		"MainFrame - Reverse Prototype v12/Livox Mid-70 3D Model and FOV Shape v4_1/Livox Mid-70 3D Model and FOV Shape v4/Body232",
	],
}

# 取り込み元のファイル名 → {ノードのパス: 色}（そのノードのマテリアルを複製して色だけ変える）
const NODE_COLORS := {
	"ugokuita-classic.fbx": {
		# 後方の板の下に付いている3Dプリント部品。元は黄色
		"MainFrame - Reverse Prototype v12/Version_2_Complete v11_1/Version_2_Complete v11/Component1_1/Component1/MeshBody1 (1) (2) (1) (1)": Color("#f47731"),
		"MainFrame - Reverse Prototype v12/Version_2_Complete v11_1/Version_2_Complete v11/Component1_1/Component1/MeshBody1 (1) (2) (1) (1) (1)": Color("#f47731"),
		"MainFrame - Reverse Prototype v12/Version_2_Complete v11_1/Version_2_Complete v11/MeshBody1 (1) (1)": Color("#f47731"),
		# Livox Mid-70 の本体。元は黄色だが実物は銀色
		"MainFrame - Reverse Prototype v12/Livox Mid-70 3D Model and FOV Shape v4_1/Livox Mid-70 3D Model and FOV Shape v4/Body232": Color("#c8cbcf"),
	},
}

# 残すノード（サブツリー全体と、その祖先）
var _keep := {}
# マテリアルの名前 → 差し替え先として読み込んだマテリアル
var _overrides := {}
# 差し替えたサーフェスの数
var _override_count := 0


func _post_import(scene: Node) -> Object:
	_keep.clear()
	var source_name := get_source_file().get_file()
	_overrides.clear()
	_override_count = 0
	var override_paths: Dictionary = MATERIAL_OVERRIDES.get(source_name, {})
	for material_name in override_paths:
		var loaded := load(override_paths[material_name]) as Material
		if loaded == null:
			push_error("robot_merge_import: 差し替え先のマテリアルを読み込めないため飛ばす: %s" % override_paths[material_name])
			continue
		_overrides[material_name] = loaded
	if not KEEP_SUBTREES.has(source_name):
		push_error("robot_merge_import: 残すノードの設定が無いためまとめを中止する: %s" % source_name)
		return scene
	# ゲームで見せない部品を取り除く
	var removed_count := 0
	for path in REMOVE_NODES.get(source_name, []):
		var target := scene.get_node_or_null(NodePath(path))
		if target == null:
			push_warning("robot_merge_import: 取り除くノードが見つからないため飛ばす: %s" % path)
			continue
		target.get_parent().remove_child(target)
		target.free()
		removed_count += 1
	# 内向きになっている面の向きを直す
	var flipped_count := 0
	for path in FIX_FACE_NODES.get(source_name, []):
		var fix_mi := scene.get_node_or_null(NodePath(path)) as MeshInstance3D
		if fix_mi == null or fix_mi.mesh == null:
			push_warning("robot_merge_import: 面の向きを直すノードが見つからないため飛ばす: %s" % path)
			continue
		flipped_count += _fix_inward_faces(fix_mi)
	# 指定したノードの色を変える。同じ色のノードは複製したマテリアルを共有する
	# （メッシュをまとめるとき、同じマテリアル同士で1つにまとまるようにするため）
	var recolored_count := 0
	var color_materials := {}
	var node_colors: Dictionary = NODE_COLORS.get(source_name, {})
	for path in node_colors:
		var mi := scene.get_node_or_null(NodePath(path)) as MeshInstance3D
		if mi == null or mi.mesh == null:
			push_warning("robot_merge_import: 色を変えるノードが見つからないため飛ばす: %s" % path)
			continue
		var color: Color = node_colors[path]
		if not color_materials.has(color):
			var base := _original_material(mi, 0) as BaseMaterial3D
			if base == null:
				push_warning("robot_merge_import: 色を変えるマテリアルが BaseMaterial3D ではないため飛ばす: %s" % path)
				continue
			var copy := base.duplicate() as BaseMaterial3D
			copy.albedo_color = color
			color_materials[color] = copy
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, color_materials[color])
		recolored_count += 1
	# 残すノードのパスが取り込み後のシーンに存在するか確かめる。1つでも無ければ何も変えない
	for path in KEEP_SUBTREES[source_name]:
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
	var lod_count := 0
	for material in groups:
		for format in groups[material]:
			var st: SurfaceTool = groups[material][format]
			var merged := MeshInstance3D.new()
			merged.name = "Merged_%d" % merged_count
			# ImporterMesh経由でLODを生成する
			var importer_mesh := ImporterMesh.new()
			importer_mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays(), [], {}, material)
			importer_mesh.generate_lods(25.0, 60.0, [])
			lod_count += importer_mesh.get_surface_lod_count(0)
			merged.mesh = importer_mesh.get_mesh()
			scene.add_child(merged)
			merged.owner = scene
			merged_count += 1

	# ライトマップのベイク対象から外し、ベイクした間接光（プローブ）だけ受けるようにする
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC

	print("robot_merge_import: まとめた元メッシュ %d 個 -> %d 個、残したメッシュ %d 個、LOD合計 %d 段、差し替えたマテリアル %d 面、取り除いた部品 %d 個、色を変えた部品 %d 個、向きを直した面 %d 枚" % [sources.size(), merged_count, kept_count, lod_count, _override_count, removed_count, recolored_count, flipped_count])
	return scene


# 内向きの三角形を外向きに直し、裏返した三角形の数を返す
# 隣り合う三角形の巻き順の食い違いをたどって向きをそろえ、閉じた形の体積の符号で全体の表裏を決める
func _fix_inward_faces(mi: MeshInstance3D) -> int:
	var mesh := mi.mesh
	var all_arrays: Array = []
	var total_flipped := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		if mesh.surface_get_primitive_type(i) == Mesh.PRIMITIVE_TRIANGLES:
			total_flipped += _flip_inward_triangles(arrays)
		all_arrays.append(arrays)
	if total_flipped == 0:
		return 0
	# 向きを直したサーフェスを含むため、メッシュを作り直して差し替える
	var fixed := ArrayMesh.new()
	for i in mesh.get_surface_count():
		fixed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, all_arrays[i])
		fixed.surface_set_material(i, mesh.surface_get_material(i))
		fixed.surface_set_name(i, mesh.surface_get_name(i))
	mi.mesh = fixed
	return total_flipped


# 1つのサーフェスの配列を直接書き換えて内向きの三角形を裏返し、裏返した数を返す
func _flip_inward_triangles(arrays: Array) -> int:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null and not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		indices.resize(verts.size())
		for i in verts.size():
			indices[i] = i
	var tri_count := indices.size() / 3

	# 位置が同じ頂点を同じ点IDにまとめる（法線やUVの継ぎ目で頂点が分かれていても隣を判定できるように）
	var weld_ids := PackedInt32Array()
	weld_ids.resize(verts.size())
	var weld := {}
	for i in verts.size():
		var p := verts[i]
		var key := Vector3i(roundi(p.x * 1e6), roundi(p.y * 1e6), roundi(p.z * 1e6))
		if not weld.has(key):
			weld[key] = weld.size()
		weld_ids[i] = weld[key]

	# 辺 → [三角形番号, 小さい点IDから大きい点IDへたどっているか] の配列
	var edges := {}
	for t in tri_count:
		for c in 3:
			var a := weld_ids[indices[t * 3 + c]]
			var b := weld_ids[indices[t * 3 + (c + 1) % 3]]
			if a == b:
				continue
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not edges.has(key):
				edges[key] = []
			edges[key].append([t, a < b])

	# 向きの伝播: 辺をちょうど2枚で共有する隣同士の巻き順をそろえる（flip: -1 未決定、0 そのまま、1 裏返す）
	var flip := PackedInt32Array()
	flip.resize(tri_count)
	flip.fill(-1)
	var component := PackedInt32Array()
	component.resize(tri_count)
	var comp_count := 0
	for start in tri_count:
		if flip[start] != -1:
			continue
		flip[start] = 0
		component[start] = comp_count
		var queue: Array[int] = [start]
		var head := 0
		while head < queue.size():
			var u := queue[head]
			head += 1
			for c in 3:
				var a := weld_ids[indices[u * 3 + c]]
				var b := weld_ids[indices[u * 3 + (c + 1) % 3]]
				if a == b:
					continue
				var shared: Array = edges[Vector2i(mini(a, b), maxi(a, b))]
				if shared.size() != 2:
					continue
				var mine: Array = shared[0] if shared[0][0] == u else shared[1]
				var other: Array = shared[1] if shared[0][0] == u else shared[0]
				var v: int = other[0]
				if v == u or flip[v] != -1:
					continue
				# 同じ向きにたどっていれば巻き順が食い違っているので逆に、逆向きなら同じにする
				var same_direction: bool = mine[1] == other[1]
				flip[v] = (1 - flip[u]) if same_direction else flip[u]
				component[v] = comp_count
				queue.append(v)
		comp_count += 1

	# 成分ごとの符号付き体積。Godot では時計回りが表なので、外向きの閉じた形なら負になる
	var volumes := PackedFloat64Array()
	volumes.resize(comp_count)
	for t in tri_count:
		var v0 := verts[indices[t * 3]]
		var v1 := verts[indices[t * 3 + 1]]
		var v2 := verts[indices[t * 3 + 2]]
		if flip[t] == 1:
			var swap := v1
			v1 = v2
			v2 = swap
		volumes[component[t]] += v0.dot(v1.cross(v2))
	for t in tri_count:
		if volumes[component[t]] > 0.0:
			flip[t] = 1 - flip[t]

	# 裏返す三角形と、そうでない三角形がそれぞれ使う頂点を数える
	var flipped_use := PackedInt32Array()
	flipped_use.resize(verts.size())
	var normal_use := PackedInt32Array()
	normal_use.resize(verts.size())
	var flipped_count := 0
	for t in tri_count:
		for c in 3:
			if flip[t] == 1:
				flipped_use[indices[t * 3 + c]] += 1
			else:
				normal_use[indices[t * 3 + c]] += 1
		if flip[t] == 1:
			flipped_count += 1
	if flipped_count == 0:
		return 0

	# 両方の三角形が使う頂点は複製し、裏返す三角形を複製側へ付け替える
	var vertex_count := verts.size()
	var duplicates := {}
	var dup_sources: Array[int] = []
	for t in tri_count:
		if flip[t] != 1:
			continue
		for c in 3:
			var vi := indices[t * 3 + c]
			if normal_use[vi] == 0:
				continue
			if not duplicates.has(vi):
				duplicates[vi] = vertex_count + dup_sources.size()
				dup_sources.append(vi)
			indices[t * 3 + c] = duplicates[vi]
	# 頂点属性の配列すべての末尾に、複製した頂点の分を足す
	for k in arrays.size():
		if k == Mesh.ARRAY_INDEX or arrays[k] == null:
			continue
		var attr = arrays[k]
		if attr.is_empty() or attr.size() % vertex_count != 0:
			continue
		var stride: int = attr.size() / vertex_count
		for src in dup_sources:
			for j in stride:
				attr.append(attr[src * stride + j])
		arrays[k] = attr

	# 法線の反転。裏返す三角形だけが使う頂点と、複製した頂点が対象
	var flip_vertices: Array[int] = []
	for vi in vertex_count:
		if flipped_use[vi] > 0 and normal_use[vi] == 0:
			flip_vertices.append(vi)
	for src in dup_sources:
		flip_vertices.append(duplicates[src])
	if arrays[Mesh.ARRAY_NORMAL] != null and not (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).is_empty():
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for vi in flip_vertices:
			normals[vi] = -normals[vi]
		arrays[Mesh.ARRAY_NORMAL] = normals
	if arrays[Mesh.ARRAY_TANGENT] != null and not (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).is_empty():
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for vi in flip_vertices:
			tangents[vi * 4 + 3] = -tangents[vi * 4 + 3]
		arrays[Mesh.ARRAY_TANGENT] = tangents

	# 巻き順を反転（インデックスの2番目と3番目を入れ替える）
	for t in tri_count:
		if flip[t] == 1:
			var tmp := indices[t * 3 + 1]
			indices[t * 3 + 1] = indices[t * 3 + 2]
			indices[t * 3 + 2] = tmp
	arrays[Mesh.ARRAY_INDEX] = indices
	return flipped_count


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
	var material := _original_material(mi, surface)
	# 差し替えはまとめる対象のメッシュにだけ効く（KEEP_SUBTREES で残すメッシュには効かない。Oak は残す対象に含まれない）
	if material != null and _overrides.has(material.resource_name):
		_override_count += 1
		return _overrides[material.resource_name]
	return material


# 名前による差し替えをする前のマテリアル（オーバーライド、material_override、メッシュ本来の順）
func _original_material(mi: MeshInstance3D, surface: int) -> Material:
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

extends SceneTree

# 実行: Godot --headless --path . --script res://tools/generate_gomi_split_meshes.gd
# 元OBJのUV2を再展開すると既存main_scene.lmbakeと一致しなくなるため、
# 本体は元の頂点バッファを保持し、階段だけ外壁で切断する。
const ORIGINAL := "res://assets/models/GOMI.obj"
const STAIRS_GROUP := "Body7:12"
const BODY_OUTPUT := "res://assets/models/gomi_station_without_long_stairs.res"
const INSIDE_OUTPUT := "res://assets/models/gomi_inside_stairs.res"
const OUTSIDE_OUTPUT := "res://assets/models/gomi_outside_stairs.res"
# Body5:20 の外壁外面は x=0、内面は x=1（メッシュ座標）。
const WALL_X := 0.0
const STAIRS_SURFACE := 108
const STAIRS_TRIANGLES := 3596

func _initialize() -> void:
	var source := load(ORIGINAL) as ArrayMesh
	assert(source != null)
	var original_arrays := source.surface_get_arrays(STAIRS_SURFACE)
	var selected_faces := _stairs_faces()
	var original_keys := _vertex_keys(original_arrays)
	var indices: PackedInt32Array = original_arrays[Mesh.ARRAY_INDEX]
	var body_indices := PackedInt32Array()
	var stair_indices := PackedInt32Array()
	for offset in range(0, indices.size(), 3):
		var key := _face_key(original_keys, indices, offset)
		var target := body_indices
		if selected_faces.get(key, 0) > 0:
			target = stair_indices
			selected_faces[key] -= 1
		for corner in range(3):
			target.append(indices[offset + corner])
	assert(stair_indices.size() == STAIRS_TRIANGLES * 3)
	assert(body_indices.size() + stair_indices.size() == indices.size())
	for remaining in selected_faces.values():
		assert(remaining == 0, "階段の面が元モデルと一致しません")

	var surfaces: Array = source.get("_surfaces").duplicate(true)
	_set_indices(surfaces[STAIRS_SURFACE], body_indices)
	var body := ArrayMesh.new()
	body.set("_surfaces", surfaces)
	body.lightmap_size_hint = source.lightmap_size_hint
	assert(ResourceSaver.save(body, BODY_OUTPUT, ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_COMPRESS) == OK)
	_verify_body(source, body, body_indices)
	var inside := _split_stairs(source, original_arrays, stair_indices, true)
	var outside := _split_stairs(source, original_arrays, stair_indices, false)
	assert(ResourceSaver.save(inside, INSIDE_OUTPUT, ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceSaver.save(outside, OUTSIDE_OUTPUT, ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_COMPRESS) == OK)
	var original_area := _area(original_arrays, stair_indices)
	var split_area := _area(inside.surface_get_arrays(0), inside.surface_get_arrays(0)[Mesh.ARRAY_INDEX]) + _area(outside.surface_get_arrays(0), outside.surface_get_arrays(0)[Mesh.ARRAY_INDEX])
	assert(absf(split_area - original_area) < original_area * 0.00001, "切断で階段の面積が変化しました")
	print("Gomi split meshes: 元UV2保持、本体 %d surfaces、屋内 %d / 屋外 %d triangles、面積誤差 %f" % [body.get_surface_count(), inside.surface_get_array_index_len(0) / 3, outside.surface_get_array_index_len(0) / 3, split_area - original_area])
	quit()


func _vertex_keys(arrays: Array) -> PackedStringArray:
	var keys := PackedStringArray()
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		keys.append(_vertex_key(arrays[Mesh.ARRAY_VERTEX][i]))
	return keys


func _face_key(keys: PackedStringArray, indices: PackedInt32Array, offset: int) -> String:
	var corners := PackedStringArray([keys[indices[offset]], keys[indices[offset + 1]], keys[indices[offset + 2]]])
	corners.sort()
	return ":".join(corners)


func _vertex_key(vertex: Vector3) -> String:
	return var_to_bytes(vertex).hex_encode()


func _stairs_faces() -> Dictionary:
	# 元OBJのグループから面を選ぶ。補助OBJの再インポートやUV2再生成は不要。
	var file := FileAccess.open(ORIGINAL, FileAccess.READ)
	assert(file != null)
	var vertices := PackedVector3Array()
	var group := ""
	var counts := {}
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("g "):
			group = line.substr(2)
		elif line.begins_with("v "):
			var values := line.split(" ", false)
			vertices.append(Vector3(float(values[1]), float(values[2]), float(values[3])))
		elif group == STAIRS_GROUP and line.begins_with("f "):
			var face := line.split(" ", false)
			assert(face.size() == 4)
			var keys := PackedStringArray()
			for corner in range(1, 4):
				var indices := face[corner].split("/")
				keys.append(_vertex_key(vertices[int(indices[0]) - 1]))
			keys.sort()
			var key := ":".join(keys)
			counts[key] = counts.get(key, 0) + 1
	return counts


func _set_indices(surface: Dictionary, indices: PackedInt32Array) -> void:
	# Godotは頂点数65536未満の場合、16bitのインデックスを格納する。
	var data := PackedByteArray()
	var stride := 2 if surface.vertex_count < 65536 else 4
	data.resize(indices.size() * stride)
	for i in range(indices.size()):
		if stride == 2:
			data.encode_u16(i * stride, indices[i])
		else:
			data.encode_u32(i * stride, indices[i])
	surface.index_data = data
	surface.index_count = indices.size()
	# 分離前のLODには階段・本体の両方が入るため再利用しない。
	surface.erase("lods")


func _verify_body(source: ArrayMesh, body: ArrayMesh, body_indices: PackedInt32Array) -> void:
	for i in range(source.get_surface_count()):
		var original := source.surface_get_arrays(i)
		var split := body.surface_get_arrays(i)
		for channel in range(Mesh.ARRAY_MAX):
			if i == STAIRS_SURFACE and channel == Mesh.ARRAY_INDEX:
				assert(split[channel] == body_indices)
			else:
				assert(original[channel] == split[channel], "元頂点属性が変化しました")
		assert(source.surface_get_name(i) == body.surface_get_name(i))


func _split_stairs(source: ArrayMesh, original: Array, indices: PackedInt32Array, inside: bool) -> ArrayMesh:
	var arrays := original.duplicate(true)
	var clipped_indices := PackedInt32Array()
	for offset in range(0, indices.size(), 3):
		var polygon: Array[int] = []
		for corner in range(3):
			var a := indices[offset + corner]
			var b := indices[offset + (corner + 1) % 3]
			var ax: float = arrays[Mesh.ARRAY_VERTEX][a].x - WALL_X
			var bx: float = arrays[Mesh.ARRAY_VERTEX][b].x - WALL_X
			var a_inside := ax >= 0.0 if inside else ax <= 0.0
			if a_inside:
				polygon.append(a)
			if ax * bx < 0.0:
				polygon.append(_cut_vertex(arrays, a, b, ax / (ax - bx)))
		for corner in range(1, polygon.size() - 1):
			clipped_indices.append_array(PackedInt32Array([polygon[0], polygon[corner], polygon[corner + 1]]))
	arrays[Mesh.ARRAY_INDEX] = clipped_indices
	var mesh := ArrayMesh.new()
	# 圧縮UV2の再量子化を避ける。復号した元UV2と補間UV2をfloatのまま保存する。
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, 0)
	mesh.surface_set_material(0, source.surface_get_material(STAIRS_SURFACE))
	mesh.surface_set_name(0, source.surface_get_name(STAIRS_SURFACE))
	mesh.lightmap_size_hint = source.lightmap_size_hint
	var saved := mesh.surface_get_arrays(0)
	assert(saved[Mesh.ARRAY_TEX_UV2] == arrays[Mesh.ARRAY_TEX_UV2], "UV2が再量子化されました")
	for i in range(original[Mesh.ARRAY_VERTEX].size()):
		assert(saved[Mesh.ARRAY_TEX_UV2][i] == original[Mesh.ARRAY_TEX_UV2][i])
	for i in clipped_indices:
		var x: float = saved[Mesh.ARRAY_VERTEX][i].x
		assert(x >= WALL_X - 0.00001 if inside else x <= WALL_X + 0.00001)
	return mesh


func _cut_vertex(arrays: Array, a: int, b: int, weight: float) -> int:
	var index: int = arrays[Mesh.ARRAY_VERTEX].size()
	var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][a].lerp(arrays[Mesh.ARRAY_VERTEX][b], weight)
	point.x = WALL_X
	arrays[Mesh.ARRAY_VERTEX].append(point)
	arrays[Mesh.ARRAY_NORMAL].append(arrays[Mesh.ARRAY_NORMAL][a].lerp(arrays[Mesh.ARRAY_NORMAL][b], weight).normalized())
	for channel in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		arrays[channel].append(arrays[channel][a].lerp(arrays[channel][b], weight))
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var ta := Vector3(tangents[a * 4], tangents[a * 4 + 1], tangents[a * 4 + 2])
	var tb := Vector3(tangents[b * 4], tangents[b * 4 + 1], tangents[b * 4 + 2])
	var tangent := ta.lerp(tb, weight).normalized()
	arrays[Mesh.ARRAY_TANGENT].append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, tangents[a * 4 + 3]]))
	return index


func _area(arrays: Array, indices: PackedInt32Array) -> float:
	var area := 0.0
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for offset in range(0, indices.size(), 3):
		area += (vertices[indices[offset + 1]] - vertices[indices[offset]]).cross(vertices[indices[offset + 2]] - vertices[indices[offset]]).length() * 0.5
	return area

extends SceneTree

# 本体メッシュを許容誤差内のLODに置き換え、元の頂点とUV2を保つ。
# 実行: Godot --headless --path . --script res://tools/simplify_gomi_mesh.gd -- <max_error_m> [--write]
# generate_gomi_split_meshes.gd で再生成した後は、このスクリプトも再実行する。
const BODY := "res://assets/models/gomi_station_without_long_stairs.res"
# gomi_station.tscn の Mesh ノードの拡大縮小（メッシュの 1 は 0.1m）
const MESH_SCALE := 0.1

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or args.size() > 2 or not args[0].is_valid_float():
		push_error("引数は <max_error_m> [--write] を指定してください")
		quit(1)
		return
	var max_error_m := args[0].to_float()
	if not is_finite(max_error_m) or max_error_m <= 0.0:
		push_error("max_error_m は有限の正の数で指定してください")
		quit(1)
		return
	var write := args.size() == 2
	if write and args[1] != "--write":
		push_error("未対応の引数です: " + args[1])
		quit(1)
		return

	var source := load(BODY) as ArrayMesh
	if source == null or source.get_surface_count() == 0:
		push_error("本体のArrayMeshを読み込めません: " + BODY)
		quit(1)
		return
	var new_mesh := ArrayMesh.new()
	var before_triangles := 0
	var after_triangles := 0
	var kept_surfaces := 0
	var simplified_surfaces := 0
	var mismatch_count := 0
	for surface in range(source.get_surface_count()):
		var original_arrays := source.surface_get_arrays(surface)
		var material := source.surface_get_material(surface)
		var surface_name := source.surface_get_name(surface)
		var format := source.surface_get_format(surface)
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			push_error("三角形以外のsurfaceです: %d" % surface)
			quit(1)
			return
		var original_vertices: PackedVector3Array = original_arrays[Mesh.ARRAY_VERTEX]
		var original_uv2: PackedVector2Array = original_arrays[Mesh.ARRAY_TEX_UV2]
		if original_vertices.is_empty() or original_uv2.size() != original_vertices.size():
			push_error("頂点とUV2が揃っていません: surface %d" % surface)
			quit(1)
			return
		var original_indices: PackedInt32Array = original_arrays[Mesh.ARRAY_INDEX]
		var before_count := original_indices.size() if not original_indices.is_empty() else original_vertices.size()
		before_triangles += before_count / 3

		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, original_arrays, [], {}, material, surface_name, format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		importer.generate_lods(25.0, 60.0, [])
		var selected_lod := -1
		for lod in range(importer.get_surface_lod_count(0) - 1, -1, -1):
			if importer.get_surface_lod_size(0, lod) <= max_error_m / MESH_SCALE:
				selected_lod = lod
				break
		var arrays := original_arrays
		if selected_lod >= 0:
			arrays = importer.get_surface_arrays(0)
			var indices := importer.get_surface_lod_indices(0, selected_lod)
			arrays = _compact(arrays, indices)
			if arrays.is_empty():
				quit(1)
				return
			simplified_surfaces += 1
		else:
			kept_surfaces += 1

		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		if new_mesh.get_surface_count() != surface + 1:
			push_error("surfaceの作成に失敗しました: %d" % surface)
			quit(1)
			return
		new_mesh.surface_set_material(surface, material)
		new_mesh.surface_set_name(surface, surface_name)
		var saved_arrays := new_mesh.surface_get_arrays(surface)
		# 位置とUV2の組を1e-5に丸め、元のsurfaceと照合する。
		var original_pairs := {}
		for vertex in range(original_vertices.size()):
			var position := original_vertices[vertex]
			var uv2 := original_uv2[vertex]
			var key := "%d,%d,%d:%d,%d" % [roundi(position.x * 100000.0), roundi(position.y * 100000.0), roundi(position.z * 100000.0), roundi(uv2.x * 100000.0), roundi(uv2.y * 100000.0)]
			original_pairs[key] = true
		var kept_positions: PackedVector3Array = saved_arrays[Mesh.ARRAY_VERTEX]
		var kept_uv2: PackedVector2Array = saved_arrays[Mesh.ARRAY_TEX_UV2]
		for vertex in range(kept_positions.size()):
			var position := kept_positions[vertex]
			var uv2 := kept_uv2[vertex]
			var key := "%d,%d,%d:%d,%d" % [roundi(position.x * 100000.0), roundi(position.y * 100000.0), roundi(position.z * 100000.0), roundi(uv2.x * 100000.0), roundi(uv2.y * 100000.0)]
			if not original_pairs.has(key):
				mismatch_count += 1
		var final_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var after_count := final_indices.size() if not final_indices.is_empty() else kept_positions.size()
		after_triangles += after_count / 3

	new_mesh.lightmap_size_hint = source.lightmap_size_hint
	new_mesh.custom_aabb = source.custom_aabb
	print("三角形: %d -> %d" % [before_triangles, after_triangles])
	print("surface: 保持 %d / 簡略化 %d" % [kept_surfaces, simplified_surfaces])
	print("位置/UV2の不一致: %d" % mismatch_count)
	if mismatch_count > 0:
		push_error("元にない位置/UV2の組があるため保存しません")
		quit(1)
		return
	if write:
		# generate_gomi_split_meshes.gd と同じく、まとめて圧縮して保存する
		var error := ResourceSaver.save(new_mesh, BODY, ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("本体の保存に失敗しました: %s" % error_string(error))
			quit(1)
			return
		var saved := FileAccess.open(BODY, FileAccess.READ)
		if saved == null:
			push_error("保存後のファイルサイズを取得できません")
			quit(1)
			return
		print("保存: %s (%d bytes)" % [BODY, saved.get_length()])
	else:
		print("dry run: --write を付けると本体を上書きします")
	quit()


func _compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()
	if vertex_count == 0 or indices.is_empty() or indices.size() % 3 != 0:
		push_error("LODの頂点または三角形がありません")
		return []
	var remap := {}
	var kept_vertices := PackedInt32Array()
	var compact_indices := PackedInt32Array()
	for index in indices:
		if index < 0 or index >= vertex_count:
			push_error("LODの頂点番号が範囲外です")
			return []
		if not remap.has(index):
			remap[index] = kept_vertices.size()
			kept_vertices.append(index)
		compact_indices.append(remap[index])
	var result := arrays.duplicate()
	# 属性の要素数から、頂点あたりの幅を求めて詰め直す。
	for slot in range(Mesh.ARRAY_MAX):
		if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
			continue
		var attribute = arrays[slot]
		if attribute.size() % vertex_count != 0:
			push_error("属性の要素数が頂点数に合いません: slot %d" % slot)
			return []
		var stride: int = attribute.size() / vertex_count
		var compact = attribute.duplicate()
		compact.resize(kept_vertices.size() * stride)
		for vertex in range(kept_vertices.size()):
			for component in range(stride):
				compact[vertex * stride + component] = attribute[kept_vertices[vertex] * stride + component]
		result[slot] = compact
	result[Mesh.ARRAY_INDEX] = compact_indices
	return result

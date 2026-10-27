extends SceneTree

# 元の衝突形状を頂点でまとめ、指定したLODで簡略化する。
# 実行: Godot --headless --path . --script res://tools/simplify_gomi_collision.gd -- <lod_index> <output_path> [--write]
# 保存後は tools/compare_gomi_collision.gd -- <old> <new> でraycast比較が必要。
# この巨大な1メッシュではlod_sizeは実誤差よりかなり大きく、誤差でなくindexで選ぶ。
# LOD1は約20mm表示だが、raycastの最大差は21mm、99%は0.008mm以内、hit/miss変更なし。
# 簡略化した表示メッシュ由来の衝突はhit/miss変更と1.2mの差で悪化した。
# tools/generate_gomi_shape.gdで元の形状を再生成した後は、このスクリプトも再実行する。
const SOURCE := "res://assets/models/GOMI_collision.res"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() > 3:
		push_error("引数は <lod_index> <output_path> [--write] を指定してください")
		quit(1)
		return
	if not args[0].is_valid_int():
		push_error("lod_index は -1 以上の整数で指定してください")
		quit(1)
		return
	var lod_index := args[0].to_int()
	if lod_index < -1:
		push_error("lod_index は -1 以上で指定してください")
		quit(1)
		return
	var output_path := args[1]
	if output_path.strip_edges().is_empty() or output_path.begins_with("--"):
		push_error("output_path を指定してください")
		quit(1)
		return
	var write := args.size() == 3
	if write and args[2] != "--write":
		push_error("未対応の引数です: " + args[2])
		quit(1)
		return

	var source := load(SOURCE) as ConcavePolygonShape3D
	if source == null:
		push_error("ConcavePolygonShape3Dを読み込めません: " + SOURCE)
		quit(1)
		return
	var old_faces := source.get_faces()
	if old_faces.is_empty() or old_faces.size() % 3 != 0:
		push_error("元の当たり判定の三角形が不正です")
		quit(1)
		return

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var welded: Dictionary[Vector3i, int] = {}
	var degenerate_count := 0
	for triangle in range(0, old_faces.size(), 3):
		var corners := PackedInt32Array()
		for corner in range(3):
			var position := old_faces[triangle + corner]
			if not position.is_finite():
				push_error("元の当たり判定に有限でない座標があります")
				quit(1)
				return
			# 位置を1e-5単位で照合し、最初の頂点座標を残す。
			var key := Vector3i((position * 100000.0).round())
			if not welded.has(key):
				welded[key] = vertices.size()
				vertices.append(position)
			corners.append(welded[key])
		var a := vertices[corners[0]]
		var b := vertices[corners[1]]
		var c := vertices[corners[2]]
		if corners[0] == corners[1] or corners[1] == corners[2] or corners[2] == corners[0] or (b - a).cross(c - a).length_squared() == 0.0:
			degenerate_count += 1
			continue
		# 元の順序を保ち、三角形の向きを変えない。
		indices.append_array(corners)
	if indices.is_empty():
		push_error("頂点をまとめた後の三角形がありません")
		quit(1)
		return

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices:
		surface.add_vertex(vertex)
	for index in indices:
		surface.add_index(index)
	surface.generate_normals()
	var arrays := surface.commit_to_arrays()
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		push_error("頂点をまとめたメッシュの作成に失敗しました")
		quit(1)
		return
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if importer.get_surface_count() != 1:
		push_error("LOD用のsurfaceの作成に失敗しました")
		quit(1)
		return
	importer.generate_lods(25.0, 60.0, [])
	var lod_count := importer.get_surface_lod_count(0)
	print("LOD -1: なし / 三角形 %d / 除外した縮退面 %d" % [indices.size() / 3, degenerate_count])
	for lod in range(lod_count):
		var lod_indices := importer.get_surface_lod_indices(0, lod)
		print("LOD %d: lod_size %.9f / 三角形 %d" % [lod, importer.get_surface_lod_size(0, lod), lod_indices.size() / 3])
	if lod_index >= lod_count:
		push_error("lod_index は -1 または生成されたLODのindexを指定してください（LOD数: %d）" % lod_count)
		quit(1)
		return

	# LOD生成で頂点配列が変わるため、生成後の配列を使う。
	arrays = importer.get_surface_arrays(0)
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		push_error("LOD生成後の頂点または頂点番号の配列が不正です")
		quit(1)
		return
	var selected_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var selected_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if lod_index >= 0:
		selected_indices = importer.get_surface_lod_indices(0, lod_index)
	if selected_vertices.is_empty() or selected_indices.is_empty() or selected_indices.size() % 3 != 0:
		push_error("選択したLODの三角形が不正です")
		quit(1)
		return
	var faces := PackedVector3Array()
	for index in selected_indices:
		if index < 0 or index >= selected_vertices.size():
			push_error("選択したLODの頂点番号が範囲外です")
			quit(1)
			return
		faces.append(selected_vertices[index])

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = source.backface_collision
	var old_aabb := AABB(old_faces[0], Vector3.ZERO)
	for vertex in old_faces:
		old_aabb = old_aabb.expand(vertex)
	var new_aabb := AABB(faces[0], Vector3.ZERO)
	for vertex in faces:
		new_aabb = new_aabb.expand(vertex)
	print("選択したLOD: %d" % lod_index)
	print("三角形: %d -> %d" % [old_faces.size() / 3, faces.size() / 3])
	print("AABB: %s -> %s" % [old_aabb, new_aabb])
	if write:
		var error := ResourceSaver.save(shape, output_path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("当たり判定の保存に失敗しました: %s" % error_string(error))
			quit(1)
			return
		var saved := FileAccess.open(output_path, FileAccess.READ)
		if saved == null:
			push_error("保存後のファイルサイズを取得できません")
			quit(1)
			return
		print("保存: %s (%d bytes)" % [output_path, saved.get_length()])
	else:
		print("dry run: --write を付けると %s に保存します" % output_path)
	quit()

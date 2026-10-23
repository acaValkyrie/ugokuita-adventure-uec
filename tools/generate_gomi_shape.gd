extends SceneTree

const MESH_PATH := "res://assets/models/GOMI.obj"
const OUTPUT_PATH := "res://assets/models/GOMI_collision.res"
const MESH_SCALE := 0.1

func _initialize() -> void:
	var mesh := load(MESH_PATH) as ArrayMesh
	if mesh == null:
		printerr("Could not load imported GOMI ArrayMesh")
		quit(1)
		return
	var faces := PackedVector3Array()
	var uv2_vertices := 0
	var total_vertices := 0
	var bounds := AABB()
	var have_bounds := false
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		if uv2.size() != vertices.size():
			printerr("Surface %d has %d UV2 entries for %d vertices" % [surface, uv2.size(), vertices.size()])
			quit(1)
			return
		total_vertices += vertices.size()
		uv2_vertices += uv2.size()
		if indices.is_empty():
			for i in range(0, vertices.size(), 3):
				_append_triangle(faces, vertices, i, i + 1, i + 2)
		else:
			for i in range(0, indices.size(), 3):
				_append_triangle(faces, vertices, indices[i], indices[i + 1], indices[i + 2])
		for vertex in vertices:
			var point := vertex * MESH_SCALE
			if not have_bounds:
				bounds = AABB(point, Vector3.ZERO)
				have_bounds = true
			else:
				bounds = bounds.expand(point)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var error := ResourceSaver.save(shape, OUTPUT_PATH)
	print("GOMI exact collision: %d surfaces, %d/%d UV2 vertices, %d triangles, AABB %s, save error %d" % [mesh.get_surface_count(), uv2_vertices, total_vertices, faces.size() / 3, bounds, error])
	quit(error)

func _append_triangle(faces: PackedVector3Array, vertices: PackedVector3Array, a: int, b: int, c: int) -> void:
	faces.append(vertices[a] * MESH_SCALE)
	faces.append(vertices[b] * MESH_SCALE)
	faces.append(vertices[c] * MESH_SCALE)

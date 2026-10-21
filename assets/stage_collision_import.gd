@tool
extends EditorScenePostImport

# ステージ用GLBの取り込み時に、ローポリ版の建物を取り除き、建物・地面・オブジェクトのメッシュへ当たり判定を自動で付ける
const COLLIDABLE_PREFIXES := ["hi_", "ground", "object", "UEC", "本館B"]

# 木の日なた判定の光線を遮る物理レイヤー（レイヤー3）。幹は機体ともぶつかり、葉は日なた判定の光線だけを遮る
const SUN_OCCLUDER_LAYER := 1 << 2
# 機体ともぶつからせる木の幹のノード名の先頭（広葉樹・低木の「幹」と、松の幹「メッシュ ボディ4」）
const TRUNK_PREFIXES := ["幹", "メッシュ ボディ4"]

# キャンパス用テクスチャのシェーダーとテクスチャの置き場所
const SHADER_PATH := "res://assets/shaders/campus_triplanar.gdshader"
# 金網フェンスのシェーダー
const FENCE_SHADER_PATH := "res://assets/shaders/chain_link_fence.gdshader"
# プールの底とプールサイドのシェーダー
const POOL_SHADER_PATH := "res://assets/shaders/pool.gdshader"
# プールの水面（半透明）のシェーダー
const POOL_WATER_SHADER_PATH := "res://assets/shaders/pool_water_surface.gdshader"
const TEXTURE_DIR := "res://assets/textures/campus/"

# 地面メッシュの元マテリアル名から地面の種類を決める対応表
const GROUND_KIND_BY_MATERIAL := {
	"Steel - Satin": "paving_brick",
	"Glass - Heavy Color": "paving_stone",
	"Plastic - Matte (Gray)": "paving_stone",
	"Plastic - Glossy (Green)": "grass",
	"Plastic - Glossy (Green).001": "grass",
	"プラスチック - 光沢(緑) (1)": "water",
	"Steel - Satin.001": "paving_stone",
	"ABS (White)": "court_line",
	"ABS(白) (1)": "court",
}

# 灰色プラスチックのうち、キャンパス外の駐車場・学校の敷地としてアスファルトにするノード名
const ASPHALT_GRAY_NODE_NAMES: Array[String] = ["Body28", "Body29"]
# 灰色の金属マテリアルのうち、公道や建物裏の通路としてアスファルトにするノード名
const ASPHALT_STEEL_NODE_NAMES: Array[String] = ["Body19", "Body459", "東地区敷地外"]
# 灰色の金属マテリアルのうち、テニスコートを囲むフェンス（高さ5mの薄い壁）として金網にするノード名
const FENCE_NODE_NAMES: Array[String] = ["Body616", "Body617", "Body734"]
# ローポリ版の建物（low-building）にしかない、西キャンパスのプールの台座と壁。取り除かずにgroundの下へ移して残す
const LOW_POLY_KEEP_NODE_NAMES: Array[String] = ["Body719", "西プール壁"]
# 水面のノード名（groundの子）。当たり判定を付けず、底のメッシュの元にする
const WATER_SURFACE_NODE_NAMES: Array[String] = ["Body720", "Body585"]
# 取り込み時に水面から作る底の一覧: 水面のノード名・底のノード名・底の高さ（ワールドY、メートル）。
# プールの底は水深 1.2 m（水面 y=0.5）。台座の穴の内壁（下端 y=0）より下は POOL_INNER_WALL_NAME の壁でふさぐ。噴水の底は周りの広場の地面（y=-0.394）より少し上
const WATER_FLOORS := [
	{"water": "Body720", "floor": "プールの底", "floor_y": -0.7},
	{"water": "Body585", "floor": "噴水の底", "floor_y": -0.39},
]
# プールの底を下げた分の内壁のノード名と、上端の高さ（台座の穴の内壁の下端、ワールドY）
const POOL_INNER_WALL_NAME := "プールの内壁"
const POOL_INNER_WALL_TOP_Y := 0.0
# プールの水面の長方形（assets/shaders/pool.gdshader の既定値と同じ値）
const POOL_CENTER := Vector2(-207.759, -178.832)
const POOL_LONG_AXIS := Vector2(0.2664, -0.9639)
const POOL_HALF_SIZE := Vector2(6.69, 12.705)
# プールの底の光の網目の集まりやすさ（水深 1.2 m ×（1 − 1/水の屈折率 1.333））
const POOL_CAUSTIC_FOCUS := 0.3
# プールの水が光を吸う強さ [1/m]（pool.gdshader の water_absorption。水深 1.2 m の底で約6割が水の色になる）
const POOL_WATER_ABSORPTION := 0.8
# プールの水深 [m]（pool_ripples.gdshaderinc の water_depth。波の伝わる速さに使う）
const POOL_WATER_DEPTH := 1.2
# 噴水の水面のノード名と、底を作ったあとに水面を上げる高さ（ワールドY、メートル）。縁（上端 y=0.21）より少し低い
const FOUNTAIN_WATER_NODE_NAME := "Body585"
const FOUNTAIN_WATER_Y := 0.12
# プールと噴水のノードごとの地面の種類（水面・底・プールサイド・柵）。元マテリアルによる割り当てより優先する
const POOL_KIND_BY_NODE_NAME := {"Body720": "pool_water", "Body585": "pool_water", "プールの底": "pool_floor", "噴水の底": "fountain_floor", "Body719": "pool_deck", "プールの内壁": "pool_deck", "西プール壁": "pool_fence"}
# プールと噴水の種類を、走行時の効果音に使う地面の種類へ読み替える対応表（水面と柵は走行面ではないので含めない）
const POOL_SURFACE_KIND := {"pool_floor": "water", "fountain_floor": "water", "pool_deck": "paving_stone"}
# 東西キャンパスの間の道路を表す線（ワールドXZ）。これより西の舗装はアスファルト、東はレンガ
const CAMPUS_BORDER_SOUTH := Vector2(-58.0, 71.0)
const CAMPUS_BORDER_NORTH := Vector2(14.0, -299.0)

# 工事のあいだの仮囲い。工事が終わって今は無いので、取り込み時に塀のメッシュから消す。
# 塀のノード名と、取り除く範囲（ワールドXZ）。3頂点すべてがこの範囲に入る三角形を取り除く
const REMOVED_WALL_NODE_NAME := "UEC壁"
const REMOVED_WALL_RECT := Rect2(Vector2(-261.5, 19.3), Vector2(9.1, 6.9))
# 取り除く三角形の想定の数（これと違えばモデルが変わったとみて警告する）
const REMOVED_WALL_EXPECTED_TRIS := 24

# 建物の屋根・外壁の色（もとの外壁テクスチャの地の色）
const BUILDING_COLOR := Color(0.77, 0.703, 0.621)
# 窓ガラスの色
const WINDOW_COLOR := Color(0.32, 0.38, 0.45)
# 窓とみなす面の条件: 周りの外壁からの奥行き（メートル）と、面の最大の幅・高さ（メートル）
const WINDOW_MIN_DEPTH := 0.05
const WINDOW_MAX_DEPTH := 0.8
const WINDOW_MAX_SIZE := Vector2(12.0, 4.0)
# 窓とみなす領域が、その範囲（外接する長方形）を埋める割合の下限。X字の筋かいなどを除く
const WINDOW_MIN_FILL_RATIO := 0.9
# 同じ平面上の三角形どうしを同じ領域とみなすときに、範囲を広げて重なりを見る幅（メートル）
const WINDOW_REGION_JOIN_MARGIN := 0.002
# 窓の周りを調べる点を、面の外側へずらす距離（メートル）
const WINDOW_PROBE_OFFSET := 0.1
# 同じ向きの面とみなす水平化した法線の内積の下限
const WINDOW_SAME_FACING_DOT := 0.995
# 鉛直な面とみなす法線のYの絶対値の上限
const WINDOW_VERTICAL_MAX_Y := 0.05
# 窓の検出に使う空間グリッドのセルの大きさ（メートル）
const WINDOW_GRID_CELL := 1.0
# LOD生成時に法線をまとめる角度・分ける角度（Godotのインポート既定値）
const LOD_NORMAL_MERGE_ANGLE := deg_to_rad(60.0)
const LOD_NORMAL_SPLIT_ANGLE := deg_to_rad(25.0)

# 建物の地面の高さの面とみなす、三角形の全頂点のワールドYの絶対値の上限（メートル）
const GROUND_FACE_MAX_Y := 0.02

# 重なる面を持ち上げる1段あたりの高さ（メートル）
const COPLANAR_LIFT_STEP := 0.003
# 同じ高さとみなす高さの差（メートル）。水平な三角形とみなす、3頂点のyの差の上限にも使う
const COPLANAR_MAX_DY := 0.0005
# 調べる三角形の面積の下限（平方メートル）
const COPLANAR_MIN_TRI_AREA := 0.001
# 重なっているとみなす面積の下限（平方メートル）
const COPLANAR_MIN_OVERLAP := 0.0001
# 重なりを探す空間グリッドのセル（メートル）
const COPLANAR_GRID_CELL := 2.0

# ライトマップ1ピクセルが覆う長さ（メートル）
const LIGHTMAP_TEXEL_SIZE := 0.5

# 同じ種類のマテリアルを取り込み中に使い回すためのキャッシュ
var _material_cache := {}
# 窓の検出数の合計（全建物）
var _window_tri_total := 0

# 窓の検出に使う三角形（シーン座標）
class WindowTri:
	var mesh: ArrayMesh
	var surface: int
	var index: int
	var a: Vector3
	var b: Vector3
	var c: Vector3
	var normal: Vector3
	var n_h: Vector3
	var center: Vector3
	var depth: float
	var is_window := false


# 同じ高さで重なる面の検出に使う水平な三角形（シーン座標）
class FlatTri:
	var id: int
	var node_index: int
	var y: float
	var poly: PackedVector2Array
	var rect: Rect2


func _post_import(scene: Node) -> Object:
	var start_msec := Time.get_ticks_msec()
	_material_cache.clear()
	_window_tri_total = 0
	var strip_cache := {}
	var strip_stats := {"tris": 0, "buildings": 0}
	_keep_low_poly_parts(scene)
	_add_pool_floor(scene)
	_remove_temporary_wall(scene)
	for child in scene.get_children():
		if _is_low_poly(child.name):
			scene.remove_child(child)
			child.free()
			continue
		_assign_materials(child, scene)
		if _is_collidable(child.name):
			_add_collisions(child)
		elif child.name == "tree":
			_add_sun_occluders(child)
		# 当たり判定を作った後で、見た目のメッシュだけから地面の高さの面を取り除く
		if String(child.name).begins_with("hi_"):
			_strip_ground_faces(child, scene, strip_cache, strip_stats)
	print("stage_collision_import: 建物の地面の高さの面を取り除いた: %d 三角形（%d 棟）" % [strip_stats["tris"], strip_stats["buildings"]])
	_lift_coplanar_overlaps(scene)
	_set_lightmap_hints(scene)
	print("窓の検出の合計: 窓の三角形=%d 取り込み時間=%d ms" % [_window_tri_total, Time.get_ticks_msec() - start_msec])
	return scene


# 別々のメッシュの水平な面が同じ高さで重なっていると、Zファイティングでフレームごとに前後が入れ替わってちらつく。
# 重なっている組のうち水平な面積の小さいほうを、見た目だけ少しずつ上に持ち上げて重ならないようにする。
# 当たり判定（StaticBody3D）は元の位置に残す
func _lift_coplanar_overlaps(scene: Node) -> void:
	var start_msec := Time.get_ticks_msec()
	var nodes: Array[MeshInstance3D] = []
	for child in scene.get_children():
		if child.name == "tree":
			continue
		_collect_coplanar_nodes(child, nodes)
	# 水平な三角形を集め、外接矩形が重なるセルすべてへ登録する
	var grid := {}
	var areas := PackedFloat64Array()
	areas.resize(nodes.size())
	var tri_count := 0
	for node_index in nodes.size():
		var node := nodes[node_index]
		var xform := _scene_transform(node, scene)
		var faces := node.mesh.get_faces()
		for i in range(0, faces.size() - 2, 3):
			var a := xform * faces[i]
			var b := xform * faces[i + 1]
			var c := xform * faces[i + 2]
			if maxf(a.y, maxf(b.y, c.y)) - minf(a.y, minf(b.y, c.y)) > COPLANAR_MAX_DY:
				continue
			var pa := Vector2(a.x, a.z)
			var pb := Vector2(b.x, b.z)
			var pc := Vector2(c.x, c.z)
			var area := absf((pb - pa).cross(pc - pa)) * 0.5
			if area < COPLANAR_MIN_TRI_AREA:
				continue
			var tri := FlatTri.new()
			tri.id = tri_count
			tri_count += 1
			tri.node_index = node_index
			tri.y = a.y
			tri.poly = PackedVector2Array([pa, pb, pc])
			var low := pa.min(pb).min(pc)
			tri.rect = Rect2(low, pa.max(pb).max(pc) - low)
			areas[node_index] += area
			var cell_low := Vector2i((low / COPLANAR_GRID_CELL).floor())
			var cell_high := Vector2i(((low + tri.rect.size) / COPLANAR_GRID_CELL).floor())
			for x in range(cell_low.x, cell_high.x + 1):
				for y in range(cell_low.y, cell_high.y + 1):
					var key := Vector2i(x, y)
					if not grid.has(key):
						grid[key] = []
					grid[key].append(tri)
	# 同じセルにある三角形の組から、重なっているノードの組を求める
	var overlap_pairs := {}
	var checked_tris := {}
	var neighbors: Array = []
	neighbors.resize(nodes.size())
	for i in nodes.size():
		neighbors[i] = []
	for cell_tris: Array in grid.values():
		for i in cell_tris.size():
			var t1: FlatTri = cell_tris[i]
			for j in range(i + 1, cell_tris.size()):
				var t2: FlatTri = cell_tris[j]
				if t1.node_index == t2.node_index or absf(t1.y - t2.y) > COPLANAR_MAX_DY:
					continue
				var node_key := Vector2i(mini(t1.node_index, t2.node_index), maxi(t1.node_index, t2.node_index))
				if overlap_pairs.has(node_key):
					continue
				var tri_key := Vector2i(mini(t1.id, t2.id), maxi(t1.id, t2.id))
				if checked_tris.has(tri_key):
					continue
				checked_tris[tri_key] = true
				if not t1.rect.intersects(t2.rect):
					continue
				var overlap := 0.0
				for polygon: PackedVector2Array in Geometry2D.intersect_polygons(t1.poly, t2.poly):
					var twice_area := 0.0
					for k in polygon.size():
						twice_area += polygon[k].cross(polygon[(k + 1) % polygon.size()])
					overlap += absf(twice_area) * 0.5
				if overlap > COPLANAR_MIN_OVERLAP:
					overlap_pairs[node_key] = true
					neighbors[node_key.x].append(node_key.y)
					neighbors[node_key.y].append(node_key.x)
	# 水平な面積の大きいノードから順に、重なる相手より1段上の段を決める
	var paths: Array[String] = []
	for node in nodes:
		paths.append(str(scene.get_path_to(node)))
	var order: Array[int] = []
	for i in nodes.size():
		order.append(i)
	order.sort_custom(func(l: int, r: int) -> bool:
		if areas[l] != areas[r]:
			return areas[l] > areas[r]
		return paths[l] < paths[r])
	var levels: Array[int] = []
	levels.resize(nodes.size())
	levels.fill(-1)
	var max_level := 0
	for index in order:
		var level := 0
		for other: int in neighbors[index]:
			if levels[other] >= 0:
				level = maxi(level, levels[other] + 1)
		levels[index] = level
		max_level = maxi(max_level, level)
	# 持ち上げる前に、ノードと直下の当たり判定のシーン座標を記録する
	var orig_world := {}
	var orig_body_world := {}
	for node in nodes:
		orig_world[node] = _scene_transform(node, scene)
		for child in node.get_children():
			if child is StaticBody3D:
				orig_body_world[child] = _scene_transform(child, scene)
	# 親が先になるよう浅い順に持ち上げ、当たり判定は元の位置へ戻す
	var lifted: Array[MeshInstance3D] = []
	for i in nodes.size():
		if levels[i] >= 1:
			lifted.append(nodes[i])
	var depths := {}
	for node in lifted:
		depths[node] = scene.get_path_to(node).get_name_count()
	lifted.sort_custom(func(l: MeshInstance3D, r: MeshInstance3D) -> bool: return depths[l] < depths[r])
	for node in lifted:
		var lift := levels[nodes.find(node)] * COPLANAR_LIFT_STEP
		var orig: Transform3D = orig_world[node]
		var target := Transform3D(orig.basis, orig.origin + Vector3(0.0, lift, 0.0))
		var parent_world := _scene_transform(node.get_parent(), scene)
		node.transform = parent_world.affine_inverse() * target
		for child in node.get_children():
			if child is StaticBody3D:
				child.transform = target.affine_inverse() * orig_body_world[child]
	print("stage_collision_import: 同じ高さで重なる面を持ち上げた: 重なる組=%d ノード=%d 最大の段=%d 時間=%d ms" % [overlap_pairs.size(), lifted.size(), max_level, Time.get_ticks_msec() - start_msec])


# 持ち上げの対象になるメッシュのノード（_col で終わらず、StaticBody3D の下以外）を集める
func _collect_coplanar_nodes(node: Node, nodes: Array[MeshInstance3D]) -> void:
	if node is StaticBody3D:
		return
	for child in node.get_children():
		_collect_coplanar_nodes(child, nodes)
	if node is MeshInstance3D and node.mesh != null and not String(node.name).ends_with("_col"):
		nodes.append(node)


# 建物の見た目のメッシュから、ワールドの高さがほぼ0の水平な三角形を取り除く。
# 敷地の地面（y=0）と同じ平面にあってZファイティングでちらつくため。
# 建物の外では敷地の地面が見えるので穴は空かない。当たり判定（_col）は変えない
func _strip_ground_faces(node: Node, scene: Node, cache: Dictionary, stats: Dictionary) -> void:
	var removed_before: int = stats["tris"]
	_strip_ground_faces_recursive(node, scene, cache, stats)
	if stats["tris"] > removed_before:
		stats["buildings"] += 1


func _strip_ground_faces_recursive(node: Node, scene: Node, cache: Dictionary, stats: Dictionary) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			continue
		_strip_ground_faces_recursive(child, scene, cache, stats)
	var node_name := String(node.name)
	if not (node is MeshInstance3D) or node_name.ends_with("_col") or not (node.mesh is ArrayMesh):
		return
	var mesh: ArrayMesh = node.mesh
	if not cache.has(mesh):
		var xform := _scene_transform(node, scene)
		var result := _strip_mesh(mesh, xform, _is_ground_face)
		cache[mesh] = result["mesh"]
		stats["tris"] += result["removed"]
	if cache[mesh] != null:
		node.mesh = cache[mesh]


# 3頂点（ワールド座標）すべてが |y| < 閾値 の三角形かを返す
func _is_ground_face(a: Vector3, b: Vector3, c: Vector3) -> bool:
	return absf(a.y) < GROUND_FACE_MAX_Y and absf(b.y) < GROUND_FACE_MAX_Y and absf(c.y) < GROUND_FACE_MAX_Y


# 3頂点（ワールド座標）すべてが REMOVED_WALL_RECT の中（x と z）にある三角形かを返す
func _is_in_removed_wall_rect(a: Vector3, b: Vector3, c: Vector3) -> bool:
	for p in [a, b, c]:
		if not REMOVED_WALL_RECT.has_point(Vector2(p.x, p.z)):
			return false
	return true


# 塀のメッシュから、工事の仮囲いの三角形を取り除く（このあとで当たり判定を付けるので、当たり判定も消える）
func _remove_temporary_wall(scene: Node) -> void:
	var wall := scene.get_node_or_null(NodePath(REMOVED_WALL_NODE_NAME)) as MeshInstance3D
	if wall == null or not (wall.mesh is ArrayMesh):
		push_warning("stage_collision_import: %s のメッシュが見つからないため、工事の仮囲いを取り除けない" % REMOVED_WALL_NODE_NAME)
		return
	var result := _strip_mesh(wall.mesh, _scene_transform(wall, scene), _is_in_removed_wall_rect)
	var removed: int = result["removed"]
	if result["mesh"] != null:
		wall.mesh = result["mesh"]
	print("stage_collision_import: 塀から工事の仮囲いを取り除いた: %d 三角形" % removed)
	if removed != REMOVED_WALL_EXPECTED_TRIS:
		push_warning("stage_collision_import: 工事の仮囲いの三角形が %d 枚だった（想定は %d 枚）。モデルが変わった可能性がある" % [removed, REMOVED_WALL_EXPECTED_TRIS])


# is_removed(a, b, c) が true を返す三角形（3頂点はワールド座標）を除いたメッシュを返す。取り除くものが無ければ mesh は null
func _strip_mesh(mesh: ArrayMesh, xform: Transform3D, is_removed: Callable) -> Dictionary:
	var removed := 0
	var importer_mesh := ImporterMesh.new()
	importer_mesh.set_lightmap_size_hint(mesh.lightmap_size_hint)
	for surface in mesh.get_surface_count():
		var primitive := mesh.surface_get_primitive_type(surface)
		var arrays := mesh.surface_get_arrays(surface)
		if primitive == Mesh.PRIMITIVE_TRIANGLES:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var old_indices = arrays[Mesh.ARRAY_INDEX]
			var corner_count: int = vertices.size() if old_indices == null else old_indices.size()
			var kept := PackedInt32Array()
			for i in range(0, corner_count - 2, 3):
				var ids := [i, i + 1, i + 2]
				if old_indices != null:
					ids = [old_indices[i], old_indices[i + 1], old_indices[i + 2]]
				if is_removed.call(xform * vertices[ids[0]], xform * vertices[ids[1]], xform * vertices[ids[2]]):
					removed += 1
				else:
					kept.append_array(PackedInt32Array(ids))
			if kept.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = kept
		importer_mesh.add_surface(primitive, arrays, [], {}, mesh.surface_get_material(surface), mesh.surface_get_name(surface))
	if removed == 0:
		return {"mesh": null, "removed": 0}
	importer_mesh.generate_lods(LOD_NORMAL_MERGE_ANGLE, LOD_NORMAL_SPLIT_ANGLE, [])
	var new_mesh := importer_mesh.get_mesh()
	new_mesh.resource_name = mesh.resource_name
	return {"mesh": new_mesh, "removed": removed}


# 残ったメッシュのUV2用に、面積から決めたライトマップのサイズを設定する
func _set_lightmap_hints(scene: Node) -> void:
	var sides := {}
	_collect_lightmap_sides(scene, scene, sides)
	var min_texels := 0
	var max_texels := 0
	var sum_texels := 0
	for mesh: ArrayMesh in sides:
		var side: int = sides[mesh]
		mesh.lightmap_size_hint = Vector2i(side, side)
		var texels := side * side
		min_texels = texels if sum_texels == 0 else mini(min_texels, texels)
		max_texels = maxi(max_texels, texels)
		sum_texels += texels
	print("ライトマップのサイズを設定: メッシュ数=%d 最小=%d 最大=%d 合計=%d texel" % [sides.size(), min_texels, max_texels, sum_texels])


# メッシュごとに最も大きい面積から辺の長さを求めて辞書へ入れる（メッシュは複数ノードで共有される）
func _collect_lightmap_sides(node: Node, root: Node, sides: Dictionary) -> void:
	for child in node.get_children():
		_collect_lightmap_sides(child, root, sides)
	if not (node is MeshInstance3D) or not (node.mesh is ArrayMesh):
		return
	var mesh: ArrayMesh = node.mesh
	if mesh.get_surface_count() == 0 or not (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2):
		return
	var xform := _scene_transform(node, root)
	var faces := mesh.get_faces()
	var area := 0.0
	for i in range(0, faces.size() - 2, 3):
		var a := xform * faces[i]
		var b := xform * faces[i + 1]
		var c := xform * faces[i + 2]
		area += 0.5 * (b - a).cross(c - a).length()
	var side := clampi(int(ceil(sqrt(area) / LIGHTMAP_TEXEL_SIZE * 1.3)), 8, 2048)
	sides[mesh] = maxi(side, sides.get(mesh, 0))


func _is_low_poly(node_name: String) -> bool:
	return node_name == "low-building" or node_name.begins_with("buil_")


# ローポリ版の建物から残すノードを、ワールドでの位置を保ったまま ground の下へ移す
func _keep_low_poly_parts(scene: Node) -> void:
	var low := scene.get_node_or_null("low-building")
	var ground := scene.get_node_or_null("ground") as Node3D
	if low == null or ground == null:
		push_warning("stage_collision_import: low-building か ground が見つからないため、ローポリ版の建物のノードを残せない")
		return
	var moved := 0
	for node_name in LOW_POLY_KEEP_NODE_NAMES:
		var node := low.get_node_or_null(NodePath(node_name)) as Node3D
		if node == null:
			push_warning("stage_collision_import: low-building の下に %s が見つからない" % node_name)
			continue
		var xform := _scene_transform(node, scene)
		# ownerを付けたまま別の親へ移すと警告が出るので、いったん外す
		node.owner = null
		low.remove_child(node)
		ground.add_child(node)
		# 保存するシーンに残るよう、子孫も含めてownerを付け直す
		_set_owner_recursive(node, scene)
		node.transform = _scene_transform(ground, scene).affine_inverse() * xform
		moved += 1
	print("stage_collision_import: ローポリ版の建物から %d 個のノードを ground の下へ移した" % moved)


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_set_owner_recursive(child, owner_node)


# 水面のメッシュを複製して、WATER_FLOORS の高さにプールと噴水の底を作る。噴水の水面は、底を作ったあとで FOUNTAIN_WATER_Y へ上げる
func _add_pool_floor(scene: Node) -> void:
	var ground := scene.get_node_or_null("ground")
	if ground == null:
		push_warning("stage_collision_import: ground が見つからないため、プールの底を作れない")
		return
	for entry in WATER_FLOORS:
		var water := ground.get_node_or_null(entry["water"]) as MeshInstance3D
		if water == null or water.mesh == null:
			push_warning("stage_collision_import: ground の下に %s のメッシュが見つからないため、%s を作れない" % [entry["water"], entry["floor"]])
			continue
		var floor_y: float = entry["floor_y"]
		var floor_node := MeshInstance3D.new()
		floor_node.name = entry["floor"]
		floor_node.mesh = water.mesh.duplicate()
		floor_node.transform = water.transform
		var aabb := _scene_transform(water, scene) * water.mesh.get_aabb()
		# groundは回転も拡大もないので、ローカルのYを動かせばよい
		floor_node.position.y -= aabb.position.y - floor_y
		ground.add_child(floor_node)
		floor_node.owner = scene
		print("stage_collision_import: %s を作った（y=%.2f）" % [entry["floor"], floor_y])
		if String(entry["floor"]) == "プールの底":
			_add_pool_inner_wall(scene, ground, water, floor_y)
		if String(entry["water"]) == FOUNTAIN_WATER_NODE_NAME:
			water.position.y += FOUNTAIN_WATER_Y - aabb.end.y
			print("stage_collision_import: 噴水の水面を y=%.2f へ上げた" % FOUNTAIN_WATER_Y)


# プールの底を下げた分、台座の穴の内壁の下端（POOL_INNER_WALL_TOP_Y）から底までを、水面の長方形の4辺に沿った壁でふさぐ。面は内側（プールの中）を向ける
func _add_pool_inner_wall(scene: Node, ground: Node3D, water: MeshInstance3D, floor_y: float) -> void:
	var short_axis := Vector2(-POOL_LONG_AXIS.y, POOL_LONG_AXIS.x)
	var corners: Array[Vector2] = [
		POOL_CENTER + short_axis * POOL_HALF_SIZE.x + POOL_LONG_AXIS * POOL_HALF_SIZE.y,
		POOL_CENTER - short_axis * POOL_HALF_SIZE.x + POOL_LONG_AXIS * POOL_HALF_SIZE.y,
		POOL_CENTER - short_axis * POOL_HALF_SIZE.x - POOL_LONG_AXIS * POOL_HALF_SIZE.y,
		POOL_CENTER + short_axis * POOL_HALF_SIZE.x - POOL_LONG_AXIS * POOL_HALF_SIZE.y,
	]
	# 頂点はワールド座標で求め、groundのローカル座標に直す
	var to_local := _scene_transform(ground, scene).affine_inverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(water.mesh.surface_get_material(0))
	for i in corners.size():
		var p0 := corners[i]
		var p1 := corners[(i + 1) % corners.size()]
		var edge := (p1 - p0).normalized()
		var inward := POOL_CENTER - (p0 + p1) * 0.5
		inward = (inward - edge * inward.dot(edge)).normalized()
		var normal := Vector3(inward.x, 0.0, inward.y)
		var a := to_local * Vector3(p0.x, POOL_INNER_WALL_TOP_Y, p0.y)
		var b := to_local * Vector3(p1.x, POOL_INNER_WALL_TOP_Y, p1.y)
		var c := to_local * Vector3(p1.x, floor_y, p1.y)
		var d := to_local * Vector3(p0.x, floor_y, p0.y)
		var tris: Array = [[a, b, c], [a, c, d]]
		for tri in tris:
			# Godotは時計回りが表。時計回りの三角形は (b-a).cross(c-a) が表の向き（内向き法線）と逆の外向きになるので、そうなるよう巻き順を入れ替える
			if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(normal) > 0.0:
				tri.reverse()
			assert((tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(normal) < 0.0, "プールの内壁の巻き順が内向きでない")
			for v in tri:
				st.set_normal(normal)
				st.add_vertex(v)
	var wall := MeshInstance3D.new()
	wall.name = POOL_INNER_WALL_NAME
	wall.mesh = st.commit()
	ground.add_child(wall)
	wall.owner = scene
	print("stage_collision_import: プールの内壁を作った（y=%.2f〜%.2f）" % [floor_y, POOL_INNER_WALL_TOP_Y])


func _is_collidable(node_name: String) -> bool:
	for prefix in COLLIDABLE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _is_trunk(node_name: String) -> bool:
	for prefix in TRUNK_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _add_collisions(node: Node) -> void:
	for child in node.get_children():
		_add_collisions(child)
	if node is MeshInstance3D:
		# プールと噴水の水面は機体が沈むように当たり判定を付けない
		if String(node.name) in WATER_SURFACE_NODE_NAMES:
			return
		node.create_trimesh_collision()


# 木のメッシュへ当たり判定を付ける。幹は機体ともぶつかり、葉は日なた判定の光線だけを遮る
func _add_sun_occluders(node: Node) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			continue
		_add_sun_occluders(child)
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		var body := node.get_child(node.get_child_count() - 1)
		if body is StaticBody3D:
			body.collision_layer = SUN_OCCLUDER_LAYER
			if _is_trunk(String(node.name)):
				body.collision_layer |= 1
			body.collision_mask = 0


# トップレベルのノードの種類に応じてマテリアルを割り当てる
func _assign_materials(node: Node, scene: Node) -> void:
	var node_name := String(node.name)
	if node_name == "ground" or node_name == "UEC敷地" or node_name == "UEC緑地" or node_name == "UEC収集所":
		_assign_ground_materials(node, scene, node_name == "ground")
	elif node_name == "UEC縁石":
		_set_override_recursive(node, _get_ground_material("paving_stone"))
	elif node_name == "UEC壁":
		_set_override_recursive(node, _get_ground_material("wall_top_concrete"))
	elif node_name.begins_with("hi_") or node_name.begins_with("本館B"):
		_set_override_recursive(node, _get_building_material())
		_mark_windows(node, scene)


# 元マテリアル名を見て、サブツリー内の各サーフェスへ地面のマテリアルを割り当てる
func _assign_ground_materials(node: Node, scene: Node, under_ground: bool) -> void:
	for child in node.get_children():
		_assign_ground_materials(child, scene, under_ground)
	if not (node is MeshInstance3D) or node.mesh == null:
		return
	for i in node.mesh.get_surface_count():
		var source: Material = node.mesh.surface_get_material(i)
		if source == null:
			continue
		var kind: String = _ground_kind(source.resource_name, node, scene, under_ground)
		if kind != "":
			node.set_surface_override_material(i, _get_ground_material(kind))
			if kind == "fence" or kind == "pool_fence" or kind == "pool_water":
				# 半透明の金網や水面はライトマップに焼き込まない
				node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				# フェンスや水面は走行できる地面ではないので surface_kind は付けない
				continue
			# 機体の下の地面の種類（走行時の効果音の切り替えに使う）。プールの種類は既存の走行面の種類へ読み替える
			if not node.has_meta("surface_kind"):
				node.set_meta("surface_kind", POOL_SURFACE_KIND.get(kind, kind))


# 元マテリアル名とノードから地面の種類を返す。該当なしは空文字
func _ground_kind(material_name: String, node: MeshInstance3D, scene: Node, under_ground: bool) -> String:
	if not GROUND_KIND_BY_MATERIAL.has(material_name):
		return ""
	var node_name := String(node.name)
	if under_ground and POOL_KIND_BY_NODE_NAME.has(node_name):
		return POOL_KIND_BY_NODE_NAME[node_name]
	if material_name == "Plastic - Matte (Gray)" and node_name in ASPHALT_GRAY_NODE_NAMES:
		return "asphalt"
	if material_name == "Steel - Satin" and under_ground:
		if node_name in FENCE_NODE_NAMES:
			return "fence"
		if node_name in ASPHALT_STEEL_NODE_NAMES:
			return "asphalt"
		var aabb := _scene_transform(node, scene) * node.mesh.get_aabb()
		var center := aabb.get_center()
		if _is_west_of_border(Vector2(center.x, center.z)):
			return "asphalt"
		return "paving_brick"
	return GROUND_KIND_BY_MATERIAL[material_name]


# 境界線より西側かを返す。cross < 0 が西（P=(-200,0) で負、P=(150,-100) で正）
func _is_west_of_border(point: Vector2) -> bool:
	var border := CAMPUS_BORDER_NORTH - CAMPUS_BORDER_SOUTH
	return border.cross(point - CAMPUS_BORDER_SOUTH) < 0.0


# 取り込み中はSceneTree外でglobal_transformが使えないため、rootの手前まで親のtransformを掛け合わせる
func _scene_transform(node: Node3D, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = current.transform * result
		current = current.get_parent()
	return result


func _set_override_recursive(node: Node, material: Material) -> void:
	for child in node.get_children():
		_set_override_recursive(child, material)
	if node is MeshInstance3D:
		node.material_override = material


# 地面の種類ごとのマテリアルを返す（なければ作る）
func _get_ground_material(kind: String) -> ShaderMaterial:
	if _material_cache.has(kind):
		return _material_cache[kind]
	var material: ShaderMaterial
	match kind:
		"paving_brick":
			material = _make_material(kind, kind, 1.0, Vector2(1.0, 1.0))
		"paving_stone":
			material = _make_material(kind, kind, 2.0, Vector2(2.0, 2.0))
		"asphalt", "dirt", "grass":
			material = _make_material(kind, kind, 4.0, Vector2(4.0, 4.0))
		"water":
			material = _make_material(kind, kind, 6.0, Vector2(6.0, 6.0))
		"court":
			material = _make_color_material(Color(0.36, 0.62, 0.40))
		"court_line":
			material = _make_color_material(Color(0.95, 0.95, 0.93))
		"wall_top_concrete":
			material = _make_material("roof_concrete", "roof_concrete", 4.0, Vector2(4.0, 4.0))
		"fence":
			material = _make_fence_material()
		"pool_water":
			material = _make_pool_water_material()
		"pool_floor":
			material = _make_pool_material(true)
			material.set_shader_parameter("caustic_focus", POOL_CAUSTIC_FOCUS)
			material.set_shader_parameter("water_absorption", POOL_WATER_ABSORPTION)
			material.set_shader_parameter("water_depth", POOL_WATER_DEPTH)
		"fountain_floor":
			material = _make_pool_material(true)
			# 噴水の底にはコースラインを引かず、少し暗い水色にする
			material.set_shader_parameter("draw_lanes", false)
			material.set_shader_parameter("floor_color", Color(0.30, 0.60, 0.70))
		"pool_deck":
			material = _make_pool_material(false)
			material.set_shader_parameter("water_absorption", POOL_WATER_ABSORPTION)
		"pool_fence":
			material = _make_fence_material()
			# プールの柵は灰色で、台座の上の高さ1〜2.5m
			material.set_shader_parameter("wire_color", Color(0.70, 0.72, 0.72))
			material.set_shader_parameter("frame_color", Color(0.58, 0.60, 0.60))
			material.set_shader_parameter("fence_bottom_y", 1.0)
			material.set_shader_parameter("fence_top_y", 2.5)
	_material_cache[kind] = material
	return material


# 建物の屋根・外壁をまとめて塗る単色のマテリアルを返す（なければ作る）
func _get_building_material() -> ShaderMaterial:
	if not _material_cache.has("building"):
		var material := _make_color_material(BUILDING_COLOR)
		material.set_shader_parameter("use_window_mask", true)
		material.set_shader_parameter("window_color", WINDOW_COLOR)
		_material_cache["building"] = material
	return _material_cache["building"]


# 外壁より奥にへこんだ小さな鉛直の面を窓とみなし、その頂点カラーを黒にしたメッシュへ差し替える
func _mark_windows(building: Node, scene: Node) -> void:
	var tris: Array[WindowTri] = []
	var nodes_by_mesh := {}
	_collect_window_tris(building, scene, tris, nodes_by_mesh)
	var grid := {}
	var vertical_count := 0
	for tri in tris:
		if tri.n_h != Vector3.ZERO:
			_register_in_grid(grid, tri)
			vertical_count += 1
	var window_count := 0
	var meshes_with_windows := {}
	for region in _collect_window_regions(tris):
		if not _is_window_region(region, grid):
			continue
		for tri: WindowTri in region:
			tri.is_window = true
			window_count += 1
			meshes_with_windows[tri.mesh] = true
	if window_count == 0:
		print("窓を検出: %s 0/%d" % [building.name, vertical_count])
		return
	var tris_by_mesh := {}
	for tri in tris:
		if meshes_with_windows.has(tri.mesh):
			if not tris_by_mesh.has(tri.mesh):
				tris_by_mesh[tri.mesh] = []
			tris_by_mesh[tri.mesh].append(tri)
	for mesh: ArrayMesh in tris_by_mesh:
		var new_mesh := _rebuild_mesh_with_window_colors(mesh, tris_by_mesh[mesh])
		for node: MeshInstance3D in nodes_by_mesh[mesh]:
			node.mesh = new_mesh
	_window_tri_total += window_count
	print("窓を検出: %s %d/%d" % [building.name, window_count, vertical_count])


# 建物配下の全三角形をシーン座標で集める（共有されたメッシュは最初のノードの変換だけを使う）
func _collect_window_tris(node: Node, scene: Node, tris: Array[WindowTri], nodes_by_mesh: Dictionary) -> void:
	for child in node.get_children():
		_collect_window_tris(child, scene, tris, nodes_by_mesh)
	if not (node is MeshInstance3D) or not (node.mesh is ArrayMesh):
		return
	var mesh: ArrayMesh = node.mesh
	if nodes_by_mesh.has(mesh):
		nodes_by_mesh[mesh].append(node)
		return
	nodes_by_mesh[mesh] = [node]
	var xform := _scene_transform(node, scene)
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var indices = arrays[Mesh.ARRAY_INDEX]
		var corner_count: int = vertices.size() if indices == null else indices.size()
		for i in range(0, corner_count - 2, 3):
			var ids := [i, i + 1, i + 2]
			if indices != null:
				ids = [indices[i], indices[i + 1], indices[i + 2]]
			var tri := _make_window_tri(xform, vertices, normals, ids)
			if tri == null:
				continue
			tri.mesh = mesh
			tri.surface = surface
			tri.index = i / 3
			tris.append(tri)


# 頂点番号3つから三角形を作る。つぶれた三角形は null を返す。鉛直でないときは n_h を零ベクトルにする
func _make_window_tri(xform: Transform3D, vertices: PackedVector3Array, normals, ids: Array) -> WindowTri:
	var tri := WindowTri.new()
	tri.a = xform * vertices[ids[0]]
	tri.b = xform * vertices[ids[1]]
	tri.c = xform * vertices[ids[2]]
	var cross := (tri.b - tri.a).cross(tri.c - tri.a)
	if cross.length_squared() < 1e-12:
		return null
	# Godotは時計回りが表なので外向きは逆向き
	tri.normal = -cross.normalized()
	if normals != null:
		var average := Vector3.ZERO
		for id in ids:
			average += xform.basis * (normals as PackedVector3Array)[id]
		if average.dot(tri.normal) < 0.0:
			tri.normal = -tri.normal
	tri.center = (tri.a + tri.b + tri.c) / 3.0
	if absf(tri.normal.y) < WINDOW_VERTICAL_MAX_Y:
		tri.n_h = Vector3(tri.normal.x, 0.0, tri.normal.z).normalized()
		tri.depth = tri.n_h.dot(tri.center)
	return tri


func _grid_cell(point: Vector3) -> Vector3i:
	return Vector3i((point / WINDOW_GRID_CELL).floor())


# 三角形のAABBが覆う全セルへ登録する
func _register_in_grid(grid: Dictionary, tri: WindowTri) -> void:
	var low := tri.a.min(tri.b).min(tri.c)
	var high := tri.a.max(tri.b).max(tri.c)
	var cell_low := _grid_cell(low)
	var cell_high := _grid_cell(high)
	for x in range(cell_low.x, cell_high.x + 1):
		for y in range(cell_low.y, cell_high.y + 1):
			for z in range(cell_low.z, cell_high.z + 1):
				var key := Vector3i(x, y, z)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(tri)


# 鉛直な三角形を、同じ平面（向きと奥行きが同じ）上でつながったまとまり（領域）に分けて返す
func _collect_window_regions(tris: Array[WindowTri]) -> Array:
	var groups := {}
	for tri in tris:
		if tri.n_h == Vector3.ZERO:
			continue
		var angle := roundi(rad_to_deg(atan2(tri.n_h.x, tri.n_h.z)) / 0.5)
		var key := Vector2i(angle, roundi(tri.depth * 100.0))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(tri)
	var regions := []
	for group: Array in groups.values():
		var tangent := Vector3.UP.cross((group[0] as WindowTri).n_h).normalized()
		var rects: Array[Rect2] = []
		for tri: WindowTri in group:
			rects.append(_tri_rect(tri, tangent).grow(WINDOW_REGION_JOIN_MARGIN))
		var parent := range(group.size())
		for i in group.size():
			for j in range(i + 1, group.size()):
				if rects[i].intersects(rects[j], true):
					var root_i := _find_root(parent, i)
					var root_j := _find_root(parent, j)
					if root_i != root_j:
						parent[root_j] = root_i
		var by_root := {}
		for i in group.size():
			var root := _find_root(parent, i)
			if not by_root.has(root):
				by_root[root] = []
			by_root[root].append(group[i])
		regions.append_array(by_root.values())
	return regions


func _find_root(parent: Array, index: int) -> int:
	while parent[index] != index:
		parent[index] = parent[parent[index]]
		index = parent[index]
	return index


# 三角形の (u, y) 平面での範囲を返す。u は tangent 方向の座標
func _tri_rect(tri: WindowTri, tangent: Vector3) -> Rect2:
	var u_values := [tri.a.dot(tangent), tri.b.dot(tangent), tri.c.dot(tangent)]
	var y_values := [tri.a.y, tri.b.y, tri.c.y]
	var u_min: float = u_values.min()
	var y_min: float = y_values.min()
	return Rect2(u_min, y_min, float(u_values.max()) - u_min, float(y_values.max()) - y_min)


# 領域の範囲が窓の大きさ以下で、領域が範囲をほぼ埋めていて、範囲の周りの4点すべての手前に同じ向きの外壁があれば窓とみなす
func _is_window_region(region: Array, grid: Dictionary) -> bool:
	var first: WindowTri = region[0]
	var tangent := Vector3.UP.cross(first.n_h).normalized()
	var rect := _tri_rect(first, tangent)
	for tri: WindowTri in region:
		rect = rect.merge(_tri_rect(tri, tangent))
	if rect.size.x > WINDOW_MAX_SIZE.x or rect.size.y > WINDOW_MAX_SIZE.y:
		return false
	var area := 0.0
	for tri: WindowTri in region:
		area += (tri.b - tri.a).cross(tri.c - tri.a).length() * 0.5
	if area < rect.get_area() * WINDOW_MIN_FILL_RATIO:
		return false
	var center := rect.get_center()
	var probes := [
		Vector2(rect.position.x - WINDOW_PROBE_OFFSET, center.y),
		Vector2(rect.end.x + WINDOW_PROBE_OFFSET, center.y),
		Vector2(center.x, rect.position.y - WINDOW_PROBE_OFFSET),
		Vector2(center.x, rect.end.y + WINDOW_PROBE_OFFSET),
	]
	for probe: Vector2 in probes:
		var point := tangent * probe.x + Vector3.UP * probe.y + first.n_h * first.depth
		if not _has_wall_in_front(point, first, grid):
			return false
	return true


# 点より手前方向（WINDOW_MIN_DEPTH〜WINDOW_MAX_DEPTH）に、同じ向きの三角形が重なっているかを返す
func _has_wall_in_front(point: Vector3, tri: WindowTri, grid: Dictionary) -> bool:
	var near_point := point + tri.n_h * WINDOW_MIN_DEPTH
	var far_point := point + tri.n_h * WINDOW_MAX_DEPTH
	var cell_low := _grid_cell(near_point.min(far_point))
	var cell_high := _grid_cell(near_point.max(far_point))
	for x in range(cell_low.x, cell_high.x + 1):
		for y in range(cell_low.y, cell_high.y + 1):
			for z in range(cell_low.z, cell_high.z + 1):
				var key := Vector3i(x, y, z)
				if not grid.has(key):
					continue
				for other: WindowTri in grid[key]:
					if _is_wall_over_point(other, point, tri):
						return true
	return false


func _is_wall_over_point(other: WindowTri, point: Vector3, tri: WindowTri) -> bool:
	if other.n_h.dot(tri.n_h) < WINDOW_SAME_FACING_DOT:
		return false
	var depth_diff := other.n_h.dot(other.center) - tri.depth
	if depth_diff < WINDOW_MIN_DEPTH or depth_diff > WINDOW_MAX_DEPTH:
		return false
	var facing := other.normal.dot(tri.n_h)
	if absf(facing) < 1e-6:
		return false
	# 点を n_h 方向に other の平面まで投影する
	var projected := point + tri.n_h * (other.normal.dot(other.a - point) / facing)
	return _is_inside_triangle(projected, other)


# 点が三角形の平面上にあるとして、重心座標で内側にあるかを返す（許容誤差 1e-4）
func _is_inside_triangle(point: Vector3, tri: WindowTri) -> bool:
	var v0 := tri.b - tri.a
	var v1 := tri.c - tri.a
	var v2 := point - tri.a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 1e-12:
		return false
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	var tolerance := 1e-4
	return v >= -tolerance and w >= -tolerance and v + w <= 1.0 + tolerance


# 窓の三角形の頂点を黒、それ以外を白にした頂点カラーを付けたメッシュをLOD付きで作り直す
func _rebuild_mesh_with_window_colors(mesh: ArrayMesh, tris: Array) -> ArrayMesh:
	var window_flags := {}
	for tri: WindowTri in tris:
		window_flags[Vector2i(tri.surface, tri.index)] = tri.is_window
	var importer_mesh := ImporterMesh.new()
	importer_mesh.set_lightmap_size_hint(mesh.lightmap_size_hint)
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
			_apply_window_colors(arrays, surface, window_flags)
		importer_mesh.add_surface(mesh.surface_get_primitive_type(surface), arrays, [], {},
				mesh.surface_get_material(surface), mesh.surface_get_name(surface))
	importer_mesh.generate_lods(LOD_NORMAL_MERGE_ANGLE, LOD_NORMAL_SPLIT_ANGLE, [])
	var new_mesh := importer_mesh.get_mesh()
	new_mesh.resource_name = mesh.resource_name
	return new_mesh


# arrays に頂点カラーを付ける。窓と窓以外の両方で使う頂点だけを窓側用に複製してインデックスを付け替える（窓だけで使う頂点は複製せず黒にする）
func _apply_window_colors(arrays: Array, surface: int, window_flags: Dictionary) -> void:
	var vertex_count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var old_indices = arrays[Mesh.ARRAY_INDEX]
	var corner_count: int = vertex_count if old_indices == null else old_indices.size()
	var colors := PackedColorArray()
	colors.resize(vertex_count)
	colors.fill(Color.WHITE)
	var new_indices := PackedInt32Array()
	new_indices.resize(corner_count)
	# 1周目: 頂点ごとに、窓の三角形で使われるか・窓以外の三角形で使われるかを集める
	var used_by_window := PackedByteArray()
	used_by_window.resize(vertex_count)
	var used_by_other := PackedByteArray()
	used_by_other.resize(vertex_count)
	for i in corner_count:
		var vertex: int = i if old_indices == null else old_indices[i]
		if window_flags.get(Vector2i(surface, i / 3), false):
			used_by_window[vertex] = 1
		else:
			used_by_other[vertex] = 1
	# 2周目: 窓用に複製した頂点: 元の頂点番号 -> 新しい頂点番号
	var window_copies := {}
	for i in corner_count:
		var vertex: int = i if old_indices == null else old_indices[i]
		if window_flags.get(Vector2i(surface, i / 3), false):
			if used_by_other[vertex] == 1:
				if not window_copies.has(vertex):
					window_copies[vertex] = _duplicate_vertex(arrays, vertex, colors, vertex_count)
				vertex = window_copies[vertex]
			else:
				colors[vertex] = Color(0.0, 0.0, 0.0)
		new_indices[i] = vertex
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = new_indices


# 頂点の全属性を末尾へ複製し、窓用の黒い頂点カラーを付けて新しい頂点番号を返す
func _duplicate_vertex(arrays: Array, vertex: int, colors: PackedColorArray, original_count: int) -> int:
	var new_vertex := colors.size()
	for kind in Mesh.ARRAY_MAX:
		if kind == Mesh.ARRAY_INDEX or kind == Mesh.ARRAY_COLOR or arrays[kind] == null:
			continue
		var data = arrays[kind]
		var stride: int = data.size() / original_count
		data.append_array(data.slice(vertex * stride, (vertex + 1) * stride))
		arrays[kind] = data
	colors.append(Color(0.0, 0.0, 0.0))
	return new_vertex


# 上面と側面のテクスチャ名を指定してテクスチャ付きマテリアルを作る
func _make_material(top: String, side: String, top_size: float, side_size: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter("top_texture", load(TEXTURE_DIR + top + ".png"))
	material.set_shader_parameter("side_texture", load(TEXTURE_DIR + side + ".png"))
	material.set_shader_parameter("top_tile_size", top_size)
	material.set_shader_parameter("side_tile_size", side_size)
	return material


# テクスチャを使わず単色で塗るマテリアルを作る
func _make_color_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter("use_textures", false)
	material.set_shader_parameter("albedo_color", color)
	return material


# 水色の菱形金網のマテリアルを作る（シェーダーのuniformは既定値を使う）
func _make_fence_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(FENCE_SHADER_PATH)
	return material


# プールの底（is_floor が true）またはプールサイドのマテリアルを作る（形の値はシェーダーの既定値を使う）
func _make_pool_material(is_floor: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(POOL_SHADER_PATH)
	material.set_shader_parameter("is_floor", is_floor)
	return material


# プールの水面の半透明のマテリアルを作る
func _make_pool_water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(POOL_WATER_SHADER_PATH)
	return material

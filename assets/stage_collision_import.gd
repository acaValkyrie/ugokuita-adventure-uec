@tool
extends EditorScenePostImport

# ステージ用GLBの取り込み時に、ローポリ版の建物を取り除き、建物・地面・オブジェクトのメッシュへ当たり判定を自動で付ける
const COLLIDABLE_PREFIXES := ["hi_", "ground", "object", "UEC", "本館B"]

# 木の日なた判定の光線を遮る物理レイヤー（レイヤー3）。幹は機体ともぶつかり、葉は日なた判定の光線だけを遮る
const SUN_OCCLUDER_LAYER := 1 << 2
# 機体ともぶつからせる木の幹のノード名の先頭
const TRUNK_PREFIX := "幹"

# キャンパス用テクスチャのシェーダーとテクスチャの置き場所
const SHADER_PATH := "res://assets/shaders/campus_triplanar.gdshader"
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
# 東西キャンパスの間の道路を表す線（ワールドXZ）。これより西の舗装はアスファルト、東はレンガ
const CAMPUS_BORDER_SOUTH := Vector2(-58.0, 71.0)
const CAMPUS_BORDER_NORTH := Vector2(14.0, -299.0)

# 建物の屋根・外壁の色（もとの外壁テクスチャの地の色）
const BUILDING_COLOR := Color(0.77, 0.703, 0.621)

# ライトマップ1ピクセルが覆う長さ（メートル）
const LIGHTMAP_TEXEL_SIZE := 0.5

# 同じ種類のマテリアルを取り込み中に使い回すためのキャッシュ
var _material_cache := {}


func _post_import(scene: Node) -> Object:
	_material_cache.clear()
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
	_set_lightmap_hints(scene)
	return scene


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
			if String(node.name).begins_with(TRUNK_PREFIX):
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
			# 機体の下の地面の種類（走行時の効果音の切り替えに使う）
			if not node.has_meta("surface_kind"):
				node.set_meta("surface_kind", kind)


# 元マテリアル名とノードから地面の種類を返す。該当なしは空文字
func _ground_kind(material_name: String, node: MeshInstance3D, scene: Node, under_ground: bool) -> String:
	if not GROUND_KIND_BY_MATERIAL.has(material_name):
		return ""
	var node_name := String(node.name)
	if material_name == "Plastic - Matte (Gray)" and node_name in ASPHALT_GRAY_NODE_NAMES:
		return "asphalt"
	if material_name == "Steel - Satin" and under_ground:
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
	_material_cache[kind] = material
	return material


# 建物の屋根・外壁をまとめて塗る単色のマテリアルを返す（なければ作る）
func _get_building_material() -> ShaderMaterial:
	if not _material_cache.has("building"):
		_material_cache["building"] = _make_color_material(BUILDING_COLOR)
	return _material_cache["building"]


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

@tool
extends EditorScenePostImport

# ステージ用GLBの取り込み時に、ローポリ版の建物を取り除き、建物・地面・オブジェクトのメッシュへ当たり判定を自動で付ける
const COLLIDABLE_PREFIXES := ["hi_", "ground", "object", "UEC", "本館B"]

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

# 灰色プラスチックのうち、土にするノード名
const DIRT_NODE_NAMES: Array[String] = ["Body28", "Body29"]

# 外壁を新しめの号館用・緑タイル用にする建物名（"hi_" を除く）。後で埋める
const MODERN_BUILDINGS: Array[String] = []
const GREEN_TILE_BUILDINGS: Array[String] = []

# 建物の屋根・外壁の寸法（メートル）
const ROOF_TILE_SIZE := 4.0
const WALL_TILE_SIZE := Vector2(7.0, 3.5)

# 同じ種類のマテリアルを取り込み中に使い回すためのキャッシュ
var _material_cache := {}


func _post_import(scene: Node) -> Object:
	_material_cache.clear()
	for child in scene.get_children():
		if _is_low_poly(child.name):
			scene.remove_child(child)
			child.free()
			continue
		_assign_materials(child)
		if _is_collidable(child.name):
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


# トップレベルのノードの種類に応じてマテリアルを割り当てる
func _assign_materials(node: Node) -> void:
	var node_name := String(node.name)
	if node_name == "ground" or node_name == "UEC敷地" or node_name == "UEC緑地" or node_name == "UEC収集所":
		_assign_ground_materials(node)
	elif node_name == "UEC縁石":
		_set_override_recursive(node, _get_ground_material("paving_stone"))
	elif node_name == "UEC壁":
		_set_override_recursive(node, _get_ground_material("wall_top_concrete"))
	elif node_name.begins_with("hi_") or node_name.begins_with("本館B"):
		_set_override_recursive(node, _get_building_material(node_name))


# 元マテリアル名を見て、サブツリー内の各サーフェスへ地面のマテリアルを割り当てる
func _assign_ground_materials(node: Node) -> void:
	for child in node.get_children():
		_assign_ground_materials(child)
	if not (node is MeshInstance3D) or node.mesh == null:
		return
	for i in node.mesh.get_surface_count():
		var source: Material = node.mesh.surface_get_material(i)
		if source == null:
			continue
		var kind: String = _ground_kind(source.resource_name, String(node.name))
		if kind != "":
			node.set_surface_override_material(i, _get_ground_material(kind))


# 元マテリアル名とノード名から地面の種類を返す。該当なしは空文字
func _ground_kind(material_name: String, node_name: String) -> String:
	if not GROUND_KIND_BY_MATERIAL.has(material_name):
		return ""
	if material_name == "Plastic - Matte (Gray)" and node_name in DIRT_NODE_NAMES:
		return "dirt"
	return GROUND_KIND_BY_MATERIAL[material_name]


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
		"paving_brick", "paving_stone":
			material = _make_material(kind, kind, 2.0, Vector2(2.0, 2.0))
		"dirt", "grass":
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


# 建物名から屋根と外壁のマテリアルを返す（なければ作る）
func _get_building_material(node_name: String) -> ShaderMaterial:
	var building := node_name.trim_prefix("hi_")
	var wall := "wall_classic"
	if building in MODERN_BUILDINGS:
		wall = "wall_modern"
	elif building in GREEN_TILE_BUILDINGS:
		wall = "wall_green_tile"
	var key := "building_" + wall
	if not _material_cache.has(key):
		_material_cache[key] = _make_material("roof_concrete", wall, ROOF_TILE_SIZE, WALL_TILE_SIZE)
	return _material_cache[key]


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

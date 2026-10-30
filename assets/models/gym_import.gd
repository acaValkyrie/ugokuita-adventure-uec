@tool
extends EditorScenePostImport

# 体育館（Gym.fbx）と、中に置く物（NadeggMini.glb）の取り込み時に、向きと見た目と当たり判定を整える
# Fusion から書き出したデータは Z が上なので、Godot の Y が上に合わせて向きを直す

# 木の日なた判定の光線を遮る物理レイヤー（レイヤー3）
const SUN_OCCLUDER_LAYER := 1 << 2
# 体育館の見た目のレイヤー（レイヤー11）。外の太陽（DirectionalLight3D）の光の対象から外す。
# 太陽の影は機体のまわり 6m しか描かないので、屋根があっても中に日が差してしまうため
const GYM_VISUAL_LAYER := 1 << 10
# 当たり判定を付けるファイル名（それ以外は見た目だけ）
const COLLIDABLE_SOURCES := ["Gym.fbx"]

# 差し替えるマテリアルの名前 → 差し替え先のマテリアルのパス
# Fusion から書き出すと木目などの外観の画像が含まれず、色も黒になるため
# 体育館の床には Poly Haven の wooden_floor_01（CC0）のフローリングを使う
const MATERIAL_OVERRIDES := {
	"Oak": "res://assets/textures/wooden_floor_01/wooden_floor_01.tres",
}


func _post_import(scene: Node) -> Object:
	# glb は Blender から Y が上の設定で書き出すため回さない
	# それ以外は Fusion の (x, y, z) を Godot の (x, z, -y) へ。X 軸まわりに -90°回す
	if scene is Node3D and get_source_file().get_extension() != "glb":
		scene.transform.basis = Basis(Vector3.RIGHT, -PI / 2.0)

	var overrides := {}
	for material_name in MATERIAL_OVERRIDES:
		var loaded := load(MATERIAL_OVERRIDES[material_name]) as Material
		if loaded == null:
			push_error("gym_import: 差し替え先のマテリアルを読み込めないため飛ばす: %s" % MATERIAL_OVERRIDES[material_name])
			continue
		overrides[material_name] = loaded

	var collidable: bool = get_source_file().get_file() in COLLIDABLE_SOURCES
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(scene, meshes)
	for mi in meshes:
		for i in mi.mesh.get_surface_count():
			var material := mi.get_active_material(i)
			if material != null and overrides.has(material.resource_name):
				mi.set_surface_override_material(i, overrides[material.resource_name])
		# 体育館の中は屋外のライトマップに含めない
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.layers = GYM_VISUAL_LAYER
		if collidable:
			mi.create_trimesh_collision()
			var body := mi.get_child(mi.get_child_count() - 1)
			if body is StaticBody3D:
				# 機体・カメラとぶつかり（レイヤー1）、太陽の光線も遮る（レイヤー3）
				body.collision_layer = 1 | SUN_OCCLUDER_LAYER
				body.collision_mask = 0
	return scene


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)

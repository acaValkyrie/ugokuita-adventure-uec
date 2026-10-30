# Web Compatibility は、設定の各組合せで余分な未使用のデフォルトシェーダーを初描画時に作り、Windows Chrome では約2.8秒止まる。
# 見た目に影響しない3つの設定を取り除き、キャンパスと共通のシェーダーへ寄せる。
extends RefCounted


static func simplify(scene: Node, single_sided: bool) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(scene, meshes)
	# 同じマテリアルを使う面のどれかに頂点カラーがあれば、色の設定を残す
	var material_colors := {}
	for mi in meshes:
		for i in mi.mesh.get_surface_count():
			var material := mi.get_active_material(i) as BaseMaterial3D
			if material == null:
				continue
			# 外部のマテリアルは他のシーンと共有するので変えない
			if material.resource_path != "" and not material.resource_path.contains("::"):
				continue
			var has_colors: bool = (mi.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0
			material_colors[material] = material_colors.get(material, false) or has_colors

	var counts := {"materials": material_colors.size(), "emission": 0, "vertex_color": 0, "cull": 0}
	# 共有されたマテリアルは1回だけ変更して数える
	for key in material_colors:
		var material := key as BaseMaterial3D
		if material.emission_enabled and material.emission_texture == null and maxf(material.emission.r, maxf(material.emission.g, material.emission.b)) * material.emission_energy_multiplier == 0.0:
			material.emission_enabled = false
			counts.emission += 1
		if material.vertex_color_use_as_albedo and not material_colors[material]:
			material.vertex_color_use_as_albedo = false
			counts.vertex_color += 1
		if single_sided and material.cull_mode == BaseMaterial3D.CULL_DISABLED and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			material.cull_mode = BaseMaterial3D.CULL_BACK
			counts.cull += 1
	return counts


static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)

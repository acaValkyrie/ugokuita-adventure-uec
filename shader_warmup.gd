extends CanvasLayer
# 起動直後に、読み込み中の画面の裏でキャンパス全体を一度描いて、シェーダーを先に作らせる。
# Compatibility では初めて描いた瞬間にシェーダーを作るので、走り出してから止まるのを防ぐ。
# 一時的なカメラを上空のタイルごとと、地上の4方向に向けて、各視点を数フレームずつ見せる。
# 前のカメラの視点で、プレイヤーの効果（ドリフトの帯、火花、ジェット、集中線）も一度描く。
# 看板の白枠とヒント（近づくまで隠れている）も、先読みの間だけ出して描かせる。
# 後から読み込む階段・倉庫・Classic の材質も、代わりの小さな物体で先に描く。
# シーンにある材質も種類ごとに小さな板で描き、隠れている物体のシェーダーも先に作る。
# 読み込み画面を先に出すため、先読みを始めるまではルートの3D描画を止める。

# タイルに分ける範囲は Map.WORLD_RECT（x / z の範囲）を使う
# 1辺のタイルの数
const GRID := 4
# 上空の視点のカメラの高さ（y=0 から）
const TILE_HEIGHT := 150.0
# 地上の視点の高さ（前のカメラが無いとき、プレイヤーの上にこの分足す）
const GROUND_VIEW_HEIGHT := 1.5
# 各視点を描いて見せるフレーム数
const FRAMES_PER_VIEW := 2
# 効果の視点を見せるフレーム数（粒の出始めを描かせるため長め）
const EFFECT_FRAMES := 4
# メインのシーンとプレイヤーが揃ってから待つフレーム数（パワーアップなどがシーンの開始時に出るため）
const START_WAIT_FRAMES := 3
# シーンはあるのにプレイヤーが居ないまま、このフレーム数たったら先読みをやめて画面を消す
const NO_PLAYER_GIVE_UP_FRAMES := 30
# ウォームアップ用の板だけを描くレンダーレイヤー20
const KIND_LAYER := 1 << 19

# 読み込み画面の見た目（DOS のような黒い画面に文字が並ぶ）
const TERM_FONT := preload("res://assets/fonts/vt323/VT323-Regular.ttf")
const TERM_COLOR := Color("#c0c0c0")
const BAR_COLOR := Color("#e0182d")
const TERM_FONT_SIZE := 32
const TERM_MARGIN := 32.0
# 進み具合の棒の文字数
const BAR_CHARS := 20

enum State { WAIT_SCENE, WAIT_FRAMES, RUNNING }

var _state := State.WAIT_SCENE
# 一度でも終えたら true。起動ごとに1回だけ動かす
var _done := false
var _wait_frames := 0
var _camera: Camera3D
var _prev_camera: Camera3D
var _views: Array[Transform3D] = []
var _view_index := 0
var _view_frames := 0
# シーンの材質を描く視点の開始番号（無ければ -1）
var _kind_view_index := -1
var _tile_view_index := 0
var _kind_materials: Array[Material] = []
var _kind_mesh: MeshInstance3D
# 効果の視点の番号（無ければ -1）
var _effects_view_index := -1
# 代わりの物体を描く視点の開始番号（無ければ -1）
var _standin_view_index := -1
var _standin_kinds: Array[int] = []
var _effects_active := false
var _saved_particles: Array = []
# シーンに置いた効果（噴水など）の粒の、元の process_mode
var _saved_world_particles: Array = []
var _warm_meshes: Array[MeshInstance3D] = []
var _standin_nodes: Array[Node3D] = []
# 最後の同設定の材質を解放するとシェーダーが再生成されるため、終了後も保持する。
var _standin_resources: Array[Resource] = []
var _standin_box: BoxMesh
var _standin_texture: ImageTexture
var _screen: ColorRect
var _term: RichTextLabel


func _ready() -> void:
	# Web の Compatibility では、最初のキャンパスの3D描画でシェーダーを作る間、
	# ブラウザの再描画が約22秒止まり、2DのDOS読み込み画面も出せなくなる。
	# 先に読み込み画面を出せるよう、先読みを始めるまでは3D描画を止める。
	get_tree().root.disable_3d = true
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_screen()
	_render_term()


# 起動時の先読み（読み込み画面）の途中か。この間はメニューとマップを開かせない
func is_loading() -> bool:
	return not _done


func _process(_delta: float) -> void:
	if _done:
		set_process(false)
		return
	match _state:
		State.WAIT_SCENE:
			_render_term()
			if get_tree().current_scene != null:
				if get_tree().get_first_node_in_group("player") != null:
					_state = State.WAIT_FRAMES
					_wait_frames = 0
				else:
					_wait_frames += 1
					if _wait_frames >= NO_PLAYER_GIVE_UP_FRAMES:
						get_tree().root.disable_3d = false
						_screen.visible = false
						_done = true
						set_process(false)
						return
		State.WAIT_FRAMES:
			_render_term()
			_wait_frames += 1
			if _wait_frames >= START_WAIT_FRAMES:
				_start()
		State.RUNNING:
			_render_term()
			_step()


# 読み込み中の画面（黒い背景に、DOS のコマンドの文字が並ぶ）。起動直後から出して、ゲーム画面が見えないようにする。入力は受け止める
func _setup_screen() -> void:
	_screen = ColorRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.color = Color(0, 0, 0)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	_term = RichTextLabel.new()
	_term.set_anchors_preset(Control.PRESET_FULL_RECT)
	_term.offset_left = TERM_MARGIN
	_term.offset_top = TERM_MARGIN
	_term.offset_right = -TERM_MARGIN
	_term.offset_bottom = -TERM_MARGIN
	_term.bbcode_enabled = true
	_term.scroll_active = false
	_term.fit_content = false
	_term.autowrap_mode = TextServer.AUTOWRAP_OFF
	_term.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_term.add_theme_font_override("normal_font", TERM_FONT)
	_term.add_theme_font_size_override("normal_font_size", TERM_FONT_SIZE)
	_term.add_theme_color_override("default_color", TERM_COLOR)
	_screen.add_child(_term)


# 始まった段階だけ、コマンドと進み具合の棒を並べる。最後の行はまたたくカーソル
func _render_term() -> void:
	var phases: Array = []
	if _kind_view_index >= 0:
		phases.append(["COMPILE SHADERS.SYS", _kind_view_index, _kind_materials.size()])
	phases.append(["LOAD CAMPUS.DAT", _tile_view_index, GRID * GRID])
	phases.append(["SCAN GROUND.DAT", _tile_view_index + GRID * GRID, 4])
	if _effects_view_index >= 0:
		phases.append(["INIT EFFECTS.SYS", _effects_view_index, 1])
	if _standin_view_index >= 0:
		phases.append(["LOAD EXTRA.DAT", _standin_view_index, _standin_kinds.size()])
	var text := "UGOKUITA-OS v1.0\n(C) Ugokuita Project\n\n"
	for phase in phases:
		var start: int = phase[1]
		var total: int = phase[2]
		if _view_index < start:
			break
		var done := clampi(_view_index - start, 0, total)
		var filled := BAR_CHARS * done / total
		text += "C:\\> %s\n" % phase[0]
		text += "  [lb][color=#%s]%s[/color]%s] %d/%d" % [
				BAR_COLOR.to_html(false), "#".repeat(filled),
				".".repeat(BAR_CHARS - filled), done, total]
		if done >= total:
			text += " OK"
		text += "\n"
	# カーソルは0.5秒ごとに出たり消えたりする
	text += "_" if (Time.get_ticks_msec() / 500) % 2 == 0 else " "
	_term.text = text


func _start() -> void:
	get_tree().root.disable_3d = false
	_screen.visible = true
	get_tree().paused = true
	_prev_camera = get_viewport().get_camera_3d()
	# 噴水など、シーンに置いた粒もツリーを止めている間は動かないので、上空と地上の視点で描かれるよう動かす
	for node in get_tree().get_nodes_in_group("warmup_particles"):
		_saved_world_particles.append([node, node.process_mode])
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = Camera3D.new()
	_camera.far = 3000.0
	_camera.fov = 75.0
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(_camera)
	_camera.make_current()
	# 看板の白枠とヒントは近づくまで隠れているので、先読みの間だけ出す
	LinkBoard.set_warmup(true)
	_build_views()
	_view_index = 0
	_view_frames = 0
	_apply_view()
	_state = State.RUNNING


# 視点の一覧を先に作る（材質の種類、上空のタイル、地上の4方向、効果、代わりの物体）
func _build_views() -> void:
	_views.clear()
	_kind_materials.clear()
	_collect_scene_materials(get_tree().current_scene, {})
	var ground_pos: Vector3
	var kind_transform: Transform3D
	if is_instance_valid(_prev_camera):
		ground_pos = _prev_camera.global_position
		kind_transform = _prev_camera.global_transform
	else:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		ground_pos = player.global_position + Vector3.UP * GROUND_VIEW_HEIGHT
		kind_transform = Transform3D(Basis.IDENTITY, ground_pos)
	_kind_view_index = -1
	if not _kind_materials.is_empty():
		_kind_view_index = 0
		for _material in _kind_materials:
			_views.append(kind_transform)
	_tile_view_index = _views.size()
	var rect: Rect2 = Map.WORLD_RECT
	var tile := rect.size / float(GRID)
	for iz in GRID:
		for ix in GRID:
			var center := rect.position + Vector2((ix + 0.5) * tile.x, (iz + 0.5) * tile.y)
			var pos := Vector3(center.x, TILE_HEIGHT, center.y)
			# X 軸まわりに -90 度回して、-Z を真下に向ける
			_views.append(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), pos))
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		_views.append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), ground_pos))
	# 前のカメラそのものの視点で効果を描き、その後に代わりの物体を描く
	_effects_view_index = -1
	var standin_transform: Transform3D = _views.back()
	if is_instance_valid(_prev_camera):
		_effects_view_index = _views.size()
		standin_transform = _prev_camera.global_transform
		_views.append(standin_transform)
	_standin_kinds.clear()
	_standin_kinds.append(0)
	_standin_kinds.append(1)
	if GameMenu.robot_model == "classic":
		_standin_kinds.append(2)
	_standin_view_index = -1
	if not _standin_kinds.is_empty():
		_standin_view_index = _views.size()
		for _kind in _standin_kinds:
			_views.append(standin_transform)


func _apply_view() -> void:
	_camera.global_transform = _views[_view_index]
	_render_term()
	if _kind_view_index >= 0 and _view_index < _tile_view_index:
		_camera.cull_mask = KIND_LAYER
		_show_kind_material(_kind_materials[_view_index - _kind_view_index])
	else:
		_camera.cull_mask = 0xFFFFF
	if _view_index == _effects_view_index:
		_begin_effects()
	if _standin_view_index >= 0 and _view_index >= _standin_view_index:
		_show_standin(_standin_kinds[_view_index - _standin_view_index])


# 各視点を FRAMES_PER_VIEW フレーム見せてから次へ進む
func _step() -> void:
	_view_frames += 1
	var frames := EFFECT_FRAMES if _view_index == _effects_view_index else FRAMES_PER_VIEW
	if _view_frames < frames:
		return
	_view_frames = 0
	_hide_kind_material()
	if _view_index == _effects_view_index:
		_end_effects()
	if _standin_view_index >= 0 and _view_index >= _standin_view_index:
		_hide_standins()
	_view_index += 1
	if _view_index >= _views.size():
		_finish()
	else:
		_apply_view()


func _finish() -> void:
	_hide_kind_material()
	_kind_materials.clear()
	_hide_standins()
	if _effects_active:
		_end_effects()
	for entry in _saved_particles:
		var p := entry[0] as CPUParticles3D
		if is_instance_valid(p):
			p.process_mode = entry[1]
			p.emitting = entry[2]
	_saved_particles.clear()
	for entry in _saved_world_particles:
		if is_instance_valid(entry[0]):
			entry[0].process_mode = entry[1]
	_saved_world_particles.clear()
	_camera.queue_free()
	if is_instance_valid(_prev_camera):
		_prev_camera.make_current()
	LinkBoard.set_warmup(false)
	get_tree().paused = false
	_screen.visible = false
	_done = true
	set_process(false)


# 見えているかどうかにかかわらず、シーンの材質を種類ごとに集める
func _collect_scene_materials(node: Node, kinds: Dictionary) -> void:
	if node is GeometryInstance3D and not (node is SpriteBase3D or node is Label3D or node is GPUParticles3D or node is CPUParticles3D):
		var geometry := node as GeometryInstance3D
		if geometry.material_override != null:
			_collect_material_chain(geometry.material_override, kinds)
		elif node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				for surface in mesh_instance.mesh.get_surface_count():
					_collect_material_chain(mesh_instance.get_active_material(surface), kinds)
		_collect_material_chain(geometry.material_overlay, kinds)
	for child in node.get_children():
		_collect_scene_materials(child, kinds)


# next_pass も描かれるので、同じ材質に戻るまで種類を調べる
func _collect_material_chain(material: Material, kinds: Dictionary) -> void:
	var visited := {}
	while material != null:
		var instance_id := material.get_instance_id()
		if visited.has(instance_id):
			break
		visited[instance_id] = true
		var key := _material_kind_key(material)
		if not key.is_empty() and not kinds.has(key):
			kinds[key] = true
			_kind_materials.append(material)
		material = material.next_pass


# 色やテクスチャの違いはまとめて、シェーダーを変える設定だけで種類を分ける
func _material_kind_key(material: Material) -> String:
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		if shader_material.shader == null:
			return ""
		return "S" + str(shader_material.shader.get_instance_id())
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		var settings: Array = []
		for property in [
			"texture_filter", "detail_uv_layer", "transparency", "alpha_antialiasing_mode",
			"shading_mode", "blend_mode", "depth_draw_mode", "cull_mode", "diffuse_mode",
			"specular_mode", "billboard_mode", "detail_blend_mode", "roughness_texture_channel",
			"emission_operator", "distance_fade_mode", "heightmap_deep_parallax", "grow",
			"proximity_fade_enabled",
		]:
			settings.append(base.get(property))
		for feature in BaseMaterial3D.FEATURE_MAX:
			settings.append(base.get_feature(feature))
		for flag in BaseMaterial3D.FLAG_MAX:
			settings.append(base.get_flag(flag))
		settings.append(base.get("no_depth_test"))
		return "B:%s:%s" % [base.get_class(), str(settings)]
	return ""


# 実際の材質を小さな板に貼り、カメラのすぐ前で一度描かせる
func _show_kind_material(material: Material) -> void:
	_hide_kind_material()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	_kind_mesh = MeshInstance3D.new()
	_kind_mesh.mesh = quad
	_kind_mesh.layers = KIND_LAYER
	_kind_mesh.material_override = material
	_kind_mesh.process_mode = Node.PROCESS_MODE_ALWAYS
	_kind_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	get_tree().current_scene.add_child(_kind_mesh)
	_kind_mesh.global_transform = Transform3D(_camera.global_basis, _camera.to_global(Vector3(0.0, 0.0, -2.0)))


# 材質の視点を離れたら板を消す
func _hide_kind_material() -> void:
	if is_instance_valid(_kind_mesh):
		_kind_mesh.queue_free()
	_kind_mesh = null


# プレイヤーの効果を一度描かせる（粒を出し、帯の材質に三角形を足し、集中線を出す）
func _begin_effects() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for node in player.find_children("*", "CPUParticles3D", true, false):
		var p := node as CPUParticles3D
		_saved_particles.append([p, p.process_mode, p.emitting])
		# 準備中はツリーを止めているので、粒だけ動かす
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.emitting = true
	for node in player.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is ImmediateMesh):
			continue
		# 帯は top_level で変換が単位行列なので、頂点はワールド座標で書く
		var p: Vector3 = (player as Node3D).global_position + Vector3.UP * 0.05
		var im := mi.mesh as ImmediateMesh
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [p, p + Vector3(0.3, 0.0, 0.0), p + Vector3(0.0, 0.0, 0.3)]:
			im.surface_set_color(Color(1.0, 0.2, 0.1, 0.5))
			im.surface_add_vertex(v)
		im.surface_end()
		_warm_meshes.append(mi)
	# 集中線もツリーと一緒に止まっているので、ここで出しても隠されない
	SpeedLines._rect.visible = true
	_effects_active = true


# 効果を止め、残りの視点を描く間に粒を消す
func _end_effects() -> void:
	if not _effects_active:
		return
	for entry in _saved_particles:
		var p := entry[0] as CPUParticles3D
		if not is_instance_valid(p):
			continue
		p.emitting = false
		# restart() は Godot 4.7.1 で一度更新して新しい粒を出すため使わない
		p.amount = p.amount
		# PROCESS_MODE_ALWAYS は先読みの終了まで保ち、停止中も粒を更新する
	for mi in _warm_meshes:
		if is_instance_valid(mi):
			(mi.mesh as ImmediateMesh).clear_surfaces()
	_warm_meshes.clear()
	SpeedLines._rect.visible = false
	_effects_active = false


# 後から読み込む材質を、種類ごとに代わりの物体で一度描かせる
func _show_standin(kind: int) -> void:
	_hide_standins()
	# 4x4 のテクスチャと BoxMesh は種類をまたいで共有する。
	if _standin_box == null:
		_standin_box = BoxMesh.new()
		_standin_box.size = Vector3.ONE * 0.3
		_standin_resources.append(_standin_box)
	if _standin_texture == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_standin_texture = ImageTexture.create_from_image(image)
		_standin_resources.append(_standin_texture)
	var node: Node3D
	match kind:
		0:
			# gomi.pck は読み込み画面の後にダウンロードされる。
			# Compatibility のシェーダーは材質の設定で決まる。
			var stair_material := StandardMaterial3D.new()
			stair_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			stair_material.albedo_color = Color(1.0, 1.0, 1.0, 0.5)
			_standin_resources.append(stair_material)
			var stair := MeshInstance3D.new()
			stair.mesh = _standin_box
			stair.material_override = stair_material
			node = stair
		1:
			var warehouse := Sprite3D.new()
			warehouse.texture = _standin_texture
			warehouse.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			warehouse.shaded = true
			warehouse.double_sided = true
			warehouse.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			warehouse.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			warehouse.pixel_size = 0.01
			warehouse.scale = Vector3.ONE * 7.5
			node = warehouse
		2:
			# classic.pck は読み込み画面の後にダウンロードされる。
			var wood_material := StandardMaterial3D.new()
			wood_material.roughness = 1.0
			wood_material.normal_enabled = true
			wood_material.uv1_triplanar = true
			_standin_resources.append(wood_material)
			var wood := MeshInstance3D.new()
			wood.mesh = _standin_box
			wood.material_override = wood_material
			node = wood
	if node == null:
		return
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(node)
	node.global_position = _camera.to_global(Vector3(0.0, 0.0, -2.0))
	_standin_nodes.append(node)


# 現在の代わりの物体を消す。材質や共有リソースは保持する。
func _hide_standins() -> void:
	for node in _standin_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_standin_nodes.clear()

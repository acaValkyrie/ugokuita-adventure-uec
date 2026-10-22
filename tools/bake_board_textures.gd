extends Node
# 機体の基板を部品ごと、board_parts.gd の view の面から撮り、board_parts.gd の texture に保存する（取り込み時に部品を取り除いた板に貼る画像）。
# 実行: Godot --path <プロジェクト> res://tools/bake_board_textures.tscn（headless では描画できない）
# glb を書き換えたら撮り直してから取り込み直す

const BoardParts := preload("res://assets/board_parts.gd")
const SOURCE := "res://assets/ugokuita-neo.glb"
# 撮る幅 [px]。縮小して輪郭をなめらかにする
const RENDER_WIDTH := 2048
# 保存する幅 [px]。基板は約 100mm なので約 5px/mm
const OUTPUT_WIDTH := 512
# 描画が落ち着くまで待つフレーム数
const WAIT_FRAMES := 10


func _ready() -> void:
    for entry in BoardParts.BOARDS.get(SOURCE.get_file(), []):
        if entry.texture == "":
            continue
        await _bake(entry)
    get_tree().quit()


func _bake(entry: Dictionary) -> void:
    # 取り込みスクリプトを通さずに読むので、部品が残ったまま
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err := doc.append_from_file(SOURCE, state)
    if err != OK:
        print("読み込めない: ", SOURCE, " (", err, ")")
        return
    var scene := doc.generate_scene(state)

    var viewport := SubViewport.new()
    viewport.own_world_3d = true
    viewport.msaa_3d = Viewport.MSAA_8X
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    viewport.add_child(scene)

    var group := scene.get_node_or_null(NodePath(entry.group)) as Node3D
    if group == null:
        print("基板のノードが見つからない: ", entry.group)
        viewport.queue_free()
        return
    var board_mi := BoardParts.find_board_mesh(group, entry.board)
    if board_mi == null:
        print("基板のメッシュが見つからない: ", entry.board)
        viewport.queue_free()
        return
    var parts := BoardParts.find_low_parts(group, board_mi, entry.top_height, entry.bottom_height)

    # 基板と取り除く部品だけを写す
    var shown := {}
    shown[board_mi] = true
    for part in parts:
        shown[part] = true
    var shown_part_count := 0
    # 光の当たり方を入れず、マテリアルの色だけを撮る（ゲームの中で改めて照らされるため）
    # マテリアルを複製して unshaded にする（SubViewport の debug_draw は効かなかった）
    var unshaded := {}
    for mi in scene.find_children("*", "MeshInstance3D", true, false):
        var visible_mesh: bool = shown.has(mi)
        if not visible_mesh:
            for part in parts:
                if part.is_ancestor_of(mi):
                    visible_mesh = true
                    break
        mi.visible = visible_mesh
        if visible_mesh:
            for i in mi.mesh.get_surface_count():
                var base := mi.get_active_material(i) as BaseMaterial3D
                if base == null:
                    continue
                if not unshaded.has(base):
                    var copy := base.duplicate() as BaseMaterial3D
                    copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    unshaded[base] = copy
                mi.set_surface_override_material(i, unshaded[base])
        if visible_mesh and mi != board_mi:
            shown_part_count += 1

    var aabb := board_mi.mesh.get_aabb()
    var out_height := roundi(OUTPUT_WIDTH * aabb.size.z / aabb.size.x)
    viewport.size = Vector2i(RENDER_WIDTH, roundi(RENDER_WIDTH * aabb.size.z / aabb.size.x))

    var g := board_mi.global_transform
    if g.basis.determinant() <= 0.0:
        push_error("基板が反転しているため撮れない: %s" % entry.board)
        viewport.queue_free()
        return
    # 向きは board_parts.gd の set_projected_uv と合わせる
    # top: 真上から見て、画像の左が板のメッシュの -X、上が -Z
    # bottom: 真下から見て、画像の左が -X、上が +Z
    var center := aabb.get_center()
    var local_basis := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
    var face_center := Vector3(center.x, aabb.end.y, center.z)
    if entry.view == "bottom":
        local_basis = Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
        face_center = Vector3(center.x, aabb.position.y, center.z)
    var cam_basis := (g.basis * local_basis).orthonormalized()
    var top_center := g * face_center
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect = Camera3D.KEEP_WIDTH
    camera.size = aabb.size.x * g.basis.x.length()
    camera.near = 0.001
    camera.far = 2.0
    viewport.add_child(camera)
    camera.global_transform = Transform3D(cam_basis, top_center + cam_basis.z * 1.0)
    camera.current = true

    for i in WAIT_FRAMES:
        await get_tree().process_frame
    var image := viewport.get_texture().get_image()
    image.resize(OUTPUT_WIDTH, out_height, Image.INTERPOLATE_LANCZOS)
    var path := ProjectSettings.globalize_path(entry.texture)
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var save_err := image.save_png(path)
    print("saved: ", path, " ", image.get_size(), " (", save_err, ") 写した部品のメッシュ: ", shown_part_count)
    viewport.queue_free()

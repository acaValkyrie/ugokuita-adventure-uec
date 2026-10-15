extends Node
# ステージを真上から撮って assets/map/campus_map.png に保存する（全体マップの背景用）。
# 実行: Godot --path <プロジェクト> res://tools/capture_map.tscn（headless では描画できない）

# map.gd の WORLD_RECT を参照する（Autoload 経由にしない）
const MapScript := preload("res://map.gd")
const OUT_PATH := "res://assets/map/campus_map.png"
const IMAGE_SIZE := Vector2i(1536, 1479)
# 描画が落ち着くまで待つフレーム数
const WAIT_FRAMES := 30


func _ready() -> void:
    var main: Node = (load("res://main_scene.tscn") as PackedScene).instantiate()
    add_child(main)
    # 機体は写さない
    for node in get_tree().get_nodes_in_group("player"):
        if node is Node3D:
            (node as Node3D).visible = false

    # メインの世界を映す SubViewport
    var viewport := SubViewport.new()
    viewport.size = IMAGE_SIZE
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)

    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    camera.size = MapScript.WORLD_RECT.size.y
    camera.near = 1.0
    camera.far = 400.0
    viewport.add_child(camera)
    var center := MapScript.WORLD_RECT.get_center()
    camera.position = Vector3(center.x, 150.0, center.y)
    # 真下を向き、画面の上がワールドの -Z になる向き
    camera.look_at(camera.position + Vector3.DOWN, Vector3.FORWARD)
    camera.current = true

    # 霧を切った環境にする
    var world_env := _find_world_environment(main)
    if world_env != null and world_env.environment != null:
        var env := world_env.environment.duplicate() as Environment
        env.fog_enabled = false
        camera.environment = env

    for i in WAIT_FRAMES:
        await get_tree().process_frame
    var image := viewport.get_texture().get_image()
    var path := ProjectSettings.globalize_path(OUT_PATH)
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var err := image.save_png(path)
    print("saved: ", path, " (", err, ")")
    get_tree().quit()


func _find_world_environment(node: Node) -> WorldEnvironment:
    if node is WorldEnvironment:
        return node
    for child in node.get_children():
        var found := _find_world_environment(child)
        if found != null:
            return found
    return null

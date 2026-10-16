extends Node
# 木の見た目を切り替える。
# ORIGINAL: 元のマテリアル、MATTE: 金属感のない葉・幹（案 A）、FLUFFY: MATTE + 葉の板で覆ったふわふわの葉（案 B）。
# デバッグビルドでは、7 キーでモード切り替え、8 キーで計測表示、スタート地点の近くに「元・A・B」の比較用の木を並べる。（F7・F8 はエディタのショートカットと重なるので使わない）

enum Mode { ORIGINAL, MATTE, FLUFFY }
enum Kind { LEAF, TRUNK, PINE_LEAF }

const DEFAULT_MODE := Mode.FLUFFY
const SHOW_COMPARE_ROW := true  # あとで false にする

# 葉の板
const CARDS_PER_M2 := 6.0
const CARD_SIZE := 1.1  # 板の大きさ（m）
const CARD_MIN := 24
const CARD_MAX := 400
const CARD_OFFSET := 0.05  # 表面から外へ浮かす距離（m）
const CARD_BASE_COLOR := Color(0.75, 0.9, 0.65)

# 色。木ごとのばらつきは明るさ ±8%、色相 ±0.03
const LEAF_COLOR := Color(0.45, 0.6, 0.38)
const PINE_LEAF_COLOR := Color(0.28, 0.42, 0.4)
const BARK_COLOR := Color(0.55, 0.48, 0.43)
const FLUFFY_INNER_DARKEN := 0.7
const BRIGHT_STEPS := 7
const HUE_STEPS := 5
const BRIGHT_RANGE := 0.08
const HUE_RANGE := 0.03
const LEAF_TILE_METERS := 1.5
const BARK_TILE_METERS := 1.0

const LEAF_CLUSTER_PATH := "res://assets/textures/foliage/leaf_cluster.png"
const LEAF_TILE_PATH := "res://assets/textures/foliage/leaf_tile.png"
const BARK_TILE_PATH := "res://assets/textures/foliage/bark_tile.png"
const LEAF_MATTE_SHADER_PATH := "res://assets/shaders/foliage_matte.gdshader"
const LEAF_CARDS_SHADER_PATH := "res://assets/shaders/leaf_cards.gdshader"
const FONT_PATH := "res://assets/fonts/noto_sans_cjk_jp_bold_ui.otf"

const BROADLEAF_TYPES := ["Tree1", "Tree1-2", "Tree2", "Tree4", "Grass1-2", "Grass2"]
const PINE_TYPES := ["PineTree", "PineTree2", "PineTree3"]

# 比較用の木
const TREE_ROOT_PATH := "UEC/tree"
const COMPARE_SOURCES := [
    "UEC/tree/東地区樹木_1/東地区樹木/Tree1 v3_2",
    "UEC/tree/東地区樹木_1/東地区樹木/Tree1-2 v4_4",
]
const CAR_START := Vector3(72.17, 0.23, -112.58)
const COMPARE_FORWARD := -16.0
const COMPARE_RIGHT := 14.8
const COMPARE_SPACING := 7.0
const COMPARE_ROW_GAP := -9.0
const COMPARE_LABEL_HEIGHT := 7.0

var mode: Mode = DEFAULT_MODE
var last_build_msec := 0.0
var card_count := 0

var _scene: Node = null
var _entries: Array = []  # 全体のモードに従う木（葉・幹のメッシュごと）
var _compare_entries: Array = []  # 比較用の木（見た目は固定）
var _mat_cache := {}
var _card_material: ShaderMaterial = null
var _leaf_tex: Texture2D = null
var _bark_tex: Texture2D = null
var _cluster_tex: Texture2D = null
var _textures_loaded := false

var _stats_layer: CanvasLayer
var _stats_label: Label


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if OS.is_debug_build():
        _stats_layer = CanvasLayer.new()
        _stats_layer.layer = 30
        _stats_layer.visible = false
        add_child(_stats_layer)
        _stats_label = Label.new()
        _stats_label.position = Vector2(16, 72)
        _stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _stats_label.add_theme_font_size_override("font_size", 14)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0, 0, 0, 0.7)
        style.set_content_margin_all(6)
        _stats_label.add_theme_stylebox_override("normal", style)
        _stats_layer.add_child(_stats_label)


func _process(_delta: float) -> void:
    var scene := get_tree().current_scene
    if scene != _scene:
        _scene = scene
        _entries.clear()
        _compare_entries.clear()
        card_count = 0
        last_build_msec = 0.0
        if scene != null:
            _build_all(scene)
    if _stats_layer != null and _stats_layer.visible:
        _update_stats_label()


func _input(event: InputEvent) -> void:
    if not OS.is_debug_build():
        return
    var key := event as InputEventKey
    if key == null or not key.pressed or key.echo:
        return
    if key.keycode == KEY_7:
        set_mode(((mode + 1) % 3) as Mode)
    elif key.keycode == KEY_8:
        _stats_layer.visible = not _stats_layer.visible


# 全体のモードを切り替える（比較用の木は固定のまま）
func set_mode(m: Mode) -> void:
    mode = m
    for entry in _entries:
        _apply_entry(entry, mode)


# 計測値を辞書で返す
func get_stats() -> Dictionary:
    return {
        "mode": Mode.keys()[mode],
        "fps": Engine.get_frames_per_second(),
        "process_msec": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
        "objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
        "video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
        "card_count": card_count,
        "build_msec": last_build_msec,
    }


func _update_stats_label() -> void:
    var s := get_stats()
    _stats_label.text = "mode: %s\nFPS: %d\nprocess: %.2f ms\ndraw calls: %d\nprimitives: %d\nobjects: %d\nVRAM: %.1f MB\ncards: %d (build %.0f ms)" % [
        s["mode"], s["fps"], s["process_msec"], s["draw_calls"], s["primitives"],
        s["objects"], s["video_mem_mb"], s["card_count"], s["build_msec"]]


# ---- 構築 ----

func _build_all(scene: Node) -> void:
    _load_textures()
    var t0 := Time.get_ticks_usec()
    var root := scene.get_node_or_null(TREE_ROOT_PATH)
    if root != null:
        _entries = _collect_entries(root)
        for entry in _entries:
            _build_cards(entry)
            _apply_entry(entry, mode)
    last_build_msec = (Time.get_ticks_usec() - t0) / 1000.0
    if SHOW_COMPARE_ROW and OS.is_debug_build():
        _build_compare_row(scene)


func _load_textures() -> void:
    if _textures_loaded:
        return
    _textures_loaded = true
    _leaf_tex = _load_tex(LEAF_TILE_PATH)
    _bark_tex = _load_tex(BARK_TILE_PATH)
    _cluster_tex = _load_tex(LEAF_CLUSTER_PATH)


func _load_tex(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return load(path) as Texture2D
    return null


func _load_shader(path: String) -> Shader:
    if ResourceLoader.exists(path):
        return load(path) as Shader
    return null


# root 以下の MeshInstance3D から、葉・幹を持つものを集める
func _collect_entries(root: Node) -> Array:
    var result: Array = []
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        for c in n.get_children():
            stack.append(c)
        var mi := n as MeshInstance3D
        if mi == null or mi.mesh == null:
            continue
        var tree_node := _find_tree_node(mi)
        if tree_node == null:
            continue
        var type_name := tree_node.name.get_slice(" v", 0)
        var is_pine := PINE_TYPES.has(type_name)
        if not is_pine and not BROADLEAF_TYPES.has(type_name):
            continue
        var kinds: Array = []
        var orig: Array = []
        var any := false
        for i in mi.mesh.get_surface_count():
            var kind := -1
            if is_pine:
                kind = _pine_surface_kind(mi, i)
            else:
                var nm := String(mi.name)
                if nm.begins_with("葉"):
                    kind = Kind.LEAF
                elif nm.begins_with("幹"):
                    kind = Kind.TRUNK
            kinds.append(kind)
            orig.append(mi.get_surface_override_material(i))
            if kind != -1:
                any = true
        if not any:
            continue
        var rng := RandomNumberGenerator.new()
        rng.seed = hash(_snap(tree_node.global_position))
        result.append({
            "node": mi,
            "kinds": kinds,
            "orig": orig,
            "bright": rng.randi() % BRIGHT_STEPS,
            "hue": rng.randi() % HUE_STEPS,
            "is_pine": is_pine,
            "cards": null,
        })
    return result


# 名前に " v" を含む最も近い祖先が木のノード
func _find_tree_node(mi: Node) -> Node3D:
    var p := mi.get_parent()
    while p != null:
        if String(p.name).contains(" v") and p is Node3D:
            return p as Node3D
        p = p.get_parent()
    return null


func _snap(v: Vector3) -> Vector3:
    return v.snapped(Vector3(0.01, 0.01, 0.01))


# 松のサーフェスは albedo の緑が赤より大きければ葉
func _pine_surface_kind(mi: MeshInstance3D, surface: int) -> int:
    var mat := mi.get_active_material(surface) as BaseMaterial3D
    if mat == null:
        return -1
    return Kind.PINE_LEAF if mat.albedo_color.g > mat.albedo_color.r else Kind.TRUNK


# ---- マテリアル ----

# 木の見た目を entry に適用する。ORIGINAL なら元に戻す。
func _apply_entry(entry: Dictionary, m: Mode) -> void:
    var mi: MeshInstance3D = entry["node"]
    if not is_instance_valid(mi):
        return
    var kinds: Array = entry["kinds"]
    for i in kinds.size():
        if kinds[i] == -1:
            continue
        if m == Mode.ORIGINAL:
            mi.set_surface_override_material(i, entry["orig"][i])
        else:
            mi.set_surface_override_material(i, _material_for(kinds[i], m, entry))
    var cards: MeshInstance3D = entry["cards"]
    if cards != null and is_instance_valid(cards):
        cards.visible = (m == Mode.FLUFFY)


func _material_for(kind: int, m: Mode, entry: Dictionary) -> Material:
    match kind:
        Kind.TRUNK:
            return _bark_material()
        Kind.PINE_LEAF:
            return _leaf_material(PINE_LEAF_COLOR, 1.0, entry)
        _:
            var dark := FLUFFY_INNER_DARKEN if m == Mode.FLUFFY else 1.0
            return _leaf_material(LEAF_COLOR, dark, entry)


func _jittered_color(base: Color, entry: Dictionary) -> Color:
    var b: int = entry["bright"]
    var h: int = entry["hue"]
    var db := (b - (BRIGHT_STEPS - 1) / 2.0) / ((BRIGHT_STEPS - 1) / 2.0) * BRIGHT_RANGE
    var dh := (h - (HUE_STEPS - 1) / 2.0) / ((HUE_STEPS - 1) / 2.0) * HUE_RANGE
    return Color.from_hsv(fposmod(base.h + dh, 1.0), base.s, clampf(base.v * (1.0 + db), 0.0, 1.0))


# ばらつきの段階ごとに共有する（木ごとに作ると重いため）
func _leaf_material(base: Color, darken: float, entry: Dictionary) -> Material:
    var key := "leaf_%s_%s_%d_%d" % [base.to_html(), darken, entry["bright"], entry["hue"]]
    if _mat_cache.has(key):
        return _mat_cache[key]
    var col := _jittered_color(base, entry) * darken
    var mat: Material
    var shader := _load_shader(LEAF_MATTE_SHADER_PATH)
    if shader != null:
        var sm := ShaderMaterial.new()
        sm.shader = shader
        sm.set_shader_parameter("leaf_texture", _leaf_tex)
        sm.set_shader_parameter("tint", Vector3(col.r, col.g, col.b))
        sm.set_shader_parameter("tile_meters", LEAF_TILE_METERS)
        mat = sm
    else:
        var sm := StandardMaterial3D.new()
        sm.albedo_color = col
        sm.metallic = 0.0
        sm.roughness = 1.0
        mat = sm
    _mat_cache[key] = mat
    return mat


func _bark_material() -> Material:
    if _mat_cache.has("bark"):
        return _mat_cache["bark"]
    var sm := StandardMaterial3D.new()
    sm.albedo_color = BARK_COLOR
    sm.albedo_texture = _bark_tex
    sm.metallic = 0.0
    sm.roughness = 1.0
    sm.metallic_specular = 0.0
    sm.uv1_triplanar = true
    sm.uv1_world_triplanar = true
    sm.uv1_scale = Vector3.ONE / BARK_TILE_METERS
    _mat_cache["bark"] = sm
    return sm


func _get_card_material() -> Material:
    if _card_material != null:
        return _card_material
    var shader := _load_shader(LEAF_CARDS_SHADER_PATH)
    if shader == null:
        return null
    _card_material = ShaderMaterial.new()
    _card_material.shader = shader
    _card_material.set_shader_parameter("leaf_texture", _cluster_tex)
    return _card_material


# ---- 葉の板 ----

# entry の葉の塊（広葉樹・低木の LEAF）に葉の板を作って子に足す
func _build_cards(entry: Dictionary) -> void:
    if entry["is_pine"] or not (entry["kinds"] as Array).has(Kind.LEAF):
        return
    var mi: MeshInstance3D = entry["node"]
    var mat := _get_card_material()
    if mat == null:
        return
    var faces := mi.mesh.get_faces()
    var tri_count := faces.size() / 3
    if tri_count == 0:
        return
    var xf := mi.global_transform
    var world := PackedVector3Array()
    world.resize(faces.size())
    var center := Vector3.ZERO
    for i in faces.size():
        world[i] = xf * faces[i]
        center += world[i]
    center /= faces.size()

    # 面積の累積（面積に比例して三角形を選ぶ）
    var cumulative := PackedFloat32Array()
    cumulative.resize(tri_count)
    var total := 0.0
    for t in tri_count:
        var a := world[t * 3]
        total += 0.5 * (world[t * 3 + 1] - a).cross(world[t * 3 + 2] - a).length()
        cumulative[t] = total
    if total <= 0.0001:
        return

    var n := clampi(roundi(total * CARDS_PER_M2), CARD_MIN, CARD_MAX)
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(_snap(mi.global_position))

    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var uv2s := PackedVector2Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    verts.resize(n * 4)
    normals.resize(n * 4)
    uvs.resize(n * 4)
    uv2s.resize(n * 4)
    colors.resize(n * 4)
    indices.resize(n * 6)
    var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
    var col := _jittered_color(CARD_BASE_COLOR, entry)

    for k in n:
        # 三角形を選ぶ
        var r := rng.randf() * total
        var lo := 0
        var hi := tri_count - 1
        while lo < hi:
            var mid := (lo + hi) / 2
            if cumulative[mid] < r:
                lo = mid + 1
            else:
                hi = mid
        var a := world[lo * 3]
        var b := world[lo * 3 + 1]
        var c := world[lo * 3 + 2]
        var r1 := sqrt(rng.randf())
        var r2 := rng.randf()
        var p := a * (1.0 - r1) + b * (r1 * (1.0 - r2)) + c * (r1 * r2)
        var tri_n := (b - a).cross(c - a).normalized()
        var dir := (p - center).normalized()
        # 巻き方向に依存しないよう、外向きの側にそろえる
        if tri_n.dot(dir) < 0.0:
            tri_n = -tri_n
        var nrm := (dir + tri_n).normalized()
        if nrm.length_squared() < 0.5:
            nrm = Vector3.UP
        p += tri_n * CARD_OFFSET
        var size := CARD_SIZE * rng.randf_range(0.8, 1.25)
        var rot := rng.randf() * TAU
        for j in 4:
            var idx := k * 4 + j
            verts[idx] = p
            normals[idx] = nrm
            uvs[idx] = corners[j]
            uv2s[idx] = Vector2(size, rot)
            colors[idx] = col
        var base := k * 4
        var ii := k * 6
        indices[ii] = base
        indices[ii + 1] = base + 1
        indices[ii + 2] = base + 2
        indices[ii + 3] = base
        indices[ii + 4] = base + 2
        indices[ii + 5] = base + 3

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_TEX_UV2] = uv2s
    arrays[Mesh.ARRAY_INDEX] = indices
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    # 頂点シェーダーで広がる分を含める
    am.custom_aabb = am.get_aabb().grow(CARD_SIZE * 1.25)

    var cards := MeshInstance3D.new()
    cards.name = "LeafCards"
    cards.mesh = am
    cards.material_override = mat
    cards.top_level = true
    cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    cards.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    mi.add_child(cards)
    cards.global_transform = Transform3D.IDENTITY
    entry["cards"] = cards
    card_count += n


# ---- 比較用の木 ----

func _build_compare_row(scene: Node) -> void:
    var scene3d := scene as Node3D
    if scene3d == null:
        return
    # 当たり判定が物理空間に入るのを待ってから、地面の高さを調べる
    await get_tree().physics_frame
    if get_tree().current_scene != scene:
        return
    var origin := Vector3(CAR_START.x + COMPARE_RIGHT, 0.0, CAR_START.z - COMPARE_FORWARD)
    var modes := [Mode.ORIGINAL, Mode.MATTE, Mode.FLUFFY]
    var plan: Array = []  # [元のノード, 位置, モード]
    for row in COMPARE_SOURCES.size():
        var src := scene.get_node_or_null(COMPARE_SOURCES[row]) as Node3D
        if src == null:
            continue
        for col in 3:
            var x := origin.x + COMPARE_SPACING * col
            var z := origin.z - COMPARE_ROW_GAP * row
            plan.append([src, Vector3(x, _ground_height(scene3d, x, z), z), modes[col]])
    var font: Font = null
    if ResourceLoader.exists(FONT_PATH):
        font = load(FONT_PATH) as Font
    var use_kanji := font != null and font.has_char("元".unicode_at(0))
    for item in plan:
        var src: Node3D = item[0]
        var pos: Vector3 = item[1]
        var m: Mode = item[2]
        var copy := src.duplicate() as Node3D
        _strip_collision(copy)
        # 全体のモードで付いた葉の板とマテリアルの上書きを、複製から取り除く
        _reset_copy_appearance(copy)
        scene.add_child(copy)
        # 元の向き・拡大のまま、位置だけ移す
        copy.global_transform = Transform3D(src.global_transform.basis, pos)
        var entries := _collect_entries(copy)
        for entry in entries:
            # 葉の板が要るのは B（FLUFFY）だけ。元と A には付けない
            if m == Mode.FLUFFY:
                _build_cards(entry)
            _apply_entry(entry, m)
        _compare_entries.append_array(entries)
        var label := _make_label(m, font, use_kanji)
        scene.add_child(label)
        label.global_position = pos + Vector3.UP * COMPARE_LABEL_HEIGHT


func _ground_height(scene3d: Node3D, x: float, z: float) -> float:
    var space := scene3d.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(Vector3(x, 100.0, z), Vector3(x, -100.0, z), 0xFFFFFFFF)
    var hit := space.intersect_ray(query)
    if hit.is_empty():
        return 0.0
    return (hit["position"] as Vector3).y


# 複製した木を元の見た目に戻す。
# 葉の板（LeafCards）を取り除き、サーフェスの上書きと material_override を空にする。
func _reset_copy_appearance(root: Node) -> void:
    var doomed: Array[Node] = []
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        for c in n.get_children():
            stack.append(c)
        var mi := n as MeshInstance3D
        if mi == null:
            continue
        for c in mi.get_children():
            if c is MeshInstance3D and c.name.begins_with("LeafCards"):
                doomed.append(c)
        mi.material_override = null
        if mi.mesh != null:
            for i in mi.mesh.get_surface_count():
                mi.set_surface_override_material(i, null)
    for n in doomed:
        n.get_parent().remove_child(n)
        n.queue_free()


# 複製した木から当たり判定を取り除く（メッシュを子に持つ物体は判定だけ無効にする）
func _strip_collision(root: Node) -> void:
    var doomed: Array[Node] = []
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        for c in n.get_children():
            stack.append(c)
        if n is CollisionShape3D or n is CollisionPolygon3D:
            doomed.append(n)
        elif n is CollisionObject3D:
            (n as CollisionObject3D).collision_layer = 0
            (n as CollisionObject3D).collision_mask = 0
            if _find_mesh(n) == null:
                doomed.append(n)
    for n in doomed:
        n.queue_free()


func _find_mesh(root: Node) -> MeshInstance3D:
    for c in root.get_children():
        if c is MeshInstance3D:
            return c
        var r := _find_mesh(c)
        if r != null:
            return r
    return null


func _make_label(m: Mode, font: Font, use_kanji: bool) -> Label3D:
    var texts_kanji := ["元", "A", "B"]
    var texts_latin := ["ORIGINAL", "A", "B"]
    var label := Label3D.new()
    label.text = (texts_kanji if use_kanji else texts_latin)[m]
    if font != null:
        label.font = font
    label.font_size = 64
    label.pixel_size = 0.01
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = Color.WHITE
    label.outline_modulate = Color.BLACK
    label.outline_size = 16
    label.no_depth_test = true
    return label

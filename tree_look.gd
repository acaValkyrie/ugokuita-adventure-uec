extends Node
# 木の葉と幹を、つや消しの葉の模様と樹皮の模様にする。
# 元のモデルのマテリアルは金属のような設定でテクスチャが無く、そのままだと不自然に光るため、シーンが変わったときに1回だけ差し替える。

enum Kind { LEAF, TRUNK, PINE_LEAF }

# 色。木ごとのばらつきは明るさ ±8%、色相 ±0.03
const LEAF_COLOR := Color(0.45, 0.6, 0.38)
const PINE_LEAF_COLOR := Color(0.28, 0.42, 0.4)
const BARK_COLOR := Color(0.55, 0.48, 0.43)
const BRIGHT_STEPS := 7
const HUE_STEPS := 5
const BRIGHT_RANGE := 0.08
const HUE_RANGE := 0.03
const LEAF_TILE_METERS := 1.5
const BARK_TILE_METERS := 1.0

const LEAF_TILE_PATH := "res://assets/textures/foliage/leaf_tile.png"
const BARK_TILE_PATH := "res://assets/textures/foliage/bark_tile.png"
const LEAF_MATTE_SHADER_PATH := "res://assets/shaders/foliage_matte.gdshader"

const BROADLEAF_TYPES := ["Tree1", "Tree1-2", "Tree2", "Tree4", "Grass1-2", "Grass2"]
const PINE_TYPES := ["PineTree", "PineTree2", "PineTree3"]

const TREE_ROOT_PATH := "UEC/tree"

var _scene: Node = null
var _mat_cache := {}
var _leaf_tex: Texture2D = null
var _bark_tex: Texture2D = null
var _textures_loaded := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
    var scene := get_tree().current_scene
    if scene != _scene:
        _scene = scene
        if scene != null:
            _build_all(scene)


# ---- 構築 ----

func _build_all(scene: Node) -> void:
    _load_textures()
    var root := scene.get_node_or_null(TREE_ROOT_PATH)
    if root == null:
        return
    for entry in _collect_entries(root):
        _apply_entry(entry)


func _load_textures() -> void:
    if _textures_loaded:
        return
    _textures_loaded = true
    _leaf_tex = _load_tex(LEAF_TILE_PATH)
    _bark_tex = _load_tex(BARK_TILE_PATH)


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
            if kind != -1:
                any = true
        if not any:
            continue
        var rng := RandomNumberGenerator.new()
        rng.seed = hash(_snap(tree_node.global_position))
        result.append({
            "node": mi,
            "kinds": kinds,
            "bright": rng.randi() % BRIGHT_STEPS,
            "hue": rng.randi() % HUE_STEPS,
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

# 木の見た目を entry に適用する
func _apply_entry(entry: Dictionary) -> void:
    var mi: MeshInstance3D = entry["node"]
    if not is_instance_valid(mi):
        return
    var kinds: Array = entry["kinds"]
    for i in kinds.size():
        if kinds[i] == -1:
            continue
        mi.set_surface_override_material(i, _material_for(kinds[i], entry))


func _material_for(kind: int, entry: Dictionary) -> Material:
    match kind:
        Kind.TRUNK:
            return _bark_material()
        Kind.PINE_LEAF:
            return _leaf_material(PINE_LEAF_COLOR, 1.0, entry)
        _:
            return _leaf_material(LEAF_COLOR, 1.0, entry)


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

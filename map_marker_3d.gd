extends Node3D
# 目的地のマーカーの場所に立つ、3Dの画面の印。光の柱と、自分からの距離の文字。
# Map が、マーカーがある間だけシーンに1つ置く。

const PILLAR_RADIUS := 0.5
const PILLAR_HEIGHT := 40.0
const PILLAR_ALPHA := 0.35
const LABEL_HEIGHT := 1.5  # 地面から。カメラは低く下向きなので、3m だと遠くで画面の上に外れるため
const LABEL_FONT_SIZE := 48
const LABEL_OUTLINE_SIZE := 12
# 地面を探すレイの高さ
const RAY_TOP := 200.0
const RAY_BOTTOM := -50.0
const MAX_RAY_HITS := 16  # 地面探しでレイを繰り返す最大回数

# 置く場所（ワールドの x・z）。add_child の前に Map が入れる
var marker_xz := Vector2.ZERO
var _label: Label3D


func _ready() -> void:
    position = Vector3(marker_xz.x, _find_ground_y(marker_xz), marker_xz.y)

    var mesh := CylinderMesh.new()
    mesh.top_radius = PILLAR_RADIUS
    mesh.bottom_radius = PILLAR_RADIUS
    mesh.height = PILLAR_HEIGHT
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(Map.MARKER_COLOR, PILLAR_ALPHA)
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    # 建物の向こうにあっても方向がわかるよう、柱は建物越しに透けて見せる
    material.no_depth_test = true
    mesh.material = material
    var pillar := MeshInstance3D.new()
    pillar.mesh = mesh
    pillar.position = Vector3(0.0, PILLAR_HEIGHT * 0.5, 0.0)
    pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(pillar)

    _label = Label3D.new()
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.fixed_size = true
    _label.no_depth_test = true
    _label.font_size = LABEL_FONT_SIZE
    _label.outline_size = LABEL_OUTLINE_SIZE
    _label.modulate = Color.WHITE
    _label.outline_modulate = Color.BLACK
    _label.position = Vector3(0.0, LABEL_HEIGHT, 0.0)
    add_child(_label)


func _process(_delta: float) -> void:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player == null:
        return
    var distance := Vector2(player.global_position.x, player.global_position.z).distance_to(marker_xz)
    _label.text = "%dm" % int(distance)


# 上から下へレイを飛ばして、地面の高さを求める（当たらなければ 0）
# 屋根や木の下の地面に立てるため、当たった点の少し下からレイを飛ばし直し、
# 当たった中でいちばん低い高さを地面とする
func _find_ground_y(xz: Vector2) -> float:
    var space := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(
            Vector3(xz.x, RAY_TOP, xz.y),
            Vector3(xz.x, RAY_BOTTOM, xz.y))
    # 建物の中から下へ飛ばしても、床や地面の裏面に当たるようにする
    query.hit_back_faces = true
    var lowest := INF
    for i in MAX_RAY_HITS:
        var hit := space.intersect_ray(query)
        if hit.is_empty():
            break
        lowest = minf(lowest, hit.position.y)
        # 次は当たった点の 0.05m 下から飛ばし直す
        var next_y: float = hit.position.y - 0.05
        if next_y <= RAY_BOTTOM:
            break
        query.from = Vector3(xz.x, next_y, xz.y)
    if lowest == INF:
        return 0.0
    return lowest

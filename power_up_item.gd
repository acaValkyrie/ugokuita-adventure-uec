extends Area3D
# パワーアップのメダル。機体が触れると取れる（物理の当たりは持たず、監視だけ）。
# kind は PowerUps.ITEMS のキー。

# 円盤の見た目
const DISC_RADIUS := 0.36
const DISC_HEIGHT := 0.06
const DISC_COLOR := Color("#d4a017")
# アイコンの1辺 [m] と、円盤の表裏からの距離 [m]
const ICON_SIZE := 0.7
const ICON_OFFSET := 0.035
# ヒントのメダルの「?」: 文字の高さ [m]（円盤の直径 0.72m に収まる）、フォントの大きさ [px]、縁取りの太さ [px]
const QUESTION_SIZE := 0.5
const QUESTION_FONT_SIZE := 128
const QUESTION_OUTLINE_SIZE := 16
# 回る速さ [度/秒]、上下の揺れの幅 [m] と周期 [s]
const SPIN_SPEED := 90.0
const BOB_AMPLITUDE := 0.1
const BOB_PERIOD := 1.5
# メダルを取れる範囲は、メダルの真下から上に伸びる細い円柱（横方向で軸から PICKUP_RADIUS 以内に車体が入ったら取れる）。
# 機体の当たり判定は地面から 0.17〜0.27m の薄い板なので、球だと高さが合わない。
# 半径 [m]。近づかないと取れないよう、メダル自体の半径 0.36m より狭くする
const PICKUP_RADIUS := 0.1
# 円柱の高さ [m] と、下の端のメダルの中心からの高さ [m]（地面より少し下）。上の端は中心の 0.5m 上になる
const PICKUP_HEIGHT := 1.2
const PICKUP_BOTTOM := -0.7

@export var kind: String = ""
# 空でないときはヒントのメダル（PowerUps.HINTS のキー）。アイコンの代わりに「?」を出し、触れるとヒントを使う
@export var hint_id: String = ""

var _visual: Node3D
var _time := 0.0


func _ready() -> void:
    # 機体（VehicleBody3D）の層。既定の 1
    collision_layer = 0
    collision_mask = 1
    var shape := CollisionShape3D.new()
    var pickup := CylinderShape3D.new()
    pickup.radius = PICKUP_RADIUS
    pickup.height = PICKUP_HEIGHT
    shape.shape = pickup
    shape.position.y = PICKUP_BOTTOM + PICKUP_HEIGHT / 2.0
    add_child(shape)
    body_entered.connect(_on_body_entered)

    _visual = Node3D.new()
    add_child(_visual)

    # 円盤（X軸まわりに90度回して立てる）
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = DISC_RADIUS
    cylinder.bottom_radius = DISC_RADIUS
    cylinder.height = DISC_HEIGHT
    var material := StandardMaterial3D.new()
    material.albedo_color = DISC_COLOR
    material.metallic = 0.6
    material.roughness = 0.35
    cylinder.material = material
    var disc := MeshInstance3D.new()
    disc.mesh = cylinder
    disc.rotation_degrees.x = 90.0
    _visual.add_child(disc)

    if hint_id != "":
        # ヒントのメダル: アイコンの代わりに「?」（表と裏）
        _add_question_mark(ICON_OFFSET, 0.0)
        _add_question_mark(-ICON_OFFSET, 180.0)
        return
    # アイコン（表と裏）
    var texture: Texture2D = null
    if PowerUps.ITEMS.has(kind):
        texture = PowerUps.ITEMS[kind]["icon"]
    _add_icon(texture, ICON_OFFSET, 0.0)
    _add_icon(texture, -ICON_OFFSET, 180.0)


func _add_question_mark(z: float, angle_y: float) -> void:
    var label := Label3D.new()
    label.text = "?"
    label.font = PowerUps.FONT
    label.font_size = QUESTION_FONT_SIZE
    label.pixel_size = QUESTION_SIZE / QUESTION_FONT_SIZE
    label.modulate = Color.WHITE
    label.outline_modulate = Color.BLACK
    label.outline_size = QUESTION_OUTLINE_SIZE
    label.shaded = false
    label.double_sided = false
    label.position.z = z
    label.rotation_degrees.y = angle_y
    _visual.add_child(label)


func _add_icon(texture: Texture2D, z: float, angle_y: float) -> void:
    var sprite := Sprite3D.new()
    sprite.texture = texture
    sprite.pixel_size = ICON_SIZE / 256.0
    sprite.shaded = false
    sprite.double_sided = false
    sprite.position.z = z
    sprite.rotation_degrees.y = angle_y
    _visual.add_child(sprite)


func _process(delta: float) -> void:
    _time += delta
    _visual.rotation_degrees.y += SPIN_SPEED * delta
    _visual.position.y = sin(_time * TAU / BOB_PERIOD) * BOB_AMPLITUDE


func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    # 二重に取らない
    set_deferred("monitoring", false)
    if hint_id != "":
        PowerUps.use_hint(hint_id)
    else:
        PowerUps.acquire(kind)
    queue_free()

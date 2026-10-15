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
# 回る速さ [度/秒]、上下の揺れの幅 [m] と周期 [s]
const SPIN_SPEED := 90.0
const BOB_AMPLITUDE := 0.1
const BOB_PERIOD := 1.5

@export var kind: String = ""

var _visual: Node3D
var _time := 0.0


func _ready() -> void:
    # 機体（VehicleBody3D）の層。既定の 1
    collision_layer = 0
    collision_mask = 1
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.0
    shape.shape = sphere
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

    # アイコン（表と裏）
    var texture: Texture2D = null
    if PowerUps.ITEMS.has(kind):
        texture = PowerUps.ITEMS[kind]["icon"]
    _add_icon(texture, ICON_OFFSET, 0.0)
    _add_icon(texture, -ICON_OFFSET, 180.0)


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
    PowerUps.acquire(kind)
    queue_free()

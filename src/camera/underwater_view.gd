extends CanvasLayer

# カメラが水の中にあるあいだ、霧を水の色にし、画面に水の色と揺らぎを重ねる

# 水の中を判定するノードのグループ（PoolRipples の WATER_GROUP と同じ）
const WATER_GROUP := "water_areas"
# 画面に水の色と揺らぎを重ねるシェーダー
const UNDERWATER_SHADER := preload("res://assets/shaders/underwater.gdshader")
# 水中の霧の濃さ
const FOG_DENSITY := 0.12
# 水中の霧の色
const FOG_COLOR := Color(0.2, 0.55, 0.75)
# 水中の霧を空にもかける割合
const FOG_SKY_AFFECT := 1.0
# 水の屈折率
const WATER_IOR := 1.333

var _underwater := false
# 画面に重ねるシェーダーの設定
var _material: ShaderMaterial
# カメラが今いる水（水中でなければ null）
var _area: Node
# 入る前の霧の設定（出るときに戻す）。
# 霧は space_sky.gd も書き換えるが、地上の高さでは値が変わらないので、入るときに覚えて出るときに戻すだけでよい
var _environment: Environment
var _saved_fog_enabled := false
var _saved_fog_density := 0.0
var _saved_fog_color := Color.WHITE
var _saved_fog_sky_affect := 0.0

func _ready() -> void:
    # 集中線（5）やHUD（10）より下にして、HUDに揺らぎや色がかからないようにする
    layer = 4
    var rect := ColorRect.new()
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = UNDERWATER_SHADER
    rect.material = material
    _material = material
    add_child(rect)
    visible = false

func _process(_delta: float) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var now_underwater := false
    _area = null
    for area in get_tree().get_nodes_in_group(WATER_GROUP):
        if area.is_under_water(camera.global_position):
            now_underwater = true
            _area = area
            break
    if now_underwater == _underwater:
        if _underwater:
            _update_light(camera)
        return
    _underwater = now_underwater
    if _underwater:
        _environment = camera.get_world_3d().environment
        if _environment != null:
            _saved_fog_enabled = _environment.fog_enabled
            _saved_fog_density = _environment.fog_density
            _saved_fog_color = _environment.fog_light_color
            _saved_fog_sky_affect = _environment.fog_sky_affect
            _environment.fog_enabled = true
            _environment.fog_density = FOG_DENSITY
            _environment.fog_light_color = FOG_COLOR
            _environment.fog_sky_affect = FOG_SKY_AFFECT
        visible = true
        _update_light(camera)
    else:
        _restore_fog()
        visible = false

# 画面の各点の視線の向きと、水中から見た太陽の向きをシェーダーに渡す
func _update_light(camera: Camera3D) -> void:
    # 画面の (u, v)（左 -1〜右 +1、下 -1〜上 +1）での視線の向きは F + R*(u*tx) + U*(v*ty)
    var size := get_viewport().get_visible_rect().size
    var ty := tan(deg_to_rad(camera.fov) / 2.0)
    var tx := ty * size.x / size.y
    _material.set_shader_parameter("view_forward", -camera.global_basis.z)
    _material.set_shader_parameter("view_right", camera.global_basis.x * tx)
    _material.set_shader_parameter("view_up", camera.global_basis.y * ty)
    var s: Vector3 = _area.sun_direction()
    # 太陽が無い、または地平線の下なら光は差し込まない
    if s == Vector3.ZERO or s.y <= 0.0:
        _material.set_shader_parameter("light_enabled", false)
        return
    # 太陽の光は水面で屈折するので、水中では真上に近づく（スネルの法則）
    var h := Vector2(s.x, s.z)
    var sin_a := h.length()
    var sin_w := sin_a / WATER_IOR
    var cos_w := sqrt(1.0 - sin_w * sin_w)
    var sun_w := Vector3.UP
    if sin_a > 0.0001:
        sun_w = Vector3(h.x / sin_a * sin_w, cos_w, h.y / sin_a * sin_w)
    _material.set_shader_parameter("sun_dir_water", sun_w)
    _material.set_shader_parameter("light_enabled", true)

func _exit_tree() -> void:
    if _underwater:
        _restore_fog()

# 覚えておいた霧の設定に戻す
func _restore_fog() -> void:
    if _environment == null:
        return
    _environment.fog_enabled = _saved_fog_enabled
    _environment.fog_density = _saved_fog_density
    _environment.fog_light_color = _saved_fog_color
    _environment.fog_sky_affect = _saved_fog_sky_affect
    _environment = null

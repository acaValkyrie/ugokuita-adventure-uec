extends CanvasLayer

# カメラが水の中にあるあいだ、霧を水の色にし、画面に水の色と揺らぎを重ねる

# 水の中を判定するノードのグループ（PoolRipples の WATER_GROUP と同じ）
const WATER_GROUP := "water_areas"
# 画面に水の色と揺らぎを重ねるシェーダー
const UNDERWATER_SHADER := preload("res://assets/shaders/underwater.gdshader")
# 水中の霧の濃さ
const FOG_DENSITY := 0.25
# 水中の霧の色
const FOG_COLOR := Color(0.2, 0.55, 0.75)
# 水中の霧を空にもかける割合
const FOG_SKY_AFFECT := 1.0

var _underwater := false
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
    add_child(rect)
    visible = false

func _process(_delta: float) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var now_underwater := false
    for area in get_tree().get_nodes_in_group(WATER_GROUP):
        if area.is_under_water(camera.global_position):
            now_underwater = true
            break
    if now_underwater == _underwater:
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
    else:
        _restore_fog()
        visible = false

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

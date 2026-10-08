extends CanvasLayer
# 通常の最高速度を超えて走っているとき（ブースト中など）、画面に集中線を重ねる。

const SHADER := preload("res://assets/shaders/speed_lines.gdshader")
# 最高速度をこの速さ [m/s] 超えたときに最も濃くする
const SPEED_RANGE := 4.0
# 濃くするとき・薄くするときの追従の速さ（大きいほど素早い）
const FADE_IN := 10.0
const FADE_OUT := 3.0

var _rect: ColorRect
var _material: ShaderMaterial
var _intensity := 0.0


func _ready() -> void:
    # 操作説明などの表示（layer 10）より下に描く
    layer = 5
    _rect = ColorRect.new()
    _rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rect.color = Color.WHITE
    _material = ShaderMaterial.new()
    _material.shader = SHADER
    _rect.material = _material
    _rect.visible = false
    add_child(_rect)


func _process(delta: float) -> void:
    var car := get_tree().get_first_node_in_group("player") as VehicleBody3D
    var target := 0.0
    if car:
        target = clampf((car.linear_velocity.length() - car.MAX_SPEED) / SPEED_RANGE, 0.0, 1.0)
    var rate := FADE_IN if target > _intensity else FADE_OUT
    _intensity = lerpf(_intensity, target, 1.0 - exp(-rate * delta))
    _rect.visible = _intensity > 0.01
    _material.set_shader_parameter("intensity", _intensity)

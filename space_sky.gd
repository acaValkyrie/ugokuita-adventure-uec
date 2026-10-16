extends WorldEnvironment

# 高く上がるほど空を宇宙のように暗くして星を出す。霞も薄くする

# space_amount を設定し直す最小の差。設定するたびに反射用の radiance を描き直すので、細かく設定しない
const UPDATE_STEP := 0.005

var _material: ShaderMaterial
var _base_fog_density := 0.0
var _base_fog_sky_affect := 0.0
# 前回設定した space_amount
var _last_amount := -1.0

func _ready() -> void:
    # シーンを読み込み直しても同じリソースが使い回されるので、自分用の複製だけを書き換える
    environment = environment.duplicate(true)
    _material = environment.sky.sky_material as ShaderMaterial
    _base_fog_density = environment.fog_density
    _base_fog_sky_affect = environment.fog_sky_affect
    if _material == null:
        push_warning("SpaceSky: 空のマテリアルが ShaderMaterial ではない")
        set_process(false)

func _process(_delta: float) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var amount := smoothstep(Ending.E3_ROOF_HEIGHT, Ending.ENDING2_HEIGHT, camera.global_position.y)
    var reached_end := (amount == 0.0 or amount == 1.0) and amount != _last_amount
    if absf(amount - _last_amount) < UPDATE_STEP and not reached_end:
        return
    _last_amount = amount
    _material.set_shader_parameter("space_amount", amount)
    environment.fog_density = lerpf(_base_fog_density, 0.0, amount)
    environment.fog_sky_affect = lerpf(_base_fog_sky_affect, 0.0, amount)

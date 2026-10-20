extends Node
# スマホなどタッチ操作の端末で、3D を描く解像度を下げ、1フレームの物理演算の回数も制限して Web 版を軽くする。
# URL の ?scale=0.5 で倍率を、?lod=0.01 で機体の LOD の偏りを強制でき、
# ?fps で FPS などを画面左上に表示する。
# ?bench で、描画の要素を1つずつ外して FPS を測るベンチ（perf_bench.gd）を動かす。
# ?tick=30 で物理演算の毎秒の回数を、?steps=2 で1フレームの物理演算の最大回数を変える。

const PERF_BENCH := preload("res://perf_bench.gd")

# 3D の描画バッファの短い辺の目安（実際の画素）
const TARGET_SHORT_SIDE := 600.0
# 自動で下げるときの倍率の下限
const MIN_SCALE := 0.4
# URL や set_forced_scale で指定できる倍率の範囲
const OVERRIDE_MIN := 0.25
const OVERRIDE_MAX := 1.0
# オーバーレイの文字を更新する間隔（秒）
const OVERLAY_INTERVAL := 0.5
# タッチ操作の端末で、機体のメッシュに付ける LOD の偏り（小さいほど粗い LOD を使う）
const VEHICLE_LOD_BIAS := 0.01
# タッチ操作の端末で、1フレームに回す物理演算の最大回数。重い端末で物理演算が追いつこうとして何回も回り、さらに遅くなるのを防ぐ（60回/秒なので 30FPS を下回るとゲームの進みが遅くなる）
const TOUCH_MAX_PHYSICS_STEPS := 2

# 強制する倍率（0 なら自動）
var forced_scale := 0.0
# 強制する機体の LOD の偏り（0 なら自動）
var forced_lod_bias := 0.0

var _layer: CanvasLayer
var _label: Label
var _elapsed := 0.0
# 空でなければ、通常の表示の代わりに出す文字
var _text_override := ""
# 物理演算の回数（直近のフレームと、表示の間隔内の最大）
var _steps_this_frame := 0
var _last_steps := 0
var _max_steps := 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_overlay()
    set_physics_process(true)
    if _is_touch_device():
        Engine.max_physics_steps_per_frame = TOUCH_MAX_PHYSICS_STEPS
    if OS.has_feature("web"):
        _read_url_parameters()
    _apply_scale()
    get_tree().root.size_changed.connect(_apply_scale)
    get_tree().node_added.connect(_on_node_added)
    for vehicle in get_tree().get_nodes_in_group("player"):
        _apply_vehicle_lod.call_deferred(vehicle)


func _physics_process(_delta: float) -> void:
    _steps_this_frame += 1


func _process(delta: float) -> void:
    # 1フレームの間に回った物理演算の回数を数える
    _last_steps = _steps_this_frame
    _steps_this_frame = 0
    _max_steps = maxi(_max_steps, _last_steps)
    _elapsed += delta
    if _elapsed < OVERLAY_INTERVAL:
        return
    _elapsed = 0.0
    _update_overlay()


# 強制する倍率を決めて、すぐ反映する（0 で自動に戻す）
func set_forced_scale(value: float) -> void:
    if value <= 0.0:
        forced_scale = 0.0
    else:
        forced_scale = clampf(value, OVERRIDE_MIN, OVERRIDE_MAX)
    _apply_scale()


func set_overlay_visible(on: bool) -> void:
    _layer.visible = on
    set_process(on)
    set_physics_process(on)
    if on:
        _elapsed = 0.0
        _update_overlay()


# オーバーレイに通常の表示の代わりの文字を出す（空で通常に戻す）
func set_overlay_text_override(text: String) -> void:
    _text_override = text
    _update_overlay()


func _setup_overlay() -> void:
    _layer = CanvasLayer.new()
    _layer.layer = 128
    add_child(_layer)
    _label = UiStyle.make_label("", 14)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.add_theme_color_override("font_outline_color", UiStyle.OUTLINE_COLOR)
    _label.add_theme_constant_override("outline_size", 4)
    _label.position = Vector2(8, 8)
    _layer.add_child(_label)
    set_overlay_visible(false)


# URL の ?scale=... と ?lod=... と ?fps を読む
func _read_url_parameters() -> void:
    var query := str(JavaScriptBridge.eval("window.location.search", true))
    query = query.trim_prefix("?")
    for pair in query.split("&", false):
        var parts := pair.split("=", true, 1)
        var key := parts[0]
        var value := parts[1] if parts.size() > 1 else ""
        if key == "scale" and value.is_valid_float():
            set_forced_scale(value.to_float())
        elif key == "lod" and value.is_valid_float():
            forced_lod_bias = clampf(value.to_float(), 0.001, 1.0)
        elif key == "tick" and value.is_valid_int():
            Engine.physics_ticks_per_second = clampi(value.to_int(), 10, 120)
        elif key == "steps" and value.is_valid_int():
            Engine.max_physics_steps_per_frame = clampi(value.to_int(), 1, 8)
        elif key == "fps":
            set_overlay_visible(true)
        elif key == "bench":
            set_overlay_visible(true)
            add_child(PERF_BENCH.new())


func _is_touch_device() -> bool:
    return OS.has_feature("web_android") or OS.has_feature("web_ios") \
        or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _current_scale() -> float:
    if forced_scale > 0.0:
        return forced_scale
    if _is_touch_device():
        var size := get_tree().root.size
        var short_side := float(mini(size.x, size.y))
        if short_side <= 0.0:
            return 1.0
        return clampf(TARGET_SHORT_SIDE / short_side, MIN_SCALE, 1.0)
    return 1.0


func _apply_scale() -> void:
    var root := get_tree().root
    root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    root.scaling_3d_scale = _current_scale()


func _vehicle_lod_bias() -> float:
    if forced_lod_bias > 0.0:
        return forced_lod_bias
    if _is_touch_device():
        return VEHICLE_LOD_BIAS
    return 1.0


func _on_node_added(node: Node) -> void:
    if node is VehicleBody3D:
        # 子ノードが揃ってから処理する
        _apply_vehicle_lod.call_deferred(node)


# 機体のメッシュに LOD の偏りを付ける（1.0 なら何もしない）
func _apply_vehicle_lod(vehicle: Node) -> void:
    if not is_instance_valid(vehicle):
        return
    var bias := _vehicle_lod_bias()
    if is_equal_approx(bias, 1.0):
        return
    for child in vehicle.find_children("*", "GeometryInstance3D", true, false):
        (child as GeometryInstance3D).lod_bias = bias


func _update_overlay() -> void:
    if _text_override != "":
        _label.text = _text_override
        return
    var root := get_tree().root
    var scale := root.scaling_3d_scale
    var buffer := Vector2i((Vector2(root.size) * scale).round())
    var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000000.0
    var line1 := "FPS %d  draw %d  tris %.2fM  3D x%.2f (%dx%d)  lod x%.2f" % [
        Performance.get_monitor(Performance.TIME_FPS),
        Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        tris, scale, buffer.x, buffer.y, _vehicle_lod_bias()]
    var line2 := "phys %.1fms  steps %d (max %d)  tick %d  maxsteps %d" % [
        Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
        _last_steps, _max_steps, Engine.physics_ticks_per_second,
        Engine.max_physics_steps_per_frame]
    _label.text = line1 + "\n" + line2
    _max_steps = 0

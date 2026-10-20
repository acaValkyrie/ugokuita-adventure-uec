extends Node
# スマホなどタッチ操作の端末で、3D を描く解像度を下げて Web 版を軽くする。
# URL の ?scale=0.5 で倍率を強制でき、?fps で FPS などを画面左上に表示する。

# 3D の描画バッファの短い辺の目安（実際の画素）
const TARGET_SHORT_SIDE := 600.0
# 自動で下げるときの倍率の下限
const MIN_SCALE := 0.4
# URL や set_forced_scale で指定できる倍率の範囲
const OVERRIDE_MIN := 0.25
const OVERRIDE_MAX := 1.0
# オーバーレイの文字を更新する間隔（秒）
const OVERLAY_INTERVAL := 0.5

# 強制する倍率（0 なら自動）
var forced_scale := 0.0

var _layer: CanvasLayer
var _label: Label
var _elapsed := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_overlay()
    if OS.has_feature("web"):
        _read_url_parameters()
    _apply_scale()
    get_tree().root.size_changed.connect(_apply_scale)


func _process(delta: float) -> void:
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
    if on:
        _elapsed = 0.0
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


# URL の ?scale=... と ?fps を読む
func _read_url_parameters() -> void:
    var query := str(JavaScriptBridge.eval("window.location.search", true))
    query = query.trim_prefix("?")
    for pair in query.split("&", false):
        var parts := pair.split("=", true, 1)
        var key := parts[0]
        var value := parts[1] if parts.size() > 1 else ""
        if key == "scale" and value.is_valid_float():
            set_forced_scale(value.to_float())
        elif key == "fps":
            set_overlay_visible(true)


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


func _update_overlay() -> void:
    var root := get_tree().root
    var scale := root.scaling_3d_scale
    var buffer := Vector2i((Vector2(root.size) * scale).round())
    var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000000.0
    _label.text = "FPS %d  draw %d  tris %.2fM  3D x%.2f (%dx%d)" % [
        Performance.get_monitor(Performance.TIME_FPS),
        Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        tris, scale, buffer.x, buffer.y]

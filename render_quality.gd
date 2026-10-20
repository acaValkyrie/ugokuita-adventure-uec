extends Node
# スマホなどタッチ操作の端末で Web 版を軽くする。
# 3D を描く解像度を下げ、機体のメッシュには粗い LOD を使い、1フレームの物理演算の回数も制限する。

# 3D の描画バッファの短い辺の目安（実際の画素）
const TARGET_SHORT_SIDE := 600.0
# 解像度を下げるときの倍率の下限
const MIN_SCALE := 0.4
# タッチ操作の端末で、機体のメッシュに付ける LOD の偏り（小さいほど粗い LOD を使う）
const VEHICLE_LOD_BIAS := 0.01
# タッチ操作の端末で、1フレームに回す物理演算の最大回数。重い端末で物理演算が追いつこうとして何回も回り、さらに遅くなるのを防ぐ（60回/秒なので 30FPS を下回るとゲームの進みが遅くなる）
const TOUCH_MAX_PHYSICS_STEPS := 2


func _ready() -> void:
    if _is_touch_device():
        Engine.max_physics_steps_per_frame = TOUCH_MAX_PHYSICS_STEPS
    _apply_scale()
    get_tree().root.size_changed.connect(_apply_scale)
    get_tree().node_added.connect(_on_node_added)
    for vehicle in get_tree().get_nodes_in_group("player"):
        _apply_vehicle_lod.call_deferred(vehicle)


func _is_touch_device() -> bool:
    return OS.has_feature("web_android") or OS.has_feature("web_ios") \
        or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _current_scale() -> float:
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

extends Node3D
# 体育館の入口。キャンパスの入口に入ると、機体を体育館の中（西の壁の入口側の出入口のそば）へ、
# 体育館の側面の壁にある6つの出入口のどれかを通ると、キャンパスの入口へ、暗転しながら瞬間移動させる

const GYM_SCENE := preload("res://gym.tscn")
# 体育館を置く位置。キャンパスから遠く離しておく。
# エンディング1が高さ y=-10 を下回ると始まるので、体育館の床は y=0 のままにして、横にだけずらす
const GYM_ORIGIN := Vector3(2000, 0, 0)
# 暗転の片道の時間 [s]
const FADE_TIME := 0.25
# 移動が終わってから、次の移動を受け付けるまでの時間 [s]（入口と出口の往復を防ぐ）
const COOLDOWN := 1.0

var _gym: Node3D
var _fade: ColorRect
var _busy := false
var _cooldown_until := 0.0
# 体育館にいる間に隠したキャンパス側のノード（出るときにこれだけ表示に戻す）
var _hidden_outside: Array[Node3D] = []

@onready var _trigger: Area3D = $Trigger
@onready var _exit_point: Marker3D = $ExitPoint

func _ready() -> void:
    # 体育館は実行時にだけ足す（シーンには保存しないので、ライトマップの焼き込みに含まれない）
    _gym = GYM_SCENE.instantiate()
    _gym.position = GYM_ORIGIN
    # 外にいる間は体育館を描かない
    _gym.visible = false
    get_parent().add_child.call_deferred(_gym)
    _trigger.body_entered.connect(_on_entrance_entered)
    for exit_area in _gym.get_node("Exits").get_children():
        exit_area.body_entered.connect(_on_exit_entered)

    var layer := CanvasLayer.new()
    layer.layer = 100
    _fade = ColorRect.new()
    _fade.color = Color.BLACK
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fade.modulate.a = 0.0
    layer.add_child(_fade)
    add_child(layer)

func _on_entrance_entered(body: Node3D) -> void:
    _start(body, _gym.get_node("Spawn").global_transform, true)

func _on_exit_entered(body: Node3D) -> void:
    _start(body, _exit_point.global_transform, false)

func _start(body: Node3D, target: Transform3D, inside: bool) -> void:
    if not body.is_in_group("player"):
        return
    var now := Time.get_ticks_msec() / 1000.0
    if _busy or now < _cooldown_until:
        return
    _busy = true
    var tween := create_tween()
    tween.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
    await tween.finished
    # 暗転している間に機体が入れ替わっていることがあるので、移動の直前に探し直す
    var vehicle := get_tree().get_first_node_in_group("player") as VehicleBody3D
    if vehicle != null:
        _set_inside(inside)
        _teleport(vehicle, target)
    tween = create_tween()
    tween.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
    await tween.finished
    _busy = false
    _cooldown_until = Time.get_ticks_msec() / 1000.0 + COOLDOWN

# 体育館とキャンパスのうち、機体がいる側だけを描く（どちらも読み込んだままで、表示だけ切り替える）
# カメラの描画距離（4000m）の中に両方が入り、壁の向こうも描いてしまうため
func _set_inside(inside: bool) -> void:
    _gym.visible = inside
    if inside:
        _hidden_outside.clear()
        for node in get_parent().get_children():
            # 体育館と、この入口自身は隠さない
            if node == _gym or node == self:
                continue
            # 描画する物ではないもの（機体は入れ替わることがあるので種類で除く）
            if not node is Node3D or node is VehicleBody3D or node is Camera3D:
                continue
            var child := node as Node3D
            # 照明は描画レイヤーで体育館と分けてある
            if child is Light3D or child is LightmapGI:
                continue
            # もともと隠れている物は、出るときに表示しないようにする
            if not child.visible:
                continue
            child.visible = false
            _hidden_outside.append(child)
    else:
        for node in _hidden_outside:
            if is_instance_valid(node):
                node.visible = true
        _hidden_outside.clear()

# 機体を target へ移す。戻り先の記録も付け替えて、体育館の中で戻ると中に、外で戻ると外になるようにする
func _teleport(vehicle: VehicleBody3D, target: Transform3D) -> void:
    target = Transform3D(target.basis.orthonormalized(), target.origin)
    var rid := vehicle.get_rid()
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, target)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
    PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
    vehicle.global_transform = target
    vehicle._motor_speed = 0.0
    var respawn := vehicle.get_node_or_null("Respawn")
    if respawn != null:
        respawn._points.clear()
        respawn._points.append(target)
        respawn._cursor = -1
    var camera := get_viewport().get_camera_3d()
    if camera != null and camera.has_method("snap_behind_vehicle"):
        camera.snap_behind_vehicle()

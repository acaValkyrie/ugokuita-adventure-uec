extends Node
# メニューで選んだ機体のプレイヤーに入れ替える。位置・速度・ブーストのゲージ・リスポーンの記録を引き継ぐ

signal player_changed(player: VehicleBody3D)

# 機体のキー（GameMenu.ROBOT_MODELS）ごとのプレイヤーのシーン
const SCENES := {
    "neo": "res://car.tscn",
    "classic": "res://car_classic.tscn",
}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    GameMenu.robot_model_changed.connect(_on_robot_model_changed)


# プレイヤーの準備ができたときに呼ばれる。シーンに置いた機体が保存済みの機体と違えば入れ替える
func on_player_ready(player: VehicleBody3D) -> void:
    if player.robot_key != GameMenu.robot_model:
        _replace.call_deferred(player, GameMenu.robot_model)


func _on_robot_model_changed(model: String) -> void:
    var player := get_tree().get_first_node_in_group("player") as VehicleBody3D
    if player != null and player.robot_key != model:
        _replace(player, model)


func _replace(old: VehicleBody3D, model: String) -> void:
    if not SCENES.has(model):
        push_warning("未知の機体: %s" % model)
        return
    var packed := load(SCENES[model]) as PackedScene
    if packed == null:
        push_warning("プレイヤーを読み込めない: %s" % SCENES[model])
        return
    var parent := old.get_parent()
    var new_player := packed.instantiate() as VehicleBody3D
    new_player.name = old.name
    # old と同じ親に入れるので、親の空間の transform をそのまま使える
    new_player.transform = old.transform
    new_player.linear_velocity = old.linear_velocity
    new_player.angular_velocity = old.angular_velocity
    new_player.boost_gauge = old.boost_gauge
    new_player._motor_speed = old._motor_speed

    # リスポーンの記録を引き継ぐ（old を外す前に取得しておく）
    var old_respawn := old.get_node_or_null("Respawn")
    var new_respawn := new_player.get_node_or_null("Respawn")
    if old_respawn != null and new_respawn != null:
        new_respawn._points = old_respawn._points.duplicate()

    var index := old.get_index()
    old.remove_from_group("player")
    parent.remove_child(old)
    old.queue_free()
    parent.add_child(new_player)
    parent.move_child(new_player, index)
    player_changed.emit(new_player)

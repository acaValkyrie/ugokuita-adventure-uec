extends Node
# ゲームの設定値と保存・反映をまとめ、UI から独立して起動する。

signal pad_layout_changed(layout: String)
signal robot_model_changed(model: String)
signal swap_confirm_changed(swapped: bool)
signal key_bindings_changed
signal pad_bindings_changed

# Master バスの既定音量（default_bus_layout.tres）
const BASE_DB := -6.0206
const SETTINGS_PATH := "user://settings.cfg"
# 操作説明に出すコントローラのボタン表記（設定ファイルに保存する値）
const PAD_LAYOUTS := ["nintendo", "xbox", "ds3", "ds4", "dualsense"]
# PlayStation の機種と、SELECT・START などの表記の世代の対応
const PS_LAYOUT_GENERATIONS := {"ds3": "ps3", "ds4": "ps4", "dualsense": "ps5"}
# 操作する機体（設定ファイルに保存する値）
const ROBOT_MODELS := ["neo", "classic"]

var pad_layout: String = "nintendo"
var robot_model: String = "neo"
# true なら決定とキャンセルのボタンを標準から入れ替える
var swap_confirm: bool = false
# カメラ操作の左右・上下を反転するか。キーボード・ゲームパッド・タッチのどれにも効く
var invert_camera_x: bool = false
var invert_camera_y: bool = false
# BGM と効果音の音量（0〜100）
var bgm_volume: int = 100
var se_volume: int = 100


# 保存した設定を読み込み、音量とパッドのボタンへ順に反映する
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_volume()
	_apply_pad_buttons()


# ボタン表記を変え、決定・キャンセルへの反映と保存後に通知する
func set_pad_layout(layout: String) -> void:
	if layout == pad_layout:
		return
	pad_layout = layout
	_apply_pad_buttons()
	_save_settings()
	pad_layout_changed.emit(pad_layout)


# 操作する機体を保存してから、切り替えを通知する
func set_robot_model(model: String) -> void:
	if model == robot_model:
		return
	robot_model = model
	_save_settings()
	robot_model_changed.emit(robot_model)


# 決定とキャンセルの入れ替えを反映し、保存後に通知する
func set_swap_confirm(swapped: bool) -> void:
	if swapped == swap_confirm:
		return
	swap_confirm = swapped
	_apply_pad_buttons()
	_save_settings()
	swap_confirm_changed.emit(swap_confirm)


# カメラの左右反転を保存する
func set_invert_camera_x(on: bool) -> void:
	if on == invert_camera_x:
		return
	invert_camera_x = on
	_save_settings()


# カメラの上下反転を保存する
func set_invert_camera_y(on: bool) -> void:
	if on == invert_camera_y:
		return
	invert_camera_y = on
	_save_settings()


# BGM の音量を反映して保存する
func set_bgm_volume(value: int) -> void:
	if value == bgm_volume:
		return
	bgm_volume = value
	_apply_volume()
	_save_settings()


# 効果音の音量を反映して保存する
func set_se_volume(value: int) -> void:
	if value == se_volume:
		return
	se_volume = value
	_apply_volume()
	_save_settings()


# 現在の設定と割り当てを保存する
func save() -> void:
	_save_settings()


# 変更したキーの割り当てを保存してから通知する
func commit_key_bindings() -> void:
	_save_settings()
	key_bindings_changed.emit()


# 変更したボタンの割り当てを保存してから通知する（決定・キャンセルは変更対象外）
func commit_pad_bindings() -> void:
	_save_settings()
	pad_bindings_changed.emit()


# その機種が PlayStation か（DualShock 3・DualShock 4・DualSense）
func is_playstation_layout(layout: String) -> bool:
	return PS_LAYOUT_GENERATIONS.has(layout)


# 今の機種での PlayStation の表記の世代（ps3・ps4・ps5）。PlayStation の機種でなければ ps5
func get_ps_generation() -> String:
	return PS_LAYOUT_GENERATIONS.get(pad_layout, "ps5")


# 決定・キャンセル（と看板を開く）のボタンを表記に合わせる。
# 標準は Nintendo が A（右）で決定・B（下）でキャンセル、PlayStation が ×（下）で決定・○（右）でキャンセル、Xbox が A（下）で決定・B（右）でキャンセル。
# swap_confirm が true なら決定とキャンセルを入れ替える
func _apply_pad_buttons() -> void:
	var confirm := JOY_BUTTON_B if pad_layout == "nintendo" else JOY_BUTTON_A
	var cancel := JOY_BUTTON_A if pad_layout == "nintendo" else JOY_BUTTON_B
	if swap_confirm:
		var swapped := confirm
		confirm = cancel
		cancel = swapped
	_set_joy_button("ui_accept", confirm)
	_set_joy_button("ui_cancel", cancel)
	# 看板を開くボタンは決定と同じ
	_set_joy_button("interact", confirm)


# アクションのゲームパッドのボタン割り当てを1つに置き換える（キーボードの割り当ては残す）
func _set_joy_button(action: StringName, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	var joy := InputEventJoypadButton.new()
	joy.device = -1
	joy.button_index = button
	InputMap.action_add_event(action, joy)


# 看板のリンクを開く前に、すべての音を消す。フォーカスが戻ったら _notification で音量を戻す
func mute_all() -> void:
	AudioServer.set_bus_mute(0, true)


# 音量を設定どおりに戻す（リンクを開いてもフォーカスが外れなかったとき用）
func restore_volume() -> void:
	_apply_volume()


# Web 版で走行中に看板のリンクを開くと、別のタブが前に出てゲームが止まり、走行音が鳴りっぱなしになる。
# ゲームの画面からフォーカスが外れている間は音を消し、戻ったら音量の設定どおりに戻す（0% ならミュートのまま）
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_apply_volume()


# Master は既定音量に固定してミュートも外し、BGM・SE のバスに設定の音量をかける
func _apply_volume() -> void:
	AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_volume_db(0, BASE_DB)
	_apply_bus_volume("BGM", bgm_volume)
	_apply_bus_volume("SE", se_volume)


# 0% はミュート、それ以外はミュートを外して比率で下げる
func _apply_bus_volume(bus_name: String, volume: int) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	var ratio := volume / 100.0
	if ratio <= 0.0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(ratio))


# 保存した設定を読み込み、古い設定と割り当ても引き継ぐ
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	# 古い設定ファイルの audio/volume は、BGM・SE の初期値に引き継ぐ
	var legacy_volume := clampi(int(config.get_value("audio", "volume", 100)), 0, 100)
	bgm_volume = clampi(int(config.get_value("audio", "bgm_volume", legacy_volume)), 0, 100)
	se_volume = clampi(int(config.get_value("audio", "se_volume", legacy_volume)), 0, 100)
	var layout := str(config.get_value("controls", "pad_layout", "nintendo"))
	if layout in PAD_LAYOUTS:
		pad_layout = layout
	elif layout == "playstation":
		# 古い設定からの引き継ぎ。PlayStation は世代を別に保存していたので、その世代の機種にする
		var generation := str(config.get_value("controls", "ps_generation", "ps5"))
		match generation:
			"ps3":
				pad_layout = "ds3"
			"ps4":
				pad_layout = "ds4"
			_:
				pad_layout = "dualsense"
	swap_confirm = bool(config.get_value("controls", "swap_confirm", false))
	invert_camera_x = bool(config.get_value("camera", "invert_x", false))
	invert_camera_y = bool(config.get_value("camera", "invert_y", false))
	var model := str(config.get_value("robot", "model", "neo"))
	if model in ROBOT_MODELS:
		robot_model = model
	KeyBindings.load_from(config)


# 設定とキー・ボタンの割り当てを既存の形式で保存する
func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "se_volume", se_volume)
	config.set_value("controls", "pad_layout", pad_layout)
	config.set_value("controls", "swap_confirm", swap_confirm)
	config.set_value("camera", "invert_x", invert_camera_x)
	config.set_value("camera", "invert_y", invert_camera_y)
	config.set_value("robot", "model", robot_model)
	KeyBindings.save_to(config)
	config.save(SETTINGS_PATH)

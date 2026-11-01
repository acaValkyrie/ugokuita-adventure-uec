extends Node

# ED3 の再生中だけ置き、一時停止とスキップの入力を受ける。
# ゲームパッドのキャンセルのボタンかキーボードの Space を短く押して離すと一時停止・再開、長押しで BAD END まで飛ばす。
# 一時停止はゲーム全体を止めるので、このノードだけは止まらないようにする。

const SKIP_HOLD_TIME := 0.6

var director: Node

var _holding := false
var _hold_time := 0.0
var _pause_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_pause_box = VBoxContainer.new()
	_pause_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pause_box.offset_top = 24
	_pause_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_pause_box)
	for line in [["一時停止中", 28, UiStyle.TEXT_COLOR], ["長押しでスキップ", 16, UiStyle.TEXT_DIM_COLOR]]:
		var label := UiStyle.make_label(line[0], line[1], line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", UiStyle.OUTLINE_COLOR)
		label.add_theme_constant_override("outline_size", 8)
		_pause_box.add_child(label)
	_pause_box.hide()


func _input(event: InputEvent) -> void:
	if GameMenu.is_open or not _is_playback_button(event):
		return
	if event.is_pressed():
		if not event.is_echo():
			_holding = true
			_hold_time = 0.0
		get_viewport().set_input_as_handled()
	elif _holding:
		_holding = false
		director.toggle_playback_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _holding:
		_hold_time += delta
		if _hold_time >= SKIP_HOLD_TIME:
			_holding = false
			director.skip_to_bad_end()
			return
	_pause_box.visible = director.is_playback_paused()


# ゲームパッドのキャンセルのボタン（決定と入れ替える設定にも従う）か、キーボードの Space
func _is_playback_button(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.is_action("ui_cancel")
	if event is InputEventKey:
		return event.physical_keycode == KEY_SPACE
	return false

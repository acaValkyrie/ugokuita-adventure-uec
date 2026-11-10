extends CanvasLayer
# 点群表示を切り替える左上のボタン。

const ICON_MID360 := preload("res://assets/ui/lidar/icon_mid360.png")
const ICON_MID70 := preload("res://assets/ui/lidar/icon_mid70.png")

var _button: Button


func _ready() -> void:
	layer = 18
	_build_button()


func get_button_rect() -> Rect2:
	return _button.get_global_rect()


func _build_button() -> void:
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var left := GameMenu.MARGIN + (GameMenu.button_size + Map.BUTTON_GAP) * 2
	_button.offset_left = left
	_button.offset_right = left + GameMenu.button_size
	_button.offset_top = GameMenu.MARGIN
	_button.offset_bottom = GameMenu.MARGIN + GameMenu.button_size
	# 見た目はアイコン側で描く。
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_button.add_theme_stylebox_override(state, empty)
	_button.pressed.connect(LidarView.toggle)
	add_child(_button)

	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_on_icon_draw.bind(icon))
	_button.add_child(icon)
	# 押している間は少し暗くする。
	_button.button_down.connect(func() -> void: icon.modulate = Color(0.8, 0.8, 0.8))
	_button.button_up.connect(func() -> void: icon.modulate = Color.WHITE)
	LidarView.enabled_changed.connect(func(_on: bool) -> void: icon.queue_redraw())
	PlayerSwitch.player_changed.connect(func(_player: VehicleBody3D) -> void: icon.queue_redraw())
	GameSettings.robot_model_changed.connect(func(_model: String) -> void: icon.queue_redraw())


func _on_icon_draw(icon: Control) -> void:
	var enabled := LidarView.is_enabled()
	var face := StyleBoxFlat.new()
	face.bg_color = GameMenu.FACE_COLOR
	face.border_color = LidarView.OUTLINE_COLOR if enabled else UiStyle.BORDER_COLOR
	face.set_border_width_all(2)
	face.set_corner_radius_all(GameMenu.BUTTON_RADIUS)
	face.anti_aliasing = true
	icon.draw_style_box(face, Rect2(Vector2.ZERO, icon.size))
	# 機体に載っている LiDAR の絵を出す
	var player := get_tree().get_first_node_in_group("player")
	var robot_key: String = player.robot_key if player != null else GameSettings.robot_model
	var texture := ICON_MID70 if robot_key == "classic" else ICON_MID360
	var size := Vector2.ONE * icon.size.x * 0.72
	var rect := Rect2((icon.size - size) * 0.5, size)
	var tint := LidarView.OUTLINE_COLOR if enabled else GameMenu.RING_COLOR
	icon.draw_texture_rect(texture, rect, false, tint)

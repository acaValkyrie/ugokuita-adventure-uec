class_name PointCloudTopView
extends RefCounted
# 点群を真上から見た画像。渡したワールドの xz の範囲を、CELL_SIZE 四方を1画素として写す。

const CELL_SIZE := 0.5
# 画像を GPU へ送り直す最短の間隔。
const UPDATE_INTERVAL_MSEC := 500

var _world_rect: Rect2
var _size: Vector2i
var _image: Image
var _texture: ImageTexture
var _heights := PackedFloat32Array()
var _dirty := false
var _last_update_msec := -UPDATE_INTERVAL_MSEC


func _init(world_rect: Rect2) -> void:
	_world_rect = world_rect
	_size = Vector2i((world_rect.size / CELL_SIZE).ceil())
	_image = Image.create_empty(_size.x, _size.y, false, Image.FORMAT_RGBA8)
	_image.fill(Color.BLACK)
	_heights.resize(_size.x * _size.y)
	_heights.fill(-INF)
	_texture = ImageTexture.create_from_image(_image)


func add_points(points: PackedVector3Array, colors: PackedColorArray) -> void:
	for i in points.size():
		var point := points[i]
		var px := floori((point.x - _world_rect.position.x) / CELL_SIZE)
		var py := floori((point.z - _world_rect.position.y) / CELL_SIZE)
		if px < 0 or py < 0 or px >= _size.x or py >= _size.y:
			continue
		var index := py * _size.x + px
		# 真上から見える一番上の点の色を残す。
		if point.y <= _heights[index]:
			continue
		_heights[index] = point.y
		_image.set_pixel(px, py, colors[i])
		_dirty = true


func clear() -> void:
	_image.fill(Color.BLACK)
	_heights.fill(-INF)
	_dirty = true


func get_texture() -> Texture2D:
	var now := Time.get_ticks_msec()
	if _dirty and now - _last_update_msec >= UPDATE_INTERVAL_MSEC:
		_texture.update(_image)
		_last_update_msec = now
		_dirty = false
	return _texture

extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scale := 0.5
	if not args.is_empty():
		scale = args[0].to_float()
	if not is_finite(scale) or scale <= 0.0:
		push_error("倍率は正の有限値を指定してください。")
		quit(1)
		return

	for path in ["res://main_scene.exr", "res://main_scene_shadow.png"]:
		var abs_path := ProjectSettings.globalize_path(path)
		var image := Image.load_from_file(abs_path)
		if image == null or image.is_empty():
			push_error("画像を読み込めません: %s" % path)
			quit(1)
			return
		var size := image.get_size()
		print("%s: size=%s, format=%s" % [path, size, image.get_format()])
		var new_size := Vector2i(roundi(size.x * scale), roundi(size.y * scale))
		# 縦に並ぶ2スライスを維持する。
		if new_size.x <= 0 or new_size.y <= 0 or new_size.y % 2 != 0:
			push_error("縮小後のサイズは正で、高さは2の倍数が必要です: %s (%s)" % [path, new_size])
			quit(1)
			return
		image.resize(new_size.x, new_size.y, Image.INTERPOLATE_BILINEAR)
		var error: Error
		if path.ends_with(".exr"):
			error = image.save_exr(abs_path, false)
		else:
			error = image.save_png(abs_path)
		if error != OK:
			push_error("画像を保存できません: %s (Error %s)" % [path, error])
			quit(1)
			return
		print("%s: new size=%s" % [path, image.get_size()])

	quit(0)

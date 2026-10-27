extends Node
# Web 版で最初の pck から外した物（ED の音・新倉庫・Classic）を、遊び始めてから裏でダウンロードして読み込む。デスクトップやエディタではファイルがあるので何もしない。

signal pack_ready(pack_name: StringName)

const PACKS := {
	&"ending_audio": {"file": "ending_audio.pck", "probe": "res://assets/audio/bgm/city_bird.ogg"},
	&"gomi": {"file": "gomi.pck", "probe": "res://gomi_station.tscn"},
	&"classic": {"file": "classic.pck", "probe": "res://car_classic.tscn"},
}

var _ready_packs := {}
var _waiting := {}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for pack_name in PACKS:
		if ResourceLoader.exists(PACKS[pack_name]["probe"]):
			_ready_packs[pack_name] = true
			_notify_ready.call_deferred(pack_name)
	_download_remaining.call_deferred()


func is_ready(pack_name: StringName) -> bool:
	return _ready_packs.has(pack_name)


func when_ready(pack_name: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		return
	if is_ready(pack_name):
		_call_if_valid.call_deferred(callback)
	else:
		if not _waiting.has(pack_name):
			var callbacks: Array[Callable] = []
			_waiting[pack_name] = callbacks
		_waiting[pack_name].append(callback)


func _notify_ready(pack_name: StringName) -> void:
	pack_ready.emit(pack_name)
	if _waiting.has(pack_name):
		for callback in _waiting[pack_name]:
			_call_if_valid(callback)
		_waiting.erase(pack_name)


func _call_if_valid(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


func _download_remaining() -> void:
	var preferred: StringName = &"classic" if GameMenu.robot_model == "classic" else &"gomi"
	var remaining: StringName = &"gomi" if preferred == &"classic" else &"classic"
	var order: Array[StringName] = [&"ending_audio", preferred, remaining]
	if not OS.has_feature("web"):
		for pack_name in order:
			if not is_ready(pack_name):
				push_warning("リソースパックが見つからない: %s" % pack_name)
		return
	DirAccess.make_dir_recursive_absolute("user://deferred_packs")
	var base := str(JavaScriptBridge.eval("new URL('.', location.href).href"))
	for pack_name in order:
		if not is_ready(pack_name):
			await _download_pack(pack_name, base)


func _download_pack(pack_name: StringName, base: String) -> void:
	var file: String = PACKS[pack_name]["file"]
	var path := "user://deferred_packs/" + file
	var request := HTTPRequest.new()
	# ブラウザが gzip をほどいて渡すので、Godot 側でもう一度ほどこうとすると失敗する
	request.accept_gzip = false
	request.download_file = path
	add_child(request)
	# 初回の失敗後、3回までやり直す
	for attempt in range(4):
		var error := request.request(base + file)
		if error == OK:
			var response: Array = await request.request_completed
			if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
				if ProjectSettings.load_resource_pack(path, false):
					_ready_packs[pack_name] = true
					_notify_ready(pack_name)
					request.queue_free()
					return
		if attempt < 3:
			await get_tree().create_timer(3.0, true, false, true).timeout
	request.queue_free()
	push_warning("リソースパックを読み込めない: %s" % pack_name)

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
	var key := JSON.stringify(str(pack_name))
	var url := JSON.stringify(base + file)
	# ブラウザの fetch で受け取る。HTTPRequest は gzip で送られた物を圧縮後の大きさで切ってしまい、pck が壊れる
	for attempt in range(4):
		var code := "(function(k, url){ window.__deferredPacks = window.__deferredPacks || {}; window.__deferredPacks[k] = {state: \"loading\"}; fetch(url).then(function(r){ if (!r.ok) throw new Error(\"HTTP \" + r.status); return r.arrayBuffer(); }).then(function(b){ window.__deferredPacks[k] = {state: \"done\", data: new Uint8Array(b)}; }).catch(function(e){ window.__deferredPacks[k] = {state: \"error\", message: String(e)}; }); })(%s, %s)" % [key, url]
		JavaScriptBridge.eval(code, true)
		var state := "loading"
		while state == "loading":
			await get_tree().create_timer(0.25, true, false, true).timeout
			state = str(JavaScriptBridge.eval("window.__deferredPacks[%s].state" % key, true))
		if state == "done":
			var bytes: PackedByteArray = JavaScriptBridge.eval("window.__deferredPacks[%s].data" % key, true)
			JavaScriptBridge.eval("delete window.__deferredPacks[%s]" % key, true)
			var output := FileAccess.open(path, FileAccess.WRITE)
			if output != null:
				output.store_buffer(bytes)
				output.close()
				if ProjectSettings.load_resource_pack(path, false):
					_ready_packs[pack_name] = true
					_notify_ready(pack_name)
					return
		elif state == "error":
			var message := str(JavaScriptBridge.eval("window.__deferredPacks[%s].message" % key, true))
			push_warning(message)
			JavaScriptBridge.eval("delete window.__deferredPacks[%s]" % key, true)
		if attempt < 3:
			await get_tree().create_timer(3.0, true, false, true).timeout
	push_warning("リソースパックを読み込めない: %s" % pack_name)

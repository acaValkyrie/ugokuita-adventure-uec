extends SceneTree

const GROUPS := {
	"ending_audio": [
		"res://assets/audio/bgm/これにてお開き、また来週！.mp3",
		"res://assets/audio/bgm/ending2_fanfare_1.mp3",
		"res://assets/audio/bgm/city_bird.ogg",
	],
	"gomi": ["res://gomi_station.tscn"],
	"classic": ["res://car_classic.tscn"],
}
const MAIN_EXTENSIONS := ["tscn", "scn", "tres", "res", "gd", "gdshader", "gdshaderinc"]
const EXCLUDED_DIRS := [
	"res://addons/", "res://tools/", "res://tests/", "res://tmp/", "res://.codex/", "res://.godot/",
]


func _init() -> void:
	var group_closures := {}
	var group_paths := {}
	for group_name in GROUPS:
		var paths := _closure(GROUPS[group_name])
		group_closures[group_name] = paths
		group_paths.merge(paths)

	var main_roots: Array[String] = []
	_collect_main_roots("res://", group_paths, main_roots)
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			var path := str(ProjectSettings.get_setting(property_name)).trim_prefix("*")
			main_roots.append(path)
	var main_paths := _closure(main_roots)

	for group_name in GROUPS:
		print("== ", group_name)
		var exclusive: Array[String] = []
		for path in group_closures[group_name]:
			if not main_paths.has(path):
				exclusive.append(path)
		_print_paths(exclusive)
	print("== shared")
	var shared: Array[String] = []
	for path in group_paths:
		if main_paths.has(path):
			shared.append(path)
	_print_paths(shared)
	quit()


func _closure(roots: Array) -> Dictionary:
	var paths := {}
	for root in roots:
		_add_dependencies(str(root), paths)
	return paths


func _add_dependencies(path: String, paths: Dictionary) -> void:
	if path.is_empty() or paths.has(path):
		return
	paths[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		# 型や UID が付いていても、末尾のパスを使う
		var dependency_path := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		if dependency_path.begins_with("uid://"):
			var uid := ResourceUID.text_to_id(dependency_path)
			if not ResourceUID.has_id(uid):
				continue
			dependency_path = ResourceUID.get_id_path(uid)
		_add_dependencies(dependency_path, paths)


func _collect_main_roots(directory: String, group_paths: Dictionary, roots: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("フォルダーを開けない: %s" % directory)
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := directory.path_join(entry)
		if dir.current_is_dir():
			if not EXCLUDED_DIRS.has(path + "/"):
				_collect_main_roots(path, group_paths, roots)
		elif MAIN_EXTENSIONS.has(path.get_extension().to_lower()) and not group_paths.has(path):
			roots.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _print_paths(paths: Array[String]) -> void:
	paths.sort()
	for path in paths:
		print(path.trim_prefix("res://"))

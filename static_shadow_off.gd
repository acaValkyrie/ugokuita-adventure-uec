extends Node

# ベイクしたシャドウマスクで静止物の影を描くので、実行時は静止物にリアルタイムの影を落とさせない
# （ベイク時は影を落とす設定が必要なので、エディタ上では変えない）
@export var target_path: NodePath

func _ready() -> void:
	var target := get_node_or_null(target_path)
	if target == null:
		push_warning("影を切る対象が見つからない: %s" % target_path)
		return
	for node in target.find_children("*", "GeometryInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

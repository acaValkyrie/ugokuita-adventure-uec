class_name InputGuard
extends RefCounted
# UI を閉じた直後の入力を共通で抑える。

# UI を閉じたときの物理フレーム番号
static var _closed_physics_frame := -100


# UI を閉じたときの物理フレーム番号を記録する
static func mark_closed() -> void:
	_closed_physics_frame = Engine.get_physics_frames()


# 閉じた直後か。閉じるのに使ったボタンがジャンプ・ブースト・看板と同じとき、再開した瞬間に発動させないために使う
static func is_just_closed() -> bool:
	return Engine.get_physics_frames() - _closed_physics_frame <= 1

extends Node
# boot_log.gd の補助。毎フレームの _process の最後に動いて、終わりの時刻を boot_log に知らせる。

var owner_log: Node


func _process(_d: float) -> void:
    owner_log.on_frame_end()

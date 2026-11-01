extends Node
# 画面の向きに合わせて UI の基準の大きさを切り替える。
# project.godot は stretch が canvas_items・expand で基準が 1152×648 なので、縦長の画面（スマホの縦持ち）では
# 幅に合わせることになり、UI がとても小さくなる。そこで縦でも横でも短い辺を 648 に合わせる。

# 横長のときの基準（project.godot の基準の大きさ。未指定の既定値 1152×648 と同じ値）
const LANDSCAPE_BASE := Vector2i(1152, 648)
# 縦長のときの基準（横長の縦横を入れ替えたもの）
const PORTRAIT_BASE := Vector2i(648, 1152)


func _ready() -> void:
    get_tree().root.size_changed.connect(_apply)
    _apply()


func _apply() -> void:
    var window := get_tree().root
    var base := PORTRAIT_BASE if window.size.y > window.size.x else LANDSCAPE_BASE
    # size_changed の繰り返しを避けるため、今と同じ値なら代入しない
    if window.content_scale_size != base:
        window.content_scale_size = base

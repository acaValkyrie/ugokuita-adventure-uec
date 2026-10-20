extends Node
# URL の ?boot で動く、起動直後の重さの記録。起動から40秒を2秒ごとに区切って、
# FPS・最大フレーム時間・物理演算の時間と回数などを画面左上のオーバーレイに並べる。
# RenderQuality が作る（autoload ではない）。

# 1つの区切りの長さ（秒）と、記録する合計の長さ（秒）
const BUCKET_SEC := 2.0
const DURATION_SEC := 40.0

# 起動からの時間（マイクロ秒の壁時計）
var _start_usec := 0
var _last_frame_usec := 0
var _bucket_index := 0
# 区切りごとの集計
var _frames := 0
var _max_frame_ms := 0.0
var _phys_sum := 0.0
var _proc_sum := 0.0
var _steps := 0
var _draws := 0

var _header := ""
var _lines: PackedStringArray = []


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_physics_process(true)
    _start_usec = Time.get_ticks_usec()
    _last_frame_usec = _start_usec
    var root := get_tree().root
    _header = "boot  screen %dx%d  3D x%.2f  maxsteps %d" % [
        root.size.x, root.size.y, root.scaling_3d_scale,
        Engine.max_physics_steps_per_frame]


func _physics_process(_delta: float) -> void:
    _steps += 1


func _process(_delta: float) -> void:
    var now := Time.get_ticks_usec()
    var frame_ms := float(now - _last_frame_usec) / 1000.0
    _last_frame_usec = now
    _frames += 1
    _max_frame_ms = maxf(_max_frame_ms, frame_ms)
    _phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
    _proc_sum += Performance.get_monitor(Performance.TIME_PROCESS)
    _draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    # 区切りの終わりを過ぎたら記録する（重いと複数の区切りをまたぐので繰り返す）
    var elapsed := float(now - _start_usec) / 1000000.0
    while elapsed >= (_bucket_index + 1) * BUCKET_SEC:
        _finish_bucket()
        if elapsed >= DURATION_SEC and _bucket_index * BUCKET_SEC >= DURATION_SEC:
            _finish_all()
            return


# 今の区切りを1行にして、表示を更新する
func _finish_bucket() -> void:
    var frames := maxi(_frames, 1)
    _lines.append("%4.0fs %5.1ffps max %6.1fms phys %5.1fms st %.1f proc %5.1fms draw %4d" % [
        _bucket_index * BUCKET_SEC, _frames / BUCKET_SEC, _max_frame_ms,
        _phys_sum / frames * 1000.0, float(_steps) / frames,
        _proc_sum / frames * 1000.0, _draws])
    _bucket_index += 1
    _frames = 0
    _max_frame_ms = 0.0
    _phys_sum = 0.0
    _proc_sum = 0.0
    _steps = 0
    RenderQuality.set_overlay_text_override(_build_text())


func _finish_all() -> void:
    _lines.append("done")
    var text := _build_text()
    print(text)
    RenderQuality.set_overlay_text_override(text)
    set_process(false)
    set_physics_process(false)


func _build_text() -> String:
    return _header + "\n" + "\n".join(_lines)

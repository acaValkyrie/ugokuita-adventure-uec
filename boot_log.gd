extends Node
# URL の ?boot で動く、起動直後の重さの記録。起動から120秒を2秒ごとに区切って、
# FPS・最大フレーム時間・物理演算の時間と回数などを画面左上のオーバーレイに並べる。
# RenderQuality が作る（autoload ではない）。

const BOOT_LOG_END := preload("res://boot_log_end.gd")

# 1つの区切りの長さ（秒）と、記録する合計の長さ（秒）
const BUCKET_SEC := 2.0
const DURATION_SEC := 120.0
# 決まった計算の繰り返し回数
const CPU_LOOP_COUNT := 200000

# 起動からの時間（マイクロ秒の壁時計）
var _start_usec := 0
var _last_frame_usec := 0
var _bucket_index := 0
# 区切りごとの集計
var _frames := 0
var _max_frame_ms := 0.0
var _phys_sum := 0.0
var _scr_sum := 0
var _steps := 0
var _draws := 0
# フレームの最初の _process の時刻（マイクロ秒）
var _frame_begin_usec := 0
# 決まった計算の結果（最適化で消されないように持っておく）
var _sink := 0.0

var _end_node: Node
var _header := ""
var _lines: PackedStringArray = []


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # 全ノードの _process より先に動かす
    process_priority = -100000
    set_physics_process(true)
    _start_usec = Time.get_ticks_usec()
    _last_frame_usec = _start_usec
    _frame_begin_usec = _start_usec
    # 全ノードの _process より後に動く補助ノード
    _end_node = BOOT_LOG_END.new()
    _end_node.owner_log = self
    _end_node.process_priority = 100000
    _end_node.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_end_node)


func _physics_process(_delta: float) -> void:
    _steps += 1


func _process(_delta: float) -> void:
    _frame_begin_usec = Time.get_ticks_usec()
    var now := _frame_begin_usec
    var frame_ms := float(now - _last_frame_usec) / 1000.0
    _last_frame_usec = now
    _frames += 1
    _max_frame_ms = maxf(_max_frame_ms, frame_ms)
    _phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
    _draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    # 区切りの終わりを過ぎたら記録する（重いと複数の区切りをまたぐので繰り返す）
    var elapsed := float(now - _start_usec) / 1000000.0
    while elapsed >= (_bucket_index + 1) * BUCKET_SEC:
        _finish_bucket()
        if elapsed >= DURATION_SEC and _bucket_index * BUCKET_SEC >= DURATION_SEC:
            _finish_all()
            return


# 補助ノードから、フレームの最後の _process で呼ばれる
func on_frame_end() -> void:
    _scr_sum += Time.get_ticks_usec() - _frame_begin_usec


# 決まった計算にかかる時間（ミリ秒）
func _measure_cpu_ms() -> float:
    var t0 := Time.get_ticks_usec()
    var x := 0.0
    for i in CPU_LOOP_COUNT:
        x += sin(float(i) * 0.001) * 1.0001
    _sink = x
    return float(Time.get_ticks_usec() - t0) / 1000.0


# 今の区切りを1行にして、表示を更新する
func _finish_bucket() -> void:
    if _header == "":
        var root := get_tree().root
        _header = "boot  screen %dx%d  3D x%.2f  maxsteps %d" % [
            root.size.x, root.size.y, root.scaling_3d_scale,
            Engine.max_physics_steps_per_frame]
    var frames := maxi(_frames, 1)
    var cpu_ms := _measure_cpu_ms()
    _lines.append("%4.0fs %5.1ffps max %6.1fms phys %5.1fms st %.1f scr %5.1fms cpu %5.1fms draw %4d" % [
        _bucket_index * BUCKET_SEC, _frames / BUCKET_SEC, _max_frame_ms,
        _phys_sum / frames * 1000.0, float(_steps) / frames,
        float(_scr_sum) / frames / 1000.0, cpu_ms, _draws])
    _bucket_index += 1
    _frames = 0
    _max_frame_ms = 0.0
    _phys_sum = 0.0
    _scr_sum = 0
    _steps = 0
    RenderQuality.set_overlay_text_override(_build_text())


func _finish_all() -> void:
    _lines.append("done")
    var text := _build_text()
    print(text)
    RenderQuality.set_overlay_text_override(text)
    RenderQuality.save_report("boot", text)
    set_process(false)
    set_physics_process(false)
    _end_node.set_process(false)


func _build_text() -> String:
    return _header + "\n" + "\n".join(_lines)

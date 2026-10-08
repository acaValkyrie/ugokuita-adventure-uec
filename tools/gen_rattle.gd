extends SceneTree

# Classic の段差音に重ねる「カチャカチャ」音（rattle_a〜d.wav）を合成して保存する。
# 短いクリック音（ノイズ + 指数減衰 + 共振バンドパス）を3〜5個重ねたもの。
# 実行方法:
#   Godot --headless --path <プロジェクト> --script res://tools/gen_rattle.gd

const SAMPLE_RATE := 44100
const DURATION := 0.2
const PEAK := 0.7
const FADE_OUT := 0.005
const NAMES := ["a", "b", "c", "d"]
const SEEDS := [1001, 1002, 1003, 1004]

func _init() -> void:
    for i in NAMES.size():
        var path := ProjectSettings.globalize_path("res://assets/audio/bump/rattle_%s.wav" % NAMES[i])
        DirAccess.make_dir_recursive_absolute(path.get_base_dir())
        var stream := _make_rattle(SEEDS[i])
        stream.save_to_wav(path)
        print(path)
    quit()

# クリックを重ねた1つ分の音を作る
func _make_rattle(seed_value: int) -> AudioStreamWAV:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var total := int(SAMPLE_RATE * DURATION)
    var buf := PackedFloat32Array()
    buf.resize(total)

    var click_count := rng.randi_range(3, 5)
    var start := 0
    var amp := 1.0
    for c in click_count:
        if c > 0:
            start += int(rng.randf_range(0.018, 0.045) * SAMPLE_RATE)
            amp *= rng.randf_range(0.5, 0.9)
        if start >= total:
            break
        var tau := rng.randf_range(0.002, 0.005)
        var freq := rng.randf_range(1800.0, 4500.0)
        var q := rng.randf_range(6.0, 10.0)
        _add_click(buf, start, amp, tau, freq, q, rng)

    # 最大振幅を PEAK にそろえる
    var max_abs := 0.0
    for s in buf:
        max_abs = maxf(max_abs, absf(s))
    var gain := PEAK / max_abs if max_abs > 0.0 else 0.0

    # 最後の 5ms はフェードアウトして 16bit に量子化する
    var fade_len := int(SAMPLE_RATE * FADE_OUT)
    var bytes := PackedByteArray()
    bytes.resize(total * 2)
    for n in total:
        var v := buf[n] * gain
        if n >= total - fade_len:
            v *= float(total - 1 - n) / float(fade_len)
        bytes.encode_s16(n * 2, int(round(clampf(v, -1.0, 1.0) * 32767.0)))

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = bytes
    return stream

# ノイズ * 指数減衰 をバンドパス（RBJ biquad, constant 0 dB peak gain）に通して buf に足す
func _add_click(buf: PackedFloat32Array, start: int, amp: float, tau: float, freq: float, q: float, rng: RandomNumberGenerator) -> void:
    var w0 := TAU * freq / SAMPLE_RATE
    var alpha := sin(w0) / (2.0 * q)
    var a0 := 1.0 + alpha
    var b0 := alpha / a0
    var b2 := -alpha / a0
    var a1 := -2.0 * cos(w0) / a0
    var a2 := (1.0 - alpha) / a0
    # フィルタの状態（クリックごとに独立）
    var x1 := 0.0
    var x2 := 0.0
    var y1 := 0.0
    var y2 := 0.0
    for n in range(start, buf.size()):
        var t := float(n - start) / SAMPLE_RATE
        var x := rng.randf_range(-1.0, 1.0) * exp(-t / tau)
        var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        buf[n] += y * amp

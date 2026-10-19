import os
import subprocess
import numpy as np

SR = 48000
PEAK_LIMIT_DB = -1.0
# チャージの音のループの開始位置 [s]。car.gd の CHARGE_LOOP_START と合わせる
CHARGE_LOOP_START = 2.9
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC_DIR = os.path.join(ROOT, "assets", "audio", "bgm", "source")
DST_DIR = os.path.join(ROOT, "assets", "audio", "drift")


def decode_mono(src):
    # ffmpegで任意の形式をモノラル・48kHzの32bit float PCMにデコードする
    cmd = ["ffmpeg", "-v", "error", "-i", src, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def encode_ogg(samples, dst):
    # float PCMをOgg Vorbis（モノラル・96kbps）に書き出す
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
           "-c:a", "libvorbis", "-b:a", "96k", dst]
    subprocess.run(cmd, check=True, input=samples.astype("<f4").tobytes())


def peak_db(x):
    return 20 * np.log10(np.max(np.abs(x)))


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)))


def make_charge(mono):
    # 元の0〜3.4秒を切り出す。ループ（CHARGE_LOOP_START〜末尾）の継ぎ目が出ないように、
    # 出力の2.9〜3.0秒を「元の2.9〜3.0秒のフェードイン＋元の3.4〜3.5秒のフェードアウト」に置き換える
    out = mono[:int(3.4 * SR)].copy()
    a = int(CHARGE_LOOP_START * SR)
    f = int(0.1 * SR)
    b = int(3.4 * SR)
    t = np.linspace(0.0, 1.0, f)
    fade_in = np.sin(t * np.pi / 2)
    fade_out = np.cos(t * np.pi / 2)
    out[a:a + f] = mono[a:a + f] * fade_in + mono[b:b + f] * fade_out
    # 先頭5msのフェードイン
    n = int(0.005 * SR)
    out[:n] *= np.linspace(0.0, 1.0, n)
    return out


def make_dash(mono):
    # 元の4.45〜7.9秒を切り出し、前後の-60 dBFS未満を削る
    seg = mono[int(4.45 * SR):int(7.9 * SR)]
    loud = np.nonzero(np.abs(seg) >= 10 ** (-60.0 / 20))[0]
    out = seg[loud[0]:loud[-1] + 1].copy()
    n = int(0.002 * SR)
    out[:n] *= np.linspace(0.0, 1.0, n)
    f = int(0.02 * SR)
    out[-f:] *= np.linspace(1.0, 0.0, f)
    return out


def main():
    os.makedirs(DST_DIR, exist_ok=True)
    mono = decode_mono(os.path.join(SRC_DIR, "freesound_community-charged-laser-7125.mp3"))
    charge = make_charge(mono)
    dash = make_dash(mono)
    # 発射のピークを-1 dBFSにそろえるゲインを、チャージにも掛ける（2つの大きさの関係を保つ）
    gain = 10 ** (PEAK_LIMIT_DB / 20) / np.max(np.abs(dash))
    charge *= gain
    dash *= gain
    print(f"gain: {20 * np.log10(gain):.2f} dB")
    for name, x in (("drift_charge", charge), ("drift_dash", dash)):
        print(f"{name}: {len(x) / SR:.3f} s, RMS {rms_db(x):.2f} dBFS, peak {peak_db(x):.2f} dBFS")
        encode_ogg(x, os.path.join(DST_DIR, name + ".ogg"))


main()

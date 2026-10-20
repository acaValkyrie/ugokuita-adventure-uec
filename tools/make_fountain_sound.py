import os
import subprocess
import numpy as np

SR = 48000
PEAK_LIMIT_DB = -1.0
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC_DIR = os.path.join(ROOT, "assets", "audio", "bgm", "source")
DST_DIR = os.path.join(ROOT, "assets", "audio", "water")


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


def make_fountain():
    # 元の1〜39秒（38秒）を切り出し、先頭2秒に末尾2秒をクロスフェードで重ねて36秒のループにする
    mono = decode_mono(os.path.join(SRC_DIR, "freesound_community-fountain-73903.mp3"))
    seg = mono[1 * SR:39 * SR]
    f = 2 * SR
    t = np.linspace(0.0, 1.0, f)
    fade_in = np.sin(t * np.pi / 2)
    fade_out = np.cos(t * np.pi / 2)
    out = seg[:36 * SR].copy()
    out[:f] = seg[:f] * fade_in + seg[36 * SR:38 * SR] * fade_out
    # RMSを-20 dBFSにそろえる（ピークが-1 dBFSを超えるときはピークで頭打ちにする）
    rms = np.sqrt(np.mean(out ** 2))
    gain = 10 ** (-20.0 / 20) / rms
    limit = 10 ** (PEAK_LIMIT_DB / 20)
    gain = min(gain, limit / np.max(np.abs(out)))
    out *= gain
    print(f"fountain: {len(out) / SR:.3f} s, RMS {20 * np.log10(np.sqrt(np.mean(out ** 2))):.2f} dBFS, peak {peak_db(out):.2f} dBFS")
    encode_ogg(out, os.path.join(DST_DIR, "fountain.ogg"))


make_fountain()

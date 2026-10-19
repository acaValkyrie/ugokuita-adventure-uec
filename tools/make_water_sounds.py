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


def make_running_stream():
    # 元の30〜52秒（22秒）を切り出し、先頭2秒に末尾2秒をクロスフェードで重ねて20秒のループにする
    mono = decode_mono(os.path.join(SRC_DIR, "allyinnature-running-stream-water-sound-239612.mp3"))
    seg = mono[30 * SR:52 * SR]
    f = 2 * SR
    t = np.linspace(0.0, 1.0, f)
    fade_in = np.sin(t * np.pi / 2)
    fade_out = np.cos(t * np.pi / 2)
    out = seg[:20 * SR].copy()
    out[:f] = seg[:f] * fade_in + seg[20 * SR:22 * SR] * fade_out
    # RMSを-20 dBFSにそろえる（ピークが-1 dBFSを超えるときはピークで頭打ちにする）
    rms = np.sqrt(np.mean(out ** 2))
    gain = 10 ** (-20.0 / 20) / rms
    limit = 10 ** (PEAK_LIMIT_DB / 20)
    gain = min(gain, limit / np.max(np.abs(out)))
    out *= gain
    print(f"running_stream: {len(out) / SR:.3f} s, RMS {20 * np.log10(np.sqrt(np.mean(out ** 2))):.2f} dBFS, peak {peak_db(out):.2f} dBFS")
    encode_ogg(out, os.path.join(DST_DIR, "running_stream.ogg"))


def make_water_splash():
    # モノラルにして末尾の無音を削り、ピークを-1 dBFSにそろえる
    mono = decode_mono(os.path.join(SRC_DIR, "universfield-water-splash-199583.mp3"))
    loud = np.nonzero(np.abs(mono) >= 10 ** (-60.0 / 20))[0]
    out = mono[:loud[-1] + 1].copy()
    # 最後の20msをフェードアウトして、プツッと切れないようにする
    f = int(0.02 * SR)
    out[-f:] *= np.linspace(1.0, 0.0, f)
    out *= 10 ** (PEAK_LIMIT_DB / 20) / np.max(np.abs(out))
    print(f"water_splash: {len(out) / SR:.3f} s, peak {peak_db(out):.2f} dBFS")
    encode_ogg(out, os.path.join(DST_DIR, "water_splash.ogg"))


make_running_stream()
make_water_splash()

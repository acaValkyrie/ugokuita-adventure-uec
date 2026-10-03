import argparse
import subprocess
import wave
import numpy as np

SR = 48000
PEAK_LIMIT_DB = -1.0


def decode_mono(src):
    # ffmpegで任意の形式をモノラル・48kHzの16bit PCMにデコードする
    cmd = ["ffmpeg", "-v", "error", "-i", src, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--start", type=float, required=True)
    ap.add_argument("--end", type=float, required=True)
    ap.add_argument("--fade", type=float, default=0.25)
    ap.add_argument("--rms-db", type=float, default=-20.0)
    args = ap.parse_args()

    sr = SR
    mono = decode_mono(args.src)

    seg = mono[int(round(args.start * sr)):int(round(args.end * sr))]
    n = len(seg)
    f = int(round(args.fade * sr))
    t = np.linspace(0.0, 1.0, f)
    fade_in = np.sin(t * np.pi / 2)
    fade_out = np.cos(t * np.pi / 2)
    out = seg[:n - f].copy()
    out[:f] = seg[:f] * fade_in + seg[n - f:] * fade_out

    rms = np.sqrt(np.mean(out ** 2))
    out *= 10 ** (args.rms_db / 20) / rms
    limit = 10 ** (PEAK_LIMIT_DB / 20)
    clipped = int(np.sum(np.abs(out) > limit))
    out = np.clip(out, -limit, limit)

    pcm = np.round(out * 32767.0).astype("<i2")
    with wave.open(args.dst, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())

    final_rms = np.sqrt(np.mean(out ** 2))
    peak = np.max(np.abs(out))
    print(f"duration: {len(out) / sr:.3f} s ({len(out)} samples, {sr} Hz)")
    print(f"RMS: {20 * np.log10(final_rms):.2f} dBFS")
    print(f"peak: {20 * np.log10(peak):.2f} dBFS")
    print(f"clipped samples: {clipped}")


main()

import sys
import wave
import numpy as np

SEG_START = 4.50
SEG_END = 7.40
FADE = 0.25
TARGET_RMS_DB = -20.0
PEAK_LIMIT_DB = -1.0


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with wave.open(src, "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        assert w.getsampwidth() == 2, "16-bit only"
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    data = raw.reshape(-1, ch).astype(np.float64) / 32768.0
    mono = data.mean(axis=1)

    seg = mono[int(round(SEG_START * sr)):int(round(SEG_END * sr))]
    n = len(seg)
    f = int(round(FADE * sr))
    t = np.linspace(0.0, 1.0, f)
    fade_in = np.sin(t * np.pi / 2)
    fade_out = np.cos(t * np.pi / 2)
    out = seg[:n - f].copy()
    out[:f] = seg[:f] * fade_in + seg[n - f:] * fade_out

    rms = np.sqrt(np.mean(out ** 2))
    out *= 10 ** (TARGET_RMS_DB / 20) / rms
    limit = 10 ** (PEAK_LIMIT_DB / 20)
    clipped = int(np.sum(np.abs(out) > limit))
    out = np.clip(out, -limit, limit)

    pcm = np.round(out * 32767.0).astype("<i2")
    with wave.open(dst, "wb") as w:
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

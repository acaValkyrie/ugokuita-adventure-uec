import os
import re
import subprocess
import sys

# 段差の衝撃音の切り出し位置 [s]（元録音で検出した衝撃の少し前から）
CLIPS = {"bump_a.ogg": 2.01, "bump_b.ogg": 2.63}
LENGTH = 0.55
FADE_IN = 0.005
FADE_OUT = 0.15
TARGET_PEAK_DB = -3.0


def ffmpeg(args):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-y"] + args, capture_output=True, text=True, encoding="utf-8", errors="replace", check=True)
    return r.stderr


def stat(path, key):
    log = ffmpeg(["-i", path, "-af", "volumedetect", "-f", "null", "-"])
    return float(re.search(key + r": (-?[\d.]+) dB", log).group(1))


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for name, start in CLIPS.items():
        base = ["-ss", str(start), "-t", str(LENGTH), "-i", src, "-ac", "1", "-ar", "44100"]
        fade = f"afade=t=in:d={FADE_IN},afade=t=out:st={LENGTH - FADE_OUT}:d={FADE_OUT}"
        # まずゲインなしで最大音量を測り、ピークが目標になるようゲインをかける
        tmp = os.path.join(out_dir, "_tmp.wav")
        ffmpeg(base + ["-af", fade, tmp])
        gain = TARGET_PEAK_DB - stat(tmp, "max_volume")
        dst = os.path.join(out_dir, name)
        ffmpeg(["-i", tmp, "-af", f"volume={gain}dB", "-c:a", "libvorbis", "-q:a", "4", dst])
        os.remove(tmp)
        print(f"{name}: peak {stat(dst, 'max_volume'):.2f} dB, mean {stat(dst, 'mean_volume'):.2f} dB (gain {gain:.2f} dB)")


main()

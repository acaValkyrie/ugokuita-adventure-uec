"""草の上の効果音用に、枯れ葉のカサカサ音(FLAC)をゲーム向けのOGGへ変換する。

- 平均音量を -24 dBFS にそろえる
- モノラル・44100Hz にダウンミックスする
- ピークが -1 dBFS を超えないようリミッターをかける
- Ogg Vorbis (品質4) で出力する

使い方:
    python tools/convert_rustles.py <入力フォルダ> <出力フォルダ> rustle02 rustle05 ...

ffmpeg が PATH 上にある必要がある。
"""
import re
import subprocess
import sys
from pathlib import Path

TARGET_MEAN_DB = -24.0
LIMIT = 0.89  # 約 -1 dBFS


def measure(path):
    # volumedetect の結果は stderr に出る。変換後と条件をそろえるためモノラルで測る
    r = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(path), "-ac", "1", "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True,
    )
    mean = float(re.search(r"mean_volume:\s*(-?[\d.]+) dB", r.stderr).group(1))
    peak = float(re.search(r"max_volume:\s*(-?[\d.]+) dB", r.stderr).group(1))
    # 進捗表示の最後の time= を長さとして使う
    times = re.findall(r"time=(\d+):(\d+):([\d.]+)", r.stderr)
    h, m, s = (float(x) for x in times[-1]) if times else (0, 0, 0)
    return mean, peak, h * 3600 + m * 60 + s


def convert(src, dst, gain):
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
         "-af", f"volume={gain:.2f}dB,alimiter=limit={LIMIT}:level=disabled",
         "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", str(dst)],
        check=True,
    )


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    src_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"{'name':<10} {'src_mean':>9} {'gain':>8} {'dur(s)':>7} {'out_mean':>9} {'out_max':>8}")
    for name in sys.argv[3:]:
        src = src_dir / f"{name}.flac"
        dst = out_dir / f"{name}.ogg"
        src_mean, _, _ = measure(src)
        gain = TARGET_MEAN_DB - src_mean
        convert(src, dst, gain)
        out_mean, out_max, dur = measure(dst)
        print(f"{name:<10} {src_mean:>9.1f} {gain:>8.1f} {dur:>7.2f} {out_mean:>9.1f} {out_max:>8.1f}")


if __name__ == "__main__":
    main()

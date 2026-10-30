#!/usr/bin/env python3
"""同名の PNG を RGB の画素差で比較する（外部依存は Pillow のみ）。

使用法:
    python compare_images.py <dir_a> <dir_b> [--threshold 8] [--diff-dir <dir>]
"""

import argparse
from pathlib import Path
import sys

from PIL import Image, ImageChops


def channel_threshold(value: str) -> int:
    """RGB の各チャンネルで指定可能な閾値に制限する。"""
    threshold = int(value)
    if not 0 <= threshold <= 255:
        raise argparse.ArgumentTypeError("threshold must be between 0 and 255")
    return threshold


def png_files(directory: Path) -> dict[str, Path]:
    return {
        file.name: file
        for file in directory.iterdir()
        if file.is_file() and file.suffix.lower() == ".png"
    }


def compare_images(path_a: Path, path_b: Path, threshold: int, diff_dir: Path | None) -> bool:
    """閾値を超えた画素の数と最大チャンネル差を表示する。"""
    with Image.open(path_a) as source_a, Image.open(path_b) as source_b:
        image_a = source_a.convert("RGB")
        image_b = source_b.convert("RGB")
    if image_a.size != image_b.size:
        raise ValueError(f"image sizes differ: {image_a.size} != {image_b.size}")

    difference = ImageChops.difference(image_a, image_b)
    red, green, blue = difference.split()
    largest_channel = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    max_difference = largest_channel.getextrema()[1]
    mask = largest_channel.point(lambda value: 255 if value > threshold else 0)
    diff_pixels = mask.histogram()[255]
    total_pixels = image_a.width * image_a.height
    print(
        f"{path_a.name} diff_pixels={diff_pixels} "
        f"ratio={diff_pixels / total_pixels:.5f} max={max_difference}"
    )

    if diff_pixels and diff_dir is not None:
        # 差分を赤、それ以外を比較元の明るさ 0.3 倍で表示する。
        dimmed = image_a.point(lambda value: int(value * 0.3))
        highlight = Image.new("RGB", image_a.size, (255, 0, 0))
        Image.composite(highlight, dimmed, mask).save(diff_dir / path_a.name)
    return diff_pixels > 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dir_a", type=Path)
    parser.add_argument("dir_b", type=Path)
    parser.add_argument("--threshold", type=channel_threshold, default=8)
    parser.add_argument("--diff-dir", type=Path)
    args = parser.parse_args()
    for directory in (args.dir_a, args.dir_b):
        if not directory.is_dir():
            parser.error(f"not a directory: {directory}")

    files_a = png_files(args.dir_a)
    files_b = png_files(args.dir_b)
    for name in sorted(files_a.keys() - files_b.keys()):
        print(f"only_in_a={name}")
    for name in sorted(files_b.keys() - files_a.keys()):
        print(f"only_in_b={name}")
    if args.diff_dir is not None:
        args.diff_dir.mkdir(parents=True, exist_ok=True)

    common_names = sorted(files_a.keys() & files_b.keys())
    diff_files = 0
    error_files = 0
    for name in common_names:
        try:
            diff_files += compare_images(files_a[name], files_b[name], args.threshold, args.diff_dir)
        except (OSError, ValueError) as error:
            error_files += 1
            print(f"{name} error={error}", file=sys.stderr)
    print(f"total_files={len(common_names)} diff_files={diff_files} error_files={error_files}")
    return 2 if error_files else 0


if __name__ == "__main__":
    sys.exit(main())

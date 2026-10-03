# タイル可能なテクスチャをCIE Labで再着色する（模様の明暗と継ぎ目は保つ）
# 使い方: python tools/recolor_texture.py <入力.png> <出力.png> --lightness 0.92 --target-a 3.0 --target-b 4.0 --chroma-scale 0.35
import argparse

import numpy as np
from PIL import Image

# D65 白色点
WHITE = np.array([0.95047, 1.0, 1.08883])
M_RGB2XYZ = np.array([[0.4124564, 0.3575761, 0.1804375],
                      [0.2126729, 0.7151522, 0.0721750],
                      [0.0193339, 0.1191920, 0.9503041]])
M_XYZ2RGB = np.linalg.inv(M_RGB2XYZ)
EPS = 216 / 24389
KAPPA = 24389 / 27


def srgb_to_lab(rgb):
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    xyz = lin @ M_RGB2XYZ.T / WHITE
    f = np.where(xyz > EPS, np.cbrt(xyz), (KAPPA * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16,
                     500 * (f[..., 0] - f[..., 1]),
                     200 * (f[..., 1] - f[..., 2])], axis=-1)


def lab_to_srgb(lab):
    fy = (lab[..., 0] + 16) / 116
    fx = fy + lab[..., 1] / 500
    fz = fy - lab[..., 2] / 200
    f = np.stack([fx, fy, fz], axis=-1)
    xyz = np.where(f ** 3 > EPS, f ** 3, (116 * f - 16) / KAPPA) * WHITE
    lin = np.clip(xyz @ M_XYZ2RGB.T, 0, 1)
    c = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)
    return np.clip(np.round(c * 255), 0, 255).astype(np.uint8)


def stats(rgb_u8):
    img = Image.fromarray(rgb_u8, "RGB")
    f = rgb_u8.astype(float)
    lum = f @ np.array([0.299, 0.587, 0.114])
    sat = np.asarray(img.convert("HSV"))[..., 1].astype(float)
    return f.reshape(-1, 3).mean(0), lum.mean(), lum.std(), sat.mean()


def edge_diff(rgb_u8):
    f = rgb_u8.astype(float)
    return (np.abs(f[:, 0] - f[:, -1]).mean(), np.abs(f[0] - f[-1]).mean())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("input")
    p.add_argument("output")
    p.add_argument("--lightness", type=float, default=1.0)
    p.add_argument("--target-a", type=float, default=0.0)
    p.add_argument("--target-b", type=float, default=0.0)
    p.add_argument("--chroma-scale", type=float, default=1.0)
    args = p.parse_args()

    im = Image.open(args.input)
    has_alpha = "A" in im.getbands()
    arr = np.asarray(im.convert("RGBA"))
    rgb, alpha = arr[..., :3], arr[..., 3]

    lab = srgb_to_lab(rgb.astype(float))
    L = np.clip(lab[..., 0] * args.lightness, 0, 100)
    a = args.target_a + (lab[..., 1] - lab[..., 1].mean()) * args.chroma_scale
    b = args.target_b + (lab[..., 2] - lab[..., 2].mean()) * args.chroma_scale
    out = lab_to_srgb(np.stack([L, a, b], axis=-1))

    if has_alpha:
        Image.fromarray(np.dstack([out, alpha]), "RGBA").save(args.output)
    else:
        Image.fromarray(out, "RGB").save(args.output)

    for name, img in (("before", rgb), ("after", out)):
        m, lm, ls, sat = stats(img)
        ec, er = edge_diff(img)
        print(f"{name}: meanRGB=({m[0]:.2f},{m[1]:.2f},{m[2]:.2f}) lum_mean={lm:.2f} lum_std={ls:.2f} "
              f"mean_sat={sat:.2f} edge_diff(col0-colW-1)={ec:.3f} edge_diff(row0-rowH-1)={er:.3f}")


if __name__ == "__main__":
    main()

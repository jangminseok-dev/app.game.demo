#!/usr/bin/env python3
"""배경 이미지 1장을 360×270 픽셀화하고 지평선에서 far/ground 로 나눈다.

사용: bg_pixelize.py <입력.png> <출력 폴더> --horizon 110 [--colors 32]
"""
import argparse
from pathlib import Path

from PIL import Image

W, H = 360, 270


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("out_dir")
    p.add_argument("--horizon", type=int, default=110)
    p.add_argument("--colors", type=int, default=32)
    a = p.parse_args()

    im = Image.open(a.src).convert("RGB")
    # 4:3 으로 중앙 크롭 후 축소
    ratio = W / H
    w, h = im.size
    if w / h > ratio:
        nw = int(h * ratio)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / ratio)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    im = im.resize((W, H), Image.NEAREST)
    im = im.quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")

    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    im.crop((0, 0, W, a.horizon)).save(out / "far.png")
    im.crop((0, a.horizon, W, H)).save(out / "ground.png")
    print(f"far {W}x{a.horizon}, ground {W}x{H - a.horizon} → {out}")


if __name__ == "__main__":
    main()

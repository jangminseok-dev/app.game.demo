#!/usr/bin/env python3
"""프레임 PNG 폴더를 가로 스트립 PNG + JSON 으로 묶는다.

사용: sheet_pack.py <프레임 루트> <출력 경로(확장자 없음)> --size 48 [--fps 8]
프레임 루트/idle/*.png, walk/*.png, attack/*.png, hit/*.png, death/*.png 가 있어야 한다.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ANIMS = ["idle", "walk", "attack", "hit", "death"]


def load_frames(folder: Path, size: int) -> list[Image.Image]:
    files = sorted(folder.glob("*.png"))
    if not files:
        sys.exit(f"프레임 없음: {folder}")
    frames = []
    for f in files:
        im = Image.open(f).convert("RGBA")
        if im.size != (size, size):
            # 원본이 더 크면 최근접으로 줄인다(픽셀 보존). 작으면 중앙 정렬.
            canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            if im.width > size or im.height > size:
                im = im.resize((size, size), Image.NEAREST)
            canvas.paste(im, ((size - im.width) // 2, size - im.height))
            im = canvas
        frames.append(im)
    return frames


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("root")
    p.add_argument("out")
    p.add_argument("--size", type=int, required=True)
    p.add_argument("--fps", type=int, default=8)
    a = p.parse_args()

    root = Path(a.root)
    all_frames: list[Image.Image] = []
    ranges: dict[str, list[int]] = {}
    for name in ANIMS:
        frames = load_frames(root / name, a.size)
        start = len(all_frames)
        all_frames.extend(frames)
        ranges[name] = [start, len(all_frames) - 1]

    strip = Image.new("RGBA", (a.size * len(all_frames), a.size), (0, 0, 0, 0))
    for i, fr in enumerate(all_frames):
        strip.paste(fr, (i * a.size, 0))
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out.with_suffix(".png"))
    out.with_suffix(".json").write_text(
        json.dumps({"frame": [a.size, a.size], "fps": a.fps, "animations": ranges}, indent=2)
    )
    print(f"{out.with_suffix('.png')}  frames={len(all_frames)}  {ranges}")


if __name__ == "__main__":
    main()

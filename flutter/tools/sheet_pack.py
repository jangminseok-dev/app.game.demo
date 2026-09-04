#!/usr/bin/env python3
"""프레임 PNG 폴더를 가로 스트립 PNG + JSON 으로 묶는다.

사용: sheet_pack.py <프레임 루트> <출력 경로(확장자 없음)> --size 48 [--fps 8] [--anims idle,walk,attack,hit,death] [--flip]
프레임 루트/<anim>/*.png 가 애니메이션마다 있어야 한다.

- 프레임 캔버스가 --size 보다 크면(PixelLab은 48 요청에 68 캔버스를 준다) 내용의 바닥 중앙을 기준으로
  --size 정사각으로 잘라낸다. 내용이 --size 보다 크면 최근접으로 줄이고 경고한다.
- --flip: 모든 프레임을 좌우 반전한다(서쪽 뷰를 오른쪽 보기로 바꿀 때). 묶인 시트는 항상 오른쪽을 본다.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

DEFAULT_ANIMS = ["idle", "walk", "attack", "hit", "death"]


def fit(im: Image.Image, size: int, flip: bool) -> Image.Image:
    im = im.convert("RGBA")
    if flip:
        im = ImageOps.mirror(im)
    bbox = im.getbbox()
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    content = im.crop(bbox)
    if content.width > size or content.height > size:
        print(f"  경고: 내용 {content.size} > {size}, 최근접 축소", file=sys.stderr)
        content.thumbnail((size, size), Image.NEAREST)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(content, ((size - content.width) // 2, size - content.height), content)
    return canvas


def load_frames(folder: Path, size: int, flip: bool) -> list[Image.Image]:
    files = sorted(folder.glob("*.png"))
    if not files:
        sys.exit(f"프레임 없음: {folder}")
    return [fit(Image.open(f), size, flip) for f in files]


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("root")
    p.add_argument("out")
    p.add_argument("--size", type=int, required=True)
    p.add_argument("--fps", type=int, default=8)
    p.add_argument("--anims", default=",".join(DEFAULT_ANIMS))
    p.add_argument("--flip", action="store_true")
    a = p.parse_args()

    root = Path(a.root)
    all_frames: list[Image.Image] = []
    ranges: dict[str, list[int]] = {}
    for name in a.anims.split(","):
        frames = load_frames(root / name, a.size, a.flip)
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

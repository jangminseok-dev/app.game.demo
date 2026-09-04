#!/usr/bin/env python3
"""itch.io 스프라이트 팩(애니메이션별 가로 스트립)을 우리 시트 형식으로 변환한다.

사용: pack_import.py <캐릭터 폴더> <출력 경로(확장자 없음)> --prefix Soldier --scale 2
폴더에 <prefix>_Idle.png, _Walk.png, _Attack01.png, _Hurt.png, _Death.png 가 있어야 한다.
모든 프레임의 합집합 경계로 잘라 정렬을 맞추고, 필요하면 최근접 확대한다.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

# 우리 애니메이션 이름 ← 팩 파일 접미사
MAP = [("idle", "Idle"), ("walk", "Walk"), ("attack", "Attack01"), ("hit", "Hurt"), ("death", "Death")]


def split(path: Path, cell: int) -> list[Image.Image]:
    im = Image.open(path).convert("RGBA")
    if im.height != cell:
        sys.exit(f"{path.name}: 높이 {im.height} != 셀 {cell}")
    return [im.crop((i * cell, 0, (i + 1) * cell, cell)) for i in range(im.width // cell)]


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("folder")
    p.add_argument("out")
    p.add_argument("--prefix", required=True)
    p.add_argument("--cell", type=int, default=100)
    p.add_argument("--scale", type=int, default=2)
    p.add_argument("--fps", type=int, default=10)
    p.add_argument("--flip", action="store_true")
    a = p.parse_args()

    folder = Path(a.folder)
    raw: dict[str, list[Image.Image]] = {}
    for ours, theirs in MAP:
        f = folder / f"{a.prefix}_{theirs}.png"
        if not f.exists():
            sys.exit(f"없음: {f}")
        frames = split(f, a.cell)
        raw[ours] = [ImageOps.mirror(x) for x in frames] if a.flip else frames

    # 모든 프레임의 합집합 경계 — 애니메이션 간 위치가 흔들리지 않게 같은 창으로 자른다
    boxes = [im.getbbox() for fs in raw.values() for im in fs if im.getbbox()]
    win = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    w, h = win[2] - win[0], win[3] - win[1]
    frame = max(w, h) * a.scale
    print(f"내용 창 {win} = {w}x{h}px → ×{a.scale} → 프레임 {frame}px")

    out_frames: list[Image.Image] = []
    ranges: dict[str, list[int]] = {}
    for ours, _ in MAP:
        start = len(out_frames)
        for im in raw[ours]:
            content = im.crop(win).resize((w * a.scale, h * a.scale), Image.NEAREST)
            canvas = Image.new("RGBA", (frame, frame), (0, 0, 0, 0))
            canvas.paste(content, ((frame - content.width) // 2, frame - content.height), content)
            out_frames.append(canvas)
        ranges[ours] = [start, len(out_frames) - 1]

    strip = Image.new("RGBA", (frame * len(out_frames), frame), (0, 0, 0, 0))
    for i, fr in enumerate(out_frames):
        strip.paste(fr, (i * frame, 0))
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out.with_suffix(".png"))
    out.with_suffix(".json").write_text(json.dumps({"frame": [frame, frame], "fps": a.fps, "animations": ranges}, indent=2))
    print(f"{out.with_suffix('.png')}  frames={len(out_frames)}  {ranges}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""스프라이트의 색 수를 센다. 화풍 규격은 5색 이내(ART_GUIDE.md 1절).

사용: count_colors.py <png...> [--max 5]

투명 픽셀(alpha 0)은 세지 않는다. 반투명 픽셀은 픽셀아트 규격 위반이라 같이 보고하되
합격 여부는 색 수로만 판정한다 — 생성기가 가장자리에 몇 픽셀 남기는 일이 흔하고,
그건 sheet_pack.py 단계에서 정리된다.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image


def count(path: Path) -> tuple[int, int]:
    """(불투명 색 수, 반투명 픽셀 수)를 돌려준다."""
    im = Image.open(path).convert("RGBA")
    colors: set[tuple[int, int, int]] = set()
    semi = 0
    for r, g, b, a in im.getdata():
        if a == 0:
            continue
        if a < 255:
            semi += 1
        colors.add((r, g, b))
    return len(colors), semi


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+", type=Path)
    ap.add_argument("--max", type=int, default=5, help="허용 색 수 (기본 5)")
    args = ap.parse_args()

    failed = False
    for p in args.paths:
        n, semi = count(p)
        ok = n <= args.max
        failed |= not ok
        note = f", 반투명 {semi}px" if semi else ""
        print(f"{'OK  ' if ok else '실패'} {p.name}: {n}색{note}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Generate deterministic hexadecimal words for the FIFO simulation."""

from __future__ import annotations

import argparse
from pathlib import Path


def generate_words(count: int, width: int) -> list[int]:
    """Create distinct, mixed bit patterns for the FIFO testbench."""
    if count < 1:
        raise ValueError("count must be at least 1")
    if width < 1:
        raise ValueError("width must be at least 1")

    mask = (1 << width) - 1
    return [((index * 0x1F3D) + 0xA55A) & mask for index in range(count)]


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--count",
        type=int,
        default=32,
        help="number of words (default: 32)",
    )
    parser.add_argument(
        "--width",
        type=int,
        default=16,
        help="data width in bits (default: 16)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=repo_root / "sim" / "input_data.txt",
        help="output file (default: sim/input_data.txt)",
    )
    args = parser.parse_args()

    words = generate_words(args.count, args.width)
    digits = (args.width + 3) // 4
    output_path = args.output.resolve()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        "".join(f"{word:0{digits}X}\n" for word in words),
        encoding="ascii",
    )

    print(f"Wrote {len(words)} {args.width}-bit words to {output_path}")


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""Convert a flat little-endian RV32 binary to one 32-bit word per line."""

from pathlib import Path
import argparse


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("binary", type=Path)
    parser.add_argument("hexfile", type=Path)
    args = parser.parse_args()

    data = args.binary.read_bytes()
    data += bytes((-len(data)) % 4)
    words = [
        int.from_bytes(data[offset:offset + 4], "little")
        for offset in range(0, len(data), 4)
    ]
    args.hexfile.write_text(
        "".join(f"{word:08x}\n" for word in words),
        encoding="ascii",
    )


if __name__ == "__main__":
    main()


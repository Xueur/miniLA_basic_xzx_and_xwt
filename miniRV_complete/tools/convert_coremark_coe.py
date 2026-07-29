#!/usr/bin/env python3

from pathlib import Path
import re
import sys

from split_hex_banks import write_banks


def convert(source: Path, destination: Path) -> int:
    text = source.read_text(encoding="utf-8-sig")
    marker = re.search(
        r"memory_initialization_vector\s*=\s*",
        text,
        flags=re.IGNORECASE,
    )
    if marker is None:
        raise ValueError("missing memory_initialization_vector")

    body = text[marker.end():]
    words = re.findall(r"\b[0-9a-fA-F]{8}\b", body)
    if len(words) != 40960:
        raise ValueError(
            f"expected 40960 words, found {len(words)}"
        )

    destination.write_text(
        "".join(word.upper() + "\n" for word in words),
        encoding="ascii",
        newline="\n",
    )
    write_banks(
        [word.upper() for word in words],
        destination.parent,
        destination.stem,
    )
    return len(words)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    source = root / "software" / "coremark" / "coremark.coe"
    destination = root / "software" / "coremark" / "coremark.hex"
    count = convert(source, destination)
    print(f"Generated {destination} ({count} words, 160 KiB)")
    print("Generated coremark_bank0.hex through coremark_bank4.hex")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"CoreMark image conversion failed: {error}", file=sys.stderr)
        raise SystemExit(1)

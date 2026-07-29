#!/usr/bin/env python3

from pathlib import Path
import re
import sys


TOTAL_WORDS = 40960
BANK_WORDS = 8192
BANK_COUNT = 5


def read_hex_words(source: Path) -> list[str]:
    words = []
    for line_number, line in enumerate(
        source.read_text(encoding="ascii").splitlines(),
        start=1,
    ):
        word = line.strip()
        if not word:
            continue
        if re.fullmatch(r"[0-9a-fA-F]{8}", word) is None:
            raise ValueError(
                f"{source}:{line_number}: expected one 32-bit HEX word"
            )
        words.append(word.upper())
    if len(words) > TOTAL_WORDS:
        raise ValueError(
            f"{source} contains {len(words)} words; "
            f"160 KiB memory holds {TOTAL_WORDS}"
        )
    return words


def write_banks(words: list[str], directory: Path, stem: str) -> list[Path]:
    padded = words + ["00000000"] * (TOTAL_WORDS - len(words))
    paths = []
    for bank in range(BANK_COUNT):
        start = bank * BANK_WORDS
        path = directory / f"{stem}_bank{bank}.hex"
        path.write_text(
            "".join(word + "\n" for word in padded[start:start + BANK_WORDS]),
            encoding="ascii",
            newline="\n",
        )
        paths.append(path)
    return paths


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(
            "Usage: python tools/split_hex_banks.py "
            "<image.hex> [output_stem]",
            file=sys.stderr,
        )
        return 2
    source = Path(sys.argv[1]).expanduser().resolve()
    stem = sys.argv[2] if len(sys.argv) == 3 else source.stem
    words = read_hex_words(source)
    paths = write_banks(words, source.parent, stem)
    print(
        f"Split {source.name}: {len(words)} data words, "
        f"{BANK_COUNT} banks x {BANK_WORDS} words"
    )
    for path in paths:
        print(path)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"HEX bank split failed: {error}", file=sys.stderr)
        raise SystemExit(1)

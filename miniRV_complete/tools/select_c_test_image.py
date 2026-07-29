#!/usr/bin/env python3

from pathlib import Path
import re
import sys

from split_hex_banks import write_banks


TESTS = {
    "0": "0_uart_test",
    "1": "1_formatIO_test",
    "2": "2_sort_test",
    "3": "3_ddr_test",
    "4": "4_coremark",
}


def normalize_test(value: str) -> str:
    if value in TESTS:
        return TESTS[value]
    if value in TESTS.values():
        return value
    choices = ", ".join(f"{key}={name}" for key, name in TESTS.items())
    raise ValueError(f"unknown test '{value}'; choose {choices}")


def read_coe(source: Path) -> list[str]:
    text = source.read_text(encoding="utf-8-sig")
    marker = re.search(
        r"memory_initialization_vector\s*=\s*",
        text,
        flags=re.IGNORECASE,
    )
    if marker is None:
        raise ValueError(f"{source} has no memory_initialization_vector")
    words = re.findall(r"\b[0-9a-fA-F]{8}\b", text[marker.end():])
    if not words:
        raise ValueError(f"{source} contains no 32-bit words")
    if len(words) > 40960:
        raise ValueError(
            f"{source} contains {len(words)} words; 160 KiB memory holds 40960"
        )
    return [word.upper() for word in words]


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(
            "Usage: python tools/select_c_test_image.py "
            "<0|1|2|3|4> [path/to/main.coe]",
            file=sys.stderr,
        )
        return 2

    root = Path(__file__).resolve().parents[1]
    test_name = normalize_test(sys.argv[1])
    if len(sys.argv) == 3:
        source = Path(sys.argv[2]).expanduser().resolve()
    else:
        source = (
            root / "software" / "c_test_official" / test_name / "main.coe"
        )

    if not source.is_file():
        raise FileNotFoundError(
            f"missing {source}; compile {test_name} in the course VM first"
        )

    words = read_coe(source)
    padded_words = words + ["00000000"] * (40960 - len(words))
    active_dir = root / "software" / "active_test"
    image_path = active_dir / "active_test.hex"
    info_path = active_dir / "active_test.txt"
    image_path.write_text(
        "".join(word + "\n" for word in padded_words),
        encoding="ascii",
        newline="\n",
    )
    bank_paths = write_banks(padded_words, active_dir, "active_test")
    info_path.write_text(test_name + "\n", encoding="ascii", newline="\n")

    print(
        f"Selected {test_name}: {len(words)} program words, "
        f"padded to 40960 words"
    )
    print(f"Active image: {image_path}")
    print(
        "BRAM banks: "
        + ", ".join(path.name for path in bank_paths)
    )
    if test_name == "3_ddr_test":
        print(
            "WARNING: test 3 needs external DDR at 0x20000000; "
            "the supplied 160 KiB BRAM board top cannot pass that hardware test."
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"C_TEST image selection failed: {error}", file=sys.stderr)
        raise SystemExit(1)

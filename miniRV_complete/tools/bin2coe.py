import argparse
import hashlib
import struct
from pathlib import Path


def read_words(input_path):
    data = input_path.read_bytes()
    original_size = len(data)
    padding = (-original_size) % 4
    if padding:
        data += b"\x00" * padding
    words = [
        struct.unpack_from("<I", data, offset)[0]
        for offset in range(0, len(data), 4)
    ]
    return words, original_size, padding


def write_coe(output_path, words):
    lines = [
        "MEMORY_INITIALIZATION_RADIX=16;",
        "MEMORY_INITIALIZATION_VECTOR=",
    ]
    if words:
        lines.extend(
            f"{word:08X}{';' if index == len(words) - 1 else ','}"
            for index, word in enumerate(words)
        )
    else:
        lines.append("00000000;")
    output_path.write_text("\n".join(lines) + "\n", encoding="ascii")


def write_hex(output_path, words):
    output_path.write_text(
        "".join(f"{word:08X}\n" for word in words),
        encoding="ascii",
    )


def verify_outputs(coe_path, hex_path, words):
    hex_words = [
        int(line, 16)
        for line in hex_path.read_text(encoding="ascii").splitlines()
        if line.strip()
    ]
    if hex_words != words:
        raise RuntimeError("HEX 校验失败")

    coe_text = coe_path.read_text(encoding="ascii")
    if not coe_text.startswith("MEMORY_INITIALIZATION_RADIX=16;\n"):
        raise RuntimeError("COE 文件头校验失败")
    if not coe_text.rstrip().endswith(";"):
        raise RuntimeError("COE 结束符校验失败")


def convert(input_bin_path, output_base=None):
    input_path = Path(input_bin_path).resolve()
    if not input_path.is_file():
        raise FileNotFoundError(f"输入文件不存在：{input_path}")

    base_path = (
        Path(output_base).resolve()
        if output_base
        else input_path.with_suffix("")
    )
    base_path.parent.mkdir(parents=True, exist_ok=True)
    coe_path = base_path.with_suffix(".coe")
    hex_path = base_path.with_suffix(".hex")

    words, original_size, padding = read_words(input_path)
    write_coe(coe_path, words)
    write_hex(hex_path, words)
    verify_outputs(coe_path, hex_path, words)

    digest = hashlib.sha256(input_path.read_bytes()).hexdigest()
    print(f"输入：{input_path}")
    print(f"COE：{coe_path}")
    print(f"HEX：{hex_path}")
    print(f"原始大小：{original_size} 字节")
    print(f"32位字数：{len(words)}")
    print(f"补零字节：{padding}")
    print(f"SHA256：{digest}")
    print("转换及校验成功")


def main():
    parser = argparse.ArgumentParser(
        description="将小端 .bin 同时转换为 Vivado COE 和 readmemh HEX"
    )
    parser.add_argument("input_bin", help="输入的小端二进制文件")
    parser.add_argument(
        "-o",
        "--output-base",
        help="输出基础路径，不含 .coe/.hex；默认与输入文件同名",
    )
    args = parser.parse_args()

    try:
        convert(args.input_bin, args.output_base)
    except Exception as exc:
        print(f"转换失败：{exc}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()

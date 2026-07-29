#!/usr/bin/env bash
set -euo pipefail

if command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
    tool_prefix=riscv64-unknown-elf-
elif command -v riscv32-unknown-elf-gcc >/dev/null 2>&1; then
    tool_prefix=riscv32-unknown-elf-
else
    echo "需要先安装 RISC-V GNU Embedded Toolchain。" >&2
    exit 1
fi

"${tool_prefix}gcc" \
    -march=rv32im -mabi=ilp32 -mcmodel=medany \
    -Os -ffreestanding -fno-builtin -fno-stack-protector \
    -nostdlib -nostartfiles \
    -Wl,-T,link.ld -Wl,-Map,c_test.map \
    start.S c_test.c -o c_test.elf

"${tool_prefix}objcopy" -O binary c_test.elf c_test.bin
python3 bin_to_hex.py c_test.bin c_test.hex
"${tool_prefix}objdump" -d -S c_test.elf > c_test.dis

echo "已生成 c_test.elf、c_test.bin、c_test.hex、c_test.dis。"


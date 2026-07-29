#!/usr/bin/env python3

from pathlib import Path
import re
import sys


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


def main() -> int:
    root = Path(__file__).resolve().parents[1]

    hex_lines = read(
        root, "software/coremark/coremark.hex"
    ).splitlines()
    require(len(hex_lines) == 40960, "coremark.hex word count")
    require(
        all(re.fullmatch(r"[0-9A-Fa-f]{8}", line) for line in hex_lines),
        "coremark.hex format",
    )

    coe = read(root, "software/coremark/coremark.coe")
    marker = re.search(
        r"memory_initialization_vector\s*=\s*",
        coe,
        flags=re.IGNORECASE,
    )
    require(marker is not None, "coremark.coe header")
    coe_words = re.findall(r"\b[0-9A-Fa-f]{8}\b", coe[marker.end():])
    require(
        [word.upper() for word in coe_words]
        == [word.upper() for word in hex_lines],
        "COE/HEX mismatch",
    )

    bank_lines = []
    for bank in range(5):
        lines = read(
            root, f"software/coremark/coremark_bank{bank}.hex"
        ).splitlines()
        require(len(lines) == 8192, f"coremark bank {bank} word count")
        require(
            all(re.fullmatch(r"[0-9A-Fa-f]{8}", line) for line in lines),
            f"coremark bank {bank} format",
        )
        bank_lines.extend(lines)
    require(
        [word.upper() for word in bank_lines]
        == [word.upper() for word in hex_lines],
        "banked HEX/coremark.hex mismatch",
    )

    soc = read(root, "src/rtl/miniRV_SoC.v")
    for bank in range(5):
        require(
            f'parameter MEM_BANK{bank}_FILE = '
            f'"coremark_bank{bank}.hex"' in soc,
            f"default program bank {bank}",
        )
    require(
        re.search(r"\.RAM_WORDS\s*\(\s*40960\s*\)", soc) is not None,
        "main memory size",
    )

    ram = read(root, "src/rtl/axi_bram_slave.v")
    require(
        re.search(r"localparam\s+BANK_WORDS\s*=\s*8192", ram)
        is not None,
        "BRAM bank depth",
    )
    for bank in range(5):
        require(
            re.search(
                rf"mem{bank}\s*\[0:BANK_WORDS-1\]",
                ram,
            )
            is not None,
            f"BRAM bank {bank}",
        )

    cpu_core = read(root, "src/rtl/cpu_core.v")
    cpu_flat = re.sub(r"\s+", " ", cpu_core)
    require(
        "mem_is_load ? (mem_req_sent && daccess_rvalid)" in cpu_flat,
        "load response must be qualified by mem_req_sent",
    )
    require(
        "mem_is_store ? (mem_req_sent && daccess_wresp)" in cpu_flat,
        "store response must be qualified by mem_req_sent",
    )
    require(
        "mem_resp_active = daccess_rvalid || daccess_wresp" in cpu_flat,
        "residual memory response guard",
    )
    require(
        "!mem_resp_active ? mem_da_ren" in cpu_flat,
        "load request residual-response guard",
    )
    require(
        "!mem_resp_active ? mem_da_wen" in cpu_flat,
        "store request residual-response guard",
    )
    trace_cpu = read(root, "AXI_Trace_mySoC/cpu_core.v")
    require(trace_cpu == cpu_core, "AXI Trace cpu_core.v mismatch")

    cpu_top = read(root, "src/rtl/cpu_top.v")
    require(
        re.search(r"\.CLK_FREQ\s*\(\s*50000000\s*\)", cpu_top)
        is not None,
        "UART input clock",
    )

    io = read(root, "src/rtl/io_peripherals.v")
    require(
        re.search(
            r"\{28'h0,\s*tx_busy,\s*!tx_busy,\s*"
            r"rx_valid,\s*rx_valid\}",
            io,
        )
        is not None,
        "UART status bits",
    )

    core_portme = read(
        root,
        "software/coremark/course_source/src/coremark/core_portme.c",
    )
    require(
        re.search(r"#define\s+MHZ\s+50(?:\D|$)", core_portme) is not None,
        "CoreMark MHZ",
    )

    clock_ip = read(root, "src/rtl/ip/clk_wiz_0/clk_wiz_0.xci")
    require(
        '"CLKOUT1_REQUESTED_OUT_FREQ": '
        '[ { "value": "50"' in clock_ip,
        "Clocking Wizard frequency",
    )

    create_script = read(root, "create_coremark_board_project.tcl")
    for bank in range(5):
        require(
            f'MEM_BANK{bank}_FILE="coremark_bank{bank}.hex"'
            in create_script,
            f"Vivado bank {bank} generic",
        )
    require(
        "CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000}" in create_script,
        "Vivado clock configuration",
    )

    print("COREMARK PROJECT AUDIT PASSED")
    print("Image: 5 x 8192 words / 160 KiB")
    print("BRAM organization: 40 x RAMB36E1 expected")
    print("Clock: CPU=50 MHz, CoreMark MHZ=50, UART=50 MHz")
    print("UART: 115200, status bit3=busy, bit2=idle")
    print("Memory handshake: request-qualified response guard present")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"COREMARK PROJECT AUDIT FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)

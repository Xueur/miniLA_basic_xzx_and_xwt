# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**miniLA** is an educational LoongArch32 (LA32) CPU implemented in Verilog for Xilinx FPGA. The top-level module is `miniLA_SoC` targeting a board with switches, LEDs, 7-segment displays, and UART peripherals.

The repository contains **two independent CPU implementations**:

| Directory | Architecture | Status |
|-----------|-------------|--------|
| `miniLA_basic/` | Multi-cycle (non-pipelined) | Fully functional, all A+B group instructions |
| `miniLA_basic_pipeline/` | 5-stage pipeline with forwarding | Active development |

The `skills/` directory contains Vivado/Vitis HLS reference skills (synthesis, simulation, constraints, debug, Tcl) — useful for Vivado workflows but not part of the CPU RTL. `cdp-tests/` is a **git submodule** containing a Verilator-based test framework (see below).

## Build / Simulation

### Vivado (both implementations)

Open `miniLA_basic/miniLA.xpr` or `miniLA_basic_pipeline/miniLA_pipeline.xpr` in Vivado 2020.x+. From the Tcl console:

```tcl
# Regenerate BRAM IP from COE files, then synthesize + implement to bitstream
source miniLA_basic/update_coe.tcl
```

The testbench is `src/sim/soc_simple_tb.v` in each project. The test passes when the CPU executes instruction `0x2b0000` (halt marker). Run it from Vivado's simulation flow.

### Verilator (cdp-tests submodule)

The `cdp-tests/` submodule provides a Verilator-based test framework with a C golden model that verifies CPU execution trace-by-trace:

```bash
cd cdp-tests
make build          # Build Verilator model (links C golden model + Verilog RTL)
make run TEST=add   # Run a single instruction test (test names match asm/*.dump names)
make clean
```

Test binaries live in `cdp-tests/bin/` (pre-assembled `.bin` files). The golden model is in `cdp-tests/golden_model/` and compares architectural state (RF writes, memory accesses) against the RTL simulation. Add `ARCH_ON=1` to compare against an architectural reference rather than the C model.

The Verilator testbench uses `miniLA_basic/src/rtl/` as its RTL source (the multi-cycle version). Key Verilator options: `--trace` for waveform, `+define+PATH=<meminit.bin>` for memory initialization.

### CoreMark Benchmark

`c_test/4_coremark/` contains a bare-metal CoreMark setup for RISC-V/LA32 cores. Port it by modifying UART output (`sc_print.c`), linker script (`ram.lds`), startup code (`init_asm.S`), and timer functions (`core_portme.c`).

```bash
cd c_test/4_coremark
make ARCH=im ITERATIONS=300
```

## Architecture

### Module Hierarchy (miniLA_basic)

```
miniLA_SoC (clock PLL, reset sync, peripheral I/O, AXI bus)
 ├── cpu_top (CPU + tightly-coupled instruction/data memory)
 │    ├── cpu_core (datapath + multi-cycle control)
 │    ├── Inst_ROM (wraps BRAM IP, 1-cycle read)
 │    └── Data_RAM (wraps BRAM IP, 1-cycle R/W)
 ├── axi_bus (AXI4 bus controller, priority: DCache > ICache)
 ├── bram_axi (BRAM with AXI4 slave interface)
 ├── ICache / DCache (cache modules instantiated when `ENABLE_ICACHE`/`ENABLE_DCACHE` defined)
 └── clk_wiz_0 (Xilinx clock PLL IP)
```

### CPU Core (`cpu_core.v`) — Multi-Cycle Design

The CPU is **multi-cycle**, not pipelined. Instructions flow through logical stages:

1. **IF (Instruction Fetch)**: `PC` + `NPC` generate next PC. Handshake: `ifetch_req` → `ifetch_valid`/`ifetch_inst`.
2. **ID (Instruction Decode)**: `Controller` decodes `inst[31:15]` into all control signals. `RF` (32×32-bit, r0 hardwired to 0) provides operands. `EXT` sign/zero-extends immediates.
3. **EX (Execute)**: `ALU` performs arithmetic/logic/branch. Multiplier and divider are instantiated as **stubs** (`multiplier.v`, `divider.v`) — mul/div instructions currently use Verilog combinational operators (`*`, `/`, `%`) directly in ALU.v.
4. **MEM (Memory Access)**: `MREQ` translates load/store control into byte-enable signals. `MEXT` aligns and extends returned data. Multi-cycle: load/store set `ld_st_flag` until `daccess_rvalid`/`daccess_wresp`.
5. **WB (Write Back)**: Multiplexed writeback (ALU result, memory data, PC+4, or extended immediate) into `RF`.

**Multi-cycle control**: Single-cycle instructions (ALU, branches) complete when `ifetch_valid` asserts. Multi-cycle instructions (load/store, mul/div) use flags (`ld_st_flag`, `mul_div_flag`) to stall PC until `inst_finished` asserts. Writeback during multi-cycle wait uses a **delayed register index** (`rf_wR_r`) to preserve the destination register number.

The mul/div multi-cycle framework is **wired but dormant**: `is_mul` and `is_div` are hardwired to `1'b0` because ALU.v handles mul/div combinationally. When `multiplier.v`/`divider.v` are implemented with proper `start`/`busy` handshakes, wire the `is_mul`/`is_div` signals to the corresponding Controller outputs and the multi-cycle mechanism activates automatically.

### Pipeline CPU (`miniLA_basic_pipeline/`) — Key Differences

The pipeline version uses a **valid-bit flow control** model instead of global stall:

- **No feedback loops** — avoids the deadlock that plagued earlier pipeline attempts
- **Pulse-based ifetch**: `ifetch_req` is a single-cycle pulse, not a level. `fetch_outstanding` tracks in-flight requests independently.
- **Fetch buffer** (`fetch_buf`) decouples instruction fetch from decode
- **Pipeline registers**: IF/ID → ID/EX → EX/MEM → MEM/WB with valid bits at each stage
- **Forwarding**: EX/MEM → EX (priority) and MEM/WB → EX, plus WB → ID combinational bypass for same-cycle RF write read-after-write hazard
- **Load-use stall**: Detects when EX stage is a load and ID stage needs its result — inserts 1-cycle NOP bubble
- **Branch misprediction flush**: Branches resolve in EX; flushes IF/ID and injects NOP into ID/EX. Mispredict penalty = 2 cycles.
- **`front_stop`** blocks only the front-end (IF/ID consumption), while ID/EX holds during memory/mul-div waits

See [`miniLA_basic_pipeline/多周期CPU架构说明.md`](miniLA_basic_pipeline/多周期CPU架构说明.md) for the full pipeline architecture document.

### Control Signals (`defines.vh`)

All control signal encodings are defined in `src/rtl/defines.vh` as `` `define`` macros. This is the single source of truth for both implementations:

- **NPC operations**: `NPC_PC4`(2'b00), `NPC_JR`(2'b01), `NPC_BRCH`(2'b10), `NPC_JMP`(2'b11)
- **Extension types**: `EXT_5`, `EXT_12`, `EXT_12U`, `EXT_16`, `EXT_20`, `EXT_26`
- **ALU operations**: `ALU_ADD`(0x00) through `ALU_MODU`(0x17) — 24 operations covering arithmetic, logic, shifts, comparisons, branches, mul/div
- **Memory access**: `RAM_EXT_*` (load extension types), `RAM_WE_*` (store byte-enable patterns)
- **Writeback sources**: `WB_PC4`(2'b00), `WB_RAM`(2'b01), `WB_EXT`(2'b10), `WB_ALU`(2'b11)
- **Address space**: `MEM_BLOCK_MEMORY`(0x00000000), `MEM_DDR3`(0x20000000), `PERI_ADDR_*`
- **Cache config**: `ENABLE_ICACHE`, `ENABLE_DCACHE`, `IC_BLK_LEN`, `DC_BLK_LEN`

### Controller (`Controller.v`)

Combinational decoder: matches `inst[31:15]` against LoongArch opcode patterns and groups instructions to share control signals. The key design pattern is **instruction grouping** — instructions with identical control signal requirements share the same group (`IS_3R`, `IS_BRCH`, `IS_LOAD`, `IS_STORE`, `IS_JUMP`, `IS_2RI5`), so adding a new instruction often just means adding its decode wire to the right group.

### Address Space

| Region | Base Address | Size |
|--------|-------------|------|
| Block Memory (BRAM) | `0x0000_0000` | 512 KB |
| DDR3 | `0x2000_0000` | 512 MB |
| Switch peripheral | `0xFFFF_0000` | — |
| LED peripheral | `0xFFFF_1000` | — |
| Digital LED | `0xFFFF_2000` | — |
| UART | `0xFFFF_3000` | — |
| Timer | `0xFFFF_4000` | — |

### Unfinished Components

- **`multiplier.v`** — Module shell exists (parameterized, `start`/`busy` handshake), body is empty. Mul/div currently work via combinational Verilog operators in ALU.v; the stubs exist for a future proper sequential implementation.
- **`divider.v`** — Same status as multiplier.
- **Cache integration** — `ICache.v` and `DCache.v` modules exist but cache coherence and full AXI integration are not yet complete.

## File Map (miniLA_basic/src/rtl/)

| File | Role |
|------|------|
| `cpu_core.v` | Main datapath, integrates all submodules, multi-cycle control |
| `Controller.v` | Instruction decoder (combinational), groups → control signals |
| `defines.vh` | All `` `define`` macros for control signal encodings |
| `ALU.v` | Arithmetic/logic/branch unit, combinational mul/div, instantiates mul/div stubs |
| `RF.v` | 32×32-bit register file (r0 hardwired to 0) |
| `NPC.v` | Next-PC generation (PC+4, branch, jump, JR) |
| `PC.v` | Program counter register |
| `EXT.v` | Immediate extension (5/12/16/20/26-bit variants, signed and unsigned) |
| `MREQ.v` | Memory request: generates byte-enable signals for load/store |
| `MEXT.v` | Memory extension: aligns and sign/zero-extends load data |
| `Inst_ROM.v` | Instruction memory wrapper (BRAM IP) |
| `Data_RAM.v` | Data memory wrapper (BRAM IP) |
| `axi_bus.v` | AXI4 bus controller with read/write state machines, ICache/DCache arbitration |
| `bram_axi.v` | BRAM with AXI4 slave interface (Xilinx IP wrapper) |
| `ICache.v` | Instruction cache module |
| `DCache.v` | Data cache module |
| `miniLA_SoC.v` | Top-level SoC (clock PLL, reset sync, peripheral ports, AXI interconnect) |
| `cpu_top.v` | CPU + IROM + DRAM instantiation |
| `multiplier.v` | Stub — sequential multiplier with `start`/`busy` handshake |
| `divider.v` | Stub — sequential divider with `start`/`busy` handshake |

## Reference Documentation

- [`miniLA_basic_数据通路与控制信号_完整版.md`](miniLA_basic_数据通路与控制信号_完整版.md) — Complete datapath and control signal table for every implemented instruction
- [`B组指令实现详解.md`](B组指令实现详解.md) — Detailed walkthrough of all 18 B-group instructions with dataflow diagrams, Controller/ALU changes, and common Q&A
- [`miniLA_basic_pipeline/多周期CPU架构说明.md`](miniLA_basic_pipeline/多周期CPU架构说明.md) — Pipeline CPU architecture: forwarding, hazard handling, flow control, and differences from the reference RV core

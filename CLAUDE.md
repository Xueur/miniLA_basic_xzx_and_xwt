# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**miniLA** is a minimal LoongArch32 (LA32) CPU implemented in Verilog, built as a Vivado FPGA project. It implements a multi-cycle microarchitecture executing a subset of the LA32 instruction set. This is an educational CPU design project — the top-level module is `miniLA_SoC` targeting a Xilinx FPGA board with switches, LEDs, 7-segment displays, and UART peripherals.

The `skills/` directory contains bundled Vivado/Vitis HLS synthesis examples and is **not** part of the CPU design — it's reference material. The actual project lives entirely within `miniLA_basic/`.

## Build / Simulation

Open `miniLA_basic/miniLA.xpr` in Xilinx Vivado (2020.x or later). From the Tcl console:

```tcl
# Update IROM/DRAM COE files and re-generate IP, then run synthesis + implementation to bitstream
source miniLA_basic/update_coe.tcl
```

The testbench is `miniLA_basic/src/sim/soc_simple_tb.v`. Run it from Vivado's simulation flow. It passes when the CPU executes instruction `0x2b0000` (a specific NOP/halt marker).

For Verilator linting (the `/* verilator public */` markers in `cpu_core.v` suggest Verilator is used for simulation outside Vivado as well).

## Architecture

### Module Hierarchy

```
miniLA_SoC (top-level SoC with clock PLL, reset logic, peripheral I/O)
 └── cpu_top (CPU + tightly-coupled instruction/data memory)
      ├── cpu_core (the actual CPU datapath + control)
      ├── Inst_ROM (instruction memory, wraps a BRAM IP)
      └── Data_RAM (data memory, wraps a BRAM IP)
```

### CPU Core (`cpu_core.v`) — The Central Module

The CPU is organized as a **multi-cycle** design (not pipelined). Instructions flow through logical stages:

1. **IF (Instruction Fetch)**: `PC` + `NPC` modules generate next PC and send request to `Inst_ROM`. The CPU uses a handshake: `ifetch_req` → `ifetch_valid`/`ifetch_inst`.
2. **ID (Instruction Decode)**: `Controller` decodes `inst[31:15]` into all control signals. `RF` (register file, 32×32-bit) provides operands. `EXT` sign/zero-extends immediates.
3. **EX (Execute)**: `ALU` performs arithmetic/logic/branch operations. Multiplier and divider are instantiated but **not yet implemented** (stubs marked `// TODO`).
4. **MEM (Memory Access)**: `MREQ` translates load/store control signals into byte-enable memory requests. `MEXT` aligns and extends returned data. Multi-cycle: load/store set `ld_st_flag` until `daccess_rvalid`/`daccess_wresp` asserts.
5. **WB (Write Back)**: Multiplexed writeback (ALU result, memory data, PC+4, or sign-extended immediate) into `RF`.

**Key design pattern**: Instructions that can complete in one cycle (ALU, branches) finish when `ifetch_valid` is asserted. Multi-cycle instructions (load/store, mul/div) use flags (`ld_st_flag`, `mul_div_flag`) to stall the PC until completion (`inst_finished` signal).

### Control Signals (`defines.vh`)

All control signal encodings are defined as macros in [`miniLA_basic/src/rtl/defines.vh`](miniLA_basic/src/rtl/defines.vh). This is the single source of truth for:
- NPC operation types (`NPC_PC4`, `NPC_BRCH`, `NPC_JMP`, `NPC_JR`)
- Extension types (`EXT_5`, `EXT_12`, `EXT_16`, `EXT_20`, `EXT_26`, etc.)
- ALU operations (`ALU_ADD` through `ALU_BGEU`)
- Memory access types (`RAM_EXT_*`, `RAM_WE_*`)
- Writeback sources (`WB_PC4`, `WB_RAM`, `WB_EXT`, `WB_ALU`)
- Address space map (`MEM_BLOCK_MEMORY`, `MEM_DDR3`, `PERI_ADDR_*`)
- Cache configuration (`ENABLE_ICACHE`/`ENABLE_DCACHE` — not yet implemented)

### Controller (`Controller.v`)

Combinational decoder: matches `inst[31:15]` against LoongArch opcode patterns and produces control signal groups. Instructions are organized by format:
- **3R-type** (register-register-register): `sll.w`, `srl.w`, `sra.w`, `add.w`, `sub.w`, `and`, `or`, `xor`, `slt`, `sltu`, `mul.w`, `div.w`, etc.
- **2RI5/2RI12-type** (register-immediate): `srli.w`, `srai.w`, `xori`, `andi`, `slti`, `sltui`, `ld.*`, `st.*`
- **1RI20-type**: `lu12i.w`, `pcaddu12i`
- **2RI16-type** (branches): `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `jirl`
- **I26-type** (jumps): `b`, `bl`

### Unfinished Components (marked `// TODO`)

- **`multiplier.v`** — module shell exists (parameterized, with `start`/`busy` handshake), body is empty
- **`divider.v`** — module shell exists, body is empty
- **B-group instructions** — many ALU ops and instruction decodes are wired to `1'b0` in `Controller.v` (e.g., `AND`, `SLT`, `SLTU`, `BLT`, `BGE`, `BLTU`, `BGEU` are reserved for student implementation)
- **Cache** — `ENABLE_ICACHE`/`ENABLE_DCACHE` defines exist but no cache modules are instantiated

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

### Reference Documentation

- [`miniLA_basic_数据通路与控制信号_完整版.md`](miniLA_basic_数据通路与控制信号_完整版.md) — Complete datapath and control signal table in Chinese, covering all implemented and planned instructions with their control signal values
- [`miniLA_单周期CPU数据通路图.html`](miniLA_单周期CPU数据通路图.html) — Visual datapath diagram of the single-cycle CPU

## File Map

| File | Role |
|------|------|
| `cpu_core.v` | Main datapath, integrates all submodules, handles multi-cycle control |
| `Controller.v` | Instruction decoder (combinational) |
| `defines.vh` | All `\`define` macros for control signal encodings |
| `ALU.v` | Arithmetic/logic/branch unit, instantiates mul/div stubs |
| `RF.v` | 32×32-bit register file (r0 hardwired to 0) |
| `NPC.v` | Next-PC generation (PC+4, branch, jump, JR) |
| `PC.v` | Program counter register |
| `EXT.v` | Immediate extension (5/12/16/20/26-bit variants) |
| `MREQ.v` | Memory request: generates byte-enable signals for load/store |
| `MEXT.v` | Memory extension: aligns and sign/zero-extends load data |
| `Inst_ROM.v` | Instruction memory wrapper (BRAM IP with 1-cycle read latency) |
| `Data_RAM.v` | Data memory wrapper (BRAM IP with 1-cycle read/write latency) |
| `miniLA_SoC.v` | Top-level SoC (clock PLL, reset sync, peripheral ports) |
| `cpu_top.v` | CPU + IROM + DRAM instantiation |
| `multiplier.v` | Stub — sequential multiplier (to be implemented) |
| `divider.v` | Stub — sequential divider (to be implemented) |

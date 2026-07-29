# miniRV 五级流水线 SoC：C_TEST 0～4 / CoreMark 50 MHz v8

这是从已经通过 `25000025` 下板和 50 MHz Post-Implementation 时序检查的
v4 工程派生出的独立 C_TEST/CoreMark 版本。v8 同时包含两项修复：

- v7 的 5 Bank 主存结构，避免 Vivado 把 160 KiB 向上推断为 256 KiB；
- v8 的访存响应限定，避免前一笔响应被后一条访存误认而丢失写入。

默认程序映像为 `software/coremark/coremark.hex`，实际综合使用 5 个
8192 字的初始化 Bank。

第一次使用请阅读：

```text
v8_最终修复_先看.md
CoreMark_先看.md
```

最简单的构建方式是双击：

```text
build_CoreMark_50MHz_bitstream_and_reports.bat
```

脚本会自动生成并打开：

```text
vivado_coremark_board_50MHz\miniRV_coremark_board_50MHz.xpr
```

只有 50 MHz 的 setup、hold 均无时序违例时，才会生成：

```text
output\miniRV_coremark_board_50MHz.bit
reports\coremark_board_50MHz\timing_summary_PASS.rpt
reports\coremark_board_50MHz\utilization_PASS.rpt
reports\coremark_board_50MHz\power_PASS.rpt
reports\coremark_board_50MHz\drc_PASS.rpt
```

## 设计内容

- IF、ID、EX、MEM、WB 五级流水线；
- 44 条 miniRV/RV32IM 指令；
- load-use 暂停、EX/MEM 与 MEM/WB 前递、分支错误路径冲刷；
- 1 KiB ICache、1 KiB DCache，16 Byte Cache Line；
- AXI4 主控状态机，缺失读取采用 4 拍 INCR 突发；
- AXI BRAM 主存：`5 × 8192 × 32 bit = 160 KiB`；
- 拨码、LED、八位数码管、UART、64 位计时器；
- EGO1 `XC7A35TCSG324-1` 引脚与 50 MHz Clocking Wizard；
- CoreMark 课程源码、原始 COE、已转换 HEX；
- 独立 CoreMark 启动/UART 与算法 CRC 仿真。

## 频率与串口

```text
SoC clock: 50.000 MHz
CoreMark MHZ: 50
UART input clock: 50 MHz
UART: 115200-8-N-1
```

UART 状态寄存器使用课程定义：

| 位 | 含义 |
|---|---|
| bit3 | TX busy/full |
| bit2 | TX idle/empty |
| bit1 | RX full |
| bit0 | RX valid/non-empty |

CoreMark 结果只看 UART，不看数码管。

## 已完成的本地 RTL 验证

```text
PIPELINE CPU: ALL 44 miniRV INSTRUCTIONS PASSED
HAZARD TEST PASSED: load-use + forwarding + flush
MEM RESPONSE HAZARD TEST PASSED: no stale response reuse
TRACE BOARD TEST PASSED: display = 0x25000025
C_TEST: SWITCH + LED + DIG + UART TX/RX + TIMER PASSED
BANKED BRAM AXI TEST PASSED: 10 checks across all 5 banks
COREMARK CRC TEST PASSED: e714 / 1fd7 / 8e3a
```

Xilinx 7 系列映射确认主存使用 40 个 `RAMB36E1`。CRC 仿真把迭代数
缩到 1，只用于快速验证三类算法的计算正确性；开发板会自动标定迭代数并
运行至少 10 秒。最终跑分和 Vivado Post-Implementation WNS/WHS 必须在
EGO1 与 Vivado 2023.2 上取得。

## 主要目录

```text
src\rtl                         CPU、Cache、AXI、主存、外设
src\sim\coremark_boot_tb.v      CoreMark 启动与 UART 仿真
src\sim\coremark_crc_tb.v       CoreMark 三项算法 CRC 仿真
src\sim\mem_response_hazard_tb.v 背靠背访存响应专项回归
software\coremark\coremark.hex  默认 160 KiB 程序映像
software\coremark\coremark_bank0.hex ... bank4.hex
software\coremark\course_source 课程 CoreMark 源码
AXI_Trace_mySoC                 课程 AXI Trace 提交目录
```

构建脚本会在实现前读取真实综合结果；如果超过器件的 50 个 RAMB36
容量，会直接停止并报告数量。原 Trace v4 工程和比特流请继续单独保留：
老师检查 Trace 时使用原版，检查 C_TEST/CoreMark 时使用本工程。

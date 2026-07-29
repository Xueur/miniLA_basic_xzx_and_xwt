# CoreMark 50 MHz 下板使用说明

这是从已经通过 `25000025` 下板、50 MHz Post-Implementation 时序检查的
v4 五级流水线 SoC 派生出的独立 CoreMark 工程。它不会覆盖原 Trace 工程。

## 已经配置好的内容

- 五级流水线 SoC 实际时钟：`50.000 MHz`
- CoreMark：`#define MHZ 50`
- UART 输入时钟：`50000000 Hz`
- UART：`115200-8-N-1`
- 主存：`5 × 8192 × 32 bit = 160 KiB`
- 初始化映像：`software/coremark/coremark.hex`
- 综合初始化：`coremark_bank0.hex`～`coremark_bank4.hex`
- UART 状态位：bit3 为 TX busy，bit2 为 TX idle
- CoreMark 课程源码：`software/coremark/course_source`

课程提供的 `coremark.coe` 已转换为 40960 行纯 HEX，并自动拆成 5 个
8192 行 Bank；不能把 COE 直接改后缀当作 HEX 使用。

## 一键生成工程、比特流和报告

先把整个压缩包解压到英文、无空格的短路径，例如：

```text
D:\miniRV_CTEST_CoreMark_v8
```

然后进入 `miniRV_complete`，双击：

```text
build_CoreMark_50MHz_bitstream_and_reports.bat
```

脚本会自动：

1. 创建 CoreMark 专用 `.xpr`；
2. 检查 CPU/CoreMark/UART 是否都为 50 MHz；
3. 检查 CoreMark HEX 与 5 个 Bank 是否逐字一致；
4. 检查主存容量、Bank 结构和 UART 状态位；
5. 运行 Synthesis，并检查真实 RAMB36/RAMB18 用量不超器件容量；
6. 运行 Implementation 并尝试多种 Vivado 性能策略；
7. 仅在 setup、hold 均无违例时生成最终比特流和 PASS 报告。

成功标志：

```text
COREMARK BOARD 50 MHz BITSTREAM AND TIMING PASSED
Post-route setup WNS = 非负数
Post-route hold WHS = 非负数
```

生成的工程与文件：

```text
vivado_coremark_board_50MHz\miniRV_coremark_board_50MHz.xpr
output\miniRV_coremark_board_50MHz.bit
reports\coremark_board_50MHz\timing_summary_PASS.rpt
reports\coremark_board_50MHz\utilization_PASS.rpt
reports\coremark_board_50MHz\power_PASS.rpt
reports\coremark_board_50MHz\drc_PASS.rpt
```

若只想先创建并打开 `.xpr`，双击：

```text
create_and_open_CoreMark_50MHz_project.bat
```

## 可选的启动与CRC仿真

工程打开后，在 Vivado Tcl Console 执行：

```tcl
source run_coremark_boot_tb.tcl
```

成功时输出：

```text
CoreMark 1.0
COREMARK BOOT/UART TEST PASSED
```

这个仿真只验证映像启动、Cache/AXI 取指访存和 UART 首行输出，不等待 700 次
CoreMark 完整运行。完整跑分以下板串口为准。

若要验证 CoreMark 三项算法的最终 CRC，在 Vivado Tcl Console 执行：

```tcl
source run_coremark_crc_tb.tcl
```

成功标志：

```text
COREMARK CRC TEST PASSED: e714 / 1fd7 / 8e3a
```

CRC 仿真把迭代数缩到 1，因此程序会同时提示运行时间不足 10 秒；这个提示
不代表 CRC 失败。开发板不会缩短迭代数，最终必须看到
`Correct operation validated.`。

访存握手专项回归可执行：

```tcl
source run_mem_response_hazard_tb.tcl
```

成功标志：

```text
MEM RESPONSE HAZARD TEST PASSED: no stale response reuse
```

## 下板步骤

1. 先打开串口工具，选择开发板对应 COM 口。
2. 设置 `115200`、8 数据位、1 停止位、无校验、无流控。
3. 在 Hardware Manager 下载：

   ```text
   output\miniRV_coremark_board_50MHz.bit
   ```

4. 下载完成后按下 S6，再松开。
5. 等待串口输出。开头约有 100 ms 软件延时；完整运行可能需要几十秒或更久。

应看到类似：

```text
CoreMark 1.0
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : ...
Total time (secs): ...
Iterations/Sec   : ...
Correct operation validated.
CoreMark 1.0 : ...
CoreMark/MHz : ...
FINISH
```

验收重点是：

```text
Correct operation validated.
FINISH
```

同时保存完整串口结果截图，以及 Project Summary 的 Post-Implementation
Timing、Utilization、Power 截图。Timing 至少满足：

```text
WNS >= 0
TNS = 0
Failing Endpoints = 0
WHS >= 0
THS = 0
```

## 注意

- CoreMark 结果看串口，不看数码管。
- 不要把这个工程的初始化文件改回 `start.hex` 后再称为 CoreMark 结果。
- 原来的 Trace v4 工程和 `25000025` 比特流继续保留，老师检查 Trace 时使用
  原版；检查 CoreMark 时使用本包。
- 若构建失败，把 `vivado.log` 和
  `reports\coremark_board_50MHz` 文件夹发回。

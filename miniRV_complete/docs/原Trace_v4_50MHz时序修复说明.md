# 50 MHz 流水线 SoC 时序修复版

本工程保持五级流水线 SoC 的实际时钟为 50 MHz，满足课程“流水线 SoC
频率不低于 50 MHz”的要求。不要使用之前的 25 MHz 工程提交。

## 已修复内容

1. ICache、DCache 的 1 KiB 数据阵列与标签阵列改为 Vivado 可识别的分布式
   RAM 模板，避免展开成上万位普通寄存器及大扇出写使能网络。
2. EGO1 的外部低有效复位和 Clocking Wizard `locked` 信号采用异步置位、
   50 MHz 时钟域两级同步释放，避免复位跨时钟域造成恢复/移除时序风险。
3. 保留此前的 128 KiB BRAM 推断修复、八位数码管两组段线修复、
   `start.hex` 初始化、I/D Cache、AXI 状态机、五类外设和五级流水线。
4. 构建脚本会核对 Clocking Wizard 为 50 MHz、UART/外设参数为
   `50000000`；若加入了 `core_portme.c`，还会核对 CoreMark 的 `MHZ` 为
   `50`。
5. 实现阶段会依次尝试 Vivado 的多种性能策略。只有满足 setup 与 hold
   slack 均不为负时，才会生成带 `PASS` 名称的报告和最终比特流。

## 最简单的使用方法

先将整个压缩包解压到纯英文、无空格的短路径，例如：

```text
D:\miniRV_50MHz_v4
```

不要在压缩包内部直接运行，也不要覆盖旧的 25 MHz 或 50 MHz 工程。

### 只创建并打开工程

双击：

```text
create_and_open_50MHz_project.bat
```

生成的可直接打开工程为：

```text
vivado_trace_board_50MHz\miniRV_trace_board_50MHz.xpr
```

### 自动综合、实现、检查时序并生成比特流

关闭正在运行的仿真，然后双击：

```text
build_50MHz_bitstream_and_reports.bat
```

脚本可能运行较长时间。如果第一种实现策略没有通过，它会自动换策略，
不需要在 Tcl Console 手动输入命令。

成功标志：

```text
TRACE BOARD 50 MHz BITSTREAM AND TIMING PASSED
Post-route setup WNS = 非负数
Post-route hold WHS = 非负数
```

输出文件：

```text
output\miniRV_trace_board_50MHz.bit
reports\trace_board_50MHz\timing_summary_PASS.rpt
reports\trace_board_50MHz\utilization_PASS.rpt
reports\trace_board_50MHz\power_PASS.rpt
```

若窗口显示 `Build or timing validation failed`，不要提交旧的红色 Timing
截图。将整个 `reports\trace_board_50MHz` 文件夹发回即可继续针对真实最差
路径优化。

## 下板与截图

在 Hardware Manager 中只下载：

```text
output\miniRV_trace_board_50MHz.bit
```

配置后数码管会很快显示：

```text
25000025
```

按住 S6 时显示全零，松开后重新显示 `25000025`。

打开生成的 `.xpr`，确认 Implementation 已完成，然后进入 Project Summary，
分别打开 Timing、Utilization、Power 的 Post-Implementation 页面截图。
Timing 至少应满足：

```text
WNS >= 0
TNS = 0
Failing Endpoints = 0
```

## 关于 CoreMark 和 UART 频率

本版没有提高到 50 MHz 以上，所以参数保持：

```c
#define MHZ 50
```

UART/外设输入时钟保持：

```verilog
.CLK_FREQ (50000000)
```

以后如果把 CPU 时钟提升为 60 MHz、75 MHz 等，Clocking Wizard、
`core_portme.c` 的 `MHZ` 和 UART/外设的 `CLK_FREQ` 必须同步修改。

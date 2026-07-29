# miniRV Trace 下板调试

本目录使用课程 `cdp-tests` 的 `bin/start.bin`，在 EGO1
`XC7A35TCSG324-1` 上运行 37 个不含乘除法的 Trace 测试点。

## 预期结果

程序启动时向 `0xFFFF2000` 写入：

```text
0x25000000
```

高字节 `0x25` 表示共 37 个测试点。每通过一项，低字节加 1。全部通过后，
数码管应保持显示：

```text
0x25000025
```

若低字节停在 `n`，通常表示第 `n+1` 个测试点失败。此时使用
`software/trace/start.dump` 和失败 PC 定位具体指令。

## 目录中的程序文件

```text
software/trace/start.bin
software/trace/start.dump
software/trace/start.coe
software/trace/start.hex
```

`start.coe` 可用于课程原版 Block Memory Generator IP。当前完整工程使用
可综合的 `axi_bram_slave.v`，因此实际初始化文件是内容完全相同的
`start.hex`。

## 重新转换程序

Windows 双击或在命令行运行：

```bat
prepare_trace_image.bat
```

也可以直接运行：

```bat
py -3 bin2coe.py software\trace\start.bin
```

WSL/Linux：

```bash
./prepare_trace_image.sh
```

根目录 `bin2coe.py` 调用 `tools/bin2coe.py` 中的完整实现。脚本按小端顺序
把每 4 字节转换为一个 32 位字，同时生成合法 COE 和
readmemh HEX，并自动校验结果。只有文件长度不是 4 的倍数时才在尾部补零。

## 建立 Trace 下板工程

将完整目录放在不含中文和空格的 Windows 路径，例如：

```text
D:\miniRV_trace_board
```

无需手工输入 Tcl 命令。双击：

```text
create_and_open_50MHz_project.bat
```

脚本会生成并打开：

```text
vivado_trace_board_50MHz/miniRV_trace_board_50MHz.xpr
```

该工程明确把顶层参数设为：

```text
MEM_INIT_FILE="start.hex"
```

不会误用默认的 `c_test.hex`。

## 先做板级程序仿真

在新工程的 Tcl Console 中执行：

```tcl
source run_trace_board_tb.tcl
```

正确结果：

```text
TRACE BOARD TEST PASSED: display = 0x25000025
```

## 生成比特流

关闭仿真后，双击：

```text
build_50MHz_bitstream_and_reports.bat
```

成功后比特流位于：

```text
output/miniRV_trace_board_50MHz.bit
```

时序、资源、功耗和 DRC 报告位于：

```text
reports/trace_board_50MHz/
```

## 下载到 EGO1

1. 打开 Hardware Manager，连接 EGO1。
2. Program Device，选择 `output/miniRV_trace_board_50MHz.bit`。
3. S6 是低电平复位：按下 S6，保持约 1 秒后松开。
4. 观察 8 位数码管。程序会逐项增加，最终应显示
   `25000025`。

本 Trace 程序运行期间，拨码、LED 和 UART 不参与结果判断。

## 失败定位

若数码管停在某个低字节数值：

1. 在 WSL 的 `cdp-tests` 中执行：

   ```bash
   make run TEST=start
   ```

2. 查看第一个不匹配的 `debug_wb_pc`。
3. 在 `software/trace/start.dump` 中搜索 PC，例如：

   ```bash
   rg "18f8:" software/trace/start.dump
   ```

4. 根据该地址附近的指令检查流水线暂停、前递、冲刷、Cache 和 AXI。

如果虚拟机 AXI Trace 的 `start` 通过而真机失败，优先检查 BRAM 初始化文件、
S6 复位、Clocking Wizard 锁定和实现后的时序报告。

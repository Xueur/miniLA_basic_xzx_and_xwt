# CoreMark 程序映像

本目录已经包含课程 CoreMark 源码、原始 COE 和可直接初始化 Verilog BRAM
的 HEX：

```text
course_source\
coremark.coe
coremark.hex
coremark_bank0.hex ... coremark_bank4.hex
```

`coremark.hex` 有 40960 个 32 位字，共 160 KiB，由
`tools/convert_coremark_coe.py` 从 COE 严格转换生成。
Vivado 使用 5 个各含 8192 字的 Bank 文件，映射为 40 个
`RAMB36E1`，不会再把 40960 深度向上扩成 65536 深度。

当前配置：

```text
CPU clock = 50 MHz
core_portme.c: #define MHZ 50
UART clock = 50 MHz
UART baud = 115200
```

真实完整成绩必须来自开发板串口输出。

# C_TEST 0～4（学号 2024311373）

本工程基于已经通过 `25000025` 下板和 50 MHz 时序检查的五级流水线
SoC。v8 使用 5 个 32 KiB BRAM Bank，并修复背靠背访存响应误认问题，避免
Vivado 2023.2 将非二次幂深度向上扩成 256 KiB。老师提供的正式 C_TEST
已放在：

```text
software/c_test_official
```

测试0～2的全部 TODO 已补完；测试3和测试4原本没有 TODO；测试5
LLAMA2未包含。

## 直接运行 CoreMark

压缩包初始已经选中测试4。双击：

```text
build_C_TEST_50MHz_bitstream_and_reports.bat
```

成功后使用：

```text
output/miniRV_c_test_active_50MHz.bit
```

串口设置为 `115200-8-N-1`，下载后按 S6。重点确认串口出现：

```text
Correct operation validated.
FINISH
```

## 编译并切换测试0、1、2

把 `software/c_test_official` 拷入课程虚拟机，在该目录执行：

```sh
chmod +x compile_all_0_to_4.sh
./compile_all_0_to_4.sh
```

也可以只进入某个测试目录执行：

```sh
./compile.sh
```

编译后相应目录会生成 `main.s`、`main.coe`、`main.bin`。把带有这些
输出的目录拷回本工程，然后在 Windows 中双击并按提示输入编号：

```text
select_C_TEST_image.bat
```

也可以在命令行后附测试编号。例如：

```bat
select_C_TEST_image.bat 0
select_C_TEST_image.bat 1
select_C_TEST_image.bat 2
select_C_TEST_image.bat 4
```

选择器会同时生成 `active_test.hex` 和
`active_test_bank0.hex`～`active_test_bank4.hex`。选择后再次双击：

```text
build_C_TEST_50MHz_bitstream_and_reports.bat
```

构建脚本每次都会重跑综合和实现，因此不会继续使用上一个程序映像。

## 每项测试的观察结果

| 编号 | 程序 | 观察方式 |
|---|---|---|
| 0 | UART收发 | 串口输出、键盘输入；LED和数码管显示字符ASCII码 |
| 1 | printf/scanf | 串口输入整数、字符、字符串；LED显示正负，数码管显示绝对值 |
| 2 | 递归/排序/malloc | 串口输入数组并检查排序结果与计时 |
| 3 | DDR | LED显示阶段结果；要求外部DDR地址 `0x20000000` |
| 4 | CoreMark | 串口查看正确性、总时间和CoreMark/MHz |

## 测试3限制

测试3源码已按老师原文件保留并可编译，但当前板级顶层使用160 KiB片上
BRAM，没有连接外部DDR控制器。它不能真实通过测试3的
`0x20000000` DDR下板检查。不要把测试3“编译成功”写成“DDR下板通过”。

测试0、1、2和4使用当前工程的片上主存、UART和计时器；CPU、UART、
计时器以及CoreMark参数均为50 MHz。

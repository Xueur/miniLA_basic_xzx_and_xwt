# AXI Trace 运行说明

## 一、不要覆盖已经通过的 Basic Trace 目录

建议保留原来的 `~/cdp-tests`，另外复制一份：

```bash
cd ~
cp -a cdp-tests cdp-tests-axi
```

## 二、复制本包准备好的 AXI 版 mySoC

假设本工程解压在 `~/miniRV_lab2_official`：

```bash
cd ~/cdp-tests-axi
make clean
find mySoC -maxdepth 1 -type f -delete
cp ~/miniRV_lab2_official/AXI_Trace_mySoC/* mySoC/
```

`AXI_Trace_mySoC` 中没有 `bram_axi.v` 是正常的。课程框架会自动编译：

```text
cdp-tests-axi/vsrc/bram_axi.v
```

顶层 `miniRV_SoC.v` 已经在 `RUN_TRACE` 分支中实例化：

```verilog
bram_axi U_bram (...);
```

## 三、编译

```bash
cd ~/cdp-tests-axi
make clean
make
```

编译完成后检查固定层次头文件：

```bash
find obj_dir -maxdepth 1 \
  \( -name 'VminiRV_SoC_cpu_top.h' \
  -o -name 'VminiRV_SoC_cpu_core.h' \
  -o -name 'VminiRV_SoC_IROM.h' \) \
  -printf '%f\n' | sort
```

正确结果应包含：

```text
VminiRV_SoC_cpu_core.h
VminiRV_SoC_cpu_top.h
```

不应包含：

```text
VminiRV_SoC_IROM.h
```

课程当前 `miniRV` 分支中 `ARCH_ON = 0` 是正常值。它只影响 Golden Model
测试点输出格式，不是 AXI 开关，不需要修改官方 `Makefile`。

## 四、先跑单项，再跑全部

```bash
make run TEST=sltu
python3 run_all_tests.py | tee axi_trace_result.txt
```

本包回归结果：

```text
Passed Tests (45)
Failed Tests (0)
```

AXI 版总结标题为：

```text
==================== SUMMARY ====================
```

如果出现：

```text
SUMMARY (Basic Tests)
```

说明使用的仍是带 IROM 的 Basic 顶层，或者 `mySoC` 没有完整替换。

## 五、三个模式的复位和主存

| 模式 | 宏 | 复位 | 主存 |
| --- | --- | --- | --- |
| 官方 AXI Trace | `RUN_TRACE` | `fpga_rst` 高有效 | 官方 `bram_axi U_bram` |
| Vivado C_TEST | `SOC_SIM` | 板级 `fpga_rst` 低有效 | 工程 `axi_bram_slave` |
| 综合下板 | 无 | 板级 `fpga_rst` 低有效，经 PLL lock 释放 | 工程 `axi_bram_slave` |

不要在 Vivado 的综合 sources 中加入课程 `vsrc/bram_axi.v`；它仅由
`cdp-tests` 在 `RUN_TRACE` 时提供。

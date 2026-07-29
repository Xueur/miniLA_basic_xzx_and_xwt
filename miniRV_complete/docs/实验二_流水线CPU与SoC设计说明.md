# 实验二：流水线 CPU 与 SoC 设计说明

## 1. 总体结构

CPU 采用经典五级流水线：

1. IF：产生取指请求并接收 ICache 返回的指令；
2. ID：译码、立即数生成、寄存器读取和相关性检测；
3. EX：ALU/乘除法、前递选择、分支判定与目标地址计算；
4. MEM：Load/Store、DCache 和 I/O 访问；
5. WB：从 ALU、Load、PC+4 或立即数中选择写回数据。

各级之间设置 IF/ID、ID/EX、EX/MEM、MEM/WB 流水寄存器，并使用
`valid` 位区分有效指令和气泡。复位、冲刷和暂停都同时处理数据与 `valid`，
避免被冲刷指令产生寄存器或存储器副作用。

## 2. 控制冒险

采用静态“不跳转”预测，IF 默认请求 `PC+4`。分支、JAL 和 JALR 在 EX
级得到真实方向与目标地址。

- 预测正确：流水线继续；
- 需要跳转：清空 IF/ID 与 ID/EX，目标 PC 重新取指；
- ICache 缺失尚未返回：保存 `redirect_pending` 和目标地址；
- 旧路径响应晚到：丢弃旧指令，再发出目标请求。

JALR 目标地址强制清除最低位，满足 RISC-V 对齐要求。

## 3. 数据冒险

| 冒险 | 处理方法 |
|---|---|
| EX 使用上一条 ALU 结果 | EX/MEM→EX 前递 |
| EX 使用上上条结果 | MEM/WB→EX 前递 |
| Store 数据依赖前序指令 | Store-data 前递 |
| ID 读取与 WB 同周期写回 | WB→ID 旁路 |
| Load-use | ID/EX 插入一个气泡，前端保持 |
| Cache/AXI 未完成 | 保持 PC 与各级流水寄存器 |
| MUL/DIV 未完成 | EX 保持，完成后只推进一次 |

前递优先级为 EX/MEM 高于 MEM/WB。Load 数据在 MEM 级末尾才有效，因此
不能从 EX/MEM 直接前递，必须暂停到数据可用。

## 4. 乘除法

RV32M 使用迭代乘法器和除法器，运算期间 `busy=1`。ALU 在启动周期锁存
操作数与操作类型，流水线在 EX 级等待完成。

已处理的边界情况：

- DIV/DIVU 除数为零时返回 `0xFFFFFFFF`；
- REM/REMU 除数为零时返回被除数；
- 有符号除法商按符号恢复；
- 有符号余数符号与被除数一致。

## 5. Cache

ICache 与 DCache 均为 64 行直接映射 Cache：

- 容量：`64 × 16 B = 1 KiB`；
- Cache Line：4 个 32 位字；
- 索引：地址 `[9:4]`；
- 块内字选择：地址 `[3:2]`；
- 缺失时向 AXI 主控申请 128 位块。

DCache 使用写穿透策略。Store 直接写 AXI，并使对应缓存行失效；这种策略
实现简单、Trace 可见性好，也避免写回脏块的一致性复杂度。I/O 地址
`0xFFFFxxxx` 始终绕过 DCache。

## 6. AXI 主控

AXI 数据宽度为 32 位。读缺失使用 4 拍、每拍 4 Byte 的 INCR Burst：

```text
ARLEN=3, ARSIZE=2, ARBURST=INCR
```

写事务为单拍：

```text
AWLEN=0, AWSIZE=2, WLAST=1
```

AW 与 W 通道分别记录握手完成状态，二者都完成后进入 B 响应状态。请求仲裁
优先级为：

```text
DCache 写 > DCache 读 > ICache 读
```

这样可防止 Store 长时间占用流水线，同时保证数据访问优先于预取。

## 7. I/O 地址空间

| 地址 | 方向 | 功能 |
|---|---|---|
| `0xFFFF0000` | R | 16 位拨码开关 |
| `0xFFFF1000` | W | 16 位 LED |
| `0xFFFF2000` | W | 8 位数码管显示值 |
| `0xFFFF3000` | R | UART RX 数据 |
| `0xFFFF3004` | W | UART TX 数据 |
| `0xFFFF3008` | R | UART 状态，bit3 TX ready，bit0 RX valid |
| `0xFFFF300C` | W | UART 控制，bit1/bit0 复位 RX/TX |
| `0xFFFF4000` | R | 64 位计时器低 32 位 |
| `0xFFFF4008` | R | 64 位计时器高 32 位 |

LED、段选和位选均按 EGO1 的高电平有效方式实现。数码管高四位与低四位分别
驱动 `dig_seg1`、`dig_seg`。

## 8. Trace 信号

WB Trace：

- `debug_wb_valid`
- `debug_wb_pc`
- `debug_wb_rf_we`
- `debug_wb_rf_wR`
- `debug_wb_rf_wD`

MEM Trace：

- `debug_mem_pc`
- `debug_mem_we`
- `debug_mem_waddr`
- `debug_mem_wdata`

工程已固定为课程要求的
`miniRV_SoC → cpu_top U_cpu → cpu_core U_core`。`RUN_TRACE` 时，
`miniRV_SoC` 连接课程提供的 `bram_axi U_bram`；正常综合和 `SOC_SIM`
仍连接工程内 `axi_bram_slave`。两条路径不会同时进入同一次编译。

## 9. 时钟与资源策略

EGO1 的 P17 输入为 100 MHz。`clk_wiz_0` 输出 50 MHz，满足流水线 SoC
不低于 50 MHz 的要求。主存采用 128 KiB BRAM，给 CoreMark 和 C_TEST
保留空间，同时避免超过 XC7A35T 的 50 块 36Kb BRAM。

实现策略设置为：

- Synthesis：`Flow_PerfOptimized_high`
- Implementation：`Performance_Explore`

最终是否无时序违例必须以 Vivado Post-Route Timing Summary 为准。

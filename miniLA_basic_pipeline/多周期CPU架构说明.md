# miniLA 多周期 CPU 架构说明

## 为什么这次能跑通

### 旧版（流水线）的三个致命问题

#### 1. ifetch 协议死锁

旧版 `ifetch_req` 是电平信号，`stall` 反馈环路形成死锁：

```verilog
// 旧版 — 有 bug
assign ifetch_req = first_req | !stall;       // ifetch_req 依赖 stall
wire if_stall     = !ifetch_valid && !first_req; // stall 依赖 ifetch_valid
assign stall      = if_stall | mem_stall | mul_stall;

// Inst_ROM.v: inst_valid <= inst_rreq  (ifetch_valid = ifetch_req 延迟 1 拍)
```

死锁路径：
```
mem_stall=1 → stall=1 → ifetch_req=0 → (1拍后) ifetch_valid=0
→ if_stall=1 → 即使 mem_stall 解除，stall 仍=1 → ifetch_req 永远=0
```

#### 2. 访存请求电平持续

旧版 `daccess_ren = da_ren` 直接连线。访存期间 stall 保持 EX/MEM 不变 → `da_ren` 持续有效 → `daccess_rvalid` 返回后 `da_ren` 仍为高 → `Data_RAM` 的 `data_valid <= |data_ren` 持久为 1 → 无法区分"响应已消费"和"新响应到达"。

#### 3. Load-use 冒险未处理

旧版没有 load-use 停顿。Load 指令在 MEM 阶段才拿到数据，但下一条指令在 EX 阶段已经需要这个数据（前递逻辑无法覆盖 MEM→EX 的时序差）。

### 新版（对照 RV 核）的解决方案

#### 1. 脉冲协议取指

```verilog
// 新版 — 单拍脉冲，无反馈环
assign ifetch_req = !cpu_rst &&
    (issue_redirect || issue_pending_redirect || issue_sequential);

// 独立的请求追踪，不依赖 ifetch_valid 反馈
always @(posedge cpu_clk) begin
    if (ifetch_req)      fetch_outstanding <= 1'b1;
    else if (ifetch_valid) fetch_outstanding <= 1'b0;
end
```

- `ifetch_req` 只在需要取指时发**单拍脉冲**
- `fetch_outstanding` 追踪 in-flight 请求，防止重复发
- `req_pc_q` 记住请求的 PC，与延迟 1 拍返回的指令保持正确对齐
- `fetch_buf` 解耦取指和译码，前端阻塞时不丢失已取指令

#### 2. 访存请求单次脉冲

```verilog
// mem_req_sent 门控，请求只发一次
assign daccess_ren = mem_is_load  && !mem_req_sent ? mem_da_ren : 4'h0;
assign daccess_wen = mem_is_store && !mem_req_sent ? mem_da_wen : 4'h0;
```

- 访存请求发出后 `mem_req_sent <= 1`，请求立即清零
- 等待 `daccess_rvalid`/`daccess_wresp` 脉冲到达
- 不会产生持续的 `data_valid` 电平

#### 3. valid-bit 流控替代全局 stall

```verilog
// 新版 — 逐级控制，只有前端被阻塞
wire front_stop = mem_wait || mul_div_wait || load_use_stall || redirect_pending;
```

- `front_stop` 只阻塞 IF/ID 消费新指令
- ID/EX 在 `mem_wait`/`mul_div_wait` 时**保持**（不是清空）
- EX/MEM 在 `mem_wait` 时保持，等响应后流动
- MEM/WB 在 `mem_wait` 时清零（防止错误写回）
- **没有反馈环路**，不会死锁

---

## 冒险处理

### 1. 数据冒险 — 前递 (Forwarding)

```
  ID/EX        EX/MEM       MEM/WB
 [rs1,rs2]    [rd, data]   [rd, data]
     |            |            |
     +--- compare --+---- compare ---+
     |            |            |
     +<--- fwd ---+            |
     |                         |
     +<---------- fwd ---------+
```

```verilog
// EX/MEM 前递（优先级更高，更新的数据）
wire exmem_forward_valid = exmem_valid && exmem_rf_we &&
    exmem_rd != 5'h0 && exmem_rf_wsel != `WB_RAM;

// MEM/WB 前递
wire memwb_forward_valid = wb_rf_we;

// 前递选择
wire [31:0] ex_rs1_forward =
    exmem_forward_valid && exmem_rd == idex_rs1 ? exmem_forward_data :  // EX/MEM 优先
    memwb_forward_valid && memwb_rd == idex_rs1 ? memwb_data :          // 其次 MEM/WB
    idex_rs1_data;                                                      // 最后寄存器文件
```

- **EX/MEM 前递**：上一条指令的 ALU 结果，在 EX 阶段直通给下一条指令
- **MEM/WB 前递**：上上条指令的结果
- **排除 Load**：`exmem_rf_wsel != WB_RAM` — Load 的数据在 MEM 阶段才拿到，无法从 EX/MEM 前递（由 load-use 停顿处理）

### 2. 数据冒险 — Load-Use 停顿

Load 指令在 MEM 阶段才获取数据，下一条指令若在 EX 阶段就需要该数据，前递来不及。需要**停顿 1 拍**：

```verilog
wire load_use_stall = ifid_valid && idex_valid &&
    idex_rf_we && idex_rf_wsel == `WB_RAM &&     // EX 阶段是 load
    idex_rd != 5'h0 &&                             // 且写目标不是 r0
    ((id_rs1_used && id_rs1 == idex_rd) ||         // ID 阶段要用 rs1
     (id_rs2_used && id_rs2 == idex_rd));          // 或要用 rs2
```

检测条件：EX 阶段有 load 写 `rd`，且 ID 阶段指令的 `rs1` 或 `rs2` 正是 `rd`。

处理方式：在 ID/EX 插入 NOP 气泡（`idex_valid <= 0`），ID 阶段指令等待 1 拍。等 load 完成 MEM→WB 后，通过 MEM/WB 前递拿到数据。

### 3. 数据冒险 — WB→ID 直通旁路

同一周期内，WB 阶段写入寄存器的值，ID 阶段读不到（RF 是同步写）。需要组合逻辑直通：

```verilog
wire [31:0] id_rs1_data = wb_rf_we && wb_rd == id_rs1 ? wb_data : rf_rd1;
wire [31:0] id_rs2_data = wb_rf_we && wb_rd == id_rs2 ? wb_data : rf_rd2;
```

如果 ID 阶段读的寄存器正好是 WB 阶段正在写的寄存器（且 `r0` 始终为 0），直接用 WB 的 `wb_data`，不用寄存器文件的旧值。

**注意**：这是为了覆盖"前递网络中下下条指令"的情况。例如：
```
指令 A (load) → EX/MEM → MEM/WB → WB 写入
指令 B         → ID/EX  → EX/MEM → (load-use stall, 等 A 的 WB)
指令 C         → IF/ID  → ID/EX → (B 等的时候 C 也等)
```
当 A 在 WB 写回时，C 在 ID 读寄存器。RF 的同步写让 C 读不到刚写的值，WB→ID 直通解决。

### 4. 控制冒险 — 跳转冲刷

跳转/分支在 EX 阶段计算目标和条件：

```verilog
// 跳转条件
wire ex_redirect_raw = idex_valid &&
    (idex_npc_op == `NPC_JMP ||                          // B, BL
     idex_npc_op == `NPC_JR  ||                          // JIRL
     (idex_npc_op == `NPC_BRCH && alu_br));              // 条件分支且 taken

// 等待访存/乘除完成后才执行跳转
wire ex_redirect = ex_redirect_raw && !mem_wait && !mul_div_wait;
```

跳转生效时：
1. IF/ID 和 fetch_buf 被清空（`ifid_valid <= 0`, `ifid_inst <= NOP`）
2. ID/EX 插入 NOP 气泡（`idex_valid <= 0`）
3. `ifetch_req` 发出跳转目标的取指请求
4. 如果取指接口忙（`!fetch_can_replace`），跳转目标暂存到 `redirect_pending`

```
时序示意（分支在 EX）：
  Cycle N:   [IF]  [ID]  [EX: branch taken]  [MEM]  [WB]
  Cycle N+1: [IF: target] [ID: NOP] [EX: NOP] [MEM] [WB]
  Cycle N+2: [IF: target+4] [ID: target] [EX] [MEM] [WB]
```

**跳转延迟 = 2 拍**（EX 阶段才解析 + 取指 1 拍延迟），与经典 5 级流水线相同。

### 5. 结构冒险 — 乘除法多周期

乘除法需要多个周期，EX 阶段在此期间不能接受新指令：

```verilog
wire mul_div_wait = idex_valid && is_mul_div_ex &&
    (!idex_md_started || mul_div_busy);
```

- **第一拍**：`idex_md_started=0` → 强制等 1 拍（ALU 需要 1 拍启动乘除法器）
- **后续**：`idex_md_started=1` → 等 `mul_div_busy` 清零
- 等待期间，`front_stop=1` 阻塞前端，ID/EX 保持数据不变
- EX/MEM 清空（`exmem_valid <= 0`），防止无效数据下流

### 6. 结构冒险 — 取指/访存共享总线

当前设计中 IROM 和 DRAM 是独立的，不存在取指和访存的竞争。如果后续合并为统一总线，需要仲裁逻辑。

---

## 完整数据通路（改后）

```
                    ┌──────────────────────────────────────────────┐
                    │              前递网络                        │
                    │  EX/MEM → EX (优先)                          │
                    │  MEM/WB → EX                                 │
                    │  WB → ID (直通旁路)                           │
                    └──────────────────────────────────────────────┘

  fetch_buf       IF/ID          ID/EX           EX/MEM          MEM/WB
  ┌──────┐      ┌──────┐       ┌──────┐        ┌──────┐        ┌──────┐
  │ inst │ ───→ │ inst │ ───→  │ inst │  ───→  │ inst │  ───→  │ inst │
  │ pc   │      │ pc   │       │ pc   │        │ pc   │        │ pc   │
  │      │      │      │       │ pc4  │        │ alu  │        │ data │
  └──────┘      │      │       │ ext  │        │ fwd  │        │ rd   │
                │ DEC  │       │ rs1  │        │ rd   │        │ we   │
                │ EXT  │       │ rs2  │        │ ram  │        │      │
                │ RF   │       │ rd   │        │ we   │        └──────┘
                └──────┘       │ ctrl │        │      │           │
                               │      │        └──────┘           │
                  ALU ←────────┤ ALU  │          │               │
                  MREQ ←──────────────────────────┤ MREQ          │
                  MEXT ←──────────────────────────┤ MEXT          │
                                                  │               │
                                                  访存等待 ←──────┤
                                                  乘除等待 ←── ID/EX
                                                  Load-use ←── IF/ID
```

## 关键编码约定

| 宏 | 值 | 含义 |
|----|-----|------|
| `NPC_PC4` | 2'b00 | PC+4 |
| `NPC_JR` | 2'b01 | JIRL 寄存器间接跳转 |
| `NPC_BRCH` | 2'b10 | 条件分支 |
| `NPC_JMP` | 2'b11 | B/BL 直接跳转 |
| `WB_PC4` | 2'b00 | 写回 PC+4 (BL/JIRL 链接地址) |
| `WB_RAM` | 2'b01 | 写回内存数据 (load) |
| `WB_EXT` | 2'b10 | 写回立即数 (LU12I) |
| `WB_ALU` | 2'b11 | 写回 ALU 结果 |

## 与 RV 参考核的差异

| | RV 参考核 | miniLA 多周期核 |
|---|---|---|
| 指令集 | RV32I | LA32 |
| Controller | opcode/funct3/funct7 | inst[31:15] |
| 立即数扩展 | SEXT (RISC-V 格式) | EXT (LA32 格式) |
| 寄存器字段 | 固定位置 [19:15]/[24:20]/[11:7] | rs2 由 r2_sel 选择，rd 由 wr_sel 选择 |
| ALU | 有 md_start 显式启动 | 无 md_start，内部自动检测 op 变化 |
| NOP | 0x00000013 | 0x03400000 |
| NPC 宏 | NPC_JALR, NPC_BRA | NPC_JR, NPC_BRCH |

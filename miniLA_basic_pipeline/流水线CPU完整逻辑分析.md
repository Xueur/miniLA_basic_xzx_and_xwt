# miniLA 流水线 CPU 完整逻辑分析

## 一、总体架构

### 1.1 模块层次

```
miniLA_SoC (顶层: PLL时钟, 复位同步, BRAM初始化)
 ├── cpu_top (CPU + Cache + AXI总线)
 │    ├── cpu_core (5级流水线核心)
 │    │    ├── Controller (指令译码, 组合逻辑)
 │    │    ├── RF (寄存器文件, 32×32, r0=0)
 │    │    ├── EXT (立即数扩展)
 │    │    ├── ALU (运算单元, 含硬件乘除法器)
 │    │    │    ├── multiplier (Booth Radix-2, 32周期)
 │    │    │    └── divider (恢复余数法, 32周期)
 │    │    ├── MREQ (访存请求生成)
 │    │    └── MEXT (访存数据对齐/扩展)
 │    ├── ICache (指令Cache, 直连映射, 1KB)
 │    ├── DCache (数据Cache, 直连映射, 1KB, 写穿+写分配)
 │    └── axi_bus (AXI4总线控制器, DCache优先级 > ICache)
 └── bram_axi (BRAM AXI4从设备, 统一指令/数据存储)
```

### 1.2 与 miniLA_basic 的核心区别

| | miniLA_basic (多周期) | miniLA_basic_pipeline (流水线) |
|---|---|---|
| **执行模型** | 单条指令历经 IF→ID→EX→MEM→WB，全程占用 | 5级流水，每周期可发射1条指令 |
| **流控机制** | 全局 stall 标志位 (`ld_st_flag`, `mul_div_flag`) | valid-bit 逐级流控，无反馈环路 |
| **取指协议** | 电平: `ifetch_req` 持续有效直到 `ifetch_valid` | 脉冲: `ifetch_req` 单拍有效 |
| **乘除法** | ALU 内 Verilog 组合逻辑 (`*`, `/`, `%`) | 硬件 Booth乘法器 + 恢复余数除法器 |
| **存储层次** | Inst_ROM/Data_RAM 直连 BRAM | ICache/DCache → axi_bus → bram_axi |
| **冒险处理** | 无 (多周期天然无冒险) | 前递 + load-use停顿 + 分支冲刷 |
| **跳转延迟** | 0拍 (同一周期内完成) | 2拍 (EX解析 + 取指延迟) |

---

## 二、取指阶段 (Fetch Stage)

### 2.1 脉冲协议取指 — 核心创新

整个流水线最关键的机制：**取指请求是单拍脉冲，不是电平**。

```verilog
// cpu_core.v:298-303 — ifetch_req 仅在需要取指的周期为1
assign ifetch_req = !cpu_rst &&
    (issue_redirect ||          // 跳转目标取指
     issue_pending_redirect ||  // 之前挂起的跳转目标取指
     issue_sequential);         // 顺序取下一条
```

**为什么必须用脉冲？** 老版流水线用电平协议导致死锁：`mem_stall → stall → ifetch_req=0 → ifetch_valid=0 → if_stall=1 → stall永远为1`。脉冲协议切断了这个反馈环——`ifetch_req` 不依赖 `ifetch_valid`。

### 2.2 取指状态机

```
                    ┌──────────┐
         复位 ───→  │  IDLE    │
                    │  out=0   │
                    └────┬─────┘
                         │ issue_* 任一为真
                         ▼
                    ┌──────────┐
                    │  REQ     │  ifetch_req=1, 保存 req_pc_q, fetch_pc+=4
                    │  out=1   │  first_fetch_sent=1
                    └────┬─────┘
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
         ifetch_valid=1        ifetch_valid=0
         out=0                  out=1 (等待中)
```

关键寄存器：

| 寄存器 | 作用 |
|--------|------|
| `fetch_pc` | 下一条要请求的 PC（每次请求后 +4） |
| `req_pc_q` | 当前 in-flight 请求的 PC（用于指令返回时对齐） |
| `fetch_outstanding` | 是否有未完成的取指请求（防止重复发） |
| `first_fetch_sent` | 是否已发出首次取指 |
| `first_wb_done` | 第一条指令是否已完成 WB |

### 2.3 启动保护: block_until_wb

```verilog
// cpu_core.v:289-291
wire block_until_wb = first_fetch_sent && !first_wb_done;
```

**作用**: 第一条指令 WB 完成之前，只允许发**一次**取指请求。这是为了防止流水线在初始状态（寄存器文件全0、控制信号不确定）时大量取指导致错误。

`fetch_can_replace` 也受此影响：
```verilog
wire fetch_can_replace = first_wb_done
    ? (!fetch_outstanding || ifetch_valid)   // 正常模式: 流水取指
    : !fetch_outstanding;                     // 启动模式: 只允许1条in-flight
```

### 2.4 5个取指触发条件

```verilog
// 1. 跳转冲刷后取目标
wire issue_redirect = ex_redirect && fetch_can_replace;

// 2. 之前因取指接口忙而挂起的跳转, 现在接口空闲了
wire issue_pending_redirect = redirect_pending && fetch_can_replace;

// 3. 正常顺序取指 — 需同时满足: 无跳转、无挂起、前端不阻塞、
//    fetch_buf为空、取指接口可用、不在一级保护期
wire issue_sequential = !ex_redirect && !redirect_pending &&
    !front_stop && !fetch_buf_valid &&
    fetch_can_replace && !block_until_wb;
```

---

## 三、译码阶段 (ID Stage) — 组合逻辑

### 3.1 无 IF/ID 寄存器

这是一个重要的微架构选择：**ID 阶段是组合逻辑，直接从取指输出驱动，不经过寄存器**。

```verilog
// cpu_core.v:43-45
wire id_valid  = fetch_buf_valid || ifetch_valid;  // 优先消费缓存
wire [31:0] id_inst = fetch_buf_valid ? fetch_buf_inst : ifetch_inst;
wire [31:0] id_pc   = fetch_buf_valid ? fetch_buf_pc  : req_pc_q;
```

**优点**: 节省 1 拍延迟。指令取到后当拍就开始译码/读寄存器，下一拍直接进入 ID/EX。

**代价**: 组合逻辑路径变长（Inst_ROM → Controller → RF 读 → ID/EX 寄存器的 setup），可能影响时序收敛。

### 3.2 fetch_buf — 前端的弹性缓冲

当流水线后端阻塞时（`front_stop=1`），取到的指令不能直接消费（ID/EX 不进新数据），需要暂存：

```verilog
// cpu_core.v:355-361
if (front_stop) begin
    if (ifetch_valid && !fetch_buf_valid) begin
        fetch_buf_valid <= 1'b1;
        fetch_buf_pc    <= req_pc_q;
        fetch_buf_inst  <= ifetch_inst;
    end
end
```

**消费时机**: `front_stop` 解除且 `fetch_buf_valid=1` 时，下一拍自动消耗。

**冲刷**: 跳转发生时 `fetch_buf_valid <= 0`（之前取的指令作废）。

### 3.3 译码 → 控制信号

`Controller` 是纯组合逻辑，输入 `inst[31:15]`，输出所有控制信号。每条指令通过 opcode 匹配归类到指令组（`IS_3R`, `IS_BRCH`, `IS_LOAD`, `IS_STORE`, `IS_JUMP`, `IS_2RI5`），组内指令共享控制信号。

```verilog
wire IS_3R = SLL_W | SRL_W | ... | MUL_W | ... | DIV_W | ... | MOD_WU;
wire IS_BRCH = BEQ | BNE | BLT | BGE | BLTU | BGEU;
// ...
```

### 3.4 寄存器文件读 + WB→ID 旁路

RF 是**异步读、同步写**。但同一周期内 WB 阶段写入的值，异步读接口读不到（写发生在时钟沿）。所以需要组合逻辑直通：

```verilog
// cpu_core.v:153-154
wire id_rs1_data = wb_rf_we && wb_rd == id_rs1 ? wb_data : rf_rd1;
wire id_rs2_data = wb_rf_we && wb_rd == id_rs2 ? wb_data : rf_rd2;
```

**场景**: 指令 A 在 WB 写 r5，指令 C 在 ID 读 r5 → RF 内部还是旧值 → 旁路直接给 `wb_data`。

---

## 四、执行阶段 (EX Stage)

### 4.1 前递网络 (Forwarding)

```
   ID/EX                EX/MEM              MEM/WB
  [rs1,rs2,rd,rdata]  [rd, fwd_data]      [rd, wb_data]
       |                    |                    |
       +<── 优先前递 ──────+                    |
       |                                         |
       +<────────── 次优先前递 ──────────────────+
```

```verilog
// cpu_core.v:171-174, 176-183
// EX/MEM 前递优先 (更新的数据)
wire exmem_forward_valid = exmem_valid && exmem_rf_we &&
    exmem_rd != 5'h0 && exmem_rf_wsel != `WB_RAM;  // Load数据不在EX/MEM

wire [31:0] ex_rs1_forward =
    exmem_forward_valid && exmem_rd == idex_rs1 ? exmem_forward_data :   // 优先
    memwb_forward_valid && memwb_rd == idex_rs1 ? memwb_data :           // 其次
    idex_rs1_data;                                                       // 寄存器
```

**关键设计: 排除 Load 的 EX/MEM 前递**。Load 在 MEM 阶段才拿到数据，EX/MEM 寄存器里的 `forward_data` 不是 load 的正确结果（是 `alu_c` = 地址计算的结果，不是内存数据）。Load 的 `exmem_rf_wsel == WB_RAM`，被排除在前递之外 → 走 load-use 停顿。

### 4.2 ALU — 硬件乘除法器（脉冲启动）

与 basic 版最大的不同：乘除法有**真正的硬件模块**，且采用**单脉冲启动**机制。

核心设计来自参考 RV 核：`md_start` 是来自流水线的 1 拍脉冲（`mul_div_start = idex_valid && is_mul_div_ex && !idex_md_started`），仅在指令首次进入 ID/EX 时发出一次。ALU 内部锁存 operands，避免电平触发导致的重复启动。

```verilog
// ALU.v:18-22 — 脉冲转启动信号
wire start_mul  = md_start && ((op == `ALU_MUL) | (op == `ALU_MULH));
wire start_mulu = md_start && (op == `ALU_MULHU);
wire start_div  = md_start && ((op == `ALU_DIV) | (op == `ALU_MOD));
wire start_divu = md_start && ((op == `ALU_DIVU) | (op == `ALU_MODU));
```

**operands 锁存**: 乘除法期间 `a`/`b` 会随流水线变化（下一条指令进入 ID/EX），所以 `md_a`/`md_b`/`md_op` 在 `md_start` 脉冲时锁存：

```verilog
// ALU.v:48-57
if (md_start) begin
    md_a  <= a;    // 锁存被乘数/被除数
    md_b  <= b;    // 锁存乘数/除数
    md_op <= op;   // 锁存操作码
end
```

除法结果符号修正使用锁存的 `md_a[31]` 和 `md_b[31]`，不再需要单独的 `a31_latch`/`b31_latch`。

**输出 `c`**: 单周期指令直接用 `a`/`b` 组合逻辑；乘除法读硬件模块输出（`mul_res`、`div_quo_signed` 等）。由于 operands 已锁存，硬件模块在整个计算期间输入稳定。

**Booth Radix-2 乘法器** (`multiplier.v`): 同上，32 周期。

**恢复余数除法器** (`divider.v`): 同上，32 周期，除零返回 0。

**为什么用电平会出错**: 电平触发的 `mul_flag = (op == ALU_MUL)` 在每个周期都有效，必须用多层 gate（`started`、`md_started`、`busy_d1`）防重复启动。背靠背 mul 时，gate 清零的时序窗口恰好让 `mul_flag` 用旧 operands 重新触发——ALU 永远输出第一条 mul 的结果。改为脉冲后，`mul_div_start` 仅在新指令的 `idex_md_started==0` 那一拍有效，不存在竞态。

### 4.3 跳转处理

跳转目标计算在 EX 阶段：

```verilog
// cpu_core.v:210-212
wire [31:0] ex_target =
    idex_npc_op == `NPC_JR ? (alu_c & 32'hFFFF_FFFE) :  // JIRL: 寄存器值, 低2位清零
                             (idex_pc + idex_ext);        // B/BL/分支: PC+偏移
```

跳转触发条件：

```verilog
// cpu_core.v:214-217
wire ex_redirect_raw = idex_valid && (
    idex_npc_op == `NPC_JMP ||           // B, BL (无条件)
    idex_npc_op == `NPC_JR  ||           // JIRL (无条件)
    (idex_npc_op == `NPC_BRCH && alu_br) // 条件分支且 taken
);

// 实际跳转还需等访存/乘除完成
wire ex_redirect = ex_redirect_raw && !mem_wait && !mul_div_wait;
```

**为什么等 mem_wait?** 如果前一条指令是 store/load 且正在 MEM 阶段等待，跳转指令也在 EX 阶段等待（`front_stop` 让 ID/EX 保持），必须等前一条完成才能跳转，否则会丢失访存操作。

**跳转挂起机制**: 如果跳转时取指接口忙（`!fetch_can_replace`），目标地址暂存到 `redirect_pending`/`redirect_target`，等接口空闲后再发：

```verilog
if (ex_redirect) begin
    redirect_pending <= !fetch_can_replace;  // 不能立即取指 → 挂起
    redirect_target  <= ex_target;
end
```

跳转延迟 = **2 拍**（EX 解析 + 取指 1 拍延迟），与经典 5 级流水线相同。

---

## 五、访存阶段 (MEM Stage)

### 5.1 单次脉冲请求

```verilog
// cpu_core.v:254-255
assign daccess_ren = mem_is_load  && !mem_req_sent ? mem_da_ren : 4'h0;
assign daccess_wen = mem_is_store && !mem_req_sent ? mem_da_wen : 4'h0;
```

`mem_req_sent` 门控确保请求只发一次。一旦发出 `mem_req_sent <= 1`，请求立即清零。等待 `daccess_rvalid`/`daccess_wresp` 脉冲到达。

**为什么必须单次?** 老版持续电平导致：响应返回后请求仍为高 → Data_RAM 的 `data_valid` 持久为 1 → 无法区分"响应已消费"和"新响应到达"。

### 5.2 MEM 等待期间的流水线行为

`mem_wait = mem_is_access && !mem_done` 时：

| 流水段 | 行为 |
|--------|------|
| **IF/ID** | `front_stop=1` → 停止消费新指令。取到的指令进 `fetch_buf`。 |
| **ID/EX** | **保持**（`idex_valid` 不变）。同时更新前递数据：若 WB 正在写 ID/EX 等待的源寄存器，更新 `idex_rs*_data`。 |
| **EX/MEM** | **保持**（`exmem_valid` 不变）。`mem_req_sent` 在请求发出后置1。 |
| **MEM/WB** | **清零**（`memwb_valid <= 0`）——防止等待期间多次写回。 |

### 5.3 MREQ + MEXT

`MREQ` 根据访存类型和地址偏移生成字节使能：
- `st.b`: 单字节复制到所有 lane，`da_wen = 4'b0001 << offset`
- `st.h`: 半字复制到高低半字，`da_wen = offset[1] ? 4'b1100 : 4'b0011`
- `st.w`: 4 字节（需字对齐）
- Load 同理，根据 `ram_rop` 和 `offset` 选择对应字节/半字

`MEXT` 从 32bit 总线数据中提取并对齐：
```verilog
case (byte_offs)
    2'b01:  real_din = { 8'h0, din[31: 8]};  // 右移1字节
    2'b10:  real_din = {16'h0, din[31:16]};  // 右移2字节
    2'b11:  real_din = {24'h0, din[31:24]};  // 右移3字节
endcase
// 然后根据 ram_rop 做符号/零扩展
```

---

## 六、访存请求的双重保护

流水线访存有两个重要的 guard，防止背靠背 load 和 Cache HIT 场景下的误触发。

### 6.1 `exmem_just_changed` — 防地址未稳定就发请求

```verilog
// cpu_core.v:258-266
reg [31:0] prev_exmem_pc;
wire exmem_just_changed = (exmem_pc != prev_exmem_pc);
assign daccess_ren = mem_is_load && !mem_req_sent && !exmem_just_changed ? mem_da_ren : 4'h0;
```

**问题场景**: 上一个 load 完成（`mem_wait=0`），下一条 load 在同一拍进入 EX/MEM。由于 NBA 延迟，`exmem_alu`（新 load 的地址）还没更新，`daccess_ren` 用旧地址发出请求 → DCache 命中旧地址 → `data_valid=1` → 新 load 误完成。

**修复**: `exmem_just_changed` 在 EX/MEM 更换指令后保持 1 拍，这一拍内禁止发 `daccess_ren`。下一拍 `exmem_alu` 已稳定为新值，请求正确发出。

### 6.2 `mem_done && mem_req_sent` — 防未发请求就接受响应

```verilog
// cpu_core.v:250-251
wire mem_done = mem_is_load ? (daccess_rvalid && mem_req_sent) :
                mem_is_store ? daccess_wresp : 1'b1;
```

**问题场景**: Cache HIT 后 `data_valid=1`，新 load 进入 EX/MEM 时 `daccess_rvalid` 还是 1（残留或同一拍的另一个 HIT），`mem_done=1` 直接判定"已完成"——拿到错误数据。

**修复**: 只有真正发出了请求（`mem_req_sent=1`）才接受响应。新 load 在 EX/MEM 的第一周期 `mem_req_sent=0`，即使 `daccess_rvalid=1` 也不会误完成。

---

## 七、写回阶段 (WB Stage)

```verilog
// cpu_core.v:493,496
memwb_valid <= exmem_valid;
memwb_data  <= mem_is_load ? mem_load_data : exmem_forward_data;
memwb_rd    <= exmem_rd;
memwb_rf_we <= exmem_rf_we;
```

`memwb_data` 的来源选择：
- **Load 指令**: MEXT 扩展后的 `mem_load_data`
- **其他**: EX 阶段计算的 `ex_forward_data`（可能是 ALU结果、PC+4或立即数）

RF 写发生在 WB 阶段且 `memwb_valid=1`：
```verilog
wire wb_rf_we = memwb_valid && memwb_rf_we && memwb_rd != 5'h0;
```

注意 `mem_wait` 期间 `memwb_valid <= 0`，避免 load 数据还没到就误写回。

---

## 八、流水线控制 — front_stop

### 7.1 四个阻塞源

```verilog
// cpu_core.v:285-286
wire front_stop = mem_wait || mul_div_wait || load_use_stall || redirect_pending;
```

| 阻塞源 | 条件 | 语义 |
|--------|------|------|
| `mem_wait` | EX/MEM 有访存指令且未完成 | 等待 daccess_rvalid/wresp |
| `mul_div_wait` | ID/EX 有乘除法且硬件 busy | 等待乘法器/除法器 |
| `load_use_stall` | ID 需要的数据正在 EX/MEM 或 MEM/WB 的 load 中 | 插入 1 拍气泡 |
| `redirect_pending` | 跳转目标尚未发出取指请求 | 等取指接口空闲 |

### 7.2 为什么没有死锁

关键在于 `front_stop` **只阻塞前端**（IF/ID 消费），不形成反馈环：

```
front_stop → 阻塞 IF/ID 消费新指令
           → 不影响 ID/EX 保持
           → 不影响 EX/MEM 保持
           → 不影响访存请求的发出和响应
           → 响应到达后 mem_wait 自动解除
           → front_stop 解除
```

老版的问题在于 `stall` 信号既阻塞前端又反馈到 `ifetch_req`，形成 `ifetch_req → ifetch_valid → stall → ifetch_req` 的环路。

### 7.3 mul_div_wait 的细节

```verilog
// cpu_core.v:272-273
wire mul_div_wait = idex_valid && is_mul_div_ex &&
    (!idex_md_started || mul_div_busy);
```

**第一拍**: `idex_md_started=0` → 强制等 1 拍（ALU 需要 1 拍启动硬件乘法器/除法器，因为 `start` 信号要在时钟沿被捕获）。

**后续**: `idex_md_started=1` → 等 `mul_div_busy` 清零。

等待期间 ID/EX 的行为：
```verilog
// cpu_core.v:399-407
if (mul_div_wait) begin
    idex_valid <= idex_valid;     // 保持
    // 更新前递数据 (WB阶段可能在写)
    if (wb_rf_we && wb_rd == idex_rs1) idex_rs1_data <= wb_data;
    if (wb_rf_we && wb_rd == idex_rs2) idex_rs2_data <= wb_data;
    // 首次等待后清除 alu_op 防止重复触发
    if (idex_md_started) idex_alu_op <= `ALU_ADD;
    idex_md_started <= 1'b1;
end
```

**关键**: `idex_md_started` 置1后将 `alu_op` 改为 `ALU_ADD`。这不会影响结果（`op_r` 已锁存真正的 op），但避免重复触发 `mul_flag`/`div_flag`。

---

## 九、Load-Use 冒险

### 8.1 检测条件

```verilog
// cpu_core.v:277-281
wire load_use_stall = id_valid && (
    // EX/MEM阶段有load正在写rd, 且ID阶段要读这个rd
    (idex_valid  && idex_rf_we  && idex_rf_wsel  == `WB_RAM && idex_rd  != 5'h0 &&
     ((id_rs1_used && id_rs1 == idex_rd) || (id_rs2_used && id_rs2 == idex_rd))) ||
    // MEM/WB阶段有load正在写rd (双load连续时)
    (exmem_valid && exmem_rf_we && exmem_rf_wsel == `WB_RAM && exmem_rd != 5'h0 &&
     ((id_rs1_used && id_rs1 == exmem_rd) || (id_rs2_used && id_rs2 == exmem_rd)))
);
```

### 8.2 处理方式

`load_use_stall` 触发 → `front_stop=1` → ID/EX 插入 NOP 气泡：

```verilog
// cpu_core.v:408-416
if (ex_redirect || load_use_stall || redirect_pending) begin
    idex_valid   <= 1'b0;       // 气泡
    idex_inst    <= NOP;
    idex_rf_we   <= 1'b0;
    idex_ram_rop <= `RAM_EXT_N;
    // ...
end
```

**停顿 1 拍后**: load 进入 MEM/WB（拿到了 `daccess_rdata`），下一条指令重新进入 ID/EX，通过 MEM/WB 前递拿到数据。

### 8.3 双 Load 连续的特殊情况

```
ld.w r5, r3, 0     EX/MEM    mem_wait=1 (等内存)
ld.w r6, r4, 0     ID/EX     mem_wait=1 (等 EX/MEM 先完成)
add.w r7, r5, r6   IF/ID     需要 r5 和 r6
```

第二条 load 的 `mem_wait` 本身就会让前端阻塞，所以 `add.w` 等第一条 load 完成时，第二条 load 可能还在 MEM 阶段。这里有两层保护：`mem_wait` + `load_use_stall`（第二条 load 在 EX/MEM 时 `add.w` 检测到 `exmem_rf_wsel == WB_RAM`）。

---

## 十、控制冒险 — 分支冲刷

### 9.1 静态预测: 总是预测不跳转

流水线在 ID 阶段不知道分支方向，默认继续顺序取指。分支在 EX 阶段解析，若 taken 则冲刷：

```verilog
// cpu_core.v:353 — fetch_buf 清空
if (ex_redirect || redirect_pending) begin
    fetch_buf_valid <= 1'b0;
end

// cpu_core.v:408 — ID/EX 插 NOP
if (ex_redirect || ...) begin
    idex_valid <= 1'b0;
end
```

### 9.2 时序示意

```
         Fetch        ID          EX         MEM        WB
Cycle N: [T+8]       [T+4]      [BR: taken]  [N-1]     [N-2]
                              ↓ ex_redirect=1
Cycle N+1: [target]   [NOP]      [NOP]       [BR]      [N-1]
                              ↓ 取指延迟1拍
Cycle N+2: [targ+4]   [target]   [NOP]       [NOP]     [BR]
Cycle N+3: [targ+8]   [targ+4]   [target]    [NOP]     [NOP]

跳转延迟 = 2拍 (N+1/N+2 的 EX 阶段是气泡)
```

---

## 十一、Cache 系统（参考 RV 核设计）

### 10.1 设计原则

DCache 和 ICache 均采用直连映射、64×128bit=1KB 的组织，内部逻辑照搬参考 RV 核：

- **`cpu_ren`/`cpu_wen` 组合逻辑**：`= (state == ST_RD_REQ) ? 4'hF : 4'h0`，不再用寄存器保持
- **单状态机**：DCache 统一读/写 FSM（`IDLE → RD_REQ → RD_WAIT → IDLE`），不再分离读/写状态机
- **`data_valid`/`inst_valid` 默认清零**：每拍 `data_valid <= 1'b0`，仅命中/refill 完成时置 1——真正的 1 拍脉冲，杜绝残留
- **无 `dev_rvalid_d1`**：响应到达当拍直接转 IDLE，不延迟 1 拍
- **Cache 命中组合逻辑**：`cpu_hit` 在 IDLE 态直接判断，命中立即返回数据，不经过单独的 LOOKUP 状态

### 10.2 ICache

- **状态机**: `IDLE → REQ → WAIT → (dev_rvalid) → IDLE`
- **`cpu_ren`**: `(state == ST_REQ) ? 4'hF : 4'h0` （组合逻辑）
- **`cpu_raddr`**: `{miss_addr[31:4], 4'b0000}` （组合逻辑）
- **命中**: IDLE 态 `cpu_hit` 为真 → 直接 `inst_out <= pick_word(lines[cpu_index], ...)`，不离开 IDLE
- **缺失**: `miss_addr <= inst_addr，state <= ST_REQ`，等待总线 refill

### 10.3 DCache

- **状态机**（统一读写）: `IDLE → RD_REQ → RD_WAIT → IDLE` / `IDLE → WR_REQ → WR_WAIT → IDLE`
- **`cpu_ren`/`cpu_wen`**: 组合逻辑，仅在对应状态为 1
- **`cpu_raddr`/`cpu_waddr`/`cpu_wdata`**: 组合逻辑
- **写穿 + 写分配**: 写入同时更新 Cache line + 发总线写请求
- **读命中**: IDLE 态直接返回，不离开 IDLE
- **读缺失**: 进入 RD_REQ → RD_WAIT，等待总线 refill 后 `dev_rvalid` 到达当拍取数据、置 `data_valid=1`、回 IDLE

### 10.4 axi_bus

参考 RV 核的 `axi_master.v`：

- **统一状态机**: `IDLE → RADDR → RDATA → IDLE` / `IDLE → WRITE → WRESP → IDLE`
- **`rvalid`/`rdata` 均为寄存器**，同一拍更新，永远对齐
- **`rrdy`/`wrdy`**: 组合逻辑（`state == ST_IDLE`）
- **DCache 优先级 > ICache**
- **`rdata` 组合逻辑回退**: 响应周期内 `rdata = {m_axi_rdata, rd_buf[2], rd_buf[1], rd_buf[0]}`（组合，与 `rvalid` 对齐）；响应结束后回退到 `rdata_reg`（寄存器保存），保证 ICache 的 `dev_rvalid` 延迟捕获也能拿到正确数据

### 10.5 旧版 Cache 的关键问题

| 问题 | 旧设计 | 新设计 |
|------|--------|--------|
| `data_valid` 残留 | 寄存器输出，状态切换后多 hold 1 拍 | 默认清零，纯 1 拍脉冲 |
| `cpu_ren` 重复 | R_REFILL 全程寄存器拉高，`dev_rvalid` 来后又重新拉高 | 组合逻辑，仅在 RD_REQ 为 1 |
| `rdata` 不对齐 | `rvalid` 组合逻辑、`rdata` 寄存器——差 1 拍 | 两者同拍更新 |
| `rd_addr_r` 过渡期丢失 | `r_state == IDLE` 在过渡期不成立 | 组合 `cpu_hit` 用 `data_addr`，不依赖捕获 |

---

## 十二、乘除法多周期机制（参考 RV 核设计）

以 `mul.w r5, r3, r4` 为例：

**关键信号**:
- `mul_div_start = idex_valid && is_mul_div_ex && !idex_md_started` — 1 拍脉冲
- `mul_div_wait = idex_valid && is_mul_div_ex && (!idex_md_started || mul_div_busy)` — 等待条件

**时序**:

```
Cycle N:   IF/ID: mul.w 解码, ID/EX 捕获
           → is_mul_div_ex=1, idex_md_started=0
           → mul_div_start = 1 (1拍脉冲!) → ALU.md_start = 1
           → ALU: start_mul = 1, 乘法器启动, busy 将在下拍拉高
           → mul_div_wait = 1 (因为 !idex_md_started=1)
           → ID/EX 保持 (mul_div_wait 分支)
           → EX/MEM 清空

Cycle N+1: idex_md_started <= 1 (NBA from N)
           → mul_div_busy=1 (乘法器 busy)
           → mul_div_wait = 1 (因为 mul_div_busy=1)
           → front_stop = 1, ID/EX 保持, 前端阻塞

Cycle N+2~N+32: mul_div_busy=1 → mul_div_wait=1 → 持续等待

Cycle N+33: 乘法器完成: busy 降 0, z <= 乘积
           → mul_div_wait = 0 (idex_md_started=1, busy=0)
           → front_stop=0, ID/EX→EX/MEM (alu_c = mul_res = z[31:0] = 正确结果)
           → 新指令进入 ID/EX

Cycle N+34: EX/MEM → MEM/WB
Cycle N+35: WB 写寄存器
```

**延迟**: 32 周期计算 + 3 拍流水线开销 = **35 拍**。

**背靠背 mul/div**: `mul_div_start` 脉冲只在 `!idex_md_started` 时发出一次。当前 mul 完成 → `mul_div_wait=0` → 下一条 mul 进入 ID/EX（`idex_md_started` 被 else 分支复位为 0）→ `mul_div_start` 再次脉冲。每次脉冲乘除法器的 operands 都已更新为正确值，不存在竞态。

---

## 十三、前递网络完整场景

### 场景 1: ALU → ALU (最常见)

```
add.w r5, r3, r4     EX/MEM: r5=ALU结果, rf_we=1
sub.w r6, r5, r7     ID/EX: rs1=r5
                     → EX/MEM前递: ex_rs1_forward = exmem_forward_data ✓
```

### 场景 2: Load → ALU (需停顿)

```
ld.w r5, r3, 0       EX/MEM: rf_wsel=WB_RAM, mem_wait=1
add.w r6, r5, r7     ID/EX: rs1=r5
                     → EX/MEM前递被排除(rf_wsel==WB_RAM)
                     → load_use_stall=1, ID/EX插NOP
                     → 等load完成 MEM/WB前递: memwb_data=load_data ✓
```

### 场景 3: 双连 ALU (EX/MEM 优先)

```
add.w r5, r3, r4     MEM/WB: r5=结果A
sub.w r5, r6, r7     EX/MEM: r5=结果B (更新)
xor  r8, r5, r9      ID/EX: rs1=r5
                     → EX/MEM前递优先: ex_rs1_forward = 结果B ✓
```

### 场景 4: WB → ID 旁路 (同周期写读)

```
ld.w r5, r3, 0       MEM/WB: wb_rf_we=1, wb_rd=r5 (此时写RF)
add.w r6, r5, r7     ID: rs1=r5, RF异步读出旧值
                     → WB→ID旁路: id_rs1_data = wb_data (新值) ✓
```

### 场景 5: mem_wait 期间的动态前递更新

```verilog
// cpu_core.v:393-398
if (mem_wait) begin
    idex_valid <= idex_valid;     // ID/EX 保持
    if (wb_rf_we && wb_rd == idex_rs1) idex_rs1_data <= wb_data;
    if (wb_rf_we && wb_rd == idex_rs2) idex_rs2_data <= wb_data;
end
```

**关键**: 若 ID/EX 在等待访存完成，而 WB 阶段恰好在写 ID/EX 需要的源寄存器，必须更新 `idex_rs*_data`。否则访存完成后 ID/EX 继续执行时，`idex_rs*_data` 还是旧值，而 RF 已被更新 → 前递网络也救不了（因为新值在 WB，ID/EX 里的 `idex_rs*_data` 是旧值不会触发前递）。

---

## 十四、NOP 指令

```verilog
localparam NOP = 32'h03400000;   // and r0, r0, r0 — 对 r0 做 AND, 无副作用
```

`r0` 硬连线为 0，写 `r0` 被 RF 忽略（`we && wR != 0`）。所以 NOP 不改变任何架构状态。

NOP 用于：
- 复位后的流水线寄存器初始值
- 跳转冲刷时 ID/EX 插入的气泡
- load-use 停顿时 ID/EX 插入的气泡
- mul_div_wait 期间 EX/MEM 清零 (`exmem_valid <= 0`)

---

## 十五、调试机制

`RUN_TRACE` 宏开启后暴露以下信号给 Verilator：

```verilog
debug_wb_pc     // WB 阶段的 PC
debug_wb_rf_we  // RF 写使能
debug_wb_rf_wR  // 写目标寄存器号
debug_wb_rf_wD  // 写数据值
debug_mem_pc    // 访存指令的 PC
debug_mem_we    // 写字节使能
debug_mem_waddr // 写地址
debug_mem_wdata // 写数据
```

这些信号被 C golden model 采集，逐条比对 RF 写入和内存写入，实现指令级差分测试。

---

## 十六、总结: 流水线 CPU 的关键设计决策

| 设计决策 | 方案 | 原因 |
|----------|------|------|
| 取指协议 | 单拍脉冲 | 避免电平协议的反馈死锁 |
| IF/ID 寄存器 | 无 (组合逻辑) | 节省 1 拍延迟 |
| 前端缓冲 | 1-deep fetch_buf | 解耦取指和译码，后端阻塞时不丢失已取指令 |
| 流控方式 | valid-bit 逐级控制 | 无全局反馈环，不死锁 |
| 分支预测 | 静态不跳转 | 简单，2 拍惩罚可接受 |
| 前递策略 | EX/MEM 优先 + 排除 Load | EX/MEM 数据更新，Load 数据不在 EX/MEM |
| 乘除法 | 硬件 Booth + 恢复余数 | 真正的多周期硬件，而非组合逻辑 |
| Cache | 直连映射, 1KB, 写穿 | 简单可验证，适合 FPGA BRAM |
| 启动保护 | 首条指令单步执行 | 防止初始状态不确定时流水线失控 |
| NOP | `and r0, r0, r0` (0x03400000) | 无副作用的真 NOP |

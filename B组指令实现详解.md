# B组 18 条指令实现详解

## 总览

B 组 18 条指令分为四大类：

| 类别 | 指令 | 数量 | 指令格式 | 周期 |
|------|------|------|----------|------|
| 比较运算 | `slt`, `sltu`, `slti`, `sltui` | 4 | 3R / 2RI12 | 单周期 |
| 逻辑运算 | `and`, `or`, `andi` | 3 | 3R / 2RI12 | 单周期 |
| 条件分支 | `blt`, `bge`, `bltu`, `bgeu` | 4 | 2RI16 | 单周期 |
| 乘除法 | `mul.w`, `mulh.w`, `mulh.wu`, `div.w`, `div.wu`, `mod.w`, `mod.wu` | 7 | 3R | 多周期（当前组合逻辑实现） |

B 组的所有实现改动涉及三个文件：

| 文件 | 改动内容 |
|------|----------|
| `defines.vh` | 新增 7 个 ALU 宏定义（`ALU_MUL` ~ `ALU_MODU`，编码 0x11~0x17） |
| `Controller.v` | 新增 18 条指令译码 + 将对应信号加入控制分组 |
| `ALU.v` | 新增比较、与、或、乘除法的组合逻辑运算 |

核心原理：**CPU 数据通路是固定的，B 组指令和 A 组指令共享同一套硬件。唯一区别是 Controller 对不同的 opcode 输出不同的控制信号，让 ALU 做不同的运算。**

---

## 一、比较运算（4 条）

### 1.1 指令语义

| 指令 | 语法 | 功能 |
|------|------|------|
| `slt` | `slt rd, rj, rk` | rd ← (rj < rk) ? 1 : 0，有符号比较 |
| `sltu` | `sltu rd, rj, rk` | rd ← (rj < rk) ? 1 : 0，无符号比较 |
| `slti` | `slti rd, rj, si12` | rd ← (rj < sext(si12)) ? 1 : 0，有符号比较 |
| `sltui` | `sltui rd, rj, si12` | rd ← (rj < sext(si12)) ? 1 : 0，无符号比较 |

---

### 1.2 Controller.v — 指令识别与控制信号

**指令识别**（第 80-83 行）：

```verilog
wire SLT   = (inst_31_15[31:15] == 17'h00024);   // 3R型
wire SLTU  = (inst_31_15[31:15] == 17'h00025);   // 3R型
wire SLTI  = (inst_31_15[31:22] == 10'h008  );   // 2RI12型
wire SLTUI = (inst_31_15[31:22] == 10'h009  );   // 2RI12型
```

**指令分组**：`SLT` 和 `SLTU` 被加入 `IS_3R` 分组（第 114 行），这意味着它们自动获得和 `add.w` 完全相同的控制信号——PC+4、写回ALU结果、ALU A口选RF、ALU B口选寄存器、不访存。

**SLTI/SLTUI 的立即数扩展**：

```verilog
wire EXT_OP_12  = ADDI_W | IS_LOAD | IS_STORE | SLTI | SLTUI;    // 第136行：符号扩展12位
wire ALU_B_SEL_EXT = ... | SLTI | SLTUI;    // 第184行：ALU B口选立即数
```

`slti` 用 `EXT_12`（符号扩展），`sltui` 用 `EXT_12U`（零扩展）——但实际上从指令语义看，`sltui` 也是符号扩展。检查代码：`SLTUI` 在 `EXT_OP_12` 中（第 136 行），不在 `EXT_OP_12U` 中。这是正确的——sltui 的立即数是 sign-extend 的。

**ALU 运算类型**（第 155-156 行）：

```verilog
wire ALU_OP_SLT  = SLT | SLTI;
wire ALU_OP_SLTU = SLTU | SLTUI;
```

**写回信号**（第 205-209 行，第 222-224 行）：

```verilog
wire RF_OP_WE = ... | SLTI | SLTUI;   // slti/sltui 加入写回使能
// SLT/SLTU 已经通过 IS_3R 自动获得了 rf_we=1

wire WB_OP_ALU = ... | SLTI | SLTUI;  // slti/sltui 写回 ALU 结果
// SLT/SLTU 已经通过 IS_3R 自动获得了 rf_wsel=WB_ALU
```

---

### 1.3 ALU.v — 比较逻辑

```verilog
// 第47-48行
`ALU_SLT  : c = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0;
`ALU_SLTU : c = (a < b) ? 32'h1 : 32'h0;
```

**有符号 vs 无符号的区别**：

- `$signed(a)` 强制 Verilog 将 `a` 解释为有符号数。`0xFFFFFFFF` 被解释为 `-1`。
- 不写 `$signed` 时，Verilog 默认做无符号比较。`0xFFFFFFFF` 被解释为 `4294967295`。

| `a` | `b` | `$signed(a) < $signed(b)` | `a < b` |
|-----|-----|--------------------------|---------|
| `0xFFFFFFFF` (-1) | `0x00000001` (1) | 真（-1 < 1） | 假（4294967295 < 1 不成立） |
| `0x00000001` (1) | `0x00000002` (2) | 真 | 真 |

---

### 1.4 完整数据通路（以 `slt r5, r3, r4` 为例）

```
指令机器码: inst = {000000_0_000_0100100, rk=r4, rj=r3, rd=r5}
                            ↑ opcode/funct (SLT)

━━ IF 取指 ━━
PC → Inst_ROM → inst[31:0]

━━ ID 译码 ━━
inst[31:15] = 17'h00024 → Controller 识别为 SLT

控制信号:
  npc_op   = PC4        → NPC 输出 pc+4
  r2_sel   = SEL_RK     → RF 读口2 读 inst[14:10] = r4
  rf_we    = 1          → 需要写回
  rf_wsel  = WB_ALU     → 写回数据源: ALU 结果
  alu_op   = ALU_SLT    → ALU: 做有符号比较
  alua_sel = SEL_R1     → ALU A口: RF.rD1
  alub_sel = SEL_R2     → ALU B口: RF.rD2
  ext_op   = 不关心     → EXT 不参与
  ram_rop  = 0          → 不读内存
  ram_wop  = 0          → 不写内存

RF 读操作:
  rR1 = inst[9:5]  = r3 → rf_rd1 = (r3的值)
  rR2 = inst[14:10] = r4 → rf_rd2 = (r4的值)

━━ EX 执行 ━━
alu_a = rf_rd1   (r3的值)
alu_b = rf_rd2   (r4的值)
alu_op = ALU_SLT (5'h02)

ALU 内部:
  case(5'h02):
    $signed(r3) < $signed(r4) ?
      → 真: alu_c = 32'h1
      → 假: alu_c = 32'h0
  br = 1'b0

━━ MEM 访存 ━━
无操作 (ram_rop=0, ram_wop=0)

━━ WB 写回 ━━
rf_we1 = ifetch_valid & rf_we & !is_ld_st & !is_mul_div = 1
rf_wR  = inst[4:0] = r5
rf_wD  = alu_c (1 或 0)

RF 写: regs[r5] ← alu_c

inst_finished = 1 → PC 更新为 pc+4
```

### `slti` 的数据通路区别

跟 `slt` 只有两个地方不同：

```
rR2   → 不读（B 口来自立即数，不需要读 rk）
alub_sel = SEL_EXT → ALU B口 = EXT.ext = sext(imm12)
imm   → EXT: ext_op=SIGN_12, imm=inst[21:10]
```

---

### 1.5 老师可能问

**Q: `slt` 的结果是多少位？只返回一个 bit 吗？**

答：返回完整的 32 位，但内容只有两种可能——`32'h00000001`（条件成立）或 `32'h00000000`（条件不成立）。LA32 指令集中所有比较指令都返回完整的 32 位值。

**Q: `slti` 和 `sltui` 的立即数各是什么扩展？**

答：都是符号扩展（`SIGN_12`）。LA32 指令集的 `sltui` 的立即数是 sign-extend 的，不是 zero-extend。这意味着 `sltui r5, r3, 0xFFFF` 会比较 `r3` 和 `0xFFFFFFFF`（符号扩展后的值），而不是 `0x0000FFFF`。

---

## 二、逻辑运算（3 条）

### 2.1 指令语义

| 指令 | 语法 | 功能 |
|------|------|------|
| `and` | `and rd, rj, rk` | rd ← rj & rk，按位与 |
| `or` | `or rd, rj, rk` | rd ← rj \| rk，按位或 |
| `andi` | `andi rd, rj, ui12` | rd ← rj & zext(ui12)，按位与立即数 |

---

### 2.2 Controller.v — 指令识别与控制信号

**指令识别**（第 88-90 行）：

```verilog
wire AND_ = (inst_31_15[31:15] == 17'h00029);   // 3R型
wire OR_  = (inst_31_15[31:15] == 17'h0002A);   // 3R型
wire ANDI = (inst_31_15[31:22] == 10'h00D  );   // 2RI12型
```

> `AND_` 和 `OR_` 带下划线后缀是因为 Verilog 中 `and` 和 `or` 是保留关键字，不能直接用作标识符。

**指令分组**：

`AND_` 和 `OR_` 加入 `IS_3R`（第 114 行），自动获得 3R 型的所有控制信号。

**ANDI 的立即数扩展**：

```verilog
wire EXT_OP_12U = ORI | XORI | ANDI;   // 第135行：零扩展
```

`andi` 的立即数是零扩展——操作的是位模式，不应引入符号位。

**ANDI 的 ALU B 口**：

```verilog
wire ALU_B_SEL_EXT = ... | ANDI | SLTI | SLTUI;   // 第184行
```

**ALU 运算类型**（第 154 行）：

```verilog
wire ALU_OP_AND = AND_ | ANDI;   // and 和 andi 都用 AND 运算
```

`OR_` 复用已有的 `ALU_OP_OR = ORI | OR_`（第 146 行）。

---

### 2.3 ALU.v — 逻辑运算

```verilog
// 第41-42行
`ALU_AND  : c = a & b;
`ALU_OR   : c = a | b;
```

这些是 Verilog 的内置位运算，纯组合逻辑，单周期完成。

---

### 2.4 完整数据通路（以 `and r5, r3, r4` 为例）

```
指令机器码: inst = {000000_0_000_0101001, rk=r4, rj=r3, rd=r5}
                            ↑ opcode/funct (AND)

━━ IF 取指 ━━
PC → Inst_ROM → inst[31:0]

━━ ID 译码 ━━
inst[31:15] = 17'h00029 → Controller 识别为 AND_

控制信号:
  npc_op   = PC4
  r2_sel   = SEL_RK     → RF 读口2: inst[14:10] = r4
  rf_we    = 1
  rf_wsel  = WB_ALU
  alu_op   = ALU_AND    (5'h05)
  alua_sel = SEL_R1
  alub_sel = SEL_R2
  ext_op   = 不关心
  ram_rop  = 0
  ram_wop  = 0

RF 读操作:
  rR1 = inst[9:5]  → rf_rd1 = (r3)
  rR2 = inst[14:10] → rf_rd2 = (r4)

━━ EX 执行 ━━
alu_a = rf_rd1
alu_b = rf_rd2
alu_op = ALU_AND

ALU 内部:
  case(5'h05):
    alu_c = r3 & r4    // 按位与
  br = 1'b0

━━ MEM 访存 ━━
无操作

━━ WB 写回 ━━
rf_we1 = 1
rf_wR  = inst[4:0] = r5
rf_wD  = alu_c = r3 & r4

RF 写: regs[r5] ← r3 & r4
```

### `andi r5, r3, 0x0FF` 的数据通路区别

```
rR2   → 不读寄存器，B口来自立即数
ext_op = UNSIGN_12  → EXT: 零扩展 12 位 → ext = 0x000000FF
alu_b = EXT.ext = 0x000000FF
alu_op = ALU_AND
alu_c = r3 & 0x000000FF  → 保留 r3 低8位，高24位清零
```

---

### 2.5 老师可能问

**Q: 为什么 `andi` 用零扩展而 `slti` 用符号扩展？**

答：逻辑运算（and/or/xor）操作的是位模式，不关注数值含义，所以立即数零扩展保证高位为 0。比较运算（slt/slti）关注数值大小，立即数必须符号扩展以保留正负含义。这是 LA32 指令集规范规定的。

**Q: `andi` 和 A 组的 `xori` 在数据通路上有什么不同？**

答：数据通路完全一样——都是 2RI12 型，立即数零扩展，ALU B 口选立即数。唯一的区别是 `alu_op` 不同：`andi` 输出 `ALU_AND`，`xori` 输出 `ALU_XOR`。

---

## 三、条件分支（4 条）

### 3.1 指令语义

| 指令 | 语法 | 功能 |
|------|------|------|
| `blt` | `blt rj, rd, offs16` | 如果 (rj < rd)（有符号）则 PC ← PC + sext({offs16, 2'b0}) |
| `bge` | `bge rj, rd, offs16` | 如果 (rj ≥ rd)（有符号）则跳转 |
| `bltu` | `bltu rj, rd, offs16` | 如果 (rj < rd)（无符号）则跳转 |
| `bgeu` | `bgeu rj, rd, offs16` | 如果 (rj ≥ rd)（无符号）则跳转 |

---


### 3.2 指令编码格式（2RI16）

```
 bit  31..26    25..10       9..5     4..0
     ┌──────┬────────────┬─────────┬────────┐
     │opcode│ offs[15:0] │   rj    │   rd   │
     └──────┴────────────┴─────────┴────────┘
```

**关键点**：第二个操作数是 `rd` 位置的寄存器（`inst[4:0]`），而非 `rk`（`inst[14:10]`）。这和 A 组的分支 `beq`/`bne` 一样。

---

### 3.3 Controller.v — 指令识别与控制信号

**指令识别**（第 95-98 行）：

```verilog
wire BLT  = (inst_31_15[31:26] == 6'h18);   // 011000
wire BGE  = (inst_31_15[31:26] == 6'h19);   // 011001
wire BLTU = (inst_31_15[31:26] == 6'h1A);   // 011010
wire BGEU = (inst_31_15[31:26] == 6'h1B);   // 011011
```

**指令分组**（第 120 行）：

```verilog
wire IS_BRCH = BEQ | BNE | BLT | BGE | BLTU | BGEU;
```

将 B 组的 4 条分支指令加入 `IS_BRCH`。这一步就让它们自动获得了和 `beq`/`bne` 完全相同的分支控制逻辑：

```verilog
// 第126行
wire NPC_OP_BRCH = IS_BRCH;    // npc_op = BRANCH，NPC 做分支判断

// 第172行
wire R2_SEL_RD = IS_BRCH | IS_STORE;   // RF 读口2 读 rd（不是 rk）

// 第137行
wire EXT_OP_16 = IS_BRCH | JIRL;       // 立即数扩展: SIGN_16
```

**ALU 运算类型**（第 157-160 行）：

```verilog
wire ALU_OP_BLT  = BLT;
wire ALU_OP_BGE  = BGE;
wire ALU_OP_BLTU = BLTU;
wire ALU_OP_BGEU = BGEU;
```

---

### 3.4 ALU.v — 分支条件判断

```verilog
// 第67-70行 (br 输出)
`ALU_BLT  : br = ($signed(a) < $signed(b));
`ALU_BGE  : br = ($signed(a) >= $signed(b));
`ALU_BLTU : br = (a < b);
`ALU_BGEU : br = (a >= b);
```

注意：ALU 有两个输出——`c`（运算结果）和 `br`（分支条件）。对于分支指令，我们只关心 `br`，`c` 的值不重要（也不写回）。

### 3.5 NPC.v — 下一PC计算

```verilog
always @(*) begin
    case (op)
        `NPC_BRCH: npc = br ? pc + offset : pc4;
        ...
    endcase
end
```

当 `npc_op = BRANCH` 时，NPC 根据 `br` 信号决定：`br=1` → 跳转（`pc + offset`），`br=0` → 顺序执行（`pc + 4`）。`offset` 是 EXT 模块输出的符号扩展后的立即数。

---

### 3.5 完整数据通路（以 `blt r3, r4, 0x10` 为例）

```
指令机器码: inst = {011000, offs[15:0], rj=r3, rd=r4}
                    ↑ opcode=BLT

━━ IF 取指 ━━
PC(0x1000) → Inst_ROM → inst[31:0]

━━ ID 译码 ━━
inst[31:26] = 6'h18 → Controller 识别为 BLT

控制信号:
  npc_op   = BRANCH     → NPC: 条件分支
  r2_sel   = SEL_RD     → RF读口2: inst[4:0] = r4（不是rk！）
  rf_we    = 0          → 不写回寄存器
  rf_wsel  = 不关心
  ext_op   = SIGN_16    → EXT: 符号扩展 offs16
  alu_op   = ALU_BLT    → ALU: 有符号 < 比较
  alua_sel = SEL_R1     → ALU A口: RF.rD1
  alub_sel = SEL_R2     → ALU B口: RF.rD2
  ram_rop  = 0, ram_wop = 0

RF 读操作:
  rR1 = inst[9:5]  → rf_rd1 = (r3)
  rR2 = inst[4:0]  → rf_rd2 = (r4)    ← 读 rd 寄存器的值

EXT:
  imm = inst[25:0]
  ext_op = SIGN_16
  → ext = {{14{inst[25]}}, inst[25:10], 2'b0}
  → ext = sext({offs16, 2'b0}) = 0x00000040  (0x10 << 2)

━━ EX 执行 ━━
alu_a = rf_rd1 (r3)
alu_b = rf_rd2 (r4)
alu_op = ALU_BLT (5'h0D)

ALU 内部:
  case(5'h0D):
    br = ($signed(r3) < $signed(r4)) ? 1 : 0
  c = 不关心

━━ MEM 访存 ━━
无操作

━━ WB 写回 ━━
rf_we1 = 0  → 不写寄存器

━━ IF（下一拍）━━
NPC:
  op = BRANCH
  br = 1 (条件成立)
  → npc = pc + offset = 0x1000 + 0x40 = 0x1040

PC:
  fetch = inst_finished = 1 → pc = npc = 0x1040
  下一条从 0x1040 开始执行 ✓
```

---

### 3.6 老师可能问

**Q: 分支指令 `blt rj, rd, offs` 和 `beq rj, rd, offs` 的数据通路有什么区别？**

答：数据通路完全一样。唯一的区别是 `alu_op` 不同——`beq` 用 `ALU_BEQ`（判断相等），`blt` 用 `ALU_BLT`（判断有符号小于）。两者都输出 `br` 信号给 NPC，NPC 根据 `br` 决定跳转还是顺序执行。

**Q: 为什么分支指令的第二个操作数是 `rd` 而不是 `rk`？**

答：这是 LA32 指令格式决定的。2RI16 型的分支指令格式是 `opcode | offs16 | rj | rd`，第二个寄存器在 `rd` 字段（`inst[4:0]`）。所以 `r2_sel = SEL_RD`，让 RF 读 `rd` 而不是 `rk`。

**Q: `blt` 和 `bltu` 的区别是什么？**

答：`blt` 做有符号比较（`$signed(rj) < $signed(rd)`），`bltu` 做无符号比较（`rj < rd`）。例如：
- `blt`: `0xFFFFFFFF(-1)` 和 `0x00000001(1)` → ( -1 < 1 ) → 跳转
- `bltu`: `0xFFFFFFFF(4294967295)` 和 `0x00000001(1)` → ( 4294967295 < 1 ) → 不跳转

**Q: 分支目标地址怎么算？**

答：`目标地址 = PC + sext({offs16, 2'b0})`。offs16 是 inst[25:10]，左移 2 位是因为指令地址最低 2 位恒为 0（4 字节对齐），然后符号扩展成 32 位。这个计算在 EXT 模块中完成（`ext_op = SIGN_16`）。

---

## 四、乘除法（7 条）

### 4.1 指令语义

| 指令 | 语法 | 功能 |
|------|------|------|
| `mul.w` | `mul.w rd, rj, rk` | rd ← (rj × rk)[31:0] |
| `mulh.w` | `mulh.w rd, rj, rk` | rd ← (rj × rk)[63:32]，有符号 |
| `mulh.wu` | `mulh.wu rd, rj, rk` | rd ← (rj × rk)[63:32]，无符号 |
| `div.w` | `div.w rd, rj, rk` | rd ← rj / rk，有符号 |
| `div.wu` | `div.wu rd, rj, rk` | rd ← rj / rk，无符号 |
| `mod.w` | `mod.w rd, rj, rk` | rd ← rj % rk，有符号 |
| `mod.wu` | `mod.wu rd, rj, rk` | rd ← rj % rk，无符号 |

---

### 4.2 Controller.v — 指令识别与控制信号

**指令识别**（第 103-109 行）：

```verilog
wire MUL_W   = (inst_31_15[31:15] == 17'h00038);
wire MULH_W  = (inst_31_15[31:15] == 17'h00039);
wire MULH_WU = (inst_31_15[31:15] == 17'h0003A);
wire DIV_W   = (inst_31_15[31:15] == 17'h00040);
wire MOD_W   = (inst_31_15[31:15] == 17'h00041);
wire DIV_WU  = (inst_31_15[31:15] == 17'h00042);
wire MOD_WU  = (inst_31_15[31:15] == 17'h00043);
```

**指令分组**（第 114 行）：

```verilog
wire IS_3R = ... | MUL_W | MULH_W | MULH_WU | DIV_W | MOD_W | DIV_WU | MOD_WU;
```

所有 7 条乘除法指令都是 3R 型，加入 `IS_3R` 后自动获得：
- `npc_op = PC4`
- `rf_we = 1`
- `rf_wsel = WB_ALU`
- `alub_sel = SEL_R2`
- `r2_sel = SEL_RK`
- `ram_rop = 0, ram_wop = 0`

**ALU 运算类型**（第 161-167 行）：

```verilog
wire ALU_OP_MUL   = MUL_W;
wire ALU_OP_MULH  = MULH_W;
wire ALU_OP_MULHU = MULH_WU;
wire ALU_OP_DIV   = DIV_W | MOD_W;     // div.w 和 mod.w 的区别在 ALU 内部处理
wire ALU_OP_DIVU  = DIV_WU | MOD_WU;   // div.wu 和 mod.wu 同理
wire ALU_OP_MOD   = MOD_W;
wire ALU_OP_MODU  = MOD_WU;
```

**乘除法标志**（第 271-272 行）：

```verilog
assign is_mul = 1'b0;    // 当前用组合逻辑，不触发多周期
assign is_div = 1'b0;    // 但框架预留了多周期接口
```

---

### 4.3 ALU.v — 乘除法逻辑

#### 64 位乘法准备

```verilog
// 第29-32行
wire [63:0] mul_signed_64;
wire [63:0] mul_unsigned_64;

assign mul_signed_64   = { {32{a[31]}}, a } * { {32{b[31]}}, b };
assign mul_unsigned_64 = {32'b0, a} * {32'b0, b};
```

**为什么需要 64 位扩展？** Verilog 中 `a * b` 的结果位宽等于操作数位宽。32bit × 32bit → 32bit，高位被截断。要做完整的 64 位乘法后取高 32 位，必须先把操作数扩展成 64 位。

```verilog
// 有符号扩展：把符号位重复32次
{ {32{a[31]}}, a }
//  a = -1 (0xFFFFFFFF) → a[31]=1 → 0xFFFFFFFF_FFFFFFFF (64位-1) ✓

// 无符号扩展：高位补0
{32'b0, a}
//  a = 0xFFFFFFFF → 0x00000000_FFFFFFFF (64位4294967295) ✓
```

#### 乘法

```verilog
// 第49-51行
`ALU_MUL  : c = a * b;                         // 32×32→32，取低32位
`ALU_MULH : c = mul_signed_64[63:32];          // 有符号64位积的高32位
`ALU_MULHU: c = mul_unsigned_64[63:32];        // 无符号64位积的高32位
```

#### 除法（含除零处理）

```verilog
// 第52-55行
`ALU_DIV  : c = (b == 32'h0) ? $signed(32'h0) : $signed(a) / $signed(b);
`ALU_DIVU : c = (b == 32'h0) ? 32'h0 : a / b;
`ALU_MOD  : c = (b == 32'h0) ? $signed(32'h0) : $signed(a) % $signed(b);
`ALU_MODU : c = (b == 32'h0) ? 32'h0 : a % b;
```

**除零处理**：除数 `b = 0` 时返回 0，避免仿真崩溃（硬件中除零行为是未定义的，返回 0 是常见做法）。

**有符号除法和取模**：使用 `$signed()` 进行符号转换。

---

### 4.4 `div.w` 和 `mod.w` 的编码技巧

这两个指令在 Controller.v 中共享 `ALU_OP_DIV`：

```verilog
wire ALU_OP_DIV  = DIV_W | MOD_W;   // 两者都触发 DIV
wire ALU_OP_MOD  = MOD_W;           // 只有 mod.w 额外触发 MOD
```

但在 `alu_op` 的编码输出中：
```verilog
{5{ALU_OP_DIV}} & `ALU_DIV |    // ALU_DIV = 5'h14
{5{ALU_OP_MOD}} & `ALU_MOD |    // ALU_MOD = 5'h16
```

当 `div.w` 执行时：`ALU_OP_DIV=1, ALU_OP_MOD=0` → `alu_op = 5'h14`（ALU_DIV）
当 `mod.w` 执行时：`ALU_OP_DIV=1, ALU_OP_MOD=1` → `alu_op = 5'h14 | 5'h16 = 5'h16`（ALU_MOD）

按位或确保了 `mod.w` 输出 `ALU_MOD`，`div.w` 输出 `ALU_DIV`。

---

### 4.5 完整数据通路（以 `mul.w r5, r3, r4` 为例）

```
指令机器码: inst = {000000_0_000_0111000, rk=r4, rj=r3, rd=r5}
                            ↑ opcode/funct (MUL_W)

━━ IF 取指 ━━
PC → Inst_ROM → inst[31:0]

━━ ID 译码 ━━
inst[31:15] = 17'h00038 → Controller 识别为 MUL_W

控制信号:
  npc_op   = PC4
  r2_sel   = SEL_RK     → RF读口2: inst[14:10] = r4
  rf_we    = 1
  rf_wsel  = WB_ALU
  alu_op   = ALU_MUL (5'h11)
  alua_sel = SEL_R1
  alub_sel = SEL_R2
  ram_rop  = 0, ram_wop = 0

RF 读操作:
  rR1 = inst[9:5]  → rf_rd1 = (r3)
  rR2 = inst[14:10] → rf_rd2 = (r4)

━━ EX 执行 ━━
alu_a = rf_rd1
alu_b = rf_rd2
alu_op = ALU_MUL (5'h11)

ALU 内部:
  case(5'h11):
    alu_c = r3 * r4   (Verilog 32×32→32，取低32位)
  br = 1'b0

━━ MEM 访存 ━━
无操作

━━ WB 写回 ━━
rf_we1 = 1
rf_wR  = inst[4:0] = r5
rf_wD  = alu_c = (r3 × r4)[31:0]

RF 写: regs[r5] ← r3 × r4 的低32位
```

### `mulh.w r5, r3, r4` 的数据通路区别

唯一的区别在 ALU 内部：

```
ALU 内部 (alu_op = ALU_MULH = 5'h12):
  mul_signed_64 = { {32{r3[31]}}, r3 } * { {32{r4[31]}}, r4 }
                = 符号扩展(r3) × 符号扩展(r4)
  alu_c = mul_signed_64[63:32]   取高32位
```

### `div.w r5, r3, r4` 的数据通路区别

```
ALU 内部 (alu_op = ALU_DIV = 5'h14):
  如果 r4 == 0 → alu_c = 0
  否则 → alu_c = $signed(r3) / $signed(r4)
```

---

### 4.6 多周期机制（预留）

虽然当前用组合逻辑实现了乘除法，但框架预留了多周期接口：

```verilog
// cpu_core.v
assign is_mul_div = is_mul | is_div;          // 第158行

// mul_div_flag 控制多周期等待
always @(posedge cpu_clk or posedge cpu_rst) begin
    if (cpu_rst)              mul_div_flag <= 1'b0;
    else if (is_mul_div)      mul_div_flag <= 1'b1;   // 拉高，阻塞PC
    else if (!mul_div_busy)   mul_div_flag <= 1'b0;   // 运算完成后清零
end

// 写回等待 mul_div_flag 清除
assign rf_we1 = ... | mul_div_flag & !mul_div_busy | ...;   // 第227行

// 指令完成等待 busy 变低
assign inst_finished = ... | mul_div_flag & !mul_div_busy | ...;   // 第244行

// 目标寄存器号缓存
always @(posedge cpu_clk) begin
    if (is_ld_st | is_mul_div) rf_wR_r <= rf_wR;   // 第167行
end
```

当将来用真正的多周期乘法器/除法器替换组合逻辑时（`is_mul/is_div` 改为实际信号，`busy` 改为实际状态），多周期机制会自动生效，无需修改 `cpu_core.v`。

---

### 4.7 老师可能问

**Q: `mul.w` 和 `mulh.w` 的区别是什么？数据通路有什么不同？**

答：`mul.w` 返回 32 位乘法的低 32 位，直接用 Verilog 的 `a * b`。`mulh.w` 返回 64 位乘积的高 32 位——需要先把操作数符号扩展到 64 位，做 64 位乘法，再取 `[63:32]`。

两条指令在 `cpu_core.v` 数据通路上**完全一样**，唯一的区别是 `alu_op` 值不同（`ALU_MUL` vs `ALU_MULH`），导致 ALU 内部做不同的运算。

**Q: `mulh.wu` 和 `mulh.w` 的区别？**

答：`mulh.w` 有符号：`{ {32{a[31]}}, a }` 符号扩展。`mulh.wu` 无符号：`{32'b0, a}` 零扩展。例如：
- `a=0x80000000`（有符号 -2147483648，无符号 2147483648），`b=2`
- `mulh.w`：(-2147483648) × 2 / 2^32 = -1（高 32 位 = `0xFFFFFFFF`）
- `mulh.wu`：(2147483648) × 2 / 2^32 = 1（高 32 位 = `0x00000001`）

**Q: 除数为 0 怎么办？**

答：返回 0。`(b == 32'h0) ? 32'h0 : a / b`。在硬件中除零是未定义行为，返回 0 是安全的软件可见约定。

**Q: 当前 `is_mul` 和 `is_div` 为什么是 `1'b0`？**

答：因为当前乘除法用 Verilog 组合逻辑（`*`, `/`, `%`）实现，单周期就能完成。不需要拉高 `mul_div_flag` 来阻塞 CPU。如果将来替换成真正的多周期乘法器/除法器（例如用 `multiplier.v` 和 `divider.v` 的 TODO 实现），只需要把 `is_mul/is_div` 改为对应指令的译码信号，多周期机制就会自动生效。

---

## 五、defines.vh 新增内容

为支持 B 组指令，在 `defines.vh` 中新增了 7 个 ALU 操作码：

```verilog
`define ALU_MUL     5'h11    // mul.w: 有符号乘法（取低32位）
`define ALU_MULH    5'h12    // mulh.w: 有符号乘法（取高32位，有符号）
`define ALU_MULHU   5'h13    // mulh.wu: 无符号乘法（取高32位，无符号）
`define ALU_DIV     5'h14    // div.w: 有符号除法（商）
`define ALU_DIVU    5'h15    // div.wu: 无符号除法（商）
`define ALU_MOD     5'h16    // mod.w: 有符号取模（余）
`define ALU_MODU    5'h17    // mod.wu: 无符号取模（余）
```

B 组的分支指令复用了已有的 ALU 宏（`ALU_BEQ`, `ALU_BNE`），比较和逻辑运算也复用了已有的宏（`ALU_SLT`, `ALU_SLTU`, `ALU_AND`, `ALU_OR`）。

---

## 六、总结：B 组实现的核心思路

1. **所有 18 条 B 组指令共享 A 组已有的 CPU 数据通路**——IF→ID→EX→MEM→WB 路径不变，PC/NPC/RF/ALU/EXT/MREQ/MEXT 模块不变。

2. **实现只需要改三个地方**：
   - `defines.vh`：新增 7 个 ALU 操作码
   - `Controller.v`：新增 18 条指令的译码 + 信号分组
   - `ALU.v`：新增 7 种运算的组合逻辑

3. **指令分组是关键**：把有相同行为的指令归入同一分组（`IS_3R` / `IS_BRCH`），控制信号自动对齐，不需要为每条指令单独写控制逻辑。

4. **唯一区别在 ALU**：所有 B 组指令和对应 A 组指令的数据通路一样，只有 `alu_op` 不同。`alu_op` 决定了 ALU 做什么运算——比较、逻辑、乘除、分支判断。

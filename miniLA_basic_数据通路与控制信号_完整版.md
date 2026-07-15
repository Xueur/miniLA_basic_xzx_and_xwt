# 数据通路表、控制信号取值表 — miniLA 完整版

---

## 一、控制信号取值表（完整版）

### 已实现指令（模板工程）+ 新增指令

| 指令 | opcode | | 控制信号 | | | | | | | | |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | 位序 | 取值 | npc_op | rf_we | rf_wsel | ext_op | alu_op | alub_sel | r2_sel | alua_sel | ram_rop | ram_wop |
| **已实现指令** | | | | | | | | | | | | |
| addi.w | [31:22] | 0000001010 | PC4 | 1 | WB_ALU | SIGN_12 | ADD | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| ori | [31:22] | 0000001110 | PC4 | 1 | WB_ALU | UNSIGN_12 | OR | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| slli.w | [31:15] | 00000000010000001 | PC4 | 1 | WB_ALU | UNSIGN_5 | SLL | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| lu12i.w | [31:25] | 0001010 | PC4 | 1 | WB_EXT | SIGN_20 | — | — | — | — | 0 | 0 |
| ld.w | [31:22] | 0010100010 | PC4 | 1 | WB_RAM | SIGN_12 | ADD | SEL_EXT | SEL_RK | SEL_R1 | RAM_EXT_W | 0 |
| beq | [31:26] | 010110 | BRANCH | 0 | — | SIGN_16 | EQ | SEL_R2 | SEL_RD | SEL_R1 | 0 | 0 |
| bne | [31:26] | 010111 | BRANCH | 0 | — | SIGN_16 | NE | SEL_R2 | SEL_RD | SEL_R1 | 0 | 0 |
| b | [31:26] | 010100 | JUMP | 0 | — | SIGN_26 | — | — | — | — | 0 | 0 |
| **3R型 — 移位运算** | | | | | | | | | | | | |
| sll.w | [31:15] | 000000 0 000 0101110 | PC4 | 1 | WB_ALU | — | SLL | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| srl.w | [31:15] | 000000 0 000 0101111 | PC4 | 1 | WB_ALU | — | SRL | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| sra.w | [31:15] | 000000 0 000 0110000 | PC4 | 1 | WB_ALU | — | SRA | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| **3R型 — 算术运算** | | | | | | | | | | | | |
| add.w | [31:15] | 000000 0 000 0100000 | PC4 | 1 | WB_ALU | — | ADD | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| sub.w | [31:15] | 000000 0 000 0100010 | PC4 | 1 | WB_ALU | — | SUB | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| **3R型 — 逻辑运算** | | | | | | | | | | | | |
| and | [31:15] | 000000 0 000 0101001 | PC4 | 1 | WB_ALU | — | AND | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| or | [31:15] | 000000 0 000 0101010 | PC4 | 1 | WB_ALU | — | OR | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| xor | [31:15] | 000000 0 000 0101011 | PC4 | 1 | WB_ALU | — | XOR | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| **3R型 — 比较运算** | | | | | | | | | | | | |
| slt | [31:15] | 000000 0 000 0100100 | PC4 | 1 | WB_ALU | — | SLT | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| sltu | [31:15] | 000000 0 000 0100101 | PC4 | 1 | WB_ALU | — | SLTU | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| **3R型 — 乘除法运算（多周期）** | | | | | | | | | | | | |
| mul.w | [31:15] | 000000 0 000 0111000 | PC4 | 1 | WB_ALU | — | MUL | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| mulh.w | [31:15] | 000000 0 000 0111001 | PC4 | 1 | WB_ALU | — | MULH | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| mulh.wu | [31:15] | 000000 0 000 0111010 | PC4 | 1 | WB_ALU | — | MULHU | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| div.w | [31:15] | 000000 0 000 1000000 | PC4 | 1 | WB_ALU | — | DIV | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| div.wu | [31:15] | 000000 0 000 1000010 | PC4 | 1 | WB_ALU | — | DIVU | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| mod.w | [31:15] | 000000 0 000 1000001 | PC4 | 1 | WB_ALU | — | MOD | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| mod.wu | [31:15] | 000000 0 000 1000011 | PC4 | 1 | WB_ALU | — | MODU | SEL_R2 | SEL_RK | SEL_R1 | 0 | 0 |
| **2RI5型 — 移位运算** | | | | | | | | | | | | |
| srli.w | [31:15] | 000000 0 001 0001001 | PC4 | 1 | WB_ALU | UNSIGN_5 | SRL | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| srai.w | [31:15] | 000000 0 001 0010001 | PC4 | 1 | WB_ALU | UNSIGN_5 | SRA | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| **2RI12型 — 逻辑运算** | | | | | | | | | | | | |
| xori | [31:22] | 0000001111 | PC4 | 1 | WB_ALU | UNSIGN_12 | XOR | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| andi | [31:22] | 0000001101 | PC4 | 1 | WB_ALU | UNSIGN_12 | AND | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| **2RI12型 — 比较运算** | | | | | | | | | | | | |
| slti | [31:22] | 0000001000 | PC4 | 1 | WB_ALU | SIGN_12 | SLT | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| sltui | [31:22] | 0000001001 | PC4 | 1 | WB_ALU | UNSIGN_12 | SLTU | SEL_EXT | SEL_RK | SEL_R1 | 0 | 0 |
| **2RI12型 — Load 指令（多周期）** | | | | | | | | | | | | |
| ld.b | [31:22] | 0010100000 | PC4 | 1 | WB_RAM | SIGN_12 | ADD | SEL_EXT | SEL_RK | SEL_R1 | RAM_EXT_B | 0 |
| ld.bu | [31:22] | 0010101000 | PC4 | 1 | WB_RAM | SIGN_12 | ADD | SEL_EXT | SEL_RK | SEL_R1 | RAM_EXT_BU | 0 |
| ld.h | [31:22] | 0010100001 | PC4 | 1 | WB_RAM | SIGN_12 | ADD | SEL_EXT | SEL_RK | SEL_R1 | RAM_EXT_H | 0 |
| ld.hu | [31:22] | 0010101001 | PC4 | 1 | WB_RAM | SIGN_12 | ADD | SEL_EXT | SEL_RK | SEL_R1 | RAM_EXT_HU | 0 |
| **2RI12型 — Store 指令（多周期）** | | | | | | | | | | | | |
| st.b | [31:22] | 0010100100 | PC4 | 0 | — | SIGN_12 | ADD | SEL_EXT | SEL_RD | SEL_R1 | 0 | RAM_WE_B |
| st.h | [31:22] | 0010100101 | PC4 | 0 | — | SIGN_12 | ADD | SEL_EXT | SEL_RD | SEL_R1 | 0 | RAM_WE_H |
| st.w | [31:22] | 0010100110 | PC4 | 0 | — | SIGN_12 | ADD | SEL_EXT | SEL_RD | SEL_R1 | 0 | RAM_WE_W |
| **1RI20型** | | | | | | | | | | | | |
| pcaddu12i | [31:25] | 0001110 | PC4 | 1 | WB_ALU | SIGN_20 | ADD | SEL_EXT | — | SEL_PC | 0 | 0 |
| **2RI16型 — 条件分支** | | | | | | | | | | | | |
| blt | [31:26] | 011000 | BRANCH | 0 | — | SIGN_16 | BLT | SEL_R2 | SEL_RD | SEL_R1 | 0 | 0 |
| bge | [31:26] | 011001 | BRANCH | 0 | — | SIGN_16 | BGE | SEL_R2 | SEL_RD | SEL_R1 | 0 | 0 |
| bltu | [31:26] | 011010 | BRANCH | 0 | — | SIGN_16 | BLTU | SEL_R2 | SEL_RD | SEL_R1 | 0 | 0 |
| bgeu | [31:26] | 011011 | BRANCH | 0 | — | SIGN_16 | BGEU | SEL_R2 | SEL_RD | SEL_R1 | 0 | 0 |
| **2RI16型 — 间接跳转（多周期？）** | | | | | | | | | | | | |
| jirl | [31:26] | 010011 | JR | 1 | WB_ALU | SIGN_16 | ADD | SEL_EXT | SEL_RK | SEL_PC | 0 | 0 |
| **I26型 — 直接跳转** | | | | | | | | | | | | |
| bl | [31:26] | 010101 | JUMP | 1 | WB_ALU | SIGN_26 | ADD | — | — | SEL_PC | 0 | 0 |

> **注**: "—" 表示该信号对当前指令不关心（don't care）或不使用。

---

## 二、数据通路表（完整版）

### 2.1 取指单元 + RF 数据通路

| 指令 | 取指单元 — NPC | | | | RF | | | 控制信号 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | npc | pc | offset | br | rR1 | rR2 | wR | npc_op |
| **已实现指令** | | | | | | | | |
| addi.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| ori | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| slli.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| lu12i.w | NPC.npc | PC.pc | — | — | — | — | IN.inst[4:0] | PC4 |
| ld.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| beq | NPC.npc | PC.pc | EXT.ext | ALU.br | IN.inst[9:5] | IN.inst[4:0] | — | BRANCH |
| bne | NPC.npc | PC.pc | EXT.ext | ALU.br | IN.inst[9:5] | IN.inst[4:0] | — | BRANCH |
| b | NPC.npc | PC.pc | EXT.ext | — | — | — | — | JUMP |
| **3R型 — 移位运算** | | | | | | | | |
| sll.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| srl.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| sra.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| **3R型 — 算术运算** | | | | | | | | |
| add.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| sub.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| **3R型 — 逻辑运算** | | | | | | | | |
| and | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| or | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| xor | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| **3R型 — 比较运算** | | | | | | | | |
| slt | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| sltu | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| **3R型 — 乘除法运算（多周期）** | | | | | | | | |
| mul.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| mulh.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| mulh.wu | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| div.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| div.wu | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| mod.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| mod.wu | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[14:10] | IN.inst[4:0] | PC4 |
| **2RI5型 — 移位运算** | | | | | | | | |
| srli.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| srai.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| **2RI12型 — 逻辑运算** | | | | | | | | |
| xori | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| andi | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| **2RI12型 — 比较运算** | | | | | | | | |
| slti | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| sltui | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| **2RI12型 — Load 指令（多周期）** | | | | | | | | |
| ld.b | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| ld.bu | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| ld.h | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| ld.hu | NPC.npc | PC.pc | — | — | IN.inst[9:5] | — | IN.inst[4:0] | PC4 |
| **2RI12型 — Store 指令（多周期）** | | | | | | | | |
| st.b | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[4:0] | — | PC4 |
| st.h | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[4:0] | — | PC4 |
| st.w | NPC.npc | PC.pc | — | — | IN.inst[9:5] | IN.inst[4:0] | — | PC4 |
| **1RI20型** | | | | | | | | |
| pcaddu12i | NPC.npc | PC.pc | — | — | — | — | IN.inst[4:0] | PC4 |
| **2RI16型 — 条件分支** | | | | | | | | |
| blt | NPC.npc | PC.pc | EXT.ext | ALU.br | IN.inst[9:5] | IN.inst[4:0] | — | BRANCH |
| bge | NPC.npc | PC.pc | EXT.ext | ALU.br | IN.inst[9:5] | IN.inst[4:0] | — | BRANCH |
| bltu | NPC.npc | PC.pc | EXT.ext | ALU.br | IN.inst[9:5] | IN.inst[4:0] | — | BRANCH |
| bgeu | NPC.npc | PC.pc | EXT.ext | ALU.br | IN.inst[9:5] | IN.inst[4:0] | — | BRANCH |
| **2RI16型 — 间接跳转** | | | | | | | | |
| jirl | ALU.c | PC.pc | EXT.ext | — | IN.inst[9:5] | — | IN.inst[4:0] | JR |
| **I26型 — 直接跳转** | | | | | | | | |
| bl | NPC.npc | PC.pc | EXT.ext | — | — | — | IN.inst[4:0]* | JUMP |

> \* BL 的 wR 固定为 5'h1（$ra 寄存器），由 wr_sel 信号控制（wr_sel=WR_Rr1 时 wR=5'h1）。

### 2.2 执行单元 + 存储单元 数据通路

| 指令 | 执行单元 | | | | 存储单元 | | | | 控制信号 | | | | |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | EXT | | ALU | | | MREQ | | MEXT | | | | | | |
| | wD | imm | A | B | | ram_addr | ram_wdata | din | byte_offs | ext_op | alu_op | alub_sel | ram_rop | ram_wop |
| **已实现指令** | | | | | | | | | | | | | |
| addi.w | ALU.C | IN.inst[21:10] | RF.rD1 | EXT.ext | | — | — | — | — | SIGN_12 | ADD | SEL_EXT | 0 | 0 |
| ori | ALU.C | IN.inst[21:10] | RF.rD1 | EXT.ext | | — | — | — | — | UNSIGN_12 | OR | SEL_EXT | 0 | 0 |
| slli.w | ALU.C | IN.inst[14:10] | RF.rD1 | EXT.ext | | — | — | — | — | UNSIGN_5 | SLL | SEL_EXT | 0 | 0 |
| lu12i.w | EXT.ext | IN.inst[24:5] | — | — | | — | — | — | — | SIGN_20 | — | — | 0 | 0 |
| ld.w | MEXT.ext | IN.inst[21:10] | RF.rD1 | EXT.ext | | ALU.C | — | IN.daccess_rdata | — | SIGN_12 | ADD | SEL_EXT | RAM_EXT_W | 0 |
| beq | — | IN.inst[25:10] | RF.rD1 | RF.rD2 | | — | — | — | — | SIGN_16 | EQ | SEL_R2 | 0 | 0 |
| bne | — | IN.inst[25:10] | RF.rD1 | RF.rD2 | | — | — | — | — | SIGN_16 | NE | SEL_R2 | 0 | 0 |
| b | — | IN.inst[9:0\|25:10] | — | — | | — | — | — | — | SIGN_26 | — | — | 0 | 0 |
| **3R型 — 移位运算** | | | | | | | | | | | | | |
| sll.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | SLL | SEL_R2 | 0 | 0 |
| srl.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | SRL | SEL_R2 | 0 | 0 |
| sra.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | SRA | SEL_R2 | 0 | 0 |
| **3R型 — 算术运算** | | | | | | | | | | | | | |
| add.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | ADD | SEL_R2 | 0 | 0 |
| sub.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | SUB | SEL_R2 | 0 | 0 |
| **3R型 — 逻辑运算** | | | | | | | | | | | | | |
| and | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | AND | SEL_R2 | 0 | 0 |
| or | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | OR | SEL_R2 | 0 | 0 |
| xor | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | XOR | SEL_R2 | 0 | 0 |
| **3R型 — 比较运算** | | | | | | | | | | | | | |
| slt | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | SLT | SEL_R2 | 0 | 0 |
| sltu | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | SLTU | SEL_R2 | 0 | 0 |
| **3R型 — 乘除法运算（多周期）** | | | | | | | | | | | | | |
| mul.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | MUL | SEL_R2 | 0 | 0 |
| mulh.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | MULH | SEL_R2 | 0 | 0 |
| mulh.wu | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | MULHU | SEL_R2 | 0 | 0 |
| div.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | DIV | SEL_R2 | 0 | 0 |
| div.wu | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | DIVU | SEL_R2 | 0 | 0 |
| mod.w | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | MOD | SEL_R2 | 0 | 0 |
| mod.wu | ALU.C | — | RF.rD1 | RF.rD2 | | — | — | — | — | — | MODU | SEL_R2 | 0 | 0 |
| **2RI5型 — 移位运算** | | | | | | | | | | | | | |
| srli.w | ALU.C | IN.inst[14:10] | RF.rD1 | EXT.ext | | — | — | — | — | UNSIGN_5 | SRL | SEL_EXT | 0 | 0 |
| srai.w | ALU.C | IN.inst[14:10] | RF.rD1 | EXT.ext | | — | — | — | — | UNSIGN_5 | SRA | SEL_EXT | 0 | 0 |
| **2RI12型 — 逻辑运算** | | | | | | | | | | | | | |
| xori | ALU.C | IN.inst[21:10] | RF.rD1 | EXT.ext | | — | — | — | — | UNSIGN_12 | XOR | SEL_EXT | 0 | 0 |
| andi | ALU.C | IN.inst[21:10] | RF.rD1 | EXT.ext | | — | — | — | — | UNSIGN_12 | AND | SEL_EXT | 0 | 0 |
| **2RI12型 — 比较运算** | | | | | | | | | | | | | |
| slti | ALU.C | IN.inst[21:10] | RF.rD1 | EXT.ext | | — | — | — | — | SIGN_12 | SLT | SEL_EXT | 0 | 0 |
| sltui | ALU.C | IN.inst[21:10] | RF.rD1 | EXT.ext | | — | — | — | — | UNSIGN_12 | SLTU | SEL_EXT | 0 | 0 |
| **2RI12型 — Load 指令（多周期）** | | | | | | | | | | | | | |
| ld.b | MEXT.ext | IN.inst[21:10] | RF.rD1 | EXT.ext | | ALU.C | — | IN.daccess_rdata | ALU.C[1:0] | SIGN_12 | ADD | SEL_EXT | RAM_EXT_B | 0 |
| ld.bu | MEXT.ext | IN.inst[21:10] | RF.rD1 | EXT.ext | | ALU.C | — | IN.daccess_rdata | ALU.C[1:0] | SIGN_12 | ADD | SEL_EXT | RAM_EXT_BU | 0 |
| ld.h | MEXT.ext | IN.inst[21:10] | RF.rD1 | EXT.ext | | ALU.C | — | IN.daccess_rdata | ALU.C[1:0] | SIGN_12 | ADD | SEL_EXT | RAM_EXT_H | 0 |
| ld.hu | MEXT.ext | IN.inst[21:10] | RF.rD1 | EXT.ext | | ALU.C | — | IN.daccess_rdata | ALU.C[1:0] | SIGN_12 | ADD | SEL_EXT | RAM_EXT_HU | 0 |
| **2RI12型 — Store 指令（多周期）** | | | | | | | | | | | | | |
| st.b | — | IN.inst[21:10] | RF.rD1 | EXT.ext | | ALU.C | RF.rD2 | — | — | SIGN_12 | ADD | SEL_EXT | 0 | RAM_WE_B |
| st.h | — | IN.inst[21:10] | RF.rD1 | EXT.ext | | ALU.C | RF.rD2 | — | — | SIGN_12 | ADD | SEL_EXT | 0 | RAM_WE_H |
| st.w | — | IN.inst[21:10] | RF.rD1 | EXT.ext | | ALU.C | RF.rD2 | — | — | SIGN_12 | ADD | SEL_EXT | 0 | RAM_WE_W |
| **1RI20型** | | | | | | | | | | | | | |
| pcaddu12i | ALU.C | IN.inst[24:5] | PC.pc | EXT.ext | | — | — | — | — | SIGN_20 | ADD | SEL_EXT | 0 | 0 |
| **2RI16型 — 条件分支** | | | | | | | | | | | | | |
| blt | — | IN.inst[25:10] | RF.rD1 | RF.rD2 | | — | — | — | — | SIGN_16 | BLT | SEL_R2 | 0 | 0 |
| bge | — | IN.inst[25:10] | RF.rD1 | RF.rD2 | | — | — | — | — | SIGN_16 | BGE | SEL_R2 | 0 | 0 |
| bltu | — | IN.inst[25:10] | RF.rD1 | RF.rD2 | | — | — | — | — | SIGN_16 | BLTU | SEL_R2 | 0 | 0 |
| bgeu | — | IN.inst[25:10] | RF.rD1 | RF.rD2 | | — | — | — | — | SIGN_16 | BGEU | SEL_R2 | 0 | 0 |
| **2RI16型 — 间接跳转** | | | | | | | | | | | | | |
| jirl | ALU.C | IN.inst[25:10] | PC.pc | EXT.ext | | — | — | — | — | SIGN_16 | ADD | SEL_EXT | 0 | 0 |
| **I26型 — 直接跳转** | | | | | | | | | | | | | |
| bl | ALU.C | IN.inst[9:0\|25:10] | PC.pc | — | | — | — | — | — | SIGN_26 | ADD | — | 0 | 0 |

> **注**: "—" 表示不关心或不使用。

---

## 三、新增控制信号宏定义参考

### ALU 操作扩展
| 宏定义 | 功能 | 使用指令 |
| --- | --- | --- |
| `ALU_ADD` | a + b | addi.w, ld.w, st.*, add.w, pcaddu12i, jirl, bl |
| `ALU_SUB` | a - b | sub.w |
| `ALU_OR` | a \| b | ori, or |
| `ALU_AND` | a & b | and, andi |
| `ALU_XOR` | a ^ b | xor, xori |
| `ALU_SLL` | a << b[4:0] | slli.w, sll.w |
| `ALU_SRL` | a >> b[4:0] (逻辑) | srli.w, srl.w |
| `ALU_SRA` | a >> b[4:0] (算术) | srai.w, sra.w |
| `ALU_SLT` | (a < b) 有符号 | slt, slti |
| `ALU_SLTU` | (a < b) 无符号 | sltu, sltui |
| `ALU_BEQ` | br = (a == b) | beq |
| `ALU_BNE` | br = (a != b) | bne |
| `ALU_BLT` | br = (a < b) 有符号 | blt |
| `ALU_BGE` | br = (a >= b) 有符号 | bge |
| `ALU_BLTU` | br = (a < b) 无符号 | bltu |
| `ALU_BGEU` | br = (a >= b) 无符号 | bgeu |
| `ALU_MUL` | (a * b)[31:0] | mul.w |
| `ALU_MULH` | (a * b)[63:32] 有符号 | mulh.w |
| `ALU_MULHU` | (a * b)[63:32] 无符号 | mulh.wu |
| `ALU_DIV` | a / b 有符号 (商) | div.w |
| `ALU_DIVU` | a / b 无符号 (商) | div.wu |
| `ALU_MOD` | a % b 有符号 (余数) | mod.w |
| `ALU_MODU` | a % b 无符号 (余数) | mod.wu |

### RAM 读操作扩展
| 宏定义 | 功能 | 使用指令 |
| --- | --- | --- |
| `RAM_EXT_N` | 无访存 | (默认) |
| `RAM_EXT_W` | 读32位字 (直通) | ld.w |
| `RAM_EXT_B` | 读8位字节 (符号扩展) | ld.b |
| `RAM_EXT_BU` | 读8位字节 (零扩展) | ld.bu |
| `RAM_EXT_H` | 读16位半字 (符号扩展) | ld.h |
| `RAM_EXT_HU` | 读16位半字 (零扩展) | ld.hu |

### RAM 写操作扩展
| 宏定义 | 功能 | 使用指令 |
| --- | --- | --- |
| `RAM_WE_N` | 无写 | (默认) |
| `RAM_WE_B` | 写8位字节 | st.b |
| `RAM_WE_H` | 写16位半字 | st.h |
| `RAM_WE_W` | 写32位字 | st.w |

### NPC 操作扩展
| 宏定义 | 功能 | 使用指令 |
| --- | --- | --- |
| `NPC_PC4` | PC + 4 | 大部分算术/逻辑/Load/Store 指令 |
| `NPC_BRCH` | if br then PC+offset else PC+4 | beq, bne, blt, bge, bltu, bgeu |
| `NPC_JMP` | PC + offset (直接跳转) | b, bl |
| `NPC_JR` | ALU结果 (间接跳转) | jirl |

### 指令分类汇总

| 类型 | 指令 | 特点 |
| --- | --- | --- |
| **单周期 ALU** | addi.w, ori, xori, andi, slli.w, srli.w, srai.w, slti, sltui, add.w, sub.w, and, or, xor, sll.w, srl.w, sra.w, slt, sltu, lu12i.w, pcaddu12i | 1 个时钟执行完毕 |
| **单周期 分支** | beq, bne, blt, bge, bltu, bgeu, b | 1 个时钟执行完毕 |
| **单周期 跳转** | bl, jirl | 1 个时钟 (但 jirl 需加 NPC_JR) |
| **多周期 乘除** | mul.w, mulh.w, mulh.wu, div.w, div.wu, mod.w, mod.wu | N 个时钟运算 (mul_div_flag 控制) |
| **多周期 访存** | ld.w, ld.b, ld.bu, ld.h, ld.hu, st.w, st.b, st.h | 等待 daccess_rvalid / daccess_wresp |

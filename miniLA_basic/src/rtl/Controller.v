`timescale 1ns / 1ps

`include "defines.vh"

module Controller (
    input  wire [31:15] inst_31_15,
    output wire [ 1: 0] npc_op,
    output wire [ 2: 0] ext_op,
    output wire         r2_sel,
    output wire         alua_sel,
    output wire         alub_sel,
    output wire [ 4: 0] alu_op,
    output wire         is_mul,
    output wire         is_div,
    output wire [ 2: 0] ram_r_op,
    output wire [ 3: 0] ram_w_op,
    output wire         rf_we,
    output wire         wr_sel,
    output wire [ 1: 0] rf_wsel
);

    // ================================================================
    // 示例指令 (模板工程已实现)
    // ================================================================
    wire LU12I_W   = (inst_31_15[31:25] == 7'h0A    );
    wire ADDI_W    = (inst_31_15[31:22] == 10'h00A  );
    wire SLLI_W    = (inst_31_15[31:15] == 17'h00081);
    wire LD_W      = (inst_31_15[31:22] == 10'h0A2  );
    wire BEQ       = (inst_31_15[31:26] == 6'h16    );
    wire BNE       = (inst_31_15[31:26] == 6'h17    );
    wire B         = (inst_31_15[31:26] == 6'h14    );
    wire ORI       = (inst_31_15[31:22] == 10'h00E  );

    // ================================================================
    // A组 — 移位运算 (3R型 + 2RI5型)
    // ================================================================
    wire SLL_W     = (inst_31_15[31:15] == 17'h0002E);
    wire SRL_W     = (inst_31_15[31:15] == 17'h0002F);
    wire SRLI_W    = (inst_31_15[31:15] == 17'h00089);
    wire SRA_W     = (inst_31_15[31:15] == 17'h00030);
    wire SRAI_W    = (inst_31_15[31:15] == 17'h00111);

    // ================================================================
    // A组 — 算术运算 (3R型 + 1RI20型)
    // ================================================================
    wire ADD_W     = (inst_31_15[31:15] == 17'h00020);
    wire SUB_W     = (inst_31_15[31:15] == 17'h00022);
    wire PCADDU12I = (inst_31_15[31:25] == 7'h0E    );

    // ================================================================
    // A组 — 逻辑运算 (3R型 + 2RI12型)
    // ================================================================
    wire XOR_      = (inst_31_15[31:15] == 17'h0002B);
    wire XORI      = (inst_31_15[31:22] == 10'h03F  );

    // ================================================================
    // A组 — Load 访存 (2RI12型)
    // ================================================================
    wire LD_B      = (inst_31_15[31:22] == 10'h0A0  );
    wire LD_BU     = (inst_31_15[31:22] == 10'h0A8  );
    wire LD_H      = (inst_31_15[31:22] == 10'h0A1  );
    wire LD_HU     = (inst_31_15[31:22] == 10'h0A9  );

    // ================================================================
    // A组 — Store 访存 (2RI12型)
    // ================================================================
    wire ST_B      = (inst_31_15[31:22] == 10'h0A4  );
    wire ST_H      = (inst_31_15[31:22] == 10'h0A5  );
    wire ST_W      = (inst_31_15[31:22] == 10'h0A6  );

    // ================================================================
    // A组 — 跳转 (2RI16型 + I26型)
    // ================================================================
    wire JIRL      = (inst_31_15[31:26] == 6'h13    );
    wire BL        = (inst_31_15[31:26] == 6'h15    );

    // ================================================================
    // 指令分组 (方便写控制信号)
    // ================================================================
    wire IS_3R     = SLL_W | SRL_W | SRA_W | ADD_W | SUB_W | XOR_;
    wire IS_2RI5   = SRLI_W | SRAI_W;
    wire IS_LOAD   = LD_W | LD_B | LD_BU | LD_H | LD_HU;
    wire IS_STORE  = ST_B | ST_H | ST_W;
    wire IS_LDST   = IS_LOAD | IS_STORE;
    wire IS_BRCH   = BEQ | BNE;
    wire IS_JUMP   = B | BL;

    // ================================================================
    // npc_op
    // ================================================================
    wire NPC_OP_BRCH = IS_BRCH;
    wire NPC_OP_JMP  = IS_JUMP;
    wire NPC_OP_JR   = JIRL;
    wire NPC_OP_PC4  = !NPC_OP_BRCH & !NPC_OP_JMP & !NPC_OP_JR;

    // ================================================================
    // ext_op
    // ================================================================
    wire EXT_OP_5   = SLLI_W | SRLI_W | SRAI_W;
    wire EXT_OP_12U = ORI | XORI;
    wire EXT_OP_12  = ADDI_W | IS_LOAD | IS_STORE;
    wire EXT_OP_16  = IS_BRCH | JIRL;
    wire EXT_OP_20  = LU12I_W | PCADDU12I;
    wire EXT_OP_26  = IS_JUMP;

    // ================================================================
    // alu_op
    // ================================================================
    wire ALU_OP_ADD  = ADDI_W | IS_LOAD | IS_STORE | ADD_W | PCADDU12I | JIRL | BL;
    wire ALU_OP_SUB  = SUB_W;
    wire ALU_OP_OR   = ORI;
    wire ALU_OP_XOR  = XOR_ | XORI;
    wire ALU_OP_SLL  = SLLI_W | SLL_W;
    wire ALU_OP_SRL  = SRL_W | SRLI_W;
    wire ALU_OP_SRA  = SRA_W | SRAI_W;
    wire ALU_OP_EQ   = BEQ;
    wire ALU_OP_NE   = BNE;
    // B组预留 (暂时为0)
    wire ALU_OP_AND  = 1'b0;
    wire ALU_OP_SLT  = 1'b0;
    wire ALU_OP_SLTU = 1'b0;
    wire ALU_OP_BLT  = 1'b0;
    wire ALU_OP_BGE  = 1'b0;
    wire ALU_OP_BLTU = 1'b0;
    wire ALU_OP_BGEU = 1'b0;

    // ================================================================
    // r2_sel: 1=inst[14:10](rk), 0=inst[4:0](rd)
    // ================================================================
    wire R2_SEL_RD = IS_BRCH | IS_STORE;

    // ================================================================
    // alua_sel: 0=PC.pc, 1=RF.rD1
    // ================================================================
    wire ALU_A_SEL_PC = PCADDU12I | JIRL | BL;

    // ================================================================
    // alub_sel: 0=EXT.ext, 1=RF.rD2
    // ================================================================
    wire ALU_B_SEL_EXT = SLLI_W | SRLI_W | SRAI_W | ADDI_W | ORI | XORI
                       | IS_LOAD | IS_STORE | PCADDU12I | JIRL;

    // ================================================================
    // ram_r_op
    // ================================================================
    wire RAM_EXT_W  = LD_W;
    wire RAM_EXT_B  = LD_B;
    wire RAM_EXT_BU = LD_BU;
    wire RAM_EXT_H  = LD_H;
    wire RAM_EXT_HU = LD_HU;

    // ================================================================
    // ram_w_op
    // ================================================================
    wire RAM_W_B = ST_B;
    wire RAM_W_H = ST_H;
    wire RAM_W_W = ST_W;

    // ================================================================
    // rf_we
    // ================================================================
    wire RF_OP_WE = LU12I_W | ADDI_W | SLLI_W | LD_W | ORI
                  | IS_3R | IS_2RI5 | PCADDU12I | XORI
                  | LD_B | LD_BU | LD_H | LD_HU
                  | JIRL | BL;

    // ================================================================
    // wr_sel: 1=rd, 0=$ra(5'h1)
    // ================================================================
    wire WR_SEL_R1 = BL;

    // ================================================================
    // rf_wsel: 写回数据源
    // ================================================================
    wire WB_OP_PC4 = JIRL | BL;
    wire WB_OP_RAM = IS_LOAD;
    wire WB_OP_EXT = LU12I_W;
    wire WB_OP_ALU = (ADDI_W | SLLI_W | ORI | IS_3R | IS_2RI5
                   |  PCADDU12I | XORI) & !WB_OP_PC4;

    // ================================================================
    // 输出编码
    // ================================================================
    assign npc_op = {2{NPC_OP_PC4 }} & `NPC_PC4  |
                    {2{NPC_OP_JR  }} & `NPC_JR   |
                    {2{NPC_OP_BRCH}} & `NPC_BRCH |
                    {2{NPC_OP_JMP }} & `NPC_JMP;

    assign ext_op = {3{EXT_OP_5  }} & `EXT_5   |
                    {3{EXT_OP_12U}} & `EXT_12U |
                    {3{EXT_OP_12 }} & `EXT_12  |
                    {3{EXT_OP_16 }} & `EXT_16  |
                    {3{EXT_OP_20 }} & `EXT_20  |
                    {3{EXT_OP_26 }} & `EXT_26;

    assign r2_sel = R2_SEL_RD ? `R2_RD : `R2_RK;

    assign alua_sel = ALU_A_SEL_PC ? `ALUA_PC : `ALUA_R1;

    assign alub_sel = ALU_B_SEL_EXT ? `ALUB_EXT : `ALUB_R2;

    assign alu_op = {5{ALU_OP_ADD  }} & `ALU_ADD   |
                    {5{ALU_OP_SUB  }} & `ALU_SUB   |
                    {5{ALU_OP_OR   }} & `ALU_OR    |
                    {5{ALU_OP_AND  }} & `ALU_AND   |
                    {5{ALU_OP_XOR  }} & `ALU_XOR   |
                    {5{ALU_OP_SLL  }} & `ALU_SLL   |
                    {5{ALU_OP_SRL  }} & `ALU_SRL   |
                    {5{ALU_OP_SRA  }} & `ALU_SRA   |
                    {5{ALU_OP_SLT  }} & `ALU_SLT   |
                    {5{ALU_OP_SLTU }} & `ALU_SLTU  |
                    {5{ALU_OP_EQ   }} & `ALU_BEQ   |
                    {5{ALU_OP_NE   }} & `ALU_BNE   |
                    {5{ALU_OP_BLT  }} & `ALU_BLT   |
                    {5{ALU_OP_BGE  }} & `ALU_BGE   |
                    {5{ALU_OP_BLTU }} & `ALU_BLTU  |
                    {5{ALU_OP_BGEU }} & `ALU_BGEU;

    assign is_mul = 1'b0;
    assign is_div = 1'b0;

    assign ram_r_op = {3{RAM_EXT_B }} & `RAM_EXT_B  |
                      {3{RAM_EXT_BU}} & `RAM_EXT_BU |
                      {3{RAM_EXT_H }} & `RAM_EXT_H  |
                      {3{RAM_EXT_HU}} & `RAM_EXT_HU |
                      {3{RAM_EXT_W }} & `RAM_EXT_W;

    assign ram_w_op = {4{RAM_W_B}} & `RAM_WE_B |
                      {4{RAM_W_H}} & `RAM_WE_H |
                      {4{RAM_W_W}} & `RAM_WE_W;

    assign rf_we = RF_OP_WE;

    assign wr_sel = WR_SEL_R1 ? `WR_Rr1 : `WR_RD;

    assign rf_wsel = {2{WB_OP_PC4}} & `WB_PC4 |
                     {2{WB_OP_ALU}} & `WB_ALU |
                     {2{WB_OP_RAM}} & `WB_RAM |
                     {2{WB_OP_EXT}} & `WB_EXT;

endmodule

`timescale 1ns / 1ps

`include "defines.vh"

module Controller (
    input  wire [ 6:0]  opcode,
    input  wire [ 2:0]  funct3,
    input  wire [ 6:0]  funct7,
    output wire [ 1:0]  npc_op,
    output wire [ 2:0]  sext_op,
    output wire         alua_sel,
    output wire         alub_sel,
    output wire [ 4:0]  alu_op,
    output wire         is_mul,
    output wire         is_div,
    output wire [ 2:0]  ram_r_op,
    output wire [ 3:0]  ram_w_op,
    output wire         rf_we,
    output wire [ 1:0]  rf_wsel
);

    wire op_imm = opcode == 7'b0010011;
    wire op_reg = opcode == 7'b0110011;
    wire op_load = opcode == 7'b0000011;
    wire op_store = opcode == 7'b0100011;
    wire op_branch = opcode == 7'b1100011;

    wire ADDI  = op_imm && funct3 == 3'b000;
    wire SLTI  = op_imm && funct3 == 3'b010;
    wire SLTIU = op_imm && funct3 == 3'b011;
    wire XORI  = op_imm && funct3 == 3'b100;
    wire ORI   = op_imm && funct3 == 3'b110;
    wire ANDI  = op_imm && funct3 == 3'b111;
    wire SLLI  = op_imm && funct3 == 3'b001 && funct7 == 7'b0000000;
    wire SRLI  = op_imm && funct3 == 3'b101 && funct7 == 7'b0000000;
    wire SRAI  = op_imm && funct3 == 3'b101 && funct7 == 7'b0100000;

    wire ADD   = op_reg && funct3 == 3'b000 && funct7 == 7'b0000000;
    wire SUB   = op_reg && funct3 == 3'b000 && funct7 == 7'b0100000;
    wire SLL   = op_reg && funct3 == 3'b001 && funct7 == 7'b0000000;
    wire SLT   = op_reg && funct3 == 3'b010 && funct7 == 7'b0000000;
    wire SLTU  = op_reg && funct3 == 3'b011 && funct7 == 7'b0000000;
    wire XOR   = op_reg && funct3 == 3'b100 && funct7 == 7'b0000000;
    wire SRL   = op_reg && funct3 == 3'b101 && funct7 == 7'b0000000;
    wire SRA   = op_reg && funct3 == 3'b101 && funct7 == 7'b0100000;
    wire OR    = op_reg && funct3 == 3'b110 && funct7 == 7'b0000000;
    wire AND   = op_reg && funct3 == 3'b111 && funct7 == 7'b0000000;

    wire MUL   = op_reg && funct7 == 7'b0000001 && funct3 == 3'b000;
    wire MULH  = op_reg && funct7 == 7'b0000001 && funct3 == 3'b001;
    wire MULHU = op_reg && funct7 == 7'b0000001 && funct3 == 3'b011;
    wire DIV   = op_reg && funct7 == 7'b0000001 && funct3 == 3'b100;
    wire DIVU  = op_reg && funct7 == 7'b0000001 && funct3 == 3'b101;
    wire REM   = op_reg && funct7 == 7'b0000001 && funct3 == 3'b110;
    wire REMU  = op_reg && funct7 == 7'b0000001 && funct3 == 3'b111;

    wire LB  = op_load && funct3 == 3'b000;
    wire LH  = op_load && funct3 == 3'b001;
    wire LW  = op_load && funct3 == 3'b010;
    wire LBU = op_load && funct3 == 3'b100;
    wire LHU = op_load && funct3 == 3'b101;
    wire SB  = op_store && funct3 == 3'b000;
    wire SH  = op_store && funct3 == 3'b001;
    wire SW  = op_store && funct3 == 3'b010;

    wire BEQ  = op_branch && funct3 == 3'b000;
    wire BNE  = op_branch && funct3 == 3'b001;
    wire BLT  = op_branch && funct3 == 3'b100;
    wire BGE  = op_branch && funct3 == 3'b101;
    wire BLTU = op_branch && funct3 == 3'b110;
    wire BGEU = op_branch && funct3 == 3'b111;

    wire LUI   = opcode == 7'b0110111;
    wire AUIPC = opcode == 7'b0010111;
    wire JAL   = opcode == 7'b1101111;
    wire JALR  = opcode == 7'b1100111 && funct3 == 3'b000;

    wire imm_alu = ADDI | SLTI | SLTIU | XORI | ORI | ANDI |
                   SLLI | SRLI | SRAI;
    wire reg_alu = ADD | SUB | SLL | SLT | SLTU | XOR | SRL | SRA |
                   OR | AND | MUL | MULH | MULHU | DIV | DIVU | REM | REMU;
    wire load_any = LB | LH | LW | LBU | LHU;
    wire store_any = SB | SH | SW;
    wire branch_any = BEQ | BNE | BLT | BGE | BLTU | BGEU;

    assign npc_op = JALR      ? `NPC_JALR :
                    JAL       ? `NPC_JMP  :
                    branch_any ? `NPC_BRA : `NPC_PC4;

    assign rf_we = imm_alu | reg_alu | load_any | LUI | AUIPC | JAL | JALR;

    assign rf_wsel = load_any    ? `WB_RAM :
                     (JAL | JALR) ? `WB_PC4 :
                     LUI          ? `WB_EXT : `WB_ALU;

    assign sext_op = store_any  ? `EXT_S :
                     branch_any ? `EXT_B :
                     (LUI | AUIPC) ? `EXT_U :
                     JAL        ? `EXT_J : `EXT_I;

    assign alu_op = SUB  ? `ALU_SUB  :
                    (XOR | XORI) ? `ALU_XOR :
                    (OR | ORI)   ? `ALU_OR  :
                    (AND | ANDI) ? `ALU_AND :
                    (SLL | SLLI) ? `ALU_SLL :
                    (SRL | SRLI) ? `ALU_SRL :
                    (SRA | SRAI) ? `ALU_SRA :
                    (SLT | SLTI | BLT)   ? `ALU_SLT  :
                    BGE                   ? `ALU_SGE  :
                    (SLTU | SLTIU | BLTU) ? `ALU_SLTU :
                    BGEU                  ? `ALU_SGEU :
                    BEQ  ? `ALU_EQ    :
                    BNE  ? `ALU_NE    :
                    MUL  ? `ALU_MUL   :
                    MULH ? `ALU_MULH  :
                    MULHU ? `ALU_MULHU :
                    DIV  ? `ALU_DIV   :
                    DIVU ? `ALU_DIVU  :
                    REM  ? `ALU_REM   :
                    REMU ? `ALU_REMU  : `ALU_ADD;

    assign alua_sel = AUIPC ? `ALU_A_PC : `ALU_A_RS1;
    assign alub_sel = (imm_alu | load_any | store_any | AUIPC | JALR) ?
                      `ALU_B_EXT : `ALU_B_RS2;

    assign ram_r_op = LB  ? `RAM_EXT_B  :
                          LBU ? `RAM_EXT_BU :
                          LH  ? `RAM_EXT_H  :
                          LHU ? `RAM_EXT_HU :
                          LW  ? `RAM_EXT_W  : `RAM_EXT_N;

    assign ram_w_op = SB ? `RAM_WE_B :
                          SH ? `RAM_WE_H :
                          SW ? `RAM_WE_W : `RAM_WE_N;

    assign is_mul = MUL | MULH | MULHU;
    assign is_div = DIV | DIVU | REM | REMU;

endmodule

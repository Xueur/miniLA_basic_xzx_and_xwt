`timescale 1ns / 1ps

module NPC (
    input  wire [ 1:0]  op,
    input  wire [31:0]  pc,
    input  wire [31:0]  offset,
    input  wire         br,
    input  wire [31:0]  jr_target,    // JIRL跳转目标 (ALU.c)

    output reg  [31:0]  npc,
    output wire [31:0]  pc4
);

    assign pc4 = pc + 32'h4;

    always @(*) begin
        case (op)
            `NPC_PC4 : npc = pc4;
            `NPC_JR  : npc = jr_target;             // JIRL: npc = rj + sext(offs)
            `NPC_BRCH: npc = br ? pc + offset : pc4;
            `NPC_JMP : npc = pc + offset;            // B, BL
            default  : npc = pc4;
        endcase
    end

endmodule
